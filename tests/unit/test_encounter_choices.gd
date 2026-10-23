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
	assert_eq(gated["check"]["attribute"], "comprehension", "notes are a Comprehension check (C-206)")
	assert_true(gated.has("on_fail"), "a failed read costs something")
	c.attributes["comprehension"] = 5
	assert_eq(Exploration.check_choice(c, d, gated, {}), "", "the check is open to anyone")
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


func test_road_talisman_peddler_sells_paper_for_eight_stones() -> void:
	var d := data()
	var enc: Dictionary = d.encounters["road_talisman_peddler"]
	var c := new_character()
	c.realm_index = 1
	c.inventory = {"spirit_stone": 7}
	assert_true(Exploration.check_choice(c, d, enc["choices"][0], {}) != "", "7 stones cannot buy the bundle")
	c.inventory = {"spirit_stone": 8}
	assert_eq(Exploration.check_choice(c, d, enc["choices"][0], {}), "", "8 stones can")
	Exploration.resolve_choice(c, d, enc, 0, {})
	assert_eq(c.item_count("talisman_paper"), 5)
	assert_eq(c.item_count("spirit_stone"), 0)


func test_choice_effect_renown_raises_current_region() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	gs.start_session(c)
	var enc := TRAVELLER.duplicate(true)
	enc["choices"][0]["effects"]["renown"] = 5
	gs.data.encounters["test_renown"] = enc
	gs.pending_encounter = "test_renown"
	var before := Renown.value(c, gs.current_region)
	gs.choose_encounter(0)
	assert_eq(Renown.value(c, gs.current_region), before + 5)
	gs.end_session()
	gs.data.encounters.erase("test_renown")


func _road_choice_renown(enc_id: String, index: int) -> int:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	gs.start_session(c)
	c.inventory["spirit_herb"] = 5
	gs.current_region = "qingshi_village"
	gs.pending_encounter = enc_id
	var before := Renown.value(c, gs.current_region)
	gs.choose_encounter(index)
	var gained := Renown.value(c, gs.current_region) - before
	gs.end_session()
	return gained


func test_road_encounters_reward_helping_with_renown() -> void:
	assert_eq(_road_choice_renown("road_milestone_carver", 0), 5, "carver's helping choice")
	assert_eq(_road_choice_renown("road_milestone_carver", 1), 0, "reading the script")
	assert_eq(_road_choice_renown("road_overturned_cart", 0), 3, "helping the farmer")
	assert_eq(_road_choice_renown("road_overturned_cart", 1), 0, "robbing the farmer")
	assert_eq(_road_choice_renown("road_lost_child", 0), 3, "walking the child home")
	assert_eq(_road_choice_renown("road_lost_child", 2), 0, "pointing down the road")


## C-175: helping the people of the first-hour regions raises renown too.
func test_region_encounters_reward_helping_with_renown() -> void:
	assert_eq(_road_choice_renown("village_drowning_child", 0), 3, "diving after the child")
	assert_eq(_road_choice_renown("village_drowning_child", 1), 0, "shouting for the miller")
	assert_eq(_road_choice_renown("village_fevered_child", 0), 3, "steeping a herb for the child")
	assert_eq(_road_choice_renown("village_fevered_child", 1), 0, "saying you cannot help")
	assert_eq(_road_choice_renown("forest_dying_gatherer", 0), 3, "carrying the gatherer home")
	assert_eq(_road_choice_renown("forest_dying_gatherer", 2), 0, "taking the map and leaving him")
	assert_eq(_road_choice_renown("forest_wounded_traveller", 0), 3, "binding the traveller's wounds")
	assert_eq(_road_choice_renown("forest_wounded_traveller", 1), 0, "stripping his pouch")


func test_road_lost_child_carry_her_raises_renown_by_five() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	c.attributes["constitution"] = 12
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	gs.pending_encounter = "road_lost_child"
	var before := Renown.value(c, gs.current_region)
	gs.choose_encounter(1)
	assert_eq(Renown.value(c, gs.current_region) - before, 5, "carry her")
	gs.end_session()


## C-178: two first-hour encounters that train your fighting style.
func _style_xp_after(enc_id: String, index: int, constitution: int, comprehension: int) -> float:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterData.new()
	c = CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	c.attributes["constitution"] = constitution
	c.attributes["comprehension"] = comprehension
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	gs.pending_encounter = enc_id
	gs.choose_encounter(index)
	var xp := float(c.techniques["iron_fist"]["xp"]) + 1000.0 * (Techniques.level(c, "iron_fist") - 1)
	gs.end_session()
	return xp


func test_fighting_style_encounters() -> void:
	var d := data()
	assert_true(d.encounters["village_boxing_yard"]["tags"].has("village"))
	assert_true(d.encounters["forest_hunter_wolf_lunge"]["tags"].has("forest"))
	for enc_id: String in ["village_boxing_yard", "forest_hunter_wolf_lunge"]:
		var attr := "constitution" if enc_id == "village_boxing_yard" else "comprehension"
		assert_true(_style_xp_after(enc_id, 0, 5, 5) > 0.0, enc_id + " training trains")
		assert_eq(_style_xp_after(enc_id, 2, 5, 5), 0.0, enc_id + " plain choice trains nothing")
		var checked: bool = d.encounters[enc_id]["choices"][1].has("check")
		if checked:
			# C-206: a chance check; a weak player may fail but is never locked out.
			assert_eq(d.encounters[enc_id]["choices"][1]["check"]["attribute"], attr)
			assert_true(d.encounters[enc_id]["choices"][1].has("on_fail"))
		else:
			assert_eq(_style_xp_after(enc_id, 1, 5, 5), 0.0, enc_id + " gated choice refused when weak")
		var hi := 20
		var gated := _style_xp_after(enc_id, 1, hi, hi)
		assert_true(gated >= _style_xp_after(enc_id, 0, hi, hi) * (0.0 if checked else 1.0), enc_id + " gated " + attr + " choice trains")
		if not checked:
			assert_true(gated > _style_xp_after(enc_id, 0, hi, hi), enc_id + " gated " + attr + " choice trains more")


func _region_choice_renown(region: String, enc_id: String, index: int) -> int:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Wanderer", gs.data, seeded_rng())
	gs.start_session(c)
	c.inventory["spirit_stone"] = 5000
	c.inventory["meridian_mending_pill"] = 2
	gs.current_region = region
	gs.pending_encounter = enc_id
	var before := Renown.value(c, region)
	gs.choose_encounter(index)
	var gained := Renown.value(c, region) - before
	gs.end_session()
	return gained


## C-179: helping people in Fallen Star Market and Azure Peak raises renown there.
func test_city_and_mountain_encounters_reward_helping_with_renown() -> void:
	var m := "fallen_star_market"
	assert_eq(_region_choice_renown(m, "city_cornered_merchant", 0), 3, "paying the merchant's debt")
	assert_eq(_region_choice_renown(m, "city_cornered_merchant", 2), 0, "helping the thugs collect")
	assert_eq(_region_choice_renown(m, "city_ruined_cultivator_debt", 0), 3, "paying his debt")
	assert_eq(_region_choice_renown(m, "city_ruined_cultivator_debt", 1), 0, "buying the case cheap")
	var a := "azure_peak"
	assert_eq(_region_choice_renown(a, "azure_poisoned_junior", 0), 3, "mending the junior")
	assert_eq(_region_choice_renown(a, "azure_poisoned_junior", 2), 0, "walking on")
	assert_eq(_region_choice_renown(a, "mountain_bullied_junior", 0), 3, "sparring the bully down")
	assert_eq(_region_choice_renown(a, "mountain_bullied_junior", 1), 0, "taking a cut")
	assert_eq(_region_choice_renown(a, "mountain_dying_explorer", 0), 3, "tending the explorer")
	assert_eq(_region_choice_renown(a, "mountain_dying_explorer", 2), 0, "taking the map")
	assert_eq(_region_choice_renown(a, "mountain_dying_rogue_map", 0), 3, "burying the rogue")
	assert_eq(_region_choice_renown(a, "mountain_dying_rogue_map", 1), 0, "taking the map and purse")


## ENC-007: fight choices carry the foe's odds and lethality.
func test_choices_carry_fight_odds() -> void:
	var d := _data_with_test_encounters()
	var c := new_character()
	c.realm_index = 1
	var list := Exploration.choices(c, d, d.encounters["test_traveller"], {})
	var foe: Dictionary = d.enemies["wild_boar"]
	assert_eq(list[3]["chance"], Combat.win_chance(c, d, foe))
	assert_eq(list[3]["lethal"], bool(foe.get("lethal", false)))
	assert_eq(list[0]["chance"], -1.0, "a non-fight choice has no odds")
	assert_false(list[0]["lethal"])
	c.realm_index = 0
	list = Exploration.choices(c, d, d.encounters["test_traveller"], {})
	assert_true(list[3]["disabled"])
	assert_eq(list[3]["chance"], -1.0, "a disabled fight is not rated")


func test_rival_duel_choice_has_odds_only_with_people() -> void:
	var d := _data_with_test_encounters()
	var c := new_character()
	d.encounters["test_duel"] = {"id": "test_duel", "tags": ["test_tag"], "text": "x", "choices": [
		{"label": "Duel", "fight_rival": true}, {"label": "Walk away"}]}
	var people: Dictionary = {}
	Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var with_rival := Exploration.choices(c, d, d.encounters["test_duel"], {}, people)
	assert_true(with_rival[0]["chance"] >= 0.0 and with_rival[0]["chance"] <= 1.0)
	assert_eq(Exploration.choices(c, d, d.encounters["test_duel"], {})[0]["chance"], -1.0)
## C-184: two village encounters for the middle Qi Refining months.
func _village_ids_at(stage: int) -> Array:
	var d := data()
	var c := CharacterFactory.create("Wanderer", d, seeded_rng())
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = stage
	var ids: Array = []
	for e: Dictionary in Exploration.eligible_encounters(c, d, ["village"], {}):
		ids.append(e["encounter"]["id"])
	return ids


func test_village_middle_qi_refining_encounters() -> void:
	var d := data()
	for id in ["village_outer_chore_swap", "village_old_boxer_spar"]:
		assert_true(d.encounters.has(id), id + " exists")
		assert_true(_village_ids_at(2).has(id), id + " eligible at the 3rd Layer")
		assert_false(_village_ids_at(1).has(id), id + " not eligible at the 2nd Layer")
	var boxer: Dictionary = d.enemies["village_boxer"]
	assert_false(bool(boxer["lethal"]), "the boxer never kills")
	var chosen := false
	for ch: Dictionary in d.encounters["village_old_boxer_spar"]["choices"]:
		chosen = chosen or ch.get("enemy", "") == "village_boxer"
	assert_true(chosen, "a choice spars the boxer")


## C-187: two Misty Forest encounters for the middle Qi Refining layers.
func _forest_ids_at(stage: int) -> Array:
	var d := data()
	var c := CharacterFactory.create("Wanderer", d, seeded_rng())
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = stage
	var ids: Array = []
	for e: Dictionary in Exploration.eligible_encounters(c, d, ["forest", "wild"], {}):
		ids.append(e["encounter"]["id"])
	return ids


func test_forest_middle_qi_refining_encounters() -> void:
	var d := data()
	for id in ["forest_spilled_herb_basket", "forest_snared_wolf_cub"]:
		assert_true(d.encounters.has(id), id + " exists")
		assert_true(_forest_ids_at(2).has(id), id + " eligible at the 3rd Layer")
		assert_false(_forest_ids_at(1).has(id), id + " not eligible at the 2nd Layer")
		for ch: Dictionary in d.encounters[id]["choices"]:
			for item_id: String in ch.get("effects", {}).get("items", {}):
				assert_true(d.items.has(item_id), item_id + " exists")


## C-191: two road encounters for the middle Qi Refining layers.
func _road_ids_at(stage: int) -> Array:
	var d := data()
	var c := CharacterFactory.create("Wanderer", d, seeded_rng())
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = stage
	var ids: Array = []
	for e: Dictionary in Exploration.eligible_encounters(c, d, ["road"], {}):
		ids.append(e["encounter"]["id"])
	return ids


func test_road_middle_qi_refining_encounters() -> void:
	var d := data()
	for id in ["road_caravan_guard", "road_fallen_rogue"]:
		assert_true(d.encounters.has(id), id + " exists")
		assert_true(_road_ids_at(2).has(id), id + " eligible at the 3rd Layer")
		assert_false(_road_ids_at(1).has(id), id + " not eligible at the 2nd Layer")
		for ch: Dictionary in d.encounters[id]["choices"]:
			for item_id: String in ch.get("effects", {}).get("items", {}):
				assert_true(d.items.has(item_id), item_id + " exists")
			if ch.has("enemy"):
				assert_true(d.enemies.has(ch["enemy"]), "enemy exists")
				assert_false(bool(d.enemies[ch["enemy"]]["lethal"]), "the guard fight never kills")


## C-198: two encounters for the upper Qi Refining layers (7th-9th).
func test_upper_qi_refining_encounters() -> void:
	var d := data()
	for id in ["village_foundation_elder_carriage", "forest_hunted_spirit_fox"]:
		assert_true(d.encounters.has(id), id + " exists")
		var ids_at := func(stage: int) -> Array: return _village_ids_at(stage) if id.begins_with("village") else _forest_ids_at(stage)
		assert_true(ids_at.call(6).has(id), id + " eligible at the 7th Layer")
		assert_false(ids_at.call(5).has(id), id + " not eligible at the 6th Layer")
		for ch: Dictionary in d.encounters[id]["choices"]:
			for item_id: String in ch.get("effects", {}).get("items", {}):
				assert_true(d.items.has(item_id), item_id + " exists")
			if ch.has("enemy"):
				assert_true(d.enemies.has(ch["enemy"]), "enemy exists")
				assert_false(bool(d.enemies[ch["enemy"]]["lethal"]), "the hunters never kill")


## ENC-008: a choice with a `check` {attribute, target} succeeds with chance attribute/target (0.1..0.9), else on_fail applies.
func _check_encounter(target: int = 20) -> Dictionary:
	return {"id": "t_check", "tags": ["x"], "weight": 1, "kind": "neutral", "days": 0, "text": "A rope bridge.", "choices": [
		{"label": "Leap across", "text": "You land safely.", "days": 1, "effects": {"qi": 10},
			"check": {"attribute": "comprehension", "target": target},
			"on_fail": {"text": "You slip.", "days": 3, "effects": {"qi": 1}}},
		{"label": "Walk around"}]}


func test_check_chance_is_clamped_ratio() -> void:
	var c := new_character()
	var choice: Dictionary = _check_encounter()["choices"][0]
	c.attributes["comprehension"] = 12
	assert_eq(snappedf(Exploration.check_chance(c, choice), 0.001), 0.6)
	c.attributes["comprehension"] = 1
	assert_eq(Exploration.check_chance(c, choice), 0.1)
	c.attributes["comprehension"] = 99
	assert_eq(Exploration.check_chance(c, choice), 0.9)
	assert_eq(Exploration.check_chance(c, {"label": "x"}), -1.0)


func test_check_choice_listing_carries_chance() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	c.attributes["comprehension"] = 12
	var list := Exploration.choices(c, d, _check_encounter(), {})
	assert_eq(snappedf(float(list[0]["chance"]), 0.001), 0.6)
	assert_eq(float(list[1]["chance"]), -1.0)
	assert_true(list[0]["roll"])
	assert_eq(EncounterWindow.fight_suffix(list[0]), " (about 60 in 100)")


func test_check_choice_success_and_failure() -> void:
	var d := GameData.load_from_dir()
	var enc := _check_encounter()
	var c := new_character()
	c.attributes["comprehension"] = 12
	var wins := 0
	var fails := 0
	for s in 40:
		var r := Exploration.resolve_choice(c, d, enc, 0, {}, "", seeded_rng(s))
		assert_true(r["ok"])
		if r["failed"]:
			fails += 1
			assert_eq(r["text"], "You slip.")
			assert_eq(r["days"], 3)
		else:
			wins += 1
			assert_eq(r["text"], "You land safely.")
			assert_eq(r["days"], 1)
	assert_true(wins > 10 and fails > 5, "about 60/40: %d/%d" % [wins, fails])
	var again := Exploration.resolve_choice(c, d, enc, 0, {}, "", seeded_rng(7))
	assert_eq(again["failed"], Exploration.resolve_choice(c, d, enc, 0, {}, "", seeded_rng(7))["failed"], "deterministic")
	assert_false(Exploration.resolve_choice(c, d, enc, 1, {}, "", seeded_rng(7))["failed"], "no check, no failure")


func test_check_choice_through_game_state() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng()))
	gs.data.encounters["t_check"] = _check_encounter(1)
	gs.player.attributes["comprehension"] = 99
	gs.pending_encounter = "t_check"
	var qi: float = gs.player.qi
	gs.choose_encounter(0)
	assert_eq(gs.pending_encounter, "")
	assert_true(gs.player.qi >= qi, "qi not lost")
	var EB: Node = _root().get_node("EventBus")
	var recent := ""
	for entry: Dictionary in EB.history.slice(-3):
		recent += String(entry["text"]) + "\n"
	assert_true(recent.contains("Your Comprehension carried it."), recent)
	# Both outcomes through GameState: a failed check applies on_fail's choice-level keys (renown 3), a passed one the
	# choice's own (renown 5). The game rng is probed to know which way the roll goes.
	var enc := _check_encounter(10)
	enc["choices"][0]["renown"] = 5
	enc["choices"][0]["on_fail"]["renown"] = 3
	gs.data.encounters["t_check"] = enc
	gs.player.attributes["comprehension"] = 5
	var seen := {}
	for s in 12:
		gs.rng.seed = s
		var probe := RandomNumberGenerator.new()
		probe.seed = gs.rng.seed
		probe.state = gs.rng.state
		var fails := probe.randf() >= 0.5
		seen[fails] = true
		var before := Renown.value(gs.player, gs.current_region)
		gs.pending_encounter = "t_check"
		gs.choose_encounter(0)
		assert_eq(Renown.value(gs.player, gs.current_region) - before, 3 if fails else 5, "seed %d failed=%s" % [s, fails])
	assert_eq(seen.size(), 2, "both outcomes exercised")
	gs.data.encounters.erase("t_check")
	gs.end_session()


## WU-300: the result line says whether the check passed.
func test_check_verdict() -> void:
	var choice: Dictionary = _check_encounter()["choices"][0]
	assert_eq(Exploration.check_verdict(choice, false), "Your Comprehension carried it.")
	assert_eq(Exploration.check_verdict(choice, true), "It was beyond you.")
	assert_eq(Exploration.check_verdict({"label": "x"}, false), "")
	var d := GameData.load_from_dir()
	var c := new_character()
	c.attributes["comprehension"] = 99
	assert_eq(Exploration.resolve_choice(c, d, _check_encounter(1), 0, {}, "", seeded_rng(1))["verdict"], "Your Comprehension carried it.")
	c.attributes["comprehension"] = 1
	var enc := _check_encounter(99)
	var beyond := 0
	for s in 30:
		if Exploration.resolve_choice(c, d, enc, 0, {}, "", seeded_rng(s))["verdict"] == "It was beyond you.":
			beyond += 1
	assert_true(beyond > 0)


func test_check_validation() -> void:
	var d := GameData.load_from_dir()
	d.encounters["t_bad"] = {"id": "t_bad", "tags": ["x"], "weight": 1, "kind": "neutral", "days": 0, "text": "t", "choices": [
		{"label": "A", "check": {"attribute": "nope", "target": 5}, "on_fail": {}},
		{"label": "B", "check": {"attribute": "comprehension", "target": 0}, "on_fail": {}},
		{"label": "C", "check": {"attribute": "comprehension", "target": 5}},
		{"label": "D", "on_fail": {}},
		{"label": "E", "check": {"attribute": "comprehension", "target": 5}, "on_fail": {"enemy": "ghost"}}]}
	var errors := Exploration.validate_choices(d)
	assert_eq(errors.size(), 5, str(errors))
	d.encounters["t_bad"] = _check_encounter()
	assert_true(Exploration.validate_choices(d).is_empty(), str(Exploration.validate_choices(d)))
