extends TestCase
## UI-006: the HUD warns when lifespan runs low and when a breakthrough is due.

const HUD := preload("res://src/ui/hud.gd")


func test_lifespan_category_thresholds() -> void:
	assert_eq(HUD.lifespan_category(50, 80), "")
	assert_eq(HUD.lifespan_category(12, 80), "warning")
	assert_eq(HUD.lifespan_category(4, 80), "danger")
	assert_eq(HUD.lifespan_category(3, 1000), "danger", "a few years left is always urgent")
	assert_eq(HUD.lifespan_category(100, 1000), "warning")
	assert_eq(HUD.lifespan_category(0, 0), "danger")


func test_bottleneck_hint_only_at_bottleneck() -> void:
	var d := data()
	var c := new_character()
	assert_eq(HUD.bottleneck_hint(c, d), "")
	var realm: RealmDef = d.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	assert_true(Cultivation.can_attempt_breakthrough(c, d))
	var hint: String = HUD.bottleneck_hint(c, d)
	assert_true(hint.begins_with("Bottleneck!"), hint)
	assert_true(hint.contains("%d%%" % int(Cultivation.breakthrough_chance(c, d) * 100)), hint)
	c.realm_index = d.realms.size() - 1
	realm = d.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	assert_eq(HUD.bottleneck_hint(c, d), "You stand at the peak of the known realms.")


## WU-014: the HUD hint panel follows the "hud_hints" setting.
func test_hud_hint_panel_follows_setting() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	var st: Node = tree.root.get_node("Settings")
	var old: Variant = st.get_value("hud_hints")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	await tree.process_frame
	var hint: Label = hud.get("_hint")
	st.set_value("hud_hints", 0)
	assert_false(hint.visible, "0 hides the panel")
	st.set_value("hud_hints", 1)
	assert_true(hint.visible)
	assert_eq(hint.text.split("\n").size(), 1)
	st.set_value("hud_hints", 3)
	var lines := hint.text.split("\n").size()
	assert_true(lines >= 2 and lines <= 3, "up to three lines, got %d" % lines)
	st.set_value("hud_hints", old)
	hud.queue_free()
	gs.end_session()


## WU-028: the status panel and log hide behind modals, not behind the time-skip overlay.
func test_hud_panels_hide_behind_modals() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	await tree.process_frame
	var status: Control = hud.get("_status_panel")
	var log_panel: Control = hud.get("_log_panel")
	assert_true(status.visible and log_panel.visible)
	var screens: Dictionary = hud.get("_screens")
	var inv: Control = screens["toggle_inventory"]
	inv.open()
	hud.call("_update_modal")
	assert_false(status.visible, "status panel hidden behind the inventory")
	assert_false(log_panel.visible, "log hidden behind the inventory")
	inv.close()
	hud.call("_update_modal")
	assert_true(status.visible and log_panel.visible)
	var skip: Control = hud.get("_time_skip")
	skip.visible = true
	hud.call("_update_modal")
	assert_true(status.visible and log_panel.visible, "time-skip overlay keeps the HUD")
	skip.visible = false
	hud.queue_free()


## WU-041: a dim line under the qi bar says how long until the next layer.
func test_hud_next_layer_label() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	await tree.process_frame
	var label: Label = hud.get("_next_layer")
	var days: int = gs.days_to_next_stage(gs.region_qi_density())
	assert_true(days > 0 and days <= 3650)
	assert_true(label.visible)
	assert_true(label.text.contains("~%d " % days), "shows %d days, got '%s'" % [days, label.text])
	c.qi = Cultivation.qi_required(c, gs.data) - 0.0
	c.stage = gs.data.realms[c.realm_index].stage_names.size() - 1
	c.qi = Cultivation.qi_required(c, gs.data)
	assert_true(Cultivation.is_at_bottleneck(c, gs.data))
	assert_eq(HUD.next_layer_text(-1, c, gs.data), "")
	assert_eq(HUD.next_layer_text(5, c, gs.data), "", "hidden at the bottleneck")
	hud.queue_free()
	gs.end_session()


## WU-044: the goal line on the HUD.
func test_goal_text() -> void:
	var d := data()
	var c := new_character()
	var first: Array[Dictionary] = Guidance.first_goals(c, d, {})
	assert_eq(HUD.goal_text(c, d, {}, null, 1.0), "Goal: " + str(first[0]["text"]))
	c.realm_index = 2
	var lines := Guidance.goals(c, d, {}, null, 1.0)
	assert_eq(HUD.goal_text(c, d, {}, null, 1.0), "Goal: " + lines[0])


## WU-082: the hunt line, the quarry note and the bounty banner.
func test_hunt_line_and_banner() -> void:
	var d := data()
	var c := new_character()
	assert_eq(HUD.hunt_line(c, d, 100), "")
	Bounties.take(c, d, "iron_back_boar_bounty", 100)
	var line: String = HUD.hunt_line(c, d, 100)
	assert_true(line.begins_with("Hunting: "), line)
	assert_true(line.contains("(60 days left)"), line)
	assert_true(HUD.hunt_line(c, d, 159).ends_with("(1 day left)"))
	assert_eq(HUD.hunt_line(c, d, 161), "")
	assert_eq(HUD.bounty_banner("Boar", 40), PackedStringArray(["Bounty claimed", "Boar: 40 spirit stones"]))


## WU-125: the fair-fight status line.
func test_fair_fight_line() -> void:
	assert_eq(HUD.fair_fight_line([]), "")
	var one: Array[Dictionary] = [{"text": "Sect mission: Boar (80%)", "chance": 0.8, "kind": "mission"}, {"text": "Other", "chance": 0.6, "kind": "deed"}]
	assert_eq(HUD.fair_fight_line(one), "Fair fight: Sect mission: Boar (80%)")
	var named: Array[Dictionary] = [{"text": "Sect mission: Boar Hunt (Even, 80 in 100)", "chance": 0.8, "kind": "mission", "enemy": "Boar"}]
	assert_eq(HUD.fair_fight_line(named), "Fair fight: Boar (Even 80)")


## WU-150: the longest enemy name still fits the 316px label (percent dropped first).
func test_fair_fight_line_fits_longest_enemy() -> void:
	var font: Font = ThemeDB.fallback_font
	var longest := ""
	for id: String in data().enemies:
		var n: String = data().enemies[id].name
		if n.length() > longest.length():
			longest = n
	var e: Array[Dictionary] = [{"text": "x", "chance": 0.55, "kind": "mission", "enemy": longest}]
	var line: String = HUD.fair_fight_line(e, font, 14, 316.0)
	assert_true(line.begins_with("Fair fight: " + longest), line)
	var full := "Fair fight: %s (Even 55)" % longest
	if font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > 316.0:
		assert_true(not line.ends_with("55)"), "percent dropped: " + line)
	var short: Array[Dictionary] = [{"text": "x", "chance": 0.8, "kind": "mission", "enemy": "Boar"}]
	assert_eq(HUD.fair_fight_line(short, font, 14, 316.0), "Fair fight: Boar (Even 80)")


func test_quarry_note_only_in_the_bounty_region() -> void:
	var d := data()
	var c := new_character()
	var Site := preload("res://src/world/interactables/explore_site.gd")
	assert_eq(Site.quarry_note(c, d, "misty_forest", 100), "")
	Bounties.take(c, d, "iron_back_boar_bounty", 100)
	assert_true(Site.quarry_note(c, d, "misty_forest", 100).ends_with("trail may be found here."))
	assert_eq(Site.quarry_note(c, d, "qingshi_village", 100), "")


## WU-130: technique level-ups are reported as a diff of levels.
func test_leveled_techniques() -> void:
	var d := data()
	var c := new_character()
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	var before := {"iron_fist": 1}
	assert_eq(HUD.leveled_techniques(before, c, d).size(), 0)
	c.techniques["iron_fist"]["level"] = 2
	var out: Array[Dictionary] = HUD.leveled_techniques(before, c, d)
	assert_eq(out.size(), 1)
	assert_eq(int(out[0]["level"]), 2)
	assert_eq(HUD.leveled_techniques({}, c, d).size(), 0, "a newly learned technique is not announced")


## WU-131: newly done first goals are reported in list order.
func test_newly_done_goals() -> void:
	var goals: Array[Dictionary] = [{"text": "A", "done": true}, {"text": "B", "done": false}, {"text": "C", "done": false}]
	var before: Array[String] = ["A"]
	assert_eq(HUD.newly_done_goals(before, goals).size(), 0)
	goals[1]["done"] = true
	assert_eq(HUD.newly_done_goals(before, goals), ["B"] as Array[String])
	goals[2]["done"] = true
	assert_eq(HUD.newly_done_goals([] as Array[String], goals), ["A", "B", "C"] as Array[String])


## The last goal of a ladder is still announced, and names the ladder it completes.
func test_goals_done_banner() -> void:
	var goals: Array[Dictionary] = [{"text": "A", "done": true}, {"text": "B", "done": false}]
	assert_eq(HUD.goals_done_banner(["A"] as Array[String], goals, "first", "J"), "")
	assert_eq(HUD.goals_done_banner([] as Array[String], goals, "first", "J"), "A  Next: B")
	goals[1]["done"] = true
	assert_eq(HUD.goals_done_banner(["A"] as Array[String], goals, "first", "J"), "B  Your first goals are done; the journal (J) has more.")
	assert_eq(HUD.goals_done_banner(["A"] as Array[String], goals, "foundation", "J"), "B  Your Foundation goals are done; the journal (J) has more.")
