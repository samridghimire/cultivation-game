extends TestCase
## QA-008: gamepad/focus audit. Opens every HUD modal on a live HUD and checks
## that a visible control inside it has keyboard/gamepad focus and that
## ui_cancel closes it (CLAUDE.md rule 8).


class MenuSource extends Node:
	var display_name := "Test Stone"

	func menu_options() -> Array[Dictionary]:
		return [{"label": "Touch it", "action": func() -> void: pass}]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_tree().root.push_input(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	_tree().root.push_input(release)


## Asserts `screen` is open with focus inside it, then closes it with ui_cancel.
func _check(screen: Control, label: String) -> void:
	await _frames()
	assert_true(screen.is_visible_in_tree(), "%s opens" % label)
	var owner := _tree().root.gui_get_focus_owner()
	assert_true(owner != null, "%s: something has focus" % label)
	if owner != null:
		assert_true(screen.is_ancestor_of(owner), "%s: focus is inside the screen (got %s)" % [label, owner.name])
		assert_true(owner.is_visible_in_tree(), "%s: the focused control is visible" % label)
	_press("ui_cancel")
	await _frames()
	assert_false(screen.visible, "%s: ui_cancel closes it" % label)


func test_every_hud_screen_has_focus_and_closes_on_cancel() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("qi_gathering_pill", 1)
	gs.start_session(c)
	gs.pending_event = ""  # skip the intro story event (ART-006b); its window would hold the input
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var screens: Dictionary = hud.get("_screens")
	assert_gt(screens.size(), 0)
	for action: String in screens:
		_press(action)
		await _check(screens[action], action)

	var crafting: Control = hud.get("_crafting")
	crafting.open("alchemist")
	await _check(crafting, "crafting")

	var shop: Control = hud.get("_shop")
	shop.open("Test Stall", 0, ["herb"])
	await _check(shop, "shop")

	var balance: Control = hud.get("_sect_balance")
	balance.open()
	await _check(balance, "sect balance")

	var report: Control = hud.get("_combat_report")
	report.show_fight("Wild Boar", true, PackedStringArray(["You face the boar.", "You win."]))
	await _check(report, "combat report")

	var source := MenuSource.new()
	root.add_child(source)
	var menu: Control = hud.get("_choice_menu")
	menu.open_for(source)
	await _check(menu, "choice menu")
	source.free()

	var gs_threat := CharacterFactory.create("Hunted", gs.data, seeded_rng(5))
	gs_threat.spiritual_roots = {"fire": 80}
	gs.start_session(gs_threat)
	var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
	foe["id"] = "audit_foe"
	foe["lethal"] = true
	gs.data.enemies["audit_foe"] = foe
	gs.pending_threat = "audit_foe"
	EventBus.threat_sensed.emit("audit_foe")
	await _check(menu, "threat prompt")
	assert_eq(gs.pending_threat, "", "closing the threat prompt slips away")

	_press("pause_menu")
	var pause: Control = hud.get("_pause_menu")
	await _check(pause, "pause menu")

	var settings: Control = hud.get("_settings")
	settings.open()
	await _check(settings, "settings")
	pause.close()

	var load_screen: Control = hud.get("_load_screen")
	load_screen.open()
	await _check(load_screen, "load")
	pause.close()

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


class ReasonSource extends Node:
	var display_name := "Reason Stone"
	var used := false

	func menu_options() -> Array[Dictionary]:
		return [
			{"label": "Open", "action": func() -> void: pass},
			{"label": "Locked", "action": _use, "disabled": true, "reason": "Needs a key."},
		]

	func _use() -> void:
		used = true


## WU-022: a gamepad can land on a disabled option and read why; accepting does nothing.
func test_choice_menu_shows_reason_of_focused_disabled_option() -> void:
	var menu := ChoiceMenu.new()
	_tree().root.add_child(menu)
	var src := ReasonSource.new()
	menu.open_for(src)
	await _frames()
	var locked: Button = menu._buttons.get_child(1)
	assert_true(locked.disabled and locked.focus_mode == Control.FOCUS_ALL, "disabled option is focusable")
	assert_true((menu._buttons.get_child(0) as Button).has_focus(), "first enabled option gets focus first")
	locked.grab_focus()
	await _frames()
	assert_eq(menu._description.text, "Needs a key.", "reason shown")
	locked.emit_signal("pressed")
	assert_false(src.used, "disabled option does nothing")
	menu.queue_free()
	src.free()


## QA-020: screens added after QA-008 that are not in the HUD's screen table: the
## respawn choice, tribulation (prepare and result), credits, auction, mission
## board, child training, help, the artifact's garden page and the save toast.
func test_late_screens_have_focus_and_close_on_cancel() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("spirit_stone", 5000)
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var board: Control = hud.get("_mission_board")
	board.open()
	await _check(board, "mission board")
	var training: Control = hud.get("_child_training")
	training.open()
	await _check(training, "child training")

	var clock: Node = root.get_node("GameClock")
	var day: int = clock.total_days
	clock.total_days = int(Auctions.house(gs.data, "fallen_star_auction")["offset_days"])
	var auction: Control = hud.get("_auction")
	auction.open("fallen_star_auction")
	await _check(auction, "auction")
	clock.total_days = day

	var help: Control = hud.get("_help")
	hud.set("_help_from_key", true)  # opened by its key it returns to the world, not the pause menu
	help.open()
	await _check(help, "help")
	var credits := CreditsScreen.new()
	hud.add_child(credits)
	credits.open()
	await _check(credits, "credits")
	credits.queue_free()

	var tribulation: Control = hud.get("_tribulation")
	tribulation.open_prepare()
	await _check(tribulation, "tribulation prepare")
	var wave := {"damage": 10, "hp_left": 90}
	tribulation.show_result("Foundation Establishment", {"max_hp": 100, "waves": [wave], "survived": true, "talismans_used": PackedStringArray()})
	await _frames()
	assert_true(tribulation.visible, "tribulation result opens")
	var owner := root.gui_get_focus_owner()
	assert_true(owner != null and tribulation.is_ancestor_of(owner), "tribulation result: focus is inside the screen")
	tribulation.close()

	var artifact: ArtifactScreen = hud.get("_screens")["toggle_artifact"]
	artifact.open()
	artifact._show_page(ArtifactScreen.PAGE_GARDEN)
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and artifact.is_ancestor_of(owner), "artifact garden page: focus is inside the screen")
	_press("ui_cancel")
	await _frames()
	assert_eq(artifact.page(), ArtifactScreen.PAGE_MAIN, "cancel leaves the garden page")
	assert_true(artifact.visible, "cancel on a sub-page does not close the screen")
	artifact.close()

	# The respawn choice: waits for the player; accept (cancel) takes the default anchor.
	var choices: Array = CreationArtifact.respawn_choices(c, gs.data)
	if not choices.is_empty():
		gs.pending_respawn = {"cause": "Test", "anchor_id": String(choices[0]["anchor_id"]), "lives_left": 1, "qi_lost": 5.0}
		var respawn: Control = hud.get("_respawn")
		respawn.open()
		await _frames()
		assert_true(respawn.visible, "respawn opens")
		owner = root.gui_get_focus_owner()
		assert_true(owner != null and respawn.is_ancestor_of(owner), "respawn: focus is inside the screen")
		respawn.close()
		gs.pending_respawn = {}

	# The save toast is display only: it never takes focus or blocks input.
	var toast := SaveToast.new()
	hud.add_child(toast)
	assert_eq(toast.focus_mode, Control.FOCUS_NONE)
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in toast.find_children("*", "Control", true, false):
		assert_true((node as Control).focus_mode == Control.FOCUS_NONE, "save toast: %s takes no focus" % node.name)
	toast.queue_free()

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


## WU-079: windows and pages added since QA-020: the encounter and discovery
## window, the settings Controls page, the message log topic filters and the
## character sheet's companion buttons.
func test_newer_windows_have_focus_and_close_on_cancel() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	# The encounter window: a plain encounter, then a region discovery.
	gs.data.encounters["audit_encounter"] = {
		"id": "audit_encounter", "tags": ["audit_tag"], "weight": 1, "kind": "neutral", "days": 1,
		"text": "A wounded traveller lies by the road.",
		"choices": [{"label": "Bind his wounds", "effects": {"alignment": 5}}, {"label": "Walk on"}],
	}
	gs.pending_encounter = "audit_encounter"
	var encounter: Control = hud.get("_encounter")
	encounter.open()
	await _frames()
	assert_true(encounter.visible, "encounter opens")
	var owner := root.gui_get_focus_owner()
	assert_true(owner != null and encounter.is_ancestor_of(owner), "encounter: focus is inside the window")
	gs.last_explore_discovery = true
	encounter.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and encounter.is_ancestor_of(owner), "discovery: focus is inside the window")
	encounter.close()
	gs.pending_encounter = ""
	gs.last_explore_discovery = false
	gs.data.encounters.erase("audit_encounter")

	# The Controls page of the settings screen.
	var settings: SettingsScreen = hud.get("_settings")
	settings.open()
	settings._show_controls(true)
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and settings.is_ancestor_of(owner) and owner.is_visible_in_tree(), "controls page: focus is on a visible control")
	settings.close()

	# The message log with a topic filter picked.
	var log: MessageLogScreen = hud.get("_screens")["toggle_message_log"]
	log.open()
	log._set_topic("combat")
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and log.is_ancestor_of(owner), "message log with a topic: focus is inside the screen")
	log.close()

	# The character sheet with a spirit beast companion.
	var beast_id: String = String(gs.data.beasts.keys()[0]) if gs.data.get("beasts") is Dictionary and not gs.data.beasts.is_empty() else ""
	if beast_id != "":
		c.companions.append(beast_id)
	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	sheet.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and sheet.is_ancestor_of(owner), "character sheet with a companion: focus is inside the screen")
	sheet.close()

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


## Asserts a visible control inside `screen` has focus after the frames settle.
func _expect_focus(screen: Control, label: String) -> void:
	await _frames(3)
	var owner := _tree().root.gui_get_focus_owner()
	assert_true(owner != null and screen.is_ancestor_of(owner) and owner.is_visible_in_tree(), "%s: focus is on a visible control inside it (got %s)" % [label, owner.name if owner != null else "nothing"])


## WU-103: the menus added since WU-079: the bounty board, the NPC gift list,
## the mission board's lost-fight line, the respawn odds line, the journal's
## letters and a shop during a festival. Each has focus on open and after a
## sub-list is closed or an entry re-shows the menu.
func test_newest_menus_keep_focus() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("spirit_stone", 5000)
	c.add_item("qi_gathering_pill", 2)
	c.add_item("core_forming_pill", 1)
	gs.start_session(c)
	gs.pending_event = ""
	gs.current_region = "qingshi_village"
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var menu: ChoiceMenu = hud.get("_choice_menu")

	# The bounty board: with offers, then with an active hunt (taking one re-shows the menu).
	var board: Node = load("res://src/world/interactables/bounty_board.gd").new()
	root.add_child(board)
	menu.open_for(board)
	await _expect_focus(menu, "bounty board offers")
	var offered: Array = Bounties.offers(c, gs.data, GameClock.total_days, gs.current_region)
	if not offered.is_empty():
		var first: Dictionary = offered[0]
		if Bounties.check_take(c, gs.data, String(first["id"]), GameClock.total_days) == "":
			gs.take_bounty(String(first["id"]))
			menu.open_for(board)
			await _expect_focus(menu, "bounty board with an active hunt")
	_press("ui_cancel")
	await _frames()
	assert_false(menu.visible, "bounty board: ui_cancel closes it")
	board.free()

	# The NPC gift list with a liked and a disliked item, and back out of it.
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 30, "region": "qingshi_village"})
	gs.npc_favor[npc.id] = 20
	gs.world_flags["taste_%s_qi_gathering_pill" % npc.id] = 1
	gs.world_flags["taste_%s_core_forming_pill" % npc.id] = -1
	var giver: Node = load("res://src/world/interactables/npc.gd").new()
	giver.npc_id = npc.id
	root.add_child(giver)
	giver._set_gift_mode(true)
	menu.open_for(giver)
	await _expect_focus(menu, "gift list")
	giver._set_gift_mode(false)
	menu.open_for(giver)  # "Back" re-shows the main entries
	await _expect_focus(menu, "npc menu after the gift list")
	_press("ui_cancel")
	await _frames()
	assert_false(menu.visible, "npc menu: ui_cancel closes it")
	giver.free()

	# The mission board with a lost-fight line.
	c.realm_index = 1
	c.stage = 1
	gs.join_sect("azure_cloud_sect")
	for mission_id: String in gs.data.sect_missions:
		c.mission_losses[mission_id] = c.age_days - 3
	var missions: Control = hud.get("_mission_board")
	missions.open()
	await _expect_focus(missions, "mission board with a lost fight")
	_press("ui_cancel")
	await _frames()

	# The respawn screen with the odds line.
	var choices: Array = CreationArtifact.respawn_choices(c, gs.data)
	if not choices.is_empty():
		gs.pending_respawn = {"cause": "Test", "anchor_id": String(choices[0]["anchor_id"]), "lives_left": 2, "qi_lost": 5.0, "enemy_name": "Stone Ape", "win_chance": 0.12}
		var respawn: Control = hud.get("_respawn")
		respawn.open()
		await _expect_focus(respawn, "respawn with the odds line")
		respawn.close()
		gs.pending_respawn = {}

	# The journal with three letters.
	for i in 3:
		Letters.remember(c, gs.data, "A letter from Friend %d: the harvest was good." % i, GameClock.total_days)
	var journal: Control = hud.get("_screens")["toggle_journal"]
	journal.open()
	await _expect_focus(journal, "journal with letters")
	_press("ui_cancel")
	await _frames()
	assert_false(journal.visible, "journal: ui_cancel closes it")

	# A shop during a festival.
	for def: Dictionary in gs.data.world_events.values():
		if def.get("festival", false) and not (def.get("shop_items", []) as Array).is_empty():
			gs.world_events = [{"id": def["id"], "region": gs.current_region, "start_day": 0, "end_day": 99999, "done": false}]
			break
	var shop: Control = hud.get("_shop")
	shop.open("Festival Stall", 0, ["herb"])
	await _expect_focus(shop, "shop during a festival")
	_press("ui_cancel")
	await _frames()
	assert_false(shop.visible, "shop: ui_cancel closes it")
	gs.world_events = []

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()
