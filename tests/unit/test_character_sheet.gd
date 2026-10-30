extends TestCase
## FAM-001b: the character sheet shows family links and a one-time gender picker.


func _game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_sheet_shows_family_and_gender_picker() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(77), "male")
	gs.start_session(c)
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(78), {"gender": "female"})
	Family.marry(c, wife, "wife")
	c.gender = ""
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("Family"), text)
	assert_true(text.contains(wife.name), text)
	assert_true(text.contains("of the Han family"), text)
	assert_true(sheet._gender_row.visible, "unknown gender shows the picker")
	sheet._choose_gender("male")
	assert_eq(c.gender, "male")
	assert_false(sheet._gender_row.visible)
	assert_true(sheet._text.get_parsed_text().contains("Wife: %s" % wife.name))
	sheet.free()


func test_sheet_shows_spouse_pregnancy_and_meditation_offers_try_for_child() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(77), "male")
	gs.start_session(c)
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(78), {"gender": "female", "region": gs.current_region})
	wife.age_days = 20 * Calendar.DAYS_PER_YEAR
	Family.marry(c, wife, "wife")
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var tries: Array = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Try for a child"))
	assert_eq(tries.size(), 1)
	assert_false(tries[0]["disabled"], tries[0]["label"])
	wife.pregnancy = {"partner": c.id, "days_left": 60}
	tries = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Try for a child"))
	assert_true(tries[0]["disabled"], "already with child")
	assert_true(String(tries[0]["reason"]).contains("already with child"), tries[0]["reason"])
	spot.free()
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("%s is with your child (2 months to the birth)" % wife.name), text)
	sheet.free()
	gs.end_session()


func test_milestones_section_and_signal() -> void:
	var gs := _game_state()
	var bus := (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(79), "male")
	gs.start_session(c)
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("Milestones (%d of %d)" % [c.milestones.size(), gs.data.milestones.size()]), text)
	# Award one directly and see it listed with its description.
	var def: Dictionary = gs.data.milestones[0]
	var id := String(def["id"])
	c.milestones.erase(id)
	var fired: Array = []
	var cb := func(mid: String, _n: String) -> void: fired.append(mid)
	bus.milestone_reached.connect(cb)
	bus.milestone_reached.emit(id, String(def["name"]))
	bus.milestone_reached.disconnect(cb)
	assert_eq(fired, [id])
	c.milestones.append(id)
	sheet.open()
	text = sheet._text.get_parsed_text()
	assert_true(text.contains("%s: %s" % [def["name"], def.get("description", "")]), text)
	sheet.free()
	gs.end_session()


## WU-016: the Adventures section appears only once there is progress.
func test_adventures_section() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(80), "male")
	gs.start_session(c)
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	assert_false(sheet._text.get_parsed_text().contains("Adventures"), "hidden when empty")
	var id: String = gs.data.inheritances.keys()[0]
	c.trial_progress[id] = 1
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("Adventures") and text.contains("%s: 1/" % gs.data.inheritances[id]["name"]), text)
	sheet.free()


func test_strongest_foe_line() -> void:
	var gs := _game_state()
	assert_eq(CharacterSheet.strongest_foe_line(gs.data, {}), "")
	var low: RealmDef = gs.data.realms[0]
	var high: RealmDef = gs.data.realms[1]
	var flags := {Guidance.beat_realm_flag(low.id): true}
	assert_eq(CharacterSheet.strongest_foe_line(gs.data, flags), "Strongest foe beaten: %s" % low.name)
	flags[Guidance.beat_realm_flag(high.id)] = true
	assert_eq(CharacterSheet.strongest_foe_line(gs.data, flags), "Strongest foe beaten: %s" % high.name)


func test_next_steps_text_caps_at_three() -> void:
	var two := CharacterSheet.next_steps_text(PackedStringArray(["a", "b"]), "J")
	assert_eq(two.count("\n"), 2)
	assert_false(two.contains("More"))
	var four := CharacterSheet.next_steps_text(PackedStringArray(["a", "b", "c", "d"]), "J")
	assert_eq(four.count("\n"), 4)
	assert_true(four.contains("More in the Journal (J)"))
	assert_false(four.contains("- d"))


func test_contribution_line() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(79), "male")
	assert_eq(CharacterSheet.contribution_line(c), "")
	c.sect = {"id": "azure_cloud", "rank": 1, "contribution": 7773, "spent": 1000}
	assert_eq(CharacterSheet.contribution_line(c), "Contribution: 6773 to spend (lifetime 7773)")


## GFX-024: the left column shows one root bar per element with the character's values.
func test_root_bars_and_portrait() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(81), "male")
	gs.start_session(c)
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var rows := CharacterSheet.root_rows(c.spiritual_roots, gs.data)
	assert_eq(rows.size(), gs.data.root_elements.size())
	assert_eq(sheet._root_box.get_child_count(), rows.size())
	for row in rows:
		assert_eq(row["value"], int(c.spiritual_roots.get(row["id"], 0)))
		var bar := sheet._root_box.get_node("root_" + String(row["id"])).get_child(1) as ProgressBar
		assert_eq(int(bar.value), row["value"])
	assert_true(sheet._portrait.texture != null, "portrait drawn")
	assert_eq(sheet._name_label.text, c.name)
	assert_false(sheet._text.get_parsed_text().contains("Spiritual Root:"), "moved to the bars")
	sheet.free()
	gs.end_session()
