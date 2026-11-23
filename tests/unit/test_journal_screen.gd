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


func test_format_entries_colors_by_tone() -> void:
	var text := JournalScreen.format_entries([
		{"section": "S", "text": "Urgent", "tone": "warning"},
		{"section": "S", "text": "Waiting", "tone": "dim"},
		{"section": "S", "text": "Plain", "tone": "normal"},
	])
	var lines := text.split("\n")
	assert_true(lines[1].contains("[color=#e8a04a]"))
	assert_true(lines[2].contains("[color=#999999]"))
	assert_false(lines[3].contains("[color"))


func test_cards_one_per_section_with_goal_boxes() -> void:
	var j := JournalScreen.new()
	j._build_cards([
		{"section": "First goals", "text": "[x] Meditate"},
		{"section": "First goals", "text": "[ ] Gather herbs"},
		{"section": "Next steps", "text": "Rest"},
	])
	assert_eq(j._cards.get_child_count(), 2)
	assert_eq(String(j._cards.get_child(0).get_meta("title")), "First goals")
	assert_eq(JournalScreen.parse_goal("[x] A"), {"done": true, "text": "A"})
	assert_true(JournalScreen.parse_goal("Plain").is_empty())
	var first: Node = j._cards.get_child(0).get_child(0)
	assert_true(first.get_child(1).get_child(0) is JournalScreen.CheckBox_pixel, "goal row has a pixel box")
	j.free()


## WU-605: the Sect tab exists for a member only; the page names the rank and the next rank's needs.
func test_sect_tab_for_members_only() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await root.get_tree().process_frame
	var journal: JournalScreen = hud.get("_screens").get("toggle_journal")
	journal.open()
	assert_false((journal._tabs.get_node("Tab_sect") as Button).visible, "rogues never see the tab")
	journal.close()
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.join_sect("azure_cloud_sect")
	(hud.get("_pending_moments") as Array).clear()
	(hud.get("_sect_card") as Control).close()
	journal.open()
	assert_true((journal._tabs.get_node("Tab_sect") as Button).visible)
	journal.set_page("sect")
	assert_true(journal._sect.visible)
	var def: SectDef = gs.data.sects["azure_cloud_sect"]
	var ladder := Sects.ladder(gs.player, gs.data)
	var texts := PackedStringArray()
	for n in journal._sect.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var all := "\n".join(texts)
	assert_true(all.contains(def.rank_name(int(gs.player.sect["rank"]))))
	for r: Dictionary in ladder:
		if not bool(r["reached"]) and not (r["needs"] as PackedStringArray).is_empty():
			assert_true(all.contains(String((r["needs"] as PackedStringArray)[0])), "next rank's needs shown")
			break
	journal.close()
	hud.queue_free()


## WU-610: rank progress, treasury costs and ready missions on the Sect page (pure helpers + page).
func test_sect_page_progress() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.join_sect("azure_cloud_sect")
	var prog := Sects.rank_progress(gs.player, gs.data)
	assert_false(prog.is_empty())
	assert_true(JournalScreen.rank_progress_text(prog).contains(" / "))
	var rows := Sects.treasury_rows(gs.player, gs.data)
	assert_false(rows.is_empty())
	assert_true(String(rows[0]["text"]).ends_with(")"))
	gs.player.sect["contribution"] = 100000
	var shop := Sects.shop_items(gs.player, gs.data)
	var after := Sects.treasury_rows(gs.player, gs.data)
	for i in after.size():
		var open := int(shop[i].get("min_rank", 0)) <= int(gs.player.sect["rank"])
		assert_eq(bool(after[i]["affordable"]), open, "rich: affordable exactly when the rank allows")
	assert_true(Sects.ready_mission_names(gs.player, gs.data, {}, 2).size() <= 2)
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await root.get_tree().process_frame
	var journal: JournalScreen = hud.get("_screens").get("toggle_journal")
	journal.open()
	journal.set_page("sect")
	assert_true(journal._sect.find_child("RankBar", true, false) != null)
	assert_true(journal._sect.find_child("SectTreasury", true, false) != null)
	hud.queue_free()
