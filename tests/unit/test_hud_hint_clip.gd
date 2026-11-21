extends TestCase
const HudScript := preload("res://src/ui/hud.gd")
## WU-586: the Next-steps hint is cut with the label's real width, so no shown entry is clipped mid-phrase.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _build() -> CanvasLayer:
	var root := _tree().root
	root.size = Vector2i(1280, 800)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await _tree().process_frame
	return hud


func test_long_last_entry_never_clips() -> void:
	var hud := await _build()
	var hint: Label = hud.get("_hint")
	var lines := PackedStringArray([
		"Hunter Ma can teach you Iron Fist.",
		"Grow closer: give Hunter Ma the Realgar Wine they like, on sale here, as a gift for a friend you made at the tea table (favor 48/60).",
	])
	hud.call("_set_hint_text", lines)
	hud.call("_apply_line_cap")
	for i in 3:
		await _tree().process_frame
	assert_true(hint.size.x > 0.0)
	assert_true(hint.get_line_count() <= hud.get("GUIDE_MAX_LINES"), "wrapped lines within the cap")
	var font := hint.get_theme_font("font")
	var shown := hint.text.split("\n")
	assert_eq(hint.get_line_count(), _wrapped_total(shown, font, hint.size.x), "label wraps as the cut assumed")
	for e in shown:
		assert_true(e in lines or e.ends_with("...") or e.ends_with("\u2026 (J)") or e.ends_with("\u2026") or e.begins_with("More in the Journal"), "whole or ellipsis: " + e)
	hud.queue_free()
	_tree().root.get_node("GameState").end_session()


func _wrapped_total(entries: PackedStringArray, font: Font, width: float) -> int:
	var n := 0
	for e in entries:
		n += maxi(1, HudScript.wrapped_lines(e, font, 14, width).size())
	return n
