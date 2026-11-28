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


## WU-613: the tab focus follows the page, the treasury is one block (affordable first) and no "within reach" duplicate.
func test_sect_page_tidy() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.join_sect("azure_cloud_sect")
	var journal := JournalScreen.new()
	root.add_child(journal)
	journal.open()
	await root.get_tree().process_frame
	journal.set_page("sect")
	await root.get_tree().process_frame
	assert_true(root.get_viewport().gui_get_focus_owner() == journal._tabs.get_node("Tab_sect"), "focus follows to the Sect tab")
	journal.set_page("journal")
	assert_true(root.get_viewport().gui_get_focus_owner() == journal._tabs.get_node("Tab_journal"), "and to every other tab")
	var rows: Array[Dictionary] = [{"text": "a (9)", "affordable": false}, {"text": "b (1)", "affordable": true}, {"text": "c (2)", "affordable": true}]
	var ordered := JournalScreen.treasury_order(rows)
	assert_eq(String(ordered[0]["text"]), "b (1)")
	assert_eq(String(ordered[2]["text"]), "a (9)")
	var lines := JournalScreen.month_lines(Sects.month_status(gs.player, gs.data, GameClock.total_days, gs.world_flags))
	for l in lines:
		assert_false(l.begins_with("Treasury"), "the treasury lives in one block")
	assert_eq(journal._sect.find_children("SectTreasury", "", true, false).size(), 1 if not Sects.treasury_rows(gs.player, gs.data).is_empty() else 0)
	journal.free()


func test_month_lines_show_contest_line() -> void:
	var lines := JournalScreen.month_lines({"duty": 0, "stipend": {}, "lecture": "", "contest": "Contest: month 3 (in 10 days)"})
	assert_true("Contest: month 3 (in 10 days)" in lines)
	assert_false("Contest" in "".join(JournalScreen.month_lines({"duty": 0, "stipend": {}})))


## WU-618: the rank goals show on the Sect page for rank 1, not rank 0 or rogues.
func test_sect_goal_rows_by_rank() -> void:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Goals", d, seeded_rng(3))
	c.realm_index = 1
	c.alignment = 50
	assert_true(JournalScreen.sect_goal_rows(c, d, {}).is_empty())
	Sects.join(c, d, "azure_cloud_sect")
	assert_true(JournalScreen.sect_goal_rows(c, d, {}).is_empty())
	c.sect["rank"] = 1
	var rows := JournalScreen.sect_goal_rows(c, d, {})
	assert_false(rows.is_empty())
	assert_eq(JournalScreen.sect_goals_heading(c, d), "Rise to %s" % d.sects["azure_cloud_sect"].rank_name(2))


## WU-622: the blocker line formats buckets in a fixed order and hides when empty.
func test_blockers_text() -> void:
	assert_eq(JournalScreen.blockers_text({}), "")
	assert_eq(JournalScreen.blockers_text({"blockers": {"items": 5, "rank": 9}}), "9 need a higher rank, 5 need items")


## WU-622: mission_blockers buckets every not-ready mission once; ready + blocked = total.
func test_mission_blockers_buckets() -> void:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Blocked", d, seeded_rng(5))
	assert_true(Sects.mission_blockers(c, d, {}).is_empty(), "rogues have none")
	c.realm_index = 1
	c.alignment = 50
	Sects.join(c, d, "azure_cloud_sect")
	var st := Sects.month_status(c, d, 0, {})
	var blocked := 0
	for k: String in st["blockers"]:
		blocked += int(st["blockers"][k])
	assert_eq(int(st["missions_ready"]) + blocked, int(st["missions_total"]))
	c.sect["rank"] = 0
	assert_true(int(Sects.mission_blockers(c, d, {}).get("rank", 0)) > 0 or int(st["missions_total"]) == int(st["missions_ready"]), "rank-0 sees rank-gated missions")


## WU-622: a met duty line is flagged met by progress >= duty (text unchanged).
func test_duty_line_text() -> void:
	var lines := JournalScreen.month_lines({"duty": 30, "progress": 12, "days_left": 9, "stipend": {}})
	assert_eq(lines[0], "Duty: 12 / 30 contribution, 9 days left")


## GFX-257: goal rows draw a tick box with the done state; the contribution row hides under the rank bar.
func test_goal_box_row_and_no_duplicate_contribution() -> void:
	var done_row := JournalScreen.goal_box_row(true, "Done thing")
	var open_row := JournalScreen.goal_box_row(false, "Open thing")
	assert_true(done_row.get_node("GoalBox").done)
	assert_false(open_row.get_node("GoalBox").done)
	done_row.free()
	open_row.free()
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Ticks", d, seeded_rng(3))
	c.realm_index = 1
	c.alignment = 50
	Sects.join(c, d, "azure_cloud_sect")
	c.sect["rank"] = 1
	for g: Dictionary in JournalScreen.sect_goal_rows(c, d, {}):
		assert_true(String(g.get("key", "")) != "contribution")


## WU-627: the contest record line is absent before the first contest and present after.
func test_contest_record_line() -> void:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Rec", d, seeded_rng(5))
	c.realm_index = 1
	Sects.join(c, d, "azure_cloud_sect")
	assert_eq(Sects.contest_record_line(c, d), "")
	Sects.record_contest(c, d, 2, 3, 100)
	var line := Sects.contest_record_line(c, d)
	assert_true(line.begins_with("Contest record: best round 2"), line)
	assert_false(line.contains("champion"))
	Sects.record_contest(c, d, 3, 3, 100)
	assert_true(Sects.contest_record_line(c, d).ends_with("champion 1 time"))
	assert_true("Contest record: x" in JournalScreen.month_lines({"duty": 0, "stipend": {}, "contest_record": "Contest record: x"}))


## SECT-051: the Sect page shows the trial preview row under the goals only while the odds are poor.
func test_sect_page_trial_preview_row() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.join_sect("azure_cloud_sect")
	gs.player.sect["rank"] = 1
	for k: String in gs.player.attributes:
		gs.player.attributes[k] = 1
	gs.player.techniques = {}
	var sect: SectDef = gs.data.sects["azure_cloud_sect"]
	var need := int(sect.ranks[2].get("contribution", 0))
	gs.player.sect["contribution"] = need / 2
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await root.get_tree().process_frame
	var journal: JournalScreen = hud.get("_screens").get("toggle_journal")
	journal.open()
	journal.set_page("sect")
	var expect := not Guidance.trial_preview(gs.player, gs.data).is_empty()
	assert_eq(journal._sect.find_child("TrialPreview", true, false) != null, expect)
	gs.player.sect["contribution"] = 0
	journal.set_page("sect")
	journal.open()
	assert_true(journal._sect.find_child("TrialPreview", true, false) == null)
	hud.queue_free()


## WU-653: a far friend's news row has a "Send congratulations" button; a friend here keeps the plain text.
func test_far_friend_news_row_has_send_button() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	FolkNews.queue_own(gs.player, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	gs.npc_favor["xiao_ling"] = 50
	var journal := JournalScreen.new()
	root.add_child(journal)
	await root.get_tree().process_frame
	gs.current_region = "qingshi_village"
	journal.open()
	assert_true(journal.find_child("Send_xiao_ling", true, false) == null, "friend is here: congratulate in person")
	gs.current_region = "withered_bone_marsh"
	journal.open()
	var btn := journal.find_child("Send_xiao_ling", true, false) as Button
	assert_true(btn != null, "far friend gets a button")
	btn.pressed.emit()
	assert_false(gs.player.friend_news.has("xiao_ling"), "the note was sent")
	assert_true(journal.find_child("Send_xiao_ling", true, false) == null, "row removed")
	journal.queue_free()
