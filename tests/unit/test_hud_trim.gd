extends TestCase
## WU-519: every fixed-width HUD line either fits its width or ends in an ellipsis; none is cut mid-glyph.

const HudScript := preload("res://src/ui/hud.gd")


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


func _text_w(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


func _fits_or_ellipsis(label: Label, text: String, width: float) -> bool:
	return _text_w(label, text) <= width or label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS


func test_status_line_longest_sect_rank_and_alignment() -> void:
	var hud := await _build()
	var gs: Node = _tree().root.get_node("GameState")
	var status: Label = hud.get("_status")
	var worst := ""
	for tier: Dictionary in gs.data.alignment_tiers:
		for sect: SectDef in gs.data.sects.values():
			for rank in sect.ranks.size():
				var line: String = HudScript.alignment_line(String(tier.get("name", "")), "%s, %s" % [sect.name, sect.rank_name(rank)])
				if _text_w(status, line) > _text_w(status, worst):
					worst = line
				assert_true(_fits_or_ellipsis(status, line, HudScript.STATUS_TEXT_WIDTH), line)
	assert_true(worst != "")
	status.text = worst
	await _tree().process_frame
	assert_true(status.get_minimum_size().x <= HudScript.STATUS_TEXT_WIDTH + 1.0, "the label never grows past its card: " + worst)
	hud.queue_free()
	gs.end_session()


func test_hunt_line_and_key_strip_fit() -> void:
	var hud := await _build()
	var gs: Node = _tree().root.get_node("GameState")
	var hunt: Label = hud.get("_hunt")
	for id: String in gs.data.regions:
		var great: Variant = gs.data.regions[id].get("roamers", {}).get("great", null)
		if not great is Dictionary:
			continue
		for enemy_id: String in [String(great.get("enemy", "")), String(great.get("return", {}).get("enemy", ""))]:
			if enemy_id == "" or not gs.data.enemies.has(enemy_id):
				continue
			var foe: String = gs.data.enemies[enemy_id].name
			for region_name: String in ["Withered Bone Marsh", "Fallen Star Market", "Myriad Peaks Ridge"]:
				var line: String = Guidance.short_fight_line("Hunting: %s in %s (9 days left)" % [foe, region_name], gs.data)
				assert_true(_fits_or_ellipsis(hunt, line + " (J)", hunt.custom_minimum_size.x), line)
	var bar: Label = hud.get("_key_bar")
	var style := bar.get_theme_stylebox("normal")
	var strip_w := _text_w(bar, bar.text) + style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	await _tree().process_frame
	var rect := bar.get_global_rect()
	assert_true(rect.size.x >= strip_w - 1.0, "the strip is as wide as its text, never cut")
	assert_true(rect.position.x >= (hud.get("_log_panel") as Control).get_global_rect().end.x, "the strip stays right of the log: %s" % rect)
	hud.queue_free()
	gs.end_session()
