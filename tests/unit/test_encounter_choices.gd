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
