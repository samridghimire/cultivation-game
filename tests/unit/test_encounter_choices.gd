extends TestCase
## W-004c: encounters with player choices and flag-gated follow-up encounters.

const TRAVELLER := {
	"id": "test_traveller", "tags": ["test_tag"], "weight": 1, "kind": "neutral", "days": 1,
	"text": "A wounded traveller lies by the road.",
	"choices": [
		{"label": "Bind his wounds", "text": "He thanks you.", "days": 2, "effects": {"alignment": 10, "set_flag": "test_helped"}},
		{"label": "Rob him", "text": "You take his pouch.", "requires": {"max_alignment": 0}, "effects": {"alignment": -10, "items": {"spirit_stone": 5}}},
		{"label": "Pay for his medicine", "effects": {"items": {"spirit_stone": -50}}},
		{"label": "Challenge the bandits who hurt him", "enemy": "wild_boar", "requires": {"min_realm": "qi_refining"}},
	],
}
const FOLLOW_UP := {"id": "test_grateful", "tags": ["test_tag"], "weight": 1, "kind": "fortune", "days": 1, "requires_flag": "test_helped", "text": "The traveller returns with a gift.", "effects": {"qi": 50}}


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _data_with_test_encounters() -> GameData:
	var d := GameData.load_from_dir()
	d.encounters["test_traveller"] = TRAVELLER.duplicate(true)
	d.encounters["test_grateful"] = FOLLOW_UP.duplicate(true)
	return d


func test_choices_and_their_requirements() -> void:
	var d := _data_with_test_encounters()
	var c := new_character()
	c.alignment = 50
	c.inventory.erase("spirit_stone")
	var list := Exploration.choices(c, d, d.encounters["test_traveller"], {})
	assert_eq(list.size(), 4)
	assert_false(list[0]["disabled"])
	assert_true(list[1]["disabled"], "too righteous to rob")
	assert_true(String(list[2]["reason"]).contains("Spirit Stone"), "cannot pay")
	assert_true(list[3]["disabled"], "realm too low")
	c.alignment = 0
	c.realm_index = 1
	c.add_item("spirit_stone", 50)
	for entry in Exploration.choices(c, d, d.encounters["test_traveller"], {}):
		assert_false(entry["disabled"], String(entry["label"]))


func test_resolve_choice_applies_outcome() -> void:
	var d := _data_with_test_encounters()
	var c := new_character()
	var flags := {}
	var result := Exploration.resolve_choice(c, d, d.encounters["test_traveller"], 0, flags)
	assert_true(result["ok"])
	assert_eq(c.alignment, 10)
	assert_eq(int(result["days"]), 2)
	assert_eq(String(result["text"]), "He thanks you.")
	assert_true(result["karma"])
	assert_true(flags.get("test_helped", false))
	assert_false(Exploration.resolve_choice(c, d, d.encounters["test_traveller"], 1, flags)["ok"], "requirements enforced")
	assert_false(Exploration.resolve_choice(c, d, d.encounters["test_traveller"], 9, flags)["ok"], "bad index")
	c.realm_index = 1
	assert_eq(String(Exploration.resolve_choice(c, d, d.encounters["test_traveller"], 3, flags)["enemy"]), "wild_boar")


func test_requires_flag_gates_follow_ups() -> void:
	var d := _data_with_test_encounters()
	var ids := func(flags: Dictionary) -> Array:
		return Exploration.eligible_encounters(new_character(), d, ["test_tag"], flags).map(func(e): return e["encounter"]["id"])
	assert_false(ids.call({}).has("test_grateful"))
	assert_true(ids.call({"test_helped": true}).has("test_grateful"))


func test_choice_validation() -> void:
	assert_true(Exploration.validate_choices(data()).is_empty(), str(Exploration.validate_choices(data())))
	var d := GameData.new()
	d.realms = data().realms
	d.items = data().items
	d.enemies = data().enemies
	d.encounters = {
		"ok": TRAVELLER.duplicate(true),
		"bad": {"id": "bad", "enemy": "wild_boar", "requires_flag": "", "choices": [{"label": "", "enemy": "ghost", "days": -1, "requires": {"min_realm": "nope"}, "effects": {"items": {"air": 1}}}]},
	}
	assert_eq(Exploration.validate_choices(d).size(), 8, str(Exploration.validate_choices(d)))


func test_game_state_explore_and_choose() -> void:
	var gs: Node = _root().get_node("GameState")
	var clock: Node = _root().get_node("GameClock")
	var c := CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	gs.start_session(c)
	gs.data.encounters["test_traveller"] = TRAVELLER.duplicate(true)
	gs.data.encounters["test_grateful"] = FOLLOW_UP.duplicate(true)
	gs.world_flags["discovered_" + gs.current_region] = true
	var requested := []
	var on_request := func(id: String) -> void: requested.append(id)
	_root().get_node("EventBus").encounter_choice_requested.connect(on_request)
	gs.explore(["test_tag"])
	_root().get_node("EventBus").encounter_choice_requested.disconnect(on_request)
	assert_eq(requested, ["test_traveller"])
	assert_eq(gs.pending_encounter, "test_traveller")
	assert_eq(gs.encounter_choices().size(), 4)
	var days: int = clock.total_days
	c.alignment = 50
	gs.choose_encounter(1)
	assert_eq(gs.pending_encounter, "test_traveller", "refused choice keeps the encounter waiting")
	gs.choose_encounter(0)
	assert_eq(gs.pending_encounter, "")
	assert_eq(c.alignment, 60)
	assert_eq(clock.total_days, days + 2)
	assert_true(gs.world_flags.get("test_helped", false))
	gs.choose_encounter(0)
	assert_eq(c.alignment, 60, "nothing pending: no-op")
	gs.explore(["test_tag"])
	gs.pending_encounter = "test_traveller"
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.pending_encounter, "", "loading drops a pending choice")
	gs.end_session()
	gs.data.encounters.erase("test_traveller")
	gs.data.encounters.erase("test_grateful")


func test_wounded_traveller_choices_unlock_their_follow_ups() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 5
	var traveller: Dictionary = d.encounters["forest_wounded_traveller"]
	var ids := func(flags: Dictionary) -> Array:
		return Exploration.eligible_encounters(c, d, ["forest"], flags).map(func(e): return e["encounter"]["id"])
	assert_false(ids.call({}).has("wounded_traveller_repays"))
	assert_false(ids.call({}).has("wounded_traveller_kin_revenge"))
	var helped := {}
	Exploration.resolve_choice(c, d, traveller, 0, helped)
	assert_gt(c.alignment, 0)
	assert_true(ids.call(helped).has("wounded_traveller_repays"))
	assert_false(ids.call(helped).has("wounded_traveller_kin_revenge"))
	var robbed := {}
	Exploration.resolve_choice(c, d, traveller, 1, robbed)
	assert_true(ids.call(robbed).has("wounded_traveller_kin_revenge"))
	assert_false(ids.call(robbed).has("wounded_traveller_repays"))
	assert_eq(String(d.encounters["wounded_traveller_kin_revenge"]["enemy"]), "vengeful_brother")


## W-004g: slaying the vengeful brother brings his sect elder at Foundation
## Establishment; the repaid traveller later vouches for you at his sect.
func test_wounded_traveller_chain_continues() -> void:
	var d := data()
	var c := new_character()
	var ids := func(flags: Dictionary) -> Array:
		return Exploration.eligible_encounters(c, d, ["forest", "city"], flags).map(func(e): return e["encounter"]["id"])
	var flags := {"robbed_wounded_traveller": true, "wounded_traveller_avenged": true}
	c.realm_index = d.realm_index_of("foundation_establishment")
	assert_false(ids.call(flags).has("wounded_traveller_sect_elder"), "the brother was not slain")
	Effects.apply(c, d, d.enemies["vengeful_brother"]["rewards"], flags)
	assert_true(flags.get("slew_vengeful_brother", false))
	assert_true(ids.call(flags).has("wounded_traveller_sect_elder"))
	c.realm_index = d.realm_index_of("qi_refining")
	assert_false(ids.call(flags).has("wounded_traveller_sect_elder"), "the elder waits for Foundation Establishment")
	var repaid := {"helped_wounded_traveller": true, "wounded_traveller_repaid": true}
	assert_false(ids.call(repaid).has("wounded_traveller_vouches"), "later: at Foundation Establishment")
	c.realm_index = d.realm_index_of("foundation_establishment")
	assert_true(ids.call(repaid).has("wounded_traveller_vouches"))
	var before := Reputation.value(c, d, "azure_cloud_sect")
	Exploration.resolve(c, d, d.encounters["wounded_traveller_vouches"], repaid)
	assert_gt(Reputation.value(c, d, "azure_cloud_sect"), before)
	assert_false(ids.call(repaid).has("wounded_traveller_vouches"), "once")


## W-004g: sparing the pickpocket teaches the thieves' knock, which opens
## the red door's flag-locked choice.
func test_pickpocket_secret_unlocks_red_door() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.inventory = {"spirit_stone": 500}
	var flags := {}
	var door: Dictionary = d.encounters["city_red_door"]
	var list := Exploration.choices(c, d, door, flags)
	assert_true(list[0]["disabled"], "nobody told you the knock")
	assert_eq(String(list[0]["reason"]), "You lack the knowledge for that.")
	assert_false(list[1]["disabled"] or list[2]["disabled"])
	assert_true(Exploration.resolve_choice(c, d, d.encounters["city_pickpocket_caught"], 2, flags)["ok"])
	var ids := func() -> Array:
		return Exploration.eligible_encounters(c, d, ["city"], flags).map(func(e): return e["encounter"]["id"])
	assert_true(ids.call().has("pickpocket_shares_secret"))
	Exploration.resolve(c, d, d.encounters["pickpocket_shares_secret"], flags)
	assert_false(ids.call().has("pickpocket_shares_secret"))
	assert_false(Exploration.choices(c, d, door, flags)[0]["disabled"])
	assert_true(Exploration.resolve_choice(c, d, door, 0, flags)["ok"])
	assert_eq(c.item_count("foundation_establishment_pill"), 1)
	assert_gt(int(d.items["foundation_establishment_pill"]["price"]), 200, "a thief's price is a bargain")
	assert_gt(200, Items.sell_price(d, "foundation_establishment_pill"), "but not a resale profit")


## W-004e: a once-per-life choice encounter gives its prize once: every choice
## with an outcome sets the encounter's blocked_by_flag, and every
## requires_flag is set by some encounter or choice.
func test_choice_encounters_set_their_flags() -> void:
	var d := data()
	var set_flags := {}
	for e: Dictionary in d.encounters.values():
		for effects: Dictionary in encounter_outcomes(e):
			if effects.has("set_flag"):
				for f in Effects.flag_list(effects["set_flag"]):
					set_flags[f] = true
	for enemy: Dictionary in d.enemies.values():
		if enemy.get("rewards", {}).has("set_flag"):
			set_flags[enemy["rewards"]["set_flag"]] = true
	set_flags[Rivals.FIRST_MEETING_FLAG] = true  # set by GameState at the first meeting (RIVAL-003)
	for e: Dictionary in d.encounters.values():
		if e.has("requires_flag"):
			assert_true(set_flags.has(e["requires_flag"]), "%s waits on a flag nothing sets" % e["id"])
		var flag: String = e.get("blocked_by_flag", "")
		if flag == "" or not e.has("choices"):
			continue
		for choice: Dictionary in e["choices"]:
			var effects: Dictionary = choice.get("effects", {})
			if not effects.is_empty():
				assert_true(Effects.flag_list(effects.get("set_flag", "")).has(flag), "%s: %s" % [e["id"], choice["label"]])


func test_qilin_choice_grants_bloodline_and_is_locked_for_bloodline_bearers() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	var qilin: Dictionary = d.encounters["mountain_dying_qilin"]
	var flags := {}
	assert_true(Exploration.resolve_choice(c, d, qilin, 0, flags)["ok"])
	assert_eq(c.bloodline, "qilin")
	assert_true(c.bloodline_awakened)
	assert_true(flags.get("met_dying_qilin", false))
	var list := Exploration.choices(c, d, qilin, flags)
	assert_true(list[0]["disabled"] and list[1]["disabled"], "already carries a bloodline")
	assert_false(list[2]["disabled"], "walking away is always possible")


## W-004h: the Blood Lotus recruiter only seeks out the wicked, the wandering
## Azure Cloud elder only the virtuous, and Blood Lotus hunters spare their own.
func test_alignment_gated_encounters() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.stage = 3  # the executioner is stage-gated (C-031)
	var ids := func() -> Array:
		return Exploration.eligible_encounters(c, d, ["wild", "village", "city"], {}).map(func(e): return e["encounter"]["id"])
	c.alignment = 0
	assert_false(ids.call().has("wild_blood_lotus_recruiter"))
	assert_false(ids.call().has("village_righteous_elder"))
	assert_true(ids.call().has("wild_blood_lotus_executioner"))
	assert_true(ids.call().has("wild_sect_patrol"))
	c.alignment = 250
	assert_true(ids.call().has("village_righteous_elder"))
	assert_false(ids.call().has("wild_blood_lotus_recruiter"))
	c.alignment = -450
	assert_true(ids.call().has("wild_blood_lotus_recruiter"))
	assert_false(ids.call().has("village_righteous_elder"))
	assert_false(ids.call().has("wild_sect_patrol"), "righteous patrols don't share fire with the wicked")
	c.alignment = -700
	assert_false(ids.call().has("wild_blood_lotus_executioner"), "the Blood Lotus spares its own kind")
	var flags := {}
	var before := Reputation.value(c, d, "blood_lotus_sect")
	assert_true(Exploration.resolve_choice(c, d, d.encounters["wild_blood_lotus_recruiter"], 0, flags)["ok"])
	assert_gt(Reputation.value(c, d, "blood_lotus_sect"), before)
	assert_true(flags.get("met_blood_lotus_recruiter", false))


## C-082: three once-only encounters that raise an attribute by exactly 1.
func test_attribute_growth_encounters() -> void:
	var d := data()
	var cases := {
		"misty_forest_waterfall_weight": ["forest", "constitution"],
		"marsh_night_among_reeds": ["marsh", "spirit"],
		"fallen_star_market_weiqi_elder": ["city", "comprehension"],
	}
	for id: String in cases:
		var tag: String = cases[id][0]
		var attr: String = cases[id][1]
		var c := new_character()
		c.realm_index = d.realm_index_of("qi_refining")
		var flags := {}
		var e: Dictionary = d.encounters[id]
		var ids := func() -> Array:
			return Exploration.eligible_encounters(c, d, [tag], flags).map(func(x): return x["encounter"]["id"])
		assert_true(ids.call().has(id), id + " is eligible at Qi Refining")
		var before := c.attribute(attr)
		assert_true(Exploration.resolve_choice(c, d, e, 0, flags)["ok"])
		assert_eq(c.attribute(attr), before + 1, id + " raises " + attr + " by 1")
		assert_false(ids.call().has(id), id + " cannot repeat")
		var declined := new_character()
		var dflags := {}
		Exploration.resolve_choice(declined, d, e, 1, dflags)
		assert_eq(declined.attribute(attr), new_character().attribute(attr), id + " decline changes nothing")


func test_min_attributes_requirement() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var choice := {"label": "Answer", "requires": {"min_attributes": {"comprehension": 12}}}
	c.attributes["comprehension"] = 12
	assert_eq(Exploration.check_choice(c, d, choice, {}), "")
	c.attributes["comprehension"] = 11
	assert_eq(Exploration.check_choice(c, d, choice, {}), "You need Comprehension 12 for that.")


func test_min_attributes_validation() -> void:
	var d := GameData.load_from_dir()
	d.encounters["t_attr"] = {"id": "t_attr", "tags": ["x"], "weight": 1, "kind": "neutral", "days": 0, "text": "t", "choices": [
		{"label": "A", "requires": {"min_attributes": {"comprehension": 12}}},
		{"label": "B", "requires": {"min_attributes": {"wisdomness": 5, "comprehension": 0}}}]}
	var errors := Exploration.validate_choices(d)
	assert_eq(errors.size(), 2, str(errors))
	assert_true(errors[0].contains("wisdomness") and errors[1].contains("comprehension"), str(errors))


func test_min_profession_requirement() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var choice := {"label": "Treat", "requires": {"min_profession": {"doctor": 1}}}
	assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to "), "rank 0 blocked")
	assert_true(Exploration.check_choice(c, d, choice, {}).contains("Doctor"))
	c.professions["doctor"] = {"rank": 1, "xp": 0.0}
	assert_eq(Exploration.check_choice(c, d, choice, {}), "")


func test_min_profession_validation() -> void:
	var d := GameData.load_from_dir()
	d.encounters["t_prof"] = {"id": "t_prof", "tags": ["x"], "weight": 1, "kind": "neutral", "days": 0, "text": "t", "choices": [
		{"label": "A", "requires": {"min_profession": {"nonesuch": 1}}},
		{"label": "B", "requires": {"min_profession": {"doctor": -1}}},
		{"label": "C", "requires": {"min_profession": {"doctor": 0}}},
		{"label": "D", "requires": {"min_profession": {"doctor": Professions.max_rank(d) + 1}}}]}
	var errors := Exploration.validate_choices(d)
	assert_eq(errors.size(), 3, str(errors))
	assert_true(errors[0].contains("nonesuch") and errors[1].contains("doctor") and errors[2].contains("doctor"), str(errors))


## PROF-006: rank 0 asks only that you practise the craft.
func test_min_profession_rank_zero() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var zero := {"label": "Try", "requires": {"min_profession": {"doctor": 0}}}
	assert_true(Exploration.check_choice(c, d, zero, {}).begins_with("You need to practise Doctor"), "blocked without the craft")
	c.professions["doctor"] = {"rank": 0, "xp": 0.0}
	assert_eq(Exploration.check_choice(c, d, zero, {}), "")
	var two := {"label": "Try", "requires": {"min_profession": {"doctor": 2}}}
	c.professions["doctor"] = {"rank": 1, "xp": 0.0}
	assert_true(Exploration.check_choice(c, d, two, {}).begins_with("You need to be "), "rank 2 still blocked at 1")


func test_first_hours_choices_open_to_apprentice() -> void:
	var d := GameData.load_from_dir()
	for pair: Array in [["village_snapped_axle", "blacksmith"], ["forest_haunted_field", "talisman_master"],
			["forest_haunted_field", "array_master"], ["forest_charcoal_burners_fever", "alchemist"]]:
		var c := new_character()
		c.professions[pair[1]] = {"rank": 0, "xp": 0.0}
		var found := false
		for choice: Dictionary in d.encounters[pair[0]]["choices"]:
			if choice.get("requires", {}).get("min_profession", {}).has(pair[1]):
				found = true
				assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s open to a fresh %s" % [pair[0], pair[1]])
		assert_true(found, "%s has a %s choice" % [pair[0], pair[1]])


func test_choice_check_tag() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var e := {"choices": [
		{"label": "Plain"},
		{"label": "Wise", "requires": {"min_attributes": {"comprehension": 12}}},
		{"label": "Heal", "requires": {"min_profession": {"doctor": 1}}}]}
	var list := Exploration.choices(c, d, e, {})
	assert_eq(list[0]["check"], "")
	assert_eq(list[1]["check"], "Comprehension 12")
	assert_eq(list[2]["check"], "Doctor, 1st Grade")


## The encounter window prefixes "[<check tag>]", so a label must not repeat it ("... (Spirit 64)").
func test_choice_labels_do_not_repeat_their_check_tag() -> void:
	var d := GameData.load_from_dir()
	for id: String in d.encounters:
		for choice: Dictionary in d.encounters[id].get("choices", []):
			var label := String(choice.get("label", ""))
			for part: String in Exploration.check_tag(d, choice).split(", ", false):
				assert_false(label.contains("(" + part), "%s: '%s' repeats '%s'" % [id, label, part])


func test_choice_check_tag_alignment_and_cost() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var item_id: String = "qi_condensing_grass"
	var item_name: String = d.items[item_id].name
	var e := {"choices": [
		{"label": "Righteous", "requires": {"min_alignment": 300}},
		{"label": "Wicked", "requires": {"max_alignment": -300}},
		{"label": "Pay item", "effects": {"items": {item_id: -2}}},
		{"label": "Pay stones", "effects": {"items": {"spirit_stone": -30}}},
		{"label": "Both", "requires": {"min_attributes": {"comprehension": 12}}, "effects": {"items": {"spirit_stone": -30}}},
		{"label": "Gain", "effects": {"items": {item_id: 2}}}]}
	var list := Exploration.choices(c, d, e, {})
	assert_eq(list[0]["check"], Alignment.tier_name(300, d))
	assert_eq(list[1]["check"], Alignment.tier_name(-300, d))
	assert_eq(list[2]["check"], "2 " + item_name)
	assert_eq(list[3]["check"], "30 stones")
	assert_eq(list[4]["check"], "Comprehension 12, 30 stones")
	assert_eq(list[5]["check"], "")


func test_profession_answers_in_the_wilds() -> void:
	var d := GameData.load_from_dir()
	var answers := {
		"forest_wounded_traveller": "doctor",
		"marsh_slaughter_field": "blacksmith",
		"ruins_soul_nourishing_alchemist": "alchemist",
		"wild_caged_spirit_beast": "beast_tamer"}
	for enc_id: String in answers:
		var prof: String = answers[enc_id]
		var found := false
		for choice: Dictionary in d.encounters[enc_id]["choices"]:
			if not choice.get("requires", {}).get("min_profession", {}).has(prof):
				continue
			found = true
			var c := new_character()
			assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to "), "%s blocked at rank 0" % enc_id)
			c.professions[prof] = {"rank": 1, "xp": 0.0}
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed at rank 1" % enc_id)
		assert_true(found, "%s has a %s choice" % [enc_id, prof])


func test_giving_up_an_item_in_qi_refining_encounters() -> void:
	var d := GameData.load_from_dir()
	var gives := {
		"forest_dying_rogue_begs_pill": "bone_setting_salve",
		"village_fevered_child": "spirit_herb",
		"marsh_wandering_alchemist_trade": "spirit_herb"}
	var tags := {}
	for enc_id: String in gives:
		var item: String = gives[enc_id]
		var enc: Dictionary = d.encounters[enc_id]
		tags[(enc["tags"] as Array)[0]] = true
		var found := false
		for choice: Dictionary in enc["choices"]:
			if not choice.get("effects", {}).get("items", {}).has(item):
				continue
			found = true
			var c := new_character()
			assert_true(Exploration.check_choice(c, d, choice, {}) != "", "%s blocked without %s" % [enc_id, item])
			c.add_item(item, 2)
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed with %s" % [enc_id, item])
		assert_true(found, "%s has a choice that gives up %s" % [enc_id, item])
		assert_true(enc["choices"].size() >= 2, "%s keeps a plain choice" % enc_id)
	assert_eq(tags.size(), 3, "three different regions")


func test_profession_answers_at_foundation() -> void:
	var d := GameData.load_from_dir()
	var answers := {
		"marsh_drowned_shrine": "array_master",
		"city_smugglers_cut": "talisman_master",
		"ruins_burial_armor": "blacksmith"}
	for enc_id: String in answers:
		var prof: String = answers[enc_id]
		var found := false
		for choice: Dictionary in d.encounters[enc_id]["choices"]:
			if not choice.get("requires", {}).get("min_profession", {}).has(prof):
				continue
			found = true
			var c := new_character()
			c.professions[prof] = {"rank": 1, "xp": 0.0}
			assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to be "), "%s blocked at rank 1" % enc_id)
			c.professions[prof] = {"rank": 2, "xp": 0.0}
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed at rank 2" % enc_id)
		assert_true(found, "%s has a rank 2 %s choice" % [enc_id, prof])


func test_profession_choices_train_the_craft() -> void:
	var d := GameData.load_from_dir()
	var n := 0
	for enc_id: String in d.encounters:
		var choices: Array = d.encounters[enc_id].get("choices", [])
		for choice: Dictionary in choices:
			var need: Dictionary = choice.get("requires", {}).get("min_profession", {})
			for prof: String in need:
				n += 1
				var xp: Dictionary = choice.get("effects", {}).get("profession_xp", {})
				assert_true(xp.has(prof), "%s: %s choice trains %s" % [enc_id, choice["label"], prof])
	assert_true(n >= 7, "at least seven profession choices")


## C-101: three Foundation Establishment encounters in different regions where a choice gives something up.
func test_giving_up_an_item_in_foundation_encounters() -> void:
	var d := GameData.load_from_dir()
	var gives := {
		"azure_poisoned_junior": "meridian_mending_pill",
		"city_penniless_formation_master": "spirit_stone",
		"marsh_hungry_ghost_offering": "azure_crystal"}
	var tags := {}
	for enc_id: String in gives:
		var item: String = gives[enc_id]
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc.get("min_realm", ""), "foundation_establishment", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		tags[(enc["tags"] as Array)[0]] = true
		var found := false
		for choice: Dictionary in enc["choices"]:
			var cost: int = int(choice.get("effects", {}).get("items", {}).get(item, 0))
			if cost >= 0:
				continue
			found = true
			var c := new_character()
			assert_true(Exploration.check_choice(c, d, choice, {}) != "", "%s blocked without %s" % [enc_id, item])
			c.add_item(item, 200)
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed with %s" % [enc_id, item])
		assert_true(found, "%s has a choice that gives up %s" % [enc_id, item])
		assert_true(enc["choices"].size() >= 2, "%s keeps a plain choice" % enc_id)
	assert_eq(tags.size(), 3, "three different regions")


## C-106: three Core Formation encounters in different regions where a choice gives something up.
func test_giving_up_an_item_in_core_encounters() -> void:
	var d := GameData.load_from_dir()
	var gives := {
		"marsh_drowned_scholar_cairn": "frost_jade_salve",
		"mountain_hermit_smith_forge": "spirit_stone",
		"wild_dying_beast_mother": "golden_core_lotus_seed"}
	var tags := {}
	var attribute_gains := 0
	for enc_id: String in gives:
		var item: String = gives[enc_id]
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc.get("min_realm", ""), "core_formation", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		tags[(enc["tags"] as Array)[0]] = true
		var found := false
		for choice: Dictionary in enc["choices"]:
			if choice.get("effects", {}).has("attributes"):
				attribute_gains += 1
			var cost: int = int(choice.get("effects", {}).get("items", {}).get(item, 0))
			if cost >= 0:
				continue
			found = true
			var c := new_character()
			assert_true(Exploration.check_choice(c, d, choice, {}) != "", "%s blocked without %s" % [enc_id, item])
			c.add_item(item, 500)
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed with %s" % [enc_id, item])
		assert_true(found, "%s has a choice that gives up %s" % [enc_id, item])
		assert_true(enc["choices"].size() >= 3, "%s keeps a plain choice and a walk-away" % enc_id)
	assert_eq(tags.size(), 3, "three different regions")
	assert_true(attribute_gains <= 1, "at most one attribute gain across the three")


func test_profession_answers_at_core_formation() -> void:
	var d := GameData.load_from_dir()
	var answers := {
		"ridge_beast_clan_truce": "beast_tamer",
		"ruins_tribulation_crater": "alchemist",
		"marsh_yin_ferryman": "doctor"}
	for enc_id: String in answers:
		var prof: String = answers[enc_id]
		var found := false
		for choice: Dictionary in d.encounters[enc_id]["choices"]:
			if not choice.get("requires", {}).get("min_profession", {}).has(prof):
				continue
			found = true
			assert_true(choice["effects"]["profession_xp"][prof] >= 40, "%s gives profession xp" % enc_id)
			var c := new_character()
			c.professions[prof] = {"rank": 2, "xp": 0.0}
			assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to be "), "%s blocked at rank 2" % enc_id)
			c.professions[prof] = {"rank": 3, "xp": 0.0}
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed at rank 3" % enc_id)
		assert_true(found, "%s has a rank 3 %s choice" % [enc_id, prof])


## C-117: three once-only Nascent Soul encounters in different regions where a choice gives something up.
func test_giving_up_an_item_in_nascent_encounters() -> void:
	var d := GameData.load_from_dir()
	var gives := {
		"marsh_sunken_bell_monk": "soul_infant_fruit",
		"ruins_stele_warden": "spirit_stone",
		"city_refugee_hall": "spirit_stone"}
	var tags := {}
	for enc_id: String in gives:
		var item: String = gives[enc_id]
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc.get("min_realm", ""), "nascent_soul", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		tags[(enc["tags"] as Array)[0]] = true
		var found := false
		for choice: Dictionary in enc["choices"]:
			assert_false(choice.get("effects", {}).has("attributes"), enc_id + " has no attribute gain")
			var cost: int = int(choice.get("effects", {}).get("items", {}).get(item, 0))
			if cost >= 0:
				continue
			found = true
			var c := new_character()
			assert_true(Exploration.check_choice(c, d, choice, {}) != "", "%s blocked without %s" % [enc_id, item])
			c.add_item(item, 99999)
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed with %s" % [enc_id, item])
			assert_true(Exploration.check_tag(d, choice) != "", "%s shows its cost in the tag" % enc_id)
		assert_true(found, "%s has a choice that gives up %s" % [enc_id, item])
		assert_true(enc["choices"].size() >= 3, "%s keeps a plain choice and a walk-away" % enc_id)
	assert_eq(tags.size(), 3, "three different regions")


## C-120: honourable deeds earn fame; demonic or selfish choices never do.
func test_good_deeds_carry_renown() -> void:
	var d: GameData = data()
	var deeds := {
		"village_elders_dispute": "Walk the boundary and judge fairly",
		"marsh_villagers_plea": "Hunt the corpse refiner",
		"ridge_beast_clan_truce": "Carry the truce to the miners",
		"azure_minor_sect_duel": "Judge the duel fairly",
	}
	for enc_id: String in deeds:
		var found := false
		for choice: Dictionary in d.encounters[enc_id]["choices"]:
			if choice["label"] == deeds[enc_id]:
				found = true
				var renown: int = int(choice.get("renown", 0))
				assert_true(renown >= 5 and renown <= 15, "%s renown %d is 5-15" % [enc_id, renown])
		assert_true(found, "%s has its honourable choice" % enc_id)


func test_no_selfish_choice_carries_renown() -> void:
	var d: GameData = data()
	for enc_id: String in d.encounters:
		for choice: Dictionary in d.encounters[enc_id].get("choices", []):
			if int(choice.get("effects", {}).get("alignment", 0)) < 0:
				assert_false(choice.has("renown"), "%s '%s' is selfish and has no renown" % [enc_id, choice["label"]])


func test_profession_answers_at_nascent_soul() -> void:
	var d := GameData.load_from_dir()
	var answers := {
		"ruins_sealed_demon_soul": "array_master",
		"wild_two_sects_clash": "talisman_master",
		"city_old_friends_grave": "blacksmith"}
	for enc_id: String in answers:
		var prof: String = answers[enc_id]
		assert_eq(d.encounters[enc_id]["min_realm"], "nascent_soul", enc_id)
		var found := false
		for choice: Dictionary in d.encounters[enc_id]["choices"]:
			if not choice.get("requires", {}).get("min_profession", {}).has(prof):
				continue
			found = true
			assert_true(choice["effects"]["profession_xp"][prof] >= 60, "%s gives profession xp" % enc_id)
			var c := new_character()
			c.professions[prof] = {"rank": 3, "xp": 0.0}
			assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to be "), "%s blocked at rank 3" % enc_id)
			c.professions[prof] = {"rank": 4, "xp": 0.0}
			assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed at rank 4" % enc_id)
		assert_true(found, "%s has a rank 4 %s choice" % [enc_id, prof])


## C-134: first-hours encounters where a craft, an attribute or a fight each opens a choice.
func test_early_profession_answers() -> void:
	var d := GameData.load_from_dir()
	var answers := {
		"village_snapped_axle": ["blacksmith"],
		"forest_haunted_field": ["talisman_master", "array_master"],
		"forest_charcoal_burners_fever": ["alchemist"],
		"forest_snared_fox_kit": ["beast_tamer"]}
	for enc_id: String in answers:
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc.get("min_realm", ""), "qi_refining", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		for prof: String in answers[enc_id]:
			var found := false
			for choice: Dictionary in enc["choices"]:
				if not choice.get("requires", {}).get("min_profession", {}).has(prof):
					continue
				found = true
				var c := new_character()
				assert_true(Exploration.check_choice(c, d, choice, {}).begins_with("You need to "), "%s blocked at no %s" % [enc_id, prof])
				c.professions[prof] = {"rank": 1, "xp": 0.0}
				assert_eq(Exploration.check_choice(c, d, choice, {}), "", "%s allowed at rank 1" % enc_id)
				assert_true(int(choice["effects"]["profession_xp"][prof]) in range(15, 21), "%s xp" % enc_id)
			assert_true(found, "%s has a %s choice" % [enc_id, prof])


func test_charcoal_burners_mix_attribute_craft_and_fight() -> void:
	var d := GameData.load_from_dir()
	var kinds := {}
	for choice: Dictionary in d.encounters["forest_charcoal_burners_fever"]["choices"]:
		var req: Dictionary = choice.get("requires", {})
		if req.has("min_attributes"):
			kinds["attribute"] = choice
		if req.has("min_profession"):
			kinds["profession"] = true
		if choice.has("enemy"):
			kinds["enemy"] = true
			assert_true(d.enemies[choice["enemy"]]["realm"] == "qi_refining" and int(d.enemies[choice["enemy"]]["stage"]) <= 3, "foe is a low Qi Refining one")
	assert_eq(kinds.size(), 3, "attribute, profession and enemy choices")
	var c := new_character()
	c.attributes["spirit"] = 10
	assert_true(Exploration.check_choice(c, d, kinds["attribute"], {}).begins_with("You need "))
	c.attributes["spirit"] = 12
	assert_eq(Exploration.check_choice(c, d, kinds["attribute"], {}), "")


func test_crafter_first_year_encounters() -> void:
	var d := GameData.load_from_dir()
	for enc_id: String in ["forest_abandoned_herb_cache", "forest_old_alchemists_notes", "village_broken_forge"]:
		assert_true(d.encounters.has(enc_id), enc_id + " exists")
		assert_eq(d.encounters[enc_id].get("min_realm", ""), "qi_refining", enc_id + " realm")
		assert_true(d.encounters[enc_id].has("blocked_by_flag"), enc_id + " is once-only")
	var notes: Dictionary = d.encounters["forest_old_alchemists_notes"]
	var c := new_character()
	var gated: Dictionary = notes["choices"][0]
	assert_eq(gated["effects"]["learn_recipe"], "visceral_mending_pill")
	c.attributes["comprehension"] = 5
	assert_true(Exploration.check_choice(c, d, gated, {}) != "", "notes need Comprehension")
	c.attributes["comprehension"] = 12
	assert_eq(Exploration.check_choice(c, d, gated, {}), "", "notes open at Comprehension 12")
	var forge: Dictionary = d.encounters["village_broken_forge"]
	var smith_choice: Dictionary = forge["choices"][0]
	assert_true(smith_choice["requires"]["min_profession"].has("blacksmith"))
	var c2 := new_character()
	assert_true(Exploration.check_choice(c2, d, smith_choice, {}) != "", "forge needs a blacksmith")
	c2.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	assert_eq(Exploration.check_choice(c2, d, smith_choice, {}), "", "forge open to a fresh blacksmith")
	assert_true(int(d.encounters["forest_abandoned_herb_cache"]["choices"][1]["effects"]["alignment"]) < 0, "taking it all costs alignment")


func test_mahayana_choice_encounters() -> void:
	var d := GameData.load_from_dir()
	for enc_id: String in ["wild_lamp_of_ten_thousand_vows", "mountain_ferryman_of_the_last_river", "ruins_ancestor_who_would_not_ascend"]:
		assert_true(d.encounters.has(enc_id), enc_id + " exists")
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc["min_realm"], "mahayana", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		assert_eq(enc["choices"].size(), 3, enc_id + " has three ways")
	var lamp: Dictionary = d.encounters["wild_lamp_of_ten_thousand_vows"]
	var c := new_character()
	c.attributes["spirit"] = 10
	assert_true(Exploration.check_choice(c, d, lamp["choices"][0], {}) != "", "the lamp needs Spirit 60")
	c.attributes["spirit"] = 60
	assert_eq(Exploration.check_choice(c, d, lamp["choices"][0], {}), "", "the lamp opens at Spirit 60")
	assert_true(int(lamp["choices"][1]["effects"]["items"]["spirit_stone"]) < 0, "the offering costs stones")
	var ferry: Dictionary = d.encounters["mountain_ferryman_of_the_last_river"]
	assert_eq(ferry["choices"][2]["enemy"], "great_vehicle_magistrate")
	assert_false(bool(d.enemies["great_vehicle_magistrate"]["lethal"]), "the ferryman's fight is not lethal")
	assert_true(int(ferry["choices"][0]["effects"]["qi"]) < 0, "the fare costs qi")
	var anc: Dictionary = d.encounters["ruins_ancestor_who_would_not_ascend"]
	assert_eq(anc["choices"][2]["enemy"], "myriad_throne_ancestor")


func test_tribulation_transcendence_choice_encounters() -> void:
	var d := GameData.load_from_dir()
	for enc_id: String in ["wild_bell_of_the_last_lightning", "mountain_cairn_of_the_failed_ascension", "ruins_elder_waiting_for_the_sky"]:
		assert_true(d.encounters.has(enc_id), enc_id + " exists")
		var enc: Dictionary = d.encounters[enc_id]
		assert_eq(enc["min_realm"], "tribulation_transcendence", enc_id + " realm")
		assert_true(enc.has("blocked_by_flag"), enc_id + " is once-only")
		assert_eq(enc["choices"].size(), 3, enc_id + " has three ways")
	var bell: Dictionary = d.encounters["wild_bell_of_the_last_lightning"]
	var c := new_character()
	c.attributes["spirit"] = 10
	assert_true(Exploration.check_choice(c, d, bell["choices"][0], {}) != "", "the bell needs Spirit 64")
	c.attributes["spirit"] = 64
	assert_eq(Exploration.check_choice(c, d, bell["choices"][0], {}), "", "the bell opens at Spirit 64")
	var cairn: Dictionary = d.encounters["mountain_cairn_of_the_failed_ascension"]
	assert_true(int(cairn["choices"][0]["effects"]["qi"]) < 0, "the vigil costs qi")
	assert_true(int(cairn["choices"][1]["effects"]["items"]["spirit_stone"]) < 0, "the cairn costs stones")
	var elder: Dictionary = d.encounters["ruins_elder_waiting_for_the_sky"]
	assert_eq(elder["choices"][2]["enemy"], "hidden_tribulation_elder")
	assert_true(d.enemies.has("hidden_tribulation_elder"), "the foe exists")
