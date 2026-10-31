extends TestCase
## GFX-010: the HUD cards (status top-left, "Next steps" top-right, key strip, log) leave the world visible.

const DECK := Vector2(1280, 800)
const HudScript := preload("res://src/ui/hud.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _build() -> CanvasLayer:
	var root := _tree().root
	root.size = Vector2i(DECK)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await _tree().process_frame
	return hud


func _done(hud: CanvasLayer) -> void:
	hud.queue_free()
	var gs: Node = _tree().root.get_node("GameState")
	gs.end_session()


func test_cards_do_not_overlap_and_cover_little() -> void:
	var hud := await _build()
	hud.set("_target_name", "Elder Mo")
	hud.call("_refresh_key_hints")
	await _tree().process_frame
	var rects: Dictionary = {}
	for name: String in ["_status_panel", "_guide_panel", "_log_panel", "_key_bar", "_prompt"]:
		var c: Control = hud.get(name)
		assert_true(c.visible, name + " visible")
		rects[name] = c.get_global_rect()
	var names := rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			assert_false((rects[names[i]] as Rect2).intersects(rects[names[j]]), "%s %s overlaps %s %s" % [names[i], rects[names[i]], names[j], rects[names[j]]])
	var limit := DECK.y - HudScript.LOG_HEIGHT - HudScript.STATUS_MARGIN
	assert_true((rects["_status_panel"] as Rect2).end.y <= limit, "status card above the log")
	assert_true((rects["_guide_panel"] as Rect2).end.y <= limit, "guide card above the log")
	var area: float = 0.0
	for name: String in ["_status_panel", "_guide_panel", "_log_panel"]:
		area += (rects[name] as Rect2).get_area()
	assert_true(area < 0.18 * DECK.x * DECK.y, "cards cover %.1f%% %s" % [100.0 * area / (DECK.x * DECK.y), rects])
	_done(hud)


func test_lines_moved_into_their_rows() -> void:
	var hud := await _build()
	assert_false((hud.get("_status") as Label).text.contains("Qi: "))
	assert_true((hud.get("_qi_text") as Label).text.begins_with("Qi "))
	assert_true((hud.get("_currency") as Label).text != "")
	var hints: PackedStringArray = hud.get("_hint_lines")
	if not hints.is_empty():
		assert_true((hud.get("_hint") as Label).text.contains(HudScript.cap_hint(hints[0]).substr(0, 20)))
	_done(hud)


func test_key_help_setting() -> void:
	var old: Variant = Settings.get_value("key_help")
	var hud := await _build()
	Settings.set_value("key_help", false)
	assert_false((hud.get("_key_bar") as Label).visible)
	Settings.set_value("key_help", true)
	assert_true((hud.get("_key_bar") as Label).visible)
	assert_eq(Settings.sanitize("key_help", "yes"), true, "non-bool falls back to the default")
	Settings.set_value("key_help", old)
	_done(hud)


func test_hunt_line_shows_with_hints_off() -> void:
	var old: Variant = Settings.get_value("hud_hints")
	var hud := await _build()
	var gs: Node = _tree().root.get_node("GameState")
	var bounty_id: String = gs.data.bounties.keys()[0]
	gs.player.bounty = {"id": bounty_id, "until_day": GameClock.total_days + 10}
	Settings.set_value("hud_hints", 0)
	hud.call("_refresh")
	hud.call("_refresh_fair_fight")
	hud.call("_fit_panels")
	assert_true((hud.get("_hunt") as Label).visible, "hunt line")
	assert_true((hud.get("_guide_panel") as Control).visible, "the hunt deadline stays on screen with hints off")
	gs.player.bounty = {}
	hud.call("_refresh")
	hud.call("_refresh_fair_fight")
	hud.call("_fit_panels")
	assert_false((hud.get("_guide_panel") as Control).visible, "nothing to show with hints off")
	Settings.set_value("hud_hints", old)
	_done(hud)


func test_log_idle_alpha() -> void:
	assert_eq(HudScript.log_idle_alpha(0.0), 1.0)
	assert_true(HudScript.log_idle_alpha(9.0) <= 0.55)


## GFX-016: slimmer cards.
func test_status_card_is_slim_and_merged() -> void:
	var hud := await _build()
	var panel := hud.get("_status_panel") as Control
	assert_true(panel.size.y <= 170.0, "status card %.0f px tall: %s | %s | bottleneck %s" % [panel.size.y, (hud.get("_status") as Label).text, (hud.get("_status") as Label).size, (hud.get("_bottleneck") as Label).text])
	var text: String = (hud.get("_status") as Label).text
	assert_false(text.contains("Alignment:"), text)
	assert_true(text.contains(" · Rogue Cultivator"), text)
	var key_bar := hud.get("_key_bar") as Label
	assert_eq(key_bar.get_line_count(), 1, key_bar.text)
	assert_true(key_bar.get_global_rect().end.x <= DECK.x)
	_done(hud)


func test_card_text_helpers() -> void:
	assert_eq(HudScript.alignment_line("Neutral", "Rogue Cultivator"), "Neutral · Rogue Cultivator")
	var font := ThemeDB.fallback_font
	assert_eq(HudScript.region_line("Qingshi Village (Qi x1.0)", "~70 days to the next stage"), "Qingshi Village (Qi x1.0) · ~70 days to the next stage")
	assert_eq(HudScript.region_line("Qingshi Village (Qi x1.0)", "", font, 13, 300.0), "Qingshi Village (Qi x1.0)")
	assert_true(HudScript.region_line("Qingshi Village (Qi x1.0)", "~70 days to the next stage", font, 13, 100.0).contains("\n"), "wraps only when too wide")
	var lines := PackedStringArray(["a", "b", "c", "d", "e", "f"])
	assert_eq(HudScript.overflow_cut(lines, 5), PackedStringArray(["a", "b", "c", "d", "... more in the journal (J)"]))
	assert_eq(HudScript.overflow_cut(lines.slice(0, 5), 5), lines.slice(0, 5))
	assert_true(HudScript.wrapped_lines("one two three four five six seven eight", font, 14, 60.0).size() > 1)
	var rect := Rect2(16, 16, 316, 150)
	assert_eq(HudScript.card_fade_target(rect, Vector2(100, 100)), 0.35)
	assert_eq(HudScript.card_fade_target(rect, Vector2(340, 100)), 0.35, "within the 16 px margin")
	assert_eq(HudScript.card_fade_target(rect, Vector2(400, 100)), 1.0)


func test_guide_card_caps_wrapped_lines() -> void:
	var hud := await _build()
	var long := PackedStringArray()
	for i in 6:
		long.append("Hint number %d says something fairly long so that it wraps across the card." % i)
	hud.call("_set_hint_text", long)
	hud.call("_fit_panels")
	var font: Font = (hud.get("_hint") as Label).get_theme_font("font")
	var shown := HudScript.wrapped_lines((hud.get("_hint") as Label).text, font, 14, 316.0)
	assert_true(shown.size() <= HudScript.GUIDE_MAX_LINES, str(shown))
	assert_true((hud.get("_hint") as Label).text.contains("more in the journal (J)"))
	_done(hud)
