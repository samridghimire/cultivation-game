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


func test_quarry_note_only_in_the_bounty_region() -> void:
	var d := data()
	var c := new_character()
	var Site := preload("res://src/world/interactables/explore_site.gd")
	assert_eq(Site.quarry_note(c, d, "misty_forest", 100), "")
	Bounties.take(c, d, "iron_back_boar_bounty", 100)
	assert_true(Site.quarry_note(c, d, "misty_forest", 100).ends_with("trail may be found here."))
	assert_eq(Site.quarry_note(c, d, "qingshi_village", 100), "")
