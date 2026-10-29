extends TestCase
## WU-091: with every HUD line on at once (goal, hunt, festival, injuries, secret realm, 3 hints,
## key bar) the status panel must stay inside the window and clear of the log and prompt.

const DECK := Vector2(1280, 800)
const HudScript := preload("res://src/ui/hud.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 4) -> void:
	for i in n:
		await _tree().process_frame


func test_status_panel_clear_of_log_and_prompt() -> void:
	await _check(1.0)


func test_status_panel_clear_of_log_and_prompt_at_115_percent() -> void:
	await _check(1.15)


func _check(scale: float) -> void:
	var root := _tree().root
	var old_size := root.size
	root.size = Vector2i(DECK)
	var old_scale: Variant = Settings.get_value("ui_scale")
	var old_hints: Variant = Settings.get_value("hud_hints")
	Settings.set_value("ui_scale", scale)
	Settings.set_value("hud_hints", 3)
	var gs: Node = root.get_node("GameState")
	var c := CharacterFactory.create("Lin Feng Of The Long Name", gs.data, seeded_rng(5), "male")
	gs.start_session(c)
	gs.pending_event = ""
	for injury_id: String in gs.data.injuries:
		Injuries.inflict(c, gs.data, injury_id)
	gs.join_sect("azure_cloud_sect")
	var offers := Bounties.offers(c, gs.data, GameClock.total_days)
	if not offers.is_empty():
		Bounties.take(c, gs.data, String(offers[0]["id"]), GameClock.total_days)
	for event_id: String in gs.data.world_events:
		if WorldEvents.is_festival(gs.data, event_id):
			gs.world_events.append({"id": event_id, "region": gs.current_region, "start_day": 0, "end_day": 99999, "done": false})
			break
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 30:
		EventBus.post("Message %d: a long line of news that wraps across the log so it takes room." % i)
	await _frames()
	var view := Rect2(Vector2.ZERO, DECK / scale)
	var status: Control = hud.get("_status_panel")
	var log_panel: Control = hud.get("_log_panel")
	var prompt: Control = hud.get("_prompt")
	var rect := status.get_global_rect()
	assert_true(view.encloses(rect), "status panel inside the window: %s" % rect)
	assert_false(rect.intersects(log_panel.get_global_rect()), "status panel %s overlaps the log %s" % [rect, log_panel.get_global_rect()])
	hud.set("_target_name", "Elder Mo")
	hud.call("_refresh_key_hints")
	await _frames()
	rect = status.get_global_rect()
	assert_false(rect.intersects(prompt.get_global_rect()), "status panel %s overlaps the prompt %s" % [rect, prompt.get_global_rect()])
	assert_true(hud.get("_lives").visible, "lives line shown")
	assert_false(rect.intersects(prompt.get_global_rect()) or rect.intersects(log_panel.get_global_rect()), "lives line keeps the panel clear")
	hud.queue_free()
	Settings.set_value("ui_scale", old_scale)
	Settings.set_value("hud_hints", old_hints)
	root.size = old_size
	gs.end_session()


func test_lives_text_and_color() -> void:
	assert_eq(HudScript.lives_text(3), "Lives 3")
	assert_eq(HudScript.lives_text(0), "Lives 0 - Final life")
	assert_eq(HudScript.lives_text(-1), "")
	assert_eq(HudScript.lives_color(1), UIStyle.CATEGORY_COLORS["warning"])
	assert_eq(HudScript.lives_color(0), UIStyle.CATEGORY_COLORS["danger"])
	assert_eq(HudScript.lives_color(4), Color.WHITE)


func test_first_sentence() -> void:
	assert_eq(HudScript.first_sentence("A b. C d."), "A b. (J)")
	assert_eq(HudScript.first_sentence("No stop here"), "No stop here")


func test_cap_hint() -> void:
	assert_eq(HudScript.cap_hint("Short line."), "Short line.")
	var long_text := "Earn 440 more sect contribution to reach the next rank, by Relieve a Fevered Village or Escort Mortal Villagers, which is ready again in 6 days. " + "x".repeat(40)
	var capped := HudScript.cap_hint(long_text)
	assert_true(capped.length() <= HudScript.HINT_MAX_CHARS + 8, "capped length %d" % capped.length())
	assert_true(capped.ends_with("\u2026 (J)"))
	assert_true(long_text.begins_with(capped.trim_suffix("\u2026 (J)")), "cut is a prefix at a word boundary")


func test_fit_keeps_one_hint_when_three_do_not_fit() -> void:
	var root := _tree().root
	var old_size := root.size
	root.size = Vector2i(DECK)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var hint: Label = hud.get("_hint")
	var panel: Control = hud.get("_guide_panel")
	var lines := PackedStringArray(["One hint line. More.", "Two hint line.", "Three hint line."])
	hud.set("_hint_lines", lines)
	hud.call("_set_hint_text", lines)
	for name: String in ["_fair"]:
		hud.get(name).visible = false
	panel.reset_size()
	var full := panel.size.y
	hud.call("_set_hint_text", lines.slice(0, 1))
	panel.reset_size()
	var one := panel.size.y
	hud.call("_set_hint_text", lines)
	assert_true(one < full, "three hints are taller than one")
	var fits: bool = hud.call("_shrink_hint", one + 1.0)
	assert_true(fits, "one hint fits the limit")
	assert_true(hint.visible, "hint still shown")
	assert_eq(hint.text.count("\n"), 0, "cut to one line")
	hud.queue_free()
	root.size = old_size
	gs.end_session()


func test_first_hint_badge_only_when_a_place_is_named() -> void:
	var names: Array = ["Village Clinic", "Village Gate"]
	assert_true(HudScript.first_hint_names_place("Try the Village Clinic.", names))
	assert_true(not HudScript.first_hint_names_place("Rest and meditate.", names))
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var place := str(gs.data.regions[gs.current_region]["places"][0]["display_name"])
	hud.call("_set_hint_text", PackedStringArray(["Visit " + place + " now."]))
	assert_true(hud.get("_hint_badge").visible, "badge shown beside a named place")
	hud.call("_set_hint_text", PackedStringArray(["Just breathe."]))
	assert_true(not hud.get("_hint_badge").visible, "no badge otherwise")
	hud.queue_free()
	gs.end_session()


func test_first_hint_badge_for_a_hint_naming_only_an_npc() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var here := ""
	var elsewhere := ""
	for c in gs.npcs.values():
		if not c.alive or gs.data.npcs.has(c.id):
			continue
		var name := "%s (%s)" % [c.name, Npcs.world_title(c, gs.player, gs.data)]
		if Npcs.region_of(c, gs.data) == gs.current_region:
			here = name
		elif elsewhere == "":
			elsewhere = name
	assert_true(here != "" and elsewhere != "", "world has generated NPCs here and elsewhere")
	var names := Interactable.region_marker_names(gs.data, gs.npcs, gs.current_region, gs.player)
	assert_true(HudScript.first_hint_names_place("%s here would spar with you." % here, names))
	assert_true(not HudScript.first_hint_names_place("%s here would spar with you." % elsewhere, names))
	# WU-297: hints write "Name (Realm)", labels "Name (Title)"; the badge must match on the name.
	var realm_form := here.get_slice(" (", 0) + " (Qi Refining)"
	assert_true(HudScript.first_hint_names_place("%s here would spar with you." % realm_form, names), "realm form of the name")
	assert_true(not HudScript.first_hint_names_place("%s here would spar with you." % (elsewhere.get_slice(" (", 0) + " (Qi Refining)"), names))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	hud.call("_set_hint_text", PackedStringArray(["%s here would spar with you." % here]))
	assert_true(hud.get("_hint_badge").visible, "badge shown for an NPC-only hint")
	hud.queue_free()
	gs.end_session()


func test_capped_hint_tooltip_has_full_text() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var long_text := "Walk to the far market and ".repeat(8) + "buy armor."
	assert_true(long_text.length() > 150)
	hud.call("_set_hint_text", PackedStringArray([long_text]))
	var label: Label = hud.get("_hint")
	assert_true(label.text.ends_with("… (J)"), "line is capped")
	assert_eq(label.tooltip_text, long_text)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_PASS)
	hud.call("_set_hint_text", PackedStringArray(["Just breathe."]))
	assert_eq(label.tooltip_text, "")
	hud.queue_free()
	gs.end_session()
