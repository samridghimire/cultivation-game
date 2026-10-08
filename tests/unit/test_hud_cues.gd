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
