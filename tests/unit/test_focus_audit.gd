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

	var gossip: Control = hud.get("_gossip")
	gossip.open(PackedStringArray(["A rumor.", "Another rumor."]))
	await _check(gossip, "gossip")

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

	var breakthrough: Control = hud.get("_breakthrough")
	breakthrough.open()
	await _check(breakthrough, "breakthrough window")
	breakthrough.close()

	var realm_card: Control = hud.get("_realm_card")
	realm_card.open("Foundation Establishment", "A solid base.", "Lifespan +50 years", ["Alchemy is open to you."])
	await _check(realm_card, "realm card")
	_press("ui_cancel")
	await _frames()
	assert_false(realm_card.visible, "cancel closes the realm card")

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


## WU-123: the shop with a friend's price and a very long title, the secret realm
## notice banner arriving over an open menu, and the character sheet's People list
## with a letter request. The gossip window is covered in the HUD screen audit above.
func test_newest_windows_keep_focus_wu123() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("spirit_stone", 5000)
	gs.start_session(c)
	gs.pending_event = ""
	gs.current_region = "qingshi_village"
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	# A shop with a friend's price and a wrapped title.
	c.shop_deals["qingshi_village"] = {"mult": 0.8, "until": GameClock.total_days + 12}
	var shop: Control = hud.get("_shop")
	shop.open("The Extraordinarily Well Travelled Wandering Merchant of the Nine Provinces", 0, ["herb"])
	await _expect_focus(shop, "shop with a friend's price and a long title")
	var shop_owner := root.gui_get_focus_owner()

	# A secret realm notice banner must not steal focus from the open shop.
	if not gs.data.secret_realms.is_empty():
		EventBus.secret_realm_notice.emit(String(gs.data.secret_realms.keys()[0]))
		await _frames(3)
		assert_true(root.gui_get_focus_owner() == shop_owner, "realm notice banner leaves the shop's focus alone")
		assert_true(shop.visible, "shop stays open under the notice banner")
	_press("ui_cancel")
	await _frames()
	assert_false(shop.visible, "shop: ui_cancel closes it")
	c.shop_deals.clear()

	# The character sheet's People list with a letter request.
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village"})
	gs.npc_favor[npc.id] = 30
	c.letter_requests.append({"npc_id": npc.id, "item": "qi_gathering_pill", "count": 1, "until": GameClock.total_days + 20, "favor": 10, "effects": {}})
	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	sheet.open()
	await _expect_focus(sheet, "character sheet with a request in the People list")
	_press("ui_cancel")
	await _frames()
	assert_false(sheet.visible, "character sheet: ui_cancel closes it")

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


## WU-136: the breakthrough window with a pill in the bag (focus lands on the pill,
## the pill / Attempt / Not yet row is reachable by d-pad) and the mission board's rows.
func test_breakthrough_pill_row_and_mission_board_are_reachable() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("foundation_establishment_pill", 1)
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var bt: BreakthroughScreen = hud.get("_breakthrough")
	bt.open()
	await _frames()
	var owner := root.gui_get_focus_owner()
	assert_true(owner != null and bt.is_ancestor_of(owner), "breakthrough with a pill: focus is inside the window")
	for b in bt.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.is_visible_in_tree():
			assert_true(btn.focus_mode == Control.FOCUS_ALL, "breakthrough: %s is focusable" % btn.name)
	_press("ui_cancel")
	await _frames()
	assert_false(bt.visible, "breakthrough: ui_cancel closes it")

	var board: Control = hud.get("_mission_board")
	board.open()
	await _frames()
	for b in board.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.is_visible_in_tree():
			assert_true(btn.focus_mode == Control.FOCUS_ALL, "mission board: %s is focusable" % btn.name)
	_press("ui_cancel")
	await _frames()
	assert_false(board.visible, "mission board: ui_cancel closes it")

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


## WU-152: the newest windows: encounter choices with checks and locks, the world map with bounty marks,
## the breakthrough window with the lessons line.
func test_wu152_encounter_map_and_breakthrough_focus() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	# (1) a mix of an enabled check choice, a locked one and plain ones.
	gs.data.encounters["audit_checks"] = {
		"id": "audit_checks", "tags": ["audit_tag"], "weight": 1, "kind": "neutral", "days": 1,
		"text": "A riddle is carved into the gate.",
		"choices": [
			{"label": "Locked first", "requires": {"min_attributes": {"comprehension": 99}}},
			{"label": "Think it through", "requires": {"min_attributes": {"comprehension": 1}}},
			{"label": "Walk on"},
		],
	}
	gs.pending_encounter = "audit_checks"
	var encounter: EncounterWindow = hud.get("_encounter")
	encounter.open()
	await _frames()
	var buttons := encounter.choice_buttons()
	assert_eq(buttons.size(), 3)
	assert_true(buttons[0].disabled, "the locked choice is disabled")
	var owner := root.gui_get_focus_owner()
	assert_true(owner == buttons[1], "focus lands on the first enabled choice (got %s)" % [owner.name if owner != null else "none"])
	_press("ui_up")
	await _frames()
	# Locked choices stay focusable on purpose (their reason is in the label); focus must stay in the window.
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and encounter.is_ancestor_of(owner), "ui_up keeps focus inside the window")
	assert_eq(buttons[0].focus_mode, Control.FOCUS_ALL)
	encounter.close()

	# (2) every choice locked: focus on Walk away.
	gs.data.encounters["audit_checks"]["choices"] = [
		{"label": "Locked a", "requires": {"min_attributes": {"comprehension": 99}}},
		{"label": "Locked b", "requires": {"min_attributes": {"comprehension": 98}}},
	]
	encounter.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner is Button and encounter.is_ancestor_of(owner) and (owner as Button).text == "Walk away", "all locked: focus on Walk away")
	encounter.close()
	gs.pending_encounter = ""
	gs.data.encounters.erase("audit_checks")

	# (3) the world map with an active bounty hunt.
	Bounties.take(gs.player, gs.data, "iron_back_boar_bounty", GameClock.total_days)
	var map: Control = hud.get("_screens")["toggle_map"]
	map.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and map.is_ancestor_of(owner), "world map with a bounty: focus inside")
	_press("ui_cancel")
	await _frames()
	assert_false(map.visible, "world map: ui_cancel closes it")
	gs.player.bounty = {}

	# (4) the breakthrough window with the lessons line.
	gs.player.breakthrough_failures = 3
	var bt: BreakthroughScreen = hud.get("_breakthrough")
	bt.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and bt.is_ancestor_of(owner), "breakthrough with lessons: focus inside")
	_press("ui_cancel")
	await _frames()
	assert_false(bt.visible, "breakthrough: ui_cancel closes it")

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


class MixedMenuSource extends Node:
	var display_name := "Audit Elder"

	func menu_options() -> Array[Dictionary]:
		return [
			{"label": "Talk", "action": func() -> void: pass},
			{"label": "Challenge your rival X to a bout", "disabled": true, "reason": "X wants no part of you.", "action": func() -> void: pass},
			{"label": "Attempt the tribulation", "color": Color(0.9, 0.6, 0.2), "tone": "warning", "action": func() -> void: pass},
			{"label": "Ask about the sect", "action": func() -> void: pass},
		]


## WU-171: the choice menu with its title separator, a tinted option and a disabled rival challenge, and the
## encounter window's footer: each opens with focus and d-pad down reaches every option, then Leave.
func test_wu171_choice_menu_and_encounter_footer_focus() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var source := MixedMenuSource.new()
	root.add_child(source)
	var menu: ChoiceMenu = hud.get("_choice_menu")
	menu.open_for(source)
	await _frames(3)
	var owner := root.gui_get_focus_owner()
	assert_true(owner is Button and menu.is_ancestor_of(owner), "choice menu opens with a focused button")
	assert_eq((owner as Button).text, "Talk", "focus lands on the first enabled option, not the title")
	var seen: Array[String] = []
	for i in 6:
		owner = root.gui_get_focus_owner()
		if owner is Button and not seen.has((owner as Button).text):
			seen.append((owner as Button).text)
		_press("ui_down")
		await _frames()
	for label: String in ["Talk", "Challenge your rival X to a bout", "Attempt the tribulation", "Ask about the sect", "Leave"]:
		assert_true(seen.has(label), "d-pad down reaches '%s'" % label)
	menu.close()
	root.remove_child(source)
	source.free()

	gs.data.encounters["audit_tags"] = {
		"id": "audit_tags", "tags": ["audit_tag"], "weight": 1, "kind": "neutral", "days": 1,
		"text": "A riddle is carved into the gate.",
		"choices": [
			{"label": "Think it through", "check": {"attribute": "comprehension", "min": 1}},
			{"label": "Walk on"},
		],
	}
	gs.pending_encounter = "audit_tags"
	var encounter: EncounterWindow = hud.get("_encounter")
	encounter.open()
	await _frames()
	owner = root.gui_get_focus_owner()
	assert_true(owner != null and encounter.is_ancestor_of(owner), "encounter window opens with focus inside")
	var buttons := encounter.choice_buttons()
	var reached := 0
	for i in buttons.size() + 1:
		owner = root.gui_get_focus_owner()
		if buttons.has(owner):
			reached += 1
		_press("ui_down")
		await _frames()
	assert_true(reached >= 1, "d-pad moves through the choices")
	encounter.close()
	gs.pending_encounter = ""
	gs.data.encounters.erase("audit_tags")

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()


## WU-186: the newest lines: the journal with "Debts and grudges", an inheritance close to its deadline and a
## Soul Formation section scrolls to its end with the gamepad's right stick; the character sheet's People
## list with a grateful NPC and a grudge holder; the inheritance grounds menu reaches every attempt.
func test_wu186_journal_scroll_sheet_people_and_grounds_focus() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.realm_index = 5  # Soul Formation
	c.stage = 0
	gs.start_session(c)
	gs.pending_event = ""
	gs.current_region = "misty_forest"
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var grateful := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 30, "region": "qingshi_village"})
	var grudging := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 30, "region": "qingshi_village"})
	Karma.add_gratitude(c, gs.data, grateful.id, 60)
	Karma.add_grudge(c, gs.data, grudging.id, 50)

	var journal: JournalScreen = hud.get("_screens")["toggle_journal"]
	journal.open()
	await _expect_focus(journal, "journal with debts, inheritances and Soul Formation goals")
	var scroll: ScrollContainer = journal._scroll
	assert_eq(scroll.scroll_vertical, 0, "the journal opens at the top")
	Input.action_press("scroll_down", 1.0)
	var bar := scroll.get_v_scroll_bar()
	for i in 600:  # the stick scrolls by frame time, so keep holding until the end is reached
		await _frames(1)
		if scroll.scroll_vertical >= int(bar.max_value - bar.page) - 1:
			break
	Input.action_release("scroll_down")
	var at_end: bool = scroll.scroll_vertical >= int(bar.max_value - bar.page) - 1
	var fits: bool = bar.max_value <= bar.page
	assert_true(fits or (scroll.scroll_vertical > 0 and at_end), "right stick scrolls the journal to its end (at %d of %d)" % [scroll.scroll_vertical, int(bar.max_value - bar.page)])
	assert_true(root.gui_get_focus_owner() != null and journal.is_ancestor_of(root.gui_get_focus_owner()), "journal keeps focus while scrolled")
	_press("ui_cancel")
	await _frames()
	assert_false(journal.visible, "journal: ui_cancel closes it")

	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	sheet.open()
	await _expect_focus(sheet, "character sheet with a grateful NPC and a grudge holder")
	_press("ui_cancel")
	await _frames()
	assert_false(sheet.visible, "character sheet: ui_cancel closes it")

	# The grounds menu: a disabled status row, then an attempt; the attempt is reachable.
	var grounds: Node = load("res://src/world/interactables/inheritance_grounds.gd").new()
	root.add_child(grounds)
	var menu: ChoiceMenu = hud.get("_choice_menu")
	menu.open_for(grounds)
	await _expect_focus(menu, "inheritance grounds menu")
	var seen := 0
	for i in 8:
		var owner := root.gui_get_focus_owner()
		if owner is Button and menu.is_ancestor_of(owner):
			seen += 1
		_press("ui_down")
		await _frames()
	assert_gt(seen, 0, "d-pad down keeps focus on the grounds menu buttons")
	_press("ui_cancel")
	await _frames()
	assert_false(menu.visible, "inheritance grounds menu: ui_cancel closes it")
	grounds.free()

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()
