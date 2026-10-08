extends TestCase
## JournalScreen (WU-007): renders Guidance.journal, opens from the HUD key and the pause menu.


func test_format_groups_by_section() -> void:
	var text := JournalScreen.format_entries([
		{"section": "Next steps", "text": "Do a thing [now]"},
		{"section": "Next steps", "text": "Another"},
		{"section": "Sect", "text": "Duty"},
	])
	assert_eq(text.count("Next steps"), 1)
	assert_true(text.contains("Sect"))
	assert_true(text.contains("[lb]now]"), "brackets are escaped")


func test_hud_registers_journal_key_and_pause_entry() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await root.get_tree().process_frame
	assert_true(InputMap.has_action("toggle_journal"))
	var journal: JournalScreen = hud.get("_screens").get("toggle_journal")
	assert_true(journal is JournalScreen)
	hud.call("_open_journal")
	assert_true(journal.visible)
	assert_false((hud.get("_pause_menu") as Control).visible)
	assert_true(journal._text.get_parsed_text().contains("Breakthrough"))
	journal.close()
	hud.queue_free()
