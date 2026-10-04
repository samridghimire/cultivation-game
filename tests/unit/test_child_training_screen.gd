extends TestCase
## FAM-004b: the child training screen opened from the character sheet.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## Starts a session with one child of `age` years; returns the child.
func _session_with_child(age: int) -> CharacterData:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": age, "region": gs.current_region, "roots": {"water": 50}})
	child.parents = [c.id]
	c.children.append(child.id)
	c.inventory["spirit_stone"] = 50
	return child


func test_options_cover_each_assignment_and_profession() -> void:
	var child := _session_with_child(12)
	var p: CharacterData = _root().get_node("GameState").player
	var options := ChildTrainingScreen.assignment_options(p, child, data())
	assert_eq(options.size(), Training.assignments(data()).size() - 1 + data().professions.size())
	var by_key := {}
	for o: Dictionary in options:
		by_key["%s/%s" % [o["assignment"], o["profession"]]] = o
	assert_eq(by_key["cultivate/"]["reason"], "")
	assert_true(String(by_key["technique/"]["reason"]).contains("Teach one first"), by_key["technique/"]["reason"])
	for prof_id in data().professions:
		assert_true(by_key.has("profession/" + prof_id), prof_id)


func test_young_child_gets_reasons() -> void:
	var child := _session_with_child(7)
	var p: CharacterData = _root().get_node("GameState").player
	for o: Dictionary in ChildTrainingScreen.assignment_options(p, child, data()):
		if o["assignment"] == "profession":
			assert_true(String(o["reason"]).contains("too young"), o["reason"])


func test_screen_assigns_and_stops_training() -> void:
	var child := _session_with_child(12)
	var screen := ChildTrainingScreen.new()
	screen._rebuild()
	assert_eq(screen._selected, child.id, "the only child is preselected")
	assert_eq(screen._current.text, "No training assigned.")
	var cultivate := screen._actions.get_node("assign_cultivate_") as Button
	assert_false(cultivate.disabled)
	cultivate.pressed.emit()
	assert_eq(Training.current(child), "cultivate")
	screen._rebuild()
	assert_true(screen._current.text.contains(Training.assignment_name(data(), "cultivate")), screen._current.text)
	assert_true((screen._actions.get_node("assign_cultivate_") as Button).disabled, "already training this")
	(screen._actions.get_node("stop") as Button).pressed.emit()
	assert_eq(Training.current(child), "")
	screen.free()


func test_sheet_button_only_with_living_children() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(new_character())
	var sheet := CharacterSheet.new()
	sheet._rebuild()
	assert_false(sheet._train_children.visible)
	var child := _session_with_child(5)
	sheet._rebuild()
	assert_true(sheet._train_children.visible)
	child.alive = false
	sheet._rebuild()
	assert_false(sheet._train_children.visible)
	sheet.free()
