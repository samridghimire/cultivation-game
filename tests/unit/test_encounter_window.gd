extends TestCase
## W-004d: EncounterWindow renders GameState.encounter_choices() and resolves them.

const ENCOUNTER := {
	"id": "test_window_encounter", "tags": ["test_window_tag"], "weight": 1, "kind": "neutral", "days": 1,
	"text": "A wounded traveller lies by the road.",
	"choices": [
		{"label": "Bind his wounds", "text": "He thanks you.", "days": 2, "effects": {"alignment": 10}},
		{"label": "Pay for his medicine", "effects": {"items": {"spirit_stone": -100000}}},
	],
}
const LOCKED := {
	"id": "test_window_locked", "tags": ["test_window_tag"], "weight": 1, "kind": "neutral", "days": 1,
	"text": "A sealed door.",
	"choices": [
		{"label": "Pay the toll", "effects": {"items": {"spirit_stone": -100000}}},
		{"label": "Break it", "requires": {"min_realm": "nascent_soul"}},
	],
}


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start(encounter: Dictionary) -> Node:
	var gs := _gs()
	gs.start_session(new_character())
	gs.data.encounters[encounter["id"]] = encounter.duplicate(true)
	gs.pending_encounter = encounter["id"]
	return gs


func _cleanup(gs: Node) -> void:
	gs.end_session()
	gs.data.encounters.erase(ENCOUNTER["id"])
	gs.data.encounters.erase(LOCKED["id"])


func test_window_lists_choices_and_resolves_one() -> void:
	var gs := _start(ENCOUNTER)
	var window := EncounterWindow.new()
	window.open()
	assert_true(window.visible)
	assert_eq(window.encounter_text(), ENCOUNTER["text"])
	var buttons := window.choice_buttons()
	assert_eq(buttons.size(), 2)
	assert_false(buttons[0].disabled)
	assert_true(buttons[1].disabled, "unaffordable choice is locked")
	assert_true(buttons[1].text.begins_with("Pay for his medicine  ("), "locked choice shows its reason")
	var alignment: int = gs.player.alignment
	buttons[0].pressed.emit()
	assert_eq(gs.pending_encounter, "")
	assert_eq(gs.player.alignment, alignment + 10)
	window.open()
	assert_false(window.visible, "nothing pending: stays closed")
	window.free()
	_cleanup(gs)


func test_discovery_title_and_log_line() -> void:
	var gs := _start(ENCOUNTER)
	gs.current_region = "misty_forest"
	gs.explore()
	assert_true(gs.last_explore_discovery)
	assert_eq(gs.pending_encounter, "misty_forest_hollow_shrine")
	var window := EncounterWindow.new()
	window.open()
	assert_true(window.visible)
	assert_eq(window._title.text, "Discovery: Hollow Shrine")
	window.free()
	assert_eq(EncounterWindow.title_for({"id": "x_y"}, true), "Discovery: X Y")
	assert_eq(EncounterWindow.title_for({"id": "x_y"}, false), "Encounter")
	assert_eq(EncounterWindow.title_for({"id": "x_y", "name": "Deep Pine"}, false, true), "Hidden path: Deep Pine")
	gs.pending_encounter = ""
	gs.explore(["test_tag"])
	assert_false(gs.last_explore_discovery, "a normal encounter is not a discovery")
	var normal := EncounterWindow.new()
	normal.open()
	assert_eq(normal._title.text, "Encounter")
	normal.free()
	_cleanup(gs)


func test_walk_away_when_every_choice_is_locked() -> void:
	var gs := _start(LOCKED)
	var window := EncounterWindow.new()
	window.open()
	var buttons := window.choice_buttons()
	assert_eq(buttons.size(), 3)
	assert_eq(buttons[2].text, "Walk away")
	var resolved := [false]
	var bus := (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	var cb := func(): resolved[0] = true
	bus.encounter_choice_resolved.connect(cb)
	buttons[2].pressed.emit()
	bus.encounter_choice_resolved.disconnect(cb)
	assert_true(resolved[0])
	assert_eq(gs.pending_encounter, "")
	window.free()
	_cleanup(gs)
