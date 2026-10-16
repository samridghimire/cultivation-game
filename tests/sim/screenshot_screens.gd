extends SceneTree
## Screenshots of every HUD screen for a mid-game character, for eyeballing
## layout at 1280x800 without a display (WU-021). Needs a GPU-less X server:
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_screens.gd
## PNGs go to user://screenshots/screens/<name>.png (OUT_DIR). Never writes saves.
## WU-116: append `-- --first-hour` for a fresh character in Qingshi Village instead (creation,
## intro, Elder Mo, the merchant's shop, exploring, a lost fight, the day-1 journal). Check each PNG
## at 1280x800 and 1280x720 (--resolution 1280x720).
## WU-127: append `-- --style-shots` for the fighting-style surfaces (techniques hint, Buy tab rows,
## Elder Mo's fighting node, a lost fight with Iron Fist 1, the journal's practice hint).
## WU-132: append `-- --win-shots` for "from a style to a win" (HUD fair-fight and goal lines with the
## Wandering Merchant's scroll mark, the journal's fights section, the mission board, an inheritance
## ground menu, the shop with a long manual row).
## WU-145: append `-- --breakthrough-shots` for the breakthrough window of a Qi Refining 9th Layer player at
## full qi: (a) no pill, 120 stones, (b) holding a Foundation Establishment Pill, (c) pill and 3 failed
## attempts (lessons line). Check each PNG at 1280x800 and 1280x720.

## WU-163: append `-- --late-realms` for the journal and character sheet of a Foundation Establishment Peak
## and a Core Formation Early character (Foundation / Core Formation goals, tribulation line, strongest foe).

## WU-177: append `-- --death-shot` for the final-death screen of a veteran with a clan, children, a met
## rival with a bout record and a long life record (the epilogue at its longest).

## WU-182: append `-- --year-shot` for the year-in-review banner with four long lines (realm change,
## tribulation, inheritance, rival bouts).

## WU-184: append `-- --soul-shot` for a Soul Formation Early player: the journal's Soul Formation goals
## (with the Starfire Body row) and the HUD goal ladder.

const OUT_DIR := "user://screenshots/screens"
const SETTLE_FRAMES := 6

var world: Node = null
var hud: CanvasLayer = null
var shots: Array[Dictionary] = []  # {name, open: Callable, close: Callable}
var index := 0
var frames := 0
var started := false
var opened := false


func _start() -> void:
	started = true
	var gs: Node = root.get_node("GameState")
	if OS.get_cmdline_user_args().has("--first-hour"):
		_start_first_hour(gs)
		return
	if OS.get_cmdline_user_args().has("--style-shots"):
		_start_style_shots(gs)
		return
	if OS.get_cmdline_user_args().has("--win-shots"):
		_start_win_shots(gs)
		return
	if OS.get_cmdline_user_args().has("--death-shot"):
		_start_death_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--year-shot"):
		_start_year_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--late-realms"):
		_start_late_realms(gs)
		return
	if OS.get_cmdline_user_args().has("--soul-shot"):
		_start_soul_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--breakthrough-shots"):
		_start_breakthrough_shots(gs)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.stage = 1
	c.age_days = 31 * Calendar.DAYS_PER_YEAR
	c.add_item("spirit_stone", 1800)
	var n := 0
	for item_id: String in gs.data.items:
		c.add_item(item_id, 2)
		n += 1
		if n >= 15:
			break
	var techs: Array = gs.data.techniques.keys()
	for k in mini(4, techs.size()):
		Techniques.learn(c, gs.data, techs[k])
	gs.join_sect("azure_cloud_sect")
	for injury_id: String in gs.data.injuries:
		Injuries.inflict(c, gs.data, injury_id)
		break
	var spouse := Npcs.spawn(gs.npcs, gs.data, rng, {"gender": "female", "region": gs.current_region, "age_years": 28})
	Family.marry(c, spouse, "wife")
	for k in 2:
		var kid := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 4 + k * 3, "region": gs.current_region})
		kid.parents = [c.id, spouse.id] as Array[String]
		c.children.append(kid.id)
	_add_week_data(gs, c)
	for i in 30:
		root.get_node("EventBus").post("Message %d: a line of news that is long enough to wrap across the log panel." % i)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	_build_shots(gs)


## WU-116: the first hour of a fresh character, in the order a new player meets it.
func _start_first_hour(gs: Node) -> void:
	var creation: Control = load("res://src/ui/character_creation.tscn").instantiate()
	root.add_child(creation)
	shots.append({"name": "fh_creation", "open": func() -> void: pass, "close": func() -> void: pass})
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, rng, "male"))
	var end_talk := func() -> void:
		var guard := 0
		while gs.in_dialogue() and guard < 40:
			var view: Dictionary = gs.dialogue_view()
			var pick := 0
			for ch: Dictionary in view.get("choices", []):
				if not bool(ch.get("disabled", false)):
					pick = int(ch["index"])
					break
			gs.choose_dialogue(pick)
			guard += 1
		if hud != null:
			hud.get("_dialogue").close()
			hud.get("_banner").visible = false
	shots.append({"name": "fh_intro_dialogue", "open": func() -> void:
		creation.queue_free()
		world = load("res://src/world/world.tscn").instantiate()
		root.add_child(world)
		hud = world.get_node("HUD"), "close": end_talk})
	shots.append({"name": "fh_hud_after_intro", "open": end_talk, "close": func() -> void: pass})
	shots.append({"name": "fh_elder_mo", "open": func() -> void: gs.start_dialogue("elder_mo"), "close": end_talk})
	shots.append({"name": "fh_merchant_buy", "open": func() -> void: hud.get("_shop").open("Wandering Merchant", 0, ["herb", "ore", "beast_material"]), "close": func() -> void: hud.get("_shop").close()})
	shots.append({"name": "fh_explore", "open": func() -> void: gs.explore(), "close": func() -> void:
		hud.get("_encounter").close()
		hud.get("_choice_menu").close()})
	shots.append({"name": "fh_lost_fight", "open": func() -> void:
		gs.fight("mist_wolf")
		hud.get("_combat_report").skip()
		hud.get("_banner").visible = false, "close": func() -> void:
		hud.get("_combat_report").close()
		hud.get("_respawn").close()})
	shots.append({"name": "fh_journal", "open": func() -> void: hud.get("_screens")["toggle_journal"].open(), "close": func() -> void: hud.get("_screens")["toggle_journal"].close()})


## WU-132: a character who knows one fighting style, in the village, then the screens around a win.
func _start_win_shots(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.add_item("spirit_stone", 300)
	c.age_days = 30 * Calendar.DAYS_PER_YEAR
	c.realm_index = 1
	c.stage = 1
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var end_talk := func() -> void:
		var guard := 0
		while gs.in_dialogue() and guard < 40:
			gs.choose_dialogue(0)
			guard += 1
		hud.get("_dialogue").close()
		hud.get("_banner").visible = false
	end_talk.call()
	var hide_banner := func() -> void: hud.get("_banner").visible = false
	shots.append({"name": "ws_hud_merchant_mark", "open": hide_banner, "close": func() -> void: pass})
	var journal: Control = hud.get("_screens")["toggle_journal"]
	var open_journal_end := func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000)
	shots.append({"name": "ws_journal_no_style", "open": open_journal_end, "close": journal.close})
	shots.append({"name": "ws_hud_fair_fight", "open": func() -> void:
		Techniques.learn(c, gs.data, "iron_fist")
		root.get_node("EventBus").player_changed.emit()
		hide_banner.call(), "close": func() -> void: pass})
	shots.append({"name": "ws_journal_fair_fights", "open": open_journal_end, "close": journal.close})
	var board: Control = hud.get("_mission_board")
	shots.append({"name": "ws_mission_board", "open": func() -> void:
		gs.join_sect("azure_cloud_sect")
		hide_banner.call()
		board.open(), "close": board.close})
	var ground: Node = load("res://src/world/interactables/inheritance_grounds.gd").new()
	ground.display_name = "Founder's Old Well"
	var menu: Control = hud.get("_choice_menu")
	shots.append({"name": "ws_inheritance_menu", "open": func() -> void: menu.open_for(ground), "close": menu.close})
	var shop: Control = hud.get("_shop")
	shots.append({"name": "ws_shop_manual", "open": func() -> void:
		shop.open("Wandering Merchant", 0, ["herb", "ore", "beast_material", "scripture", "manual"])
		shop._set_category("Manuals & Scrolls"), "close": shop.close})


## WU-145: the breakthrough window in three states.
func _start_breakthrough_shots(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 30 * Calendar.DAYS_PER_YEAR
	c.realm_index = 1
	var realm: RealmDef = gs.data.realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	c.add_item("spirit_stone", 120)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var win: Control = hud.get("_breakthrough")
	var hide_banner := func() -> void: hud.get("_banner").visible = false
	shots.append({"name": "bs_a_no_pill", "open": func() -> void:
		hide_banner.call()
		win.open(), "close": win.close})
	shots.append({"name": "bs_b_pill", "open": func() -> void:
		c.add_item("foundation_establishment_pill", 1)
		hide_banner.call()
		win.open(), "close": win.close})
	shots.append({"name": "bs_c_pill_lessons", "open": func() -> void:
		c.breakthrough_failures = 3
		hide_banner.call()
		win.open(), "close": win.close})


## WU-163: journal and character sheet for a Foundation Establishment Peak and a Core Formation Early character.
func _start_late_realms(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 45 * Calendar.DAYS_PER_YEAR
	c.add_item("spirit_stone", 900)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	var hide_banner := func() -> void: hud.get("_banner").visible = false
	LifeStats.add(c, "rival_bouts_won", 2)
	LifeStats.add(c, "rival_bouts_lost", 1)
	# WU-172: a met rival elsewhere, with a bout record and a grudge, so the sheet's longest line shows.
	var rival_region: String = "qingshi_village"
	for rid: String in gs.data.regions.keys():
		if rid != gs.current_region:
			rival_region = rid
			break
	var rival: CharacterData = Rivals.spawn(c, gs.npcs, gs.data, rng, rival_region)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs.world_flags[Rivals.BOUTS_WON_FLAG] = 2
	gs.world_flags[Rivals.BOUTS_LOST_FLAG] = 1
	gs.npc_favor[rival.id] = -3
	Karma.add_grudge(c, gs.data, rival.id, 5)  # below grudge_words[1]: the Rival line reads "a slight"
	# WU-183: one grateful NPC (gratitude 50, favor 0) and one grudge holder (grudge 20) for the People list.
	var extras: Array = []
	for nid: String in gs.npcs.keys():
		var other: CharacterData = gs.npcs[nid]
		if nid != rival.id and other.alive and not c.parents.has(nid) and not c.spouses.has(nid):
			extras.append(nid)
		if extras.size() == 2:
			break
	if extras.size() == 2:
		Karma.add_gratitude(c, gs.data, extras[0], 50)
		Karma.add_grudge(c, gs.data, extras[1], 20)
	for spec: Array in [["fe_peak", "foundation_establishment", -1], ["cf_early", "core_formation", 0]]:
		var realm_index: int = gs.data.realm_index_of(spec[1])
		var stage: int = int(spec[2])
		if stage < 0:
			stage = gs.data.realms[realm_index].stage_count() - 1
		var setup := func() -> void:
			gs.world_flags[Guidance.beat_realm_flag("foundation_establishment")] = true
			if spec[0] == "cf_early":
				gs.world_flags[Guidance.beat_realm_flag("core_formation")] = true
			c.realm_index = realm_index
			c.stage = stage
			c.qi = gs.data.realms[realm_index].qi_required(stage)
			rival.realm_index = realm_index
			rival.stage = stage
			hide_banner.call()
		shots.append({"name": "lr_%s_journal" % spec[0], "open": func() -> void:
			setup.call()
			journal.open(), "close": journal.close})
		shots.append({"name": "lr_%s_sheet" % spec[0], "open": func() -> void:
			setup.call()
			sheet.open(), "close": sheet.close})
		shots.append({"name": "lr_%s_sheet_end" % spec[0], "open": func() -> void:
			setup.call()
			sheet.open()
			sheet.get("_scroll").set_deferred("scroll_vertical", 100000), "close": sheet.close})


## WU-184: a Soul Formation Early player, journal and HUD.
func _start_soul_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 120 * Calendar.DAYS_PER_YEAR
	c.realm_index = gs.data.realm_index_of("soul_formation")
	c.stage = 0
	c.qi = gs.data.realms[c.realm_index].qi_required(0)
	for realm_id: String in ["foundation_establishment", "core_formation", "nascent_soul"]:
		gs.world_flags[Guidance.beat_realm_flag(realm_id)] = true
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "soul_hud", "open": func() -> void: hud.get("_banner").visible = false, "close": func() -> void: pass})
	shots.append({"name": "soul_journal", "open": func() -> void: journal.open(), "close": journal.close})
	shots.append({"name": "soul_journal_end", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


## WU-177: the final-death screen with every epilogue line present.
func _start_year_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var banner: Control = hud.get("_banner")
	var lines := LifeStats.year_summary({}, {"tribulations_survived": 1, "inheritances_claimed": 1, "rival_bouts_won": 2,
			"rival_bouts_lost": 1}, "Foundation Establishment Peak", "Core Formation Early")
	shots.append({"name": "year_banner", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("%s of your journey" % LifeStats.review_title(10, 14), "\n".join(lines), Color(0.9, 0.78, 0.4), 60.0),
		"close": func() -> void: pass})


func _start_death_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.realm_index = gs.data.realm_index_of("core_formation")
	c.age_days = 300 * Calendar.DAYS_PER_YEAR
	gs.join_sect("azure_cloud_sect")
	for i in 3:
		c.children.append("child_%d" % i)
	gs.clan = ClanData.new()
	gs.clan.name = "Lin Clan of the Azure Mountain"
	for i in 6:
		gs.clan.members["m%d" % i] = {}
	for key: String in ["rival_bouts_won", "rival_bouts_lost", "regions_visited", "breakthroughs", "beasts_slain",
			"herbs_gathered", "pills_brewed", "gifts_given", "missions_done", "fights_won"]:
		LifeStats.add(c, key, 12)
	var rival: CharacterData = Rivals.spawn(c, gs.npcs, gs.data, rng, "qingshi_village")
	rival.name = "Murong Xuanming Zhaoyang"
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs.world_flags[Rivals.BOUTS_WON_FLAG] = 7
	gs.world_flags[Rivals.BOUTS_LOST_FLAG] = 11
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	shots.append({"name": "death_final", "open": func() -> void:
		hud.get("_banner").visible = false
		hud._on_player_died("Struck down by a heavenly tribulation lightning bolt while attempting to break through."), "close": func() -> void:
		hud.get("_death_screen").visible = false})


## WU-127: the fighting-style surfaces for a fresh character, then for one who has just learned Iron Fist.
func _start_style_shots(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.add_item("spirit_stone", 200)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var end_talk := func() -> void:
		var guard := 0
		while gs.in_dialogue() and guard < 40:
			gs.choose_dialogue(0)
			guard += 1
		hud.get("_dialogue").close()
		hud.get("_banner").visible = false
	end_talk.call()
	var techs: Control = hud.get("_screens")["toggle_techniques"]
	var open_manual_shop := func() -> void:
		var shop: Control = hud.get("_shop")
		shop.open("Wandering Merchant", 0, ["herb", "ore", "beast_material", "scripture", "manual"])
		shop._set_category("Manuals & Scrolls")
	shots.append({"name": "ss_techniques_hint", "open": techs.open, "close": techs.close})
	shots.append({"name": "ss_shop_buy", "open": open_manual_shop, "close": func() -> void: hud.get("_shop").close()})
	shots.append({"name": "ss_elder_mo_fighting", "open": func() -> void:
		Techniques.learn(c, gs.data, "basic_breathing")
		gs.start_dialogue("elder_mo")
		# One frame later, so the dialogue window is open before the choice is made.
		root.get_tree().process_frame.connect(func() -> void:
			for ch: Dictionary in gs.dialogue_view().get("choices", []):
				if String(ch.get("label", "")).begins_with("Breathing alone"):
					gs.choose_dialogue(int(ch["index"]))
					hud.get("_dialogue").open()
					break, CONNECT_ONE_SHOT), "close": end_talk})
	shots.append({"name": "ss_lost_fight_iron_fist_1", "open": func() -> void:
		Techniques.learn(c, gs.data, "iron_fist")
		gs.fight("mist_wolf")
		hud.get("_combat_report").skip()
		hud.get("_banner").visible = false, "close": func() -> void:
		hud.get("_combat_report").close()
		hud.get("_respawn").close()})
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "ss_journal_practice_hint", "open": func() -> void:
		hud.get("_banner").visible = false
		journal.open(), "close": journal.close})


## WU-093: data for the blocks added this week: letters, renown, a mastered region,
## an active bounty and festival, and a lost mission.
func _add_week_data(gs: Node, c: CharacterData) -> void:
	for line: String in ["Wei Lan writes: the harvest was good and the village asks after you.",
			"Elder Murong writes: come to the sect hall when the moon is full; there is a matter to discuss at length.",
			"Old friend Zhao writes from the Misty Forest about a wolf pack that has grown bold."]:
		Letters.remember(c, gs.data, line, root.get_node("GameClock").total_days)
	c.renown["qingshi_village"] = 60
	c.renown["misty_forest"] = 110
	gs.world_flags["mastered_" + gs.current_region] = true
	var offers := Bounties.offers(c, gs.data, root.get_node("GameClock").total_days)
	if not offers.is_empty():
		Bounties.take(c, gs.data, String(offers[0]["id"]), root.get_node("GameClock").total_days)
	for event_id: String in gs.data.world_events:
		if event_id == "lantern_festival":
			gs.world_events.append({"id": event_id, "region": gs.current_region, "start_day": root.get_node("GameClock").total_days, "end_day": root.get_node("GameClock").total_days + 6, "done": false})
			break
	for mission_id: String in Sects.available_missions(c, gs.data):
		c.mission_losses[mission_id] = c.age_days - 3
		break


func _screen(label: String, action: String) -> void:
	var s: Control = hud.get("_screens")[action]
	shots.append({"name": label, "open": s.open, "close": s.close})


func _modal(label: String, field: String, args: Array = []) -> void:
	var s: Control = hud.get(field)
	shots.append({"name": label, "open": Callable(s, "open").bindv(args), "close": s.close})


func _build_shots(gs: Node) -> void:
	for action: String in ["toggle_character_sheet", "toggle_inventory", "toggle_techniques", "toggle_artifact",
			"toggle_map", "toggle_message_log", "toggle_clan", "toggle_journal", "toggle_family"]:
		if hud.get("_screens").has(action):
			_screen(action.trim_prefix("toggle_"), action)
	_modal("crafting", "_crafting", [gs.data.professions.keys()[0]])
	_modal("shop", "_shop", ["Everything Stall", 0, ["herb", "ore", "equipment", "talisman", "scripture"]])
	_modal("mission_board", "_mission_board")
	_modal("auction", "_auction", [gs.data.auction_houses.keys()[0]])
	_modal("sect_balance", "_sect_balance")
	_modal("help", "_help")
	_modal("settings", "_settings")
	_modal("pause", "_pause_menu")
	_modal("child_training", "_child_training")
	for enc_id: String in gs.data.encounters:
		if gs.data.encounters[enc_id].has("choices"):
			shots.append({"name": "encounter", "open": func() -> void:
				gs.pending_encounter = enc_id
				hud.get("_encounter").open(), "close": hud.get("_encounter").close})
			break
	var report: Control = hud.get("_combat_report")
	var lines := PackedStringArray()
	for i in 30:
		lines.append("Round %d: you strike the Stone Ape for 123. (Stone Ape: 4567 hp)" % i)
	shots.append({"name": "combat_report", "open": func() -> void: report.show_fight("Stone Ape", false, lines), "close": report.close})
	var board: Node = load("res://src/world/interactables/bounty_board.gd").new()
	board.display_name = "Qingshi Bounty Board"
	var board_menu: Control = hud.get("_choice_menu")
	shots.append({"name": "bounty_board_menu", "open": func() -> void: board_menu.open_for(board), "close": board_menu.close})
	_build_deck_shots(gs)
	_build_effect_shots(gs)
	_build_letter_shots(gs)
	var menu_source := _find_menu_source()
	if menu_source != null:
		var menu: Control = hud.get("_choice_menu")
		shots.append({"name": "choice_menu", "open": func() -> void: menu.open_for(menu_source), "close": menu.close})


## WU-065: the newest menus at UI scale 115% (long names on purpose): a senior
## NPC with pointer and spar entries, the sect hall with the lecture entry, the
## journal's Opportunities and the report after a spar.
func _build_deck_shots(gs: Node) -> void:
	var menu: Control = hud.get("_choice_menu")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var player: CharacterData = gs.player
	var long_id := ""
	for tech_id: String in player.techniques:
		long_id = tech_id
		break
	if long_id != "":
		(gs.data.techniques[long_id] as TechniqueDef).name = "Nine Heavens Thunder-Swallowing Celestial Dragon Palm"
	var senior := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 60, "region": gs.current_region})
	senior.name = "Elder Murong Zhongshan-Baiyun"
	senior.realm_index = player.realm_index + 1
	senior.stage = 1
	if long_id != "":
		senior.techniques[long_id] = {"level": 5}
	gs.npc_favor[senior.id] = 90
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = senior.id
	npc.display_name = senior.name
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	hall.display_name = "Azure Cloud Sect Hall"
	var scale_up := func() -> void: root.content_scale_factor = 1.15
	var scale_back := func() -> void: root.content_scale_factor = 1.0
	for source: Node in [npc, hall]:
		var name_ := "deck_npc_menu" if source == npc else "deck_sect_hall_menu"
		shots.append({"name": name_, "open": func() -> void:
			scale_up.call()
			menu.open_for(source), "close": func() -> void:
			menu.close()
			scale_back.call()})
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "deck_journal", "open": func() -> void:
		scale_up.call()
		journal.open(), "close": func() -> void:
		journal.close()
		scale_back.call()})
	var report: Control = hud.get("_combat_report")
	var lines := PackedStringArray(["Round 1: you trade palm strikes with Elder Murong Zhongshan-Baiyun.", "Round 2: the elder holds back and nods."])
	shots.append({"name": "deck_spar_report", "open": func() -> void:
		scale_up.call()
		report.show_fight(senior.name, true, lines, "", PackedStringArray(), [], 0, 0, true), "close": func() -> void:
		report.close()
		scale_back.call()})


## WU-112: the shop with a friend's price, the merchant menu at a festival, the
## People list with a request and the gossip window.
func _build_letter_shots(gs: Node) -> void:
	var c: CharacterData = gs.player
	var today: int = root.get_node("GameClock").total_days
	c.shop_deals[gs.current_region] = {"mult": 0.8, "until": today + 12}
	var shop: Control = hud.get("_shop")
	shots.append({"name": "shop_friend_price", "open": Callable(shop, "open").bindv(["Everything Stall", 0, ["herb", "ore", "equipment", "talisman", "scripture"]]), "close": shop.close})
	var merchant: Node = load("res://src/world/interactables/merchant.gd").new()
	merchant.display_name = "Lantern Festival Stall"
	var menu: Control = hud.get("_choice_menu")
	shots.append({"name": "merchant_festival_menu", "open": func() -> void: menu.open_for(merchant), "close": menu.close})
	var friend_id := ""
	for npc_id: String in gs.npcs:
		friend_id = npc_id
		if gs.npcs[npc_id].name.begins_with("Elder Murong"):
			break
	if friend_id != "":
		c.letter_requests.append({"npc_id": friend_id, "item": "spirit_stone", "count": 5, "until": today + 9, "favor": 10, "effects": []})
	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	shots.append({"name": "people_list_request", "open": func() -> void:
		sheet.open()
		sheet.get("_scroll").set_deferred("scroll_vertical", 100000), "close": sheet.close})
	var gossip: Control = hud.get("_gossip")
	var lines := PackedStringArray(["A merchant whispers that the Lantern Festival draws near.", "They say a secret realm stirs beyond the Misty Forest, and the sect elders are uneasy about it."])
	shots.append({"name": "gossip_window", "open": Callable(gossip, "open").bindv([lines]), "close": gossip.close})


## WU-069: the breakthrough effects half a second in and the first-visit arrival card.
func _build_effect_shots(gs: Node) -> void:
	var player_node: Node = world.get_node_or_null("Player")
	if player_node != null and player_node.has_method("celebrate"):
		for ok: bool in [true, false]:
			shots.append({"name": "effect_celebrate_%s" % ("success" if ok else "failure"), "open": func() -> void:
				player_node.celebrate(ok)
				player_node.set("_celebrate_left", player_node.CELEBRATE_SECONDS - 0.5), "close": func() -> void:
				player_node.set("_celebrate_left", 0.0)})
	if hud.has_method("_on_arrival"):
		shots.append({"name": "effect_arrival_card", "open": func() -> void:
			gs.last_arrival_first_visit = true
			hud._on_arrival(gs.current_region), "close": func() -> void:
			gs.last_arrival_first_visit = false})


func _find_menu_source() -> Node:
	var best: Node = null
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Node2D and node.has_method("menu_options") and "display_name" in node:
			if best == null or node.menu_options().size() > best.menu_options().size():
				best = node
	return best


func _process(_d: float) -> bool:
	if not started:
		_start()
		return false
	if index >= shots.size():
		return true
	var shot: Dictionary = shots[index]
	if not opened:
		(shot["open"] as Callable).call()
		opened = true
		frames = 0
		return false
	frames += 1
	if frames == SETTLE_FRAMES:
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var file := "%s/%s.png" % [OUT_DIR, shot["name"]]
		root.get_viewport().get_texture().get_image().save_png(file)
		print("saved %s" % ProjectSettings.globalize_path(file))
		(shot["close"] as Callable).call()
		opened = false
		index += 1
	return false
