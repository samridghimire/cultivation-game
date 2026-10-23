extends TestCase
## FH-004b: the threat prompt (ChoiceMenu source) and its HUD wiring.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Threat", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


## Registers a mist-wolf clone whose attack and hp are tuned until it earns `label`.
func _foe(gs: Node, c: CharacterData, id: String, label: String, lethal: bool) -> void:
	for atk in range(-10, 120, 2):
		for hp in range(-30, 200, 10):
			var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
			foe["id"] = id
			foe["realm"] = "mortal"
			foe["attack"] = atk
			foe["hp"] = hp
			foe["lethal"] = lethal
			if Combat.danger_label(c, gs.data, foe) == label:
				gs.data.enemies[id] = foe
				return
	assert_true(false, "no foe found rated " + label)


func _pending() -> ThreatPrompt:
	var gs := _gs()
	var c := _start()
	_foe(gs, c, "t_danger", "Dangerous", true)
	gs._resolve_explore_enemy("t_danger")
	var prompt := ThreatPrompt.new()
	prompt.prepare("t_danger")
	return prompt


func test_options() -> void:
	var prompt := _pending()
	var options := prompt.menu_options()
	assert_eq(options.size(), 2)
	assert_true(String(options[0]["label"]).begins_with("Slip away"))
	assert_true(String(options[1]["label"]).contains("to the death"))
	assert_true(String(options[1]["label"]).contains("%"))
	prompt.free()
	_gs().end_session()


func test_slip_away_clears_threat_and_passes_a_day() -> void:
	var prompt := _pending()
	var day: int = GameClock.total_days
	(prompt.menu_options()[0]["action"] as Callable).call()
	assert_eq(_gs().pending_threat, "")
	assert_eq(GameClock.total_days, day + 1)
	prompt.free()
	_gs().end_session()


func test_closing_slips_away_only_when_pending() -> void:
	var prompt := _pending()
	var day: int = GameClock.total_days
	prompt.on_menu_closed()
	assert_eq(_gs().pending_threat, "")
	assert_eq(GameClock.total_days, day + 1)
	prompt.on_menu_closed()
	assert_eq(GameClock.total_days, day + 1)
	prompt.free()
	_gs().end_session()


func test_travel_clears_threat() -> void:
	var prompt := _pending()
	var gs := _gs()
	var region: Dictionary = gs.data.regions[gs.current_region]
	var dest := ""
	for id in region.get("connections", {}):
		dest = String(id)
		break
	if dest == "":
		prompt.free()
		gs.end_session()
		return
	gs.travel(dest)
	assert_eq(gs.pending_threat, "")
	prompt.free()
	gs.end_session()


func test_hud_shows_prompt_with_slip_away_focused() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var prompt := _pending()
	prompt.free()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	await tree.process_frame
	EventBus.threat_sensed.emit("t_danger")
	await tree.process_frame
	await tree.process_frame
	var menu: Control = hud.get("_choice_menu")
	assert_true(menu.visible)
	var owner := tree.root.gui_get_focus_owner()
	assert_true(owner is Button and (owner as Button).text.begins_with("Slip away"), "slip away focused")
	menu.close()
	assert_false(menu.visible)
	assert_eq(_gs().pending_threat, "")
	tree.root.remove_child(hud)
	hud.free()
	_gs().end_session()


## [REVIEW] ENC-009 senses non-lethal foes too: neither the log line nor the prompt may speak of death.
func test_non_lethal_threat_never_warns_of_death() -> void:
	var gs := _gs()
	var c := _start()
	c.artifact_lives = 0
	_foe(gs, c, "t_soft_danger", "Dangerous", false)
	gs.data.enemies["t_soft_danger"]["attack"] = 400
	assert_true(Exploration.should_offer_flee(c, gs.data, "t_soft_danger"))
	var lines: Array[String] = []
	var grab := func(text: String, _category: String) -> void: lines.append(text)
	EventBus.message_posted.connect(grab)
	gs._resolve_explore_enemy("t_soft_danger")
	EventBus.message_posted.disconnect(grab)
	assert_eq(gs.pending_threat, "t_soft_danger")
	assert_false(" ".join(lines).contains("kill"), "a non-lethal foe is not hungry for a kill")
	var prompt := ThreatPrompt.new()
	prompt.prepare("t_soft_danger")
	var fight := prompt.menu_options()[1]
	assert_false(String(fight["description"]).contains(Warnings.FINAL_DEATH))
	assert_false(String(fight["label"]).contains("to the death"))
	prompt.free()
	gs.pending_threat = ""
	gs.data.enemies.erase("t_soft_danger")
	gs.end_session()
