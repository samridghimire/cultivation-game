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
				set_flags[effects["set_flag"]] = true
	for enemy: Dictionary in d.enemies.values():
		if enemy.get("rewards", {}).has("set_flag"):
			set_flags[enemy["rewards"]["set_flag"]] = true
	for e: Dictionary in d.encounters.values():
		if e.has("requires_flag"):
			assert_true(set_flags.has(e["requires_flag"]), "%s waits on a flag nothing sets" % e["id"])
		var flag: String = e.get("blocked_by_flag", "")
		if flag == "" or not e.has("choices"):
			continue
		for choice: Dictionary in e["choices"]:
			var effects: Dictionary = choice.get("effects", {})
			if not effects.is_empty():
				assert_eq(String(effects.get("set_flag", "")), flag, "%s: %s" % [e["id"], choice["label"]])


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
