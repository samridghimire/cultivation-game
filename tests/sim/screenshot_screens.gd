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

## WU-234: `--year-shot` also shoots year_banner_orders (filled-and-lapsed orders line) and lapse_log (longest PROF-013 lapse text).

## WU-197: append `-- --banner-shot` for the HUD with a notice banner up, and the journal open under one.
## WU-204: `--banner-shot` also shoots the longest real arrival subtitle and the longest milestone name.

## WU-187: append `-- --respawn-shot` for the respawn screen after a 98%-odds loss to a long-named foe
## (the longest "still fell" lesson). `--year-shot` now has a four-line year with a respawn line.

## WU-184: append `-- --soul-shot` for a Soul Formation Early player: the journal's Soul Formation goals
## (with the Starfire Body row) and the HUD goal ladder.

## WU-226: append `-- --pill-shot` for a Body Integration Peak player at full qi: the breakthrough window with a Great Vehicle
## Pill plus a Flawless one (pill_a_window.png), and the HUD hint panel with no pill (pill_b_hint.png).

## WU-240: `--pill-shot` also writes tt_pill_a_window.png / tt_pill_b_hint.png for a Mahayana Peak player (Heavenly Tribulation Pills). The window fits at 1280x720 and 1280x800; the long hint is hidden by _fit_status_panel (too tall for the panel at both sizes), so the HUD shows no hint line there.
## WU-266: re-run after WU-257 at 1280x720 and 1280x800: tt_pill_b_hint now shows the hint in the HUD panel (wrapped, "> You are ready to break through ... ready shield talismans."), nothing clipped.

## WU-225: append `-- --inherit-shot` for a Body Integration Early player in Withered Bone Marsh at the Hollow of the
## Unbroken Body (C-136): the grounds menu and the journal's Opportunities with the realm trial next, then with the
## Constitution trial next and missed (inherit_menu*.png, inherit_journal*.png).

## WU-188: append `-- --void-shot` for a Void Refinement Early player: HUD goal ladder and the
## journal's Void Refinement goals.

## WU-193: append `-- --body-shot` for a Body Integration Early player: HUD goal ladder and the journal's
## Body Integration goals.

## WU-236: append `-- --tt-shot` for a Tribulation Transcendence Early player (WU-229's pattern): tt_hud, tt_journal, tt_journal_end.

## WU-242: append `-- --tt-foes` for a Tribulation Transcendence Early player facing Lightning-Tithe Sovereign: the
## sensed-threat prompt (tt_foe_prompt), the combat report after losing (tt_foe_report) and the message log (tt_foe_log).

## WU-229: append `-- --maha-shot` for a Mahayana Early player: HUD goal ladder and the journal's Mahayana goals.

## WU-216: append `-- --rankup-shot` for the message log after the crafts' rank-ups (the longest "You are now ..."
## plus rank_up_line pair across every craft and rank): the HUD log panel and the full log screen.

## WU-222: append `-- --goal-shot` for the journal's "Next steps" with a rank-1 crafter whose "Next recipe: ..." goal
## line (GUIDE-053) is the longest of any craft: goal_journal.png and goal_journal_end.png (scrolled to the bottom).

## WU-180: append `-- --debts-shot` for the journal with two grateful NPCs, a grudge holder at hunt
## strength and an inheritance three months from its deadline (Debts and grudges, Opportunities).

## WU-190: append `-- --encounter-shot` for the encounter window with tagged choices. No single encounter has an
## attribute gate, a profession gate and an enemy choice, so three real ones are shot (a gate met and a gate missed in
## each of the first two): village_field_quarrel (charisma), marsh_yin_ferryman (doctor, 5 choices, longest labels)
## and wild_wounded_disciple (enemy choice).
## WU-228: also the three Mahayana choice encounters, gates missed and met: encounter_maha_<id>_<missed|met>.png.
## WU-238: also the three Tribulation Transcendence choice encounters: encounter_tt_<id>_<missed|met>.png.
## WU-221: also the three crafter encounters (herb cache, old alchemist's notes, broken forge): encounter_crafter_<id>.png.

## WU-196: append `-- --renown-shot` for a Qi Refining player with Respected-bound renown in Qingshi Village (first title,
## halfway to the second): the arrival banner ("Known here: ...") and the journal page with the next-title line.

## WU-201: append `-- --craft-shots` for the crafting screen of each workshop craft (rank 0, first starter recipe
## selected, one ingredient short): craft_<profession>.png.
## WU-208: append `-- --workshop-shot` for the Village Workshop menu of a practised Alchemist with an open
## commission: workshop_menu.png and workshop_menu_odd_jobs.png (pay line), then workshop_journal_commissions.png
## (WU-214: the journal's Commissions section with its "Needs <item>: <where>." line).
## WU-233: also workshop_hint_estimate_<within|over> and workshop_journal_estimate_<within|over> (PROF-014 gathering estimate).

## WU-207: append `-- --rival-shot` for the journal's Household section with a met rival one realm ahead (the
## "Reach <realm> to stand a chance against <name>." line), then the bitter variant. Shoot at 1280x800 and 1280x720.
## WU-210: it then breaks through level with the rival (rival_caught_up_log / rival_caught_up_journal).
## WU-246: `-- --first-hour` also writes fh_<workshop|shop|journal_first_goals|journal_next_steps|journal_commissions|board>_<day1|month1>_<size>.png.
## WU-273: append `-- --techniques-shot` for techniques_practice[_scale115].png (Iron Fist level 1 details, practice button focused); run once per --resolution. Checked at 1280x720 and 1280x800: nothing clipped, the action row wraps.
## WU-271: `--hint-shot` also writes hint_trial_[journal_]<size>.png (open sect trial odds, Fights you can win) and hint_sell_armor_[journal_]<size>.png ("Sell your ..." armor line).
## WU-258: `--hint-shot` also writes hint_armor_far_[journal_]<size>.png and hint_empty_fights_journal_<size>.png.
## WU-268: `--hint-shot` also writes hint_long_[journal_]<size>.png (Azure Cloud outer disciple, Qi Refining 1st layer, Iron Fist 1: practice days, far qi, stipend).
## WU-252: `--hint-shot` also writes hint_buy_ingredient_[poor_][journal_]<size>.png and hint_thin_defence_long_[journal_]<size>.png (longest thin-defence line); all fit at 1280x720 and 1280x800. With the injury the HUD panel drops the hint lines by design (_fit_status_panel), so the journal carries them.
## WU-243: `-- --hint-shot` also writes hint_thin_defence_<size>.png / hint_idle_crafter_<size>.png (HUD) and *_journal_<size>.png (Next steps); checked at 1280x720 and 1280x800, nothing clipped.

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
	if OS.get_cmdline_user_args().has("--workshop-shot"):
		_start_workshop_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--shop-shot"):
		_start_shop_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--goal-shot"):
		_start_goal_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--rankup-shot"):
		_start_rankup_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--craft-shots"):
		_start_craft_shots(gs)
		return
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
	if OS.get_cmdline_user_args().has("--respawn-shot"):
		_start_respawn_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--late-realms"):
		_start_late_realms(gs)
		return
	if OS.get_cmdline_user_args().has("--debts-shot"):
		_start_debts_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--void-shot"):
		_start_void_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--body-shot"):
		_start_void_shot(gs, "body_integration", "body")
		return
	if OS.get_cmdline_user_args().has("--maha-shot"):
		_start_void_shot(gs, "mahayana", "maha")
		return
	if OS.get_cmdline_user_args().has("--tt-shot"):
		_start_void_shot(gs, "tribulation_transcendence", "tt")
		return
	if OS.get_cmdline_user_args().has("--tt-foes"):
		_start_tt_foes_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--inherit-shot"):
		_start_inherit_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--encounter-shot"):
		_start_encounter_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--rival-shot"):
		_start_rival_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--renown-shot"):
		_start_renown_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--banner-shot"):
		_start_banner_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--hint-shot"):
		_start_hint_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--map-shot"):
		_start_map_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--techniques-shot"):
		_start_techniques_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--soul-shot"):
		_start_soul_shot(gs)
		return
	if OS.get_cmdline_user_args().has("--breakthrough-shots"):
		_start_breakthrough_shots(gs)
		return
	if OS.get_cmdline_user_args().has("--pill-shot"):
		_start_pill_shot(gs)
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
	# WU-246: the workshop menu, the Wandering Merchant, the journal sections and the mission board as a fresh
	# Qingshi character sees them on day 1 and after the first month (named fh_<what>_<day1|month1>_<size>.png).
	var size_tag := "%dx%d" % [root.size.x, root.size.y]
	var clock: Node = root.get_node("GameClock")
	# The HUD only exists once fh_intro_dialogue has opened, so the screens are looked up on first use.
	var ui := {}
	var ensure := func() -> void:
		if ui.has("journal"):
			return
		ui["journal"] = hud.get("_screens")["toggle_journal"]
		ui["menu"] = hud.get("_choice_menu")
		ui["board"] = hud.get("_mission_board")
		ui["shop"] = hud.get("_shop")
		var stack: Array[Node] = [world]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node.get_script() != null and String(node.get_script().resource_path).ends_with("workshop.gd"):
				ui["workshop"] = node
		assert(ui.has("workshop"), "no workshop in the starting region")
	var journal_at := func(heading: String) -> void:
		ensure.call()
		hud.get("_banner").visible = false
		ui["journal"].open()
		for _i in 4:
			await root.get_tree().process_frame
		# The journal is one RichTextLabel: scroll to the paragraph holding the section heading.
		var text: RichTextLabel = ui["journal"].get("_text")
		var lines := text.get_parsed_text().split("\n")
		var at := lines.find(heading)
		assert(at >= 0, "journal has no section " + heading)
		ui["journal"].get("_scroll").scroll_vertical = int(text.get_paragraph_offset(at))
	var month_start := func() -> void:
		clock.total_days = Calendar.DAYS_PER_MONTH
		# By month one the newcomer has taken up Alchemy at the village workshop and has an order posted.
		gs.player.professions["alchemist"] = {"rank": 0, "xp": 0.0}
		gs.call("_commissions_month", "alchemist")
		root.get_node("EventBus").player_changed.emit()
	for phase: String in ["day1", "month1"]:
		var tag := "%s_%s" % [phase, size_tag]
		shots.append({"name": "fh_workshop_%s" % tag, "open": func() -> void:
			ensure.call()
			if phase == "month1":
				month_start.call()
			hud.get("_banner").visible = false
			ui["menu"].open_for(ui["workshop"]), "close": func() -> void: ui["menu"].close()})
		shots.append({"name": "fh_shop_%s" % tag, "open": func() -> void:
			ensure.call()
			hud.get("_banner").visible = false
			ui["shop"].open("Wandering Merchant", 0, ["herb", "ore", "equipment", "manual"])
			ui["shop"]._set_category("All"), "close": func() -> void: ui["shop"].close()})
		for heading: String in ["First goals", "Next steps", "Commissions"]:
			if heading == "Commissions" and phase == "day1":
				continue  # no order is posted until the first month
			shots.append({"name": "fh_journal_%s_%s" % [heading.to_lower().replace(" ", "_"), tag], "open": journal_at.bind(heading), "close": func() -> void: ui["journal"].close()})
		shots.append({"name": "fh_board_%s" % tag, "open": func() -> void:
			ensure.call()
			hud.get("_banner").visible = false
			ui["board"].open(), "close": func() -> void: ui["board"].close()})


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


## WU-226: C-147's Great Vehicle Pills in the breakthrough window, and the HUD hint with no pill.
func _start_pill_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 300 * Calendar.DAYS_PER_YEAR
	c.realm_index = gs.data.realm_index_of("body_integration")
	var realm: RealmDef = gs.data.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	c.inventory = {}
	root.get_node("Settings").call("set_value", "hud_hints", 3)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var win: Control = hud.get("_breakthrough")
	var hint_text := func() -> String:
		return (hud.get("_hint") as Label).text
	shots.append({"name": "pill_a_window", "open": func() -> void:
		c.add_item("mahayana_pill", 1)
		c.add_item("flawless_mahayana_pill", 1)
		hud.get("_banner").visible = false
		win.open(), "close": win.close})
	shots.append({"name": "pill_b_hint", "open": func() -> void:
		c.inventory = {}
		root.get_node("EventBus").player_changed.emit()
		# WU-231: player_changed can raise a Milestone banner; hide it one frame later so the hint panel is clear.
		await root.get_tree().process_frame
		hud.get("_banner").visible = false
		print("pill-shot hint: ", hint_text.call())
		print("pill-shot saving: ", Guidance.pill_saving_goal(c, gs.data), " | source: ", Guidance.pill_source_goal(c, gs.data)), "close": func() -> void: pass})
	# WU-240: C-157's Heavenly Tribulation Pills for a Mahayana Peak player at full qi: the window with both, then the no-pill hint.
	var to_mahayana := func() -> void:
		c.realm_index = gs.data.realm_index_of("mahayana")
		var maha: RealmDef = gs.data.realms[c.realm_index]
		c.stage = maha.stage_count() - 1
		c.qi = maha.qi_required(c.stage)
		c.inventory = {}
	shots.append({"name": "tt_pill_a_window", "open": func() -> void:
		to_mahayana.call()
		c.add_item("tribulation_transcendence_pill", 1)
		c.add_item("flawless_tribulation_transcendence_pill", 1)
		hud.get("_banner").visible = false
		win.open(), "close": win.close})
	shots.append({"name": "tt_pill_b_hint", "open": func() -> void:
		to_mahayana.call()
		root.get_node("EventBus").player_changed.emit()
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		hud.get("_banner").visible = false
		print("tt-pill-shot hint visible=", (hud.get("_hint") as Label).visible, ": ", hint_text.call())
		print("tt-pill-shot saving: ", Guidance.pill_saving_goal(c, gs.data), " | source: ", Guidance.pill_source_goal(c, gs.data)), "close": func() -> void: pass})


## WU-201: the crafting screen for every workshop craft, a rank-0 player one ingredient short.
func _start_workshop_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	Commissions.roll(c, gs.data, rng, int(root.get_node("GameClock").total_days))
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var workshop: Node = null
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("workshop.gd"):
			workshop = node
	var menu: Control = hud.get("_choice_menu")
	shots.append({"name": "workshop_menu", "open": func() -> void:
		hud.get("_banner").visible = false
		menu.open_for(workshop), "close": menu.close})
	# Focus on "Odd jobs as Alchemist" so its pay description line shows.
	shots.append({"name": "workshop_menu_odd_jobs", "open": func() -> void:
		hud.get("_banner").visible = false
		menu.open_for(workshop)
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		for b: Node in menu.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Odd jobs as"):
				(b as Button).grab_focus(), "close": menu.close})
	# WU-214: the journal's Commissions entries with GUIDE-052's "Needs <item>: <where>." (nothing in the pack).
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "workshop_journal_commissions", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})
	# WU-224: the order button for the longest-named recipe output (word-boundary cut from WU-219).
	shots.append({"name": "workshop_menu_long_order", "open": func() -> void:
		var best: Dictionary = {}
		for rid: String in gs.data.recipes:
			var rec: Dictionary = gs.data.recipes[rid]
			var iname := String(gs.data.items[String(rec["output"]["item"])].name)
			if best.is_empty() or iname.length() > String(best["name"]).length():
				best = {"name": iname, "recipe": rec}
		var item_id := String(best["recipe"]["output"]["item"])
		var today := int(root.get_node("GameClock").total_days)
		var p: CharacterData = gs.player
		p.commissions.clear()
		p.commissions.append({"profession": String(best["recipe"].get("profession", "alchemist")), "recipe": String(best["recipe"]["id"]),
			"item": item_id, "count": 12, "reward": 1234, "xp": 150.0, "due_day": today + 40})
		print("WU-224 label: ", Commissions.short_label(p, gs.data, p.commissions[0], today))
		hud.get("_banner").visible = false
		menu.open_for(workshop), "close": menu.close})
	# WU-233: PROF-014's gathering estimate, the longest real due-soon line with and without "longer than the order has".
	var hint_label: Label = hud.get("_hint")
	for variant: Array in [["estimate_within", 14], ["estimate_over", 3]]:
		var order := _longest_estimate_order(gs, int(variant[1]))
		if order.is_empty():
			continue
		var vname := String(variant[0])
		shots.append({"name": "workshop_hint_" + vname, "open": func() -> void:
			var p: CharacterData = gs.player
			p.commissions.clear()
			p.commissions.append(order.duplicate())
			p.inventory.clear()
			p.add_item("spirit_stone", 9999)  # rich enough that the odd-jobs hint stands down
			p.realm_index = maxi(p.realm_index, 2)  # past the newcomer hints, which would outrank the order line
			_set_all_ranks(gs, 2)  # the herb hint fades at CRAFT_HINT_MAX_RANK (2), leaving the order line first
			root.get_node("Settings").call("set_value", "hud_hints", 3)
			hud.get("_banner").visible = false
			root.get_node("EventBus").player_changed.emit()
			print("WU-233 hint (%s): %s" % [vname, hint_label.text])
			assert(hint_label.text.contains("of gathering"), "estimate not in hint: " + hint_label.text), "close": func() -> void: pass})
		shots.append({"name": "workshop_journal_" + vname, "open": func() -> void:
			var p: CharacterData = gs.player
			p.commissions.clear()
			p.commissions.append(order.duplicate())
			p.inventory.clear()
			journal.open()
			journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


func _set_all_ranks(gs: Node, rank: int) -> void:
	for prof_id: String in gs.data.professions:
		gs.player.professions[prof_id] = {"rank": rank, "xp": 0.0}


## WU-233: the commission with the longest "Needs ..." line that carries a gathering estimate, due in `due_in` days
## (3 is shorter than any gathering time, so it reads "longer than the order has").
func _longest_estimate_order(gs: Node, due_in: int) -> Dictionary:
	var today := int(root.get_node("GameClock").total_days)
	var c: CharacterData = gs.player
	var saved: Array = c.commissions.duplicate(true)
	var saved_inv: Dictionary = c.inventory.duplicate(true)
	var saved_profs: Dictionary = c.professions.duplicate(true)
	_set_all_ranks(gs, 2)
	var best: Dictionary = {}
	var best_len := 0
	for rid: String in gs.data.recipes:
		var rec: Dictionary = gs.data.recipes[rid]
		var item_id := String(rec["output"]["item"])
		for count in range(1, 13):
			var entry := {"profession": String(rec.get("profession", "alchemist")), "recipe": rid, "item": item_id, "count": count,
				"reward": 1234, "xp": 150.0, "due_day": today + due_in}
			c.commissions.clear()
			c.commissions.append(entry)
			c.inventory.clear()
			var line := Commissions.due_soon_hint(c, gs.data, gs.current_region, today)
			if line.contains("of gathering") and line.contains("longer than the order has") == (due_in <= 3) and line.length() > best_len:
				best_len = line.length()
				best = entry
	c.commissions = saved
	c.inventory = saved_inv
	c.professions = saved_profs
	print("WU-233 longest (due in %d): %d chars %s" % [due_in, best_len, best.get("recipe", "none")])
	return best


## WU-216: the rank-up lines in the message log, longest title + line pair of any craft and rank.
func _start_rankup_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	var best_prof := ""
	var best_rank := 1
	var best_len := 0
	for prof_id: String in gs.data.professions:
		for r in range(1, Professions.max_rank(gs.data) + 1):
			c.professions[prof_id] = {"rank": r, "xp": 0.0}
			var text: String = "You are now %s! %s" % [Text.a(Professions.rank_title(c, gs.data, prof_id)), Professions.rank_up_line(c, gs.data, prof_id)]
			if text.length() > best_len:
				best_len = text.length()
				best_prof = prof_id
				best_rank = r
	c.professions.clear()
	print("longest rank-up: %s rank %d (%d chars)" % [best_prof, best_rank, best_len])
	c.professions[best_prof] = {"rank": best_rank, "xp": 0.0}
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	gs.call("_post_rank_up", best_prof)
	var log_screen: Control = hud.get("_screens")["toggle_message_log"]
	shots.append({"name": "rankup_hud", "open": func() -> void: hud.get("_banner").visible = false, "close": func() -> void: pass})
	shots.append({"name": "rankup_log", "open": func() -> void: log_screen.open(), "close": log_screen.close})


## WU-222: the journal's goals with the longest "Next recipe: ..." line of any craft at rank 1.
func _start_goal_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	var today := int(root.get_node("GameClock").total_days)
	var best_prof := ""
	var best_len := 0
	for prof_id: String in gs.data.professions:
		c.professions.clear()
		c.professions[prof_id] = {"rank": 1, "xp": 0.0}
		var line := Guidance.next_recipe_line(c, gs.data, prof_id, gs.current_region, today)
		if line.length() > best_len:
			best_len = line.length()
			best_prof = prof_id
	c.professions.clear()
	c.professions[best_prof] = {"rank": 1, "xp": 0.0}
	c.realm_index = 2  # past the first goals, so the "Goals" section shows
	print("longest next-recipe line: %s (%d chars): %s" % [best_prof, best_len, Guidance.next_recipe_line(c, gs.data, best_prof, gs.current_region, today)])
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "goal_journal", "open": func() -> void:
		hud.get("_banner").visible = false
		journal.open(), "close": journal.close})
	# Scroll to the "Goals" heading so its "Next recipe: ..." line shows.
	shots.append({"name": "goal_journal_end", "open": func() -> void:
		hud.get("_banner").visible = false
		journal.open()
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		for l: Node in journal.find_children("*", "Label", true, false):
			if (l as Label).text == "Goals":
				journal.get("_scroll").set_deferred("scroll_vertical", int((l as Label).position.y)), "close": journal.close})


func _start_craft_shots(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var screen: Control = hud.get("_crafting")
	for prof_id: String in ["alchemist", "blacksmith", "talisman_master", "array_master", "beast_tamer"]:
		shots.append({"name": "craft_" + prof_id, "open": func() -> void:
			hud.get("_banner").visible = false
			c.professions[prof_id] = {"rank": 0, "xp": 0.0}
			c.inventory = {}
			var ids := Alchemy.known_recipes(c, gs.data, prof_id)
			if not ids.is_empty():
				# Hold every ingredient but one so the "grows at" line shows.
				var ingredients: Dictionary = gs.data.recipes[ids[0]]["ingredients"]
				var keys := ingredients.keys()
				for k in keys.size() - 1:
					c.add_item(keys[k], int(ingredients[keys[k]]))
			screen.open(prof_id)
			if not ids.is_empty():
				screen.call("_select", ids[0]), "close": screen.close})


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


## WU-180: the journal's newest lines: Debts and grudges, and an inheritance close to its deadline.
func _start_debts_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	var clock: Node = root.get_node("GameClock")
	# village_founder_well has deadline_years 12: three months before it.
	clock.total_days = 12 * Calendar.DAYS_PER_YEAR - 3 * Calendar.DAYS_PER_MONTH
	c.age_days = 16 * Calendar.DAYS_PER_YEAR
	var names := ["Ayla the Herbalist", "Old Bo the Ferryman", "Gu Wen of the Iron Hall"]
	for i in names.size():
		var npc := CharacterData.new()
		npc.id = "shot_npc_%d" % i
		npc.name = names[i]
		npc.home_region = gs.current_region
		gs.npcs[npc.id] = npc
	Karma.add_gratitude(c, gs.data, "shot_npc_0", 70)
	Karma.add_gratitude(c, gs.data, "shot_npc_1", 45)
	Karma.add_grudge(c, gs.data, "shot_npc_2", 60)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "debts_journal", "open": func() -> void: journal.open(), "close": journal.close})
	shots.append({"name": "debts_journal_end", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


## WU-225: the Hollow of the Unbroken Body (marrow_throne_hollow) at its first trial, then at the missed Constitution gate.
func _start_inherit_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 300 * Calendar.DAYS_PER_YEAR
	# WU-232: the second case is C-152's Mahayana Sutra Barge, with comprehension 28 missed.
	var cases: Array[Dictionary] = [
		{"id": "marrow_throne_hollow", "realm": "body_integration", "attr": "constitution", "tag": "Unbroken Body",
			"name": "Hollow of the Unbroken Body", "prefix": "inherit", "steps": [["", 0], ["_gate", 1]]},
		{"id": "great_vehicle_sutra_barge", "realm": "mahayana", "attr": "comprehension", "tag": "Sutra Barge",
			"name": "Sutra Barge of the Great Vehicle", "prefix": "inherit_maha", "steps": [["_gate", 1]]},
	]
	var first_def: Dictionary = gs.data.inheritances[cases[0]["id"]]
	root.get_node("GameClock").total_days = Inheritances.appears_day(first_def) + 2 * Calendar.DAYS_PER_YEAR
	gs.current_region = String(first_def["region"])
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	var menu: Control = hud.get("_choice_menu")
	for case: Dictionary in cases:
		var id: String = case["id"]
		var def: Dictionary = gs.data.inheritances[id]
		var ground: Node = load("res://src/world/interactables/inheritance_grounds.gd").new()
		ground.display_name = case["name"]
		for step: Array in case["steps"]:
			var suffix: String = step[0]
			var cleared: int = step[1]
			var prefix: String = case["prefix"]
			shots.append({"name": prefix + "_menu" + suffix, "open": func() -> void:
				c.realm_index = gs.data.realm_index_of(case["realm"])
				c.stage = 0
				c.attributes[case["attr"]] = 10
				root.get_node("GameClock").total_days = Inheritances.appears_day(def) + 2 * Calendar.DAYS_PER_YEAR
				gs.current_region = String(def["region"])
				c.trial_progress[id] = cleared
				hud.get("_banner").visible = false
				menu.open_for(ground), "close": menu.close})
			shots.append({"name": prefix + "_journal" + suffix, "open": func() -> void:
				c.trial_progress[id] = cleared
				journal.open()
				journal.get("_scroll").set_deferred("scroll_vertical", 100000)
				var opps: Array[Dictionary] = []
				Guidance._opportunity_entries(opps, c, gs.data, gs.world_flags, root.get_node("GameClock").total_days, gs.current_region)
				for o: Dictionary in opps:
					if String(o.get("text", "")).contains(case["tag"]):
						print("inherit-shot journal: ", o.get("text", "")), "close": journal.close})


## WU-207: the journal with a met rival a realm ahead, calm and then bitter.
func _start_rival_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	var rival := CharacterData.new()
	rival.id = "shot_rival"
	rival.name = "Murong Xuanming of the Iron Hall"
	rival.home_region = gs.current_region
	rival.realm_index = c.realm_index + 1
	rival.alive = true
	gs.npcs[rival.id] = rival
	c.rival = rival.id
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "rival_journal", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})
	shots.append({"name": "rival_journal_bitter", "open": func() -> void:
		Karma.add_grudge(c, gs.data, rival.id, 30)
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})
	# WU-210: a breakthrough brings you level with the rival (RIVAL-020 news in the message log).
	shots.append({"name": "rival_caught_up_log", "open": func() -> void:
		var old_realm := c.realm_index
		c.realm_index += 1
		gs.call("_check_rival_caught_up", old_realm)
		hud.get("_banner").visible = false, "close": func() -> void: pass})
	shots.append({"name": "rival_caught_up_journal", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


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


## WU-188: a Void Refinement Early player, journal and HUD.
func _start_void_shot(gs: Node, realm_id: String = "void_refinement", prefix: String = "void") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 300 * Calendar.DAYS_PER_YEAR
	c.realm_index = gs.data.realm_index_of(realm_id)
	c.stage = 0
	c.qi = gs.data.realms[c.realm_index].qi_required(0) if prefix == "void" else gs.data.realms[c.realm_index].qi_required(0) / 2
	for beat_id: String in ["foundation_establishment", "core_formation", "nascent_soul", "soul_formation", "void_refinement"]:
		gs.world_flags[Guidance.beat_realm_flag(realm_id)] = true
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": prefix + "_hud", "open": func() -> void: hud.get("_banner").visible = false, "close": func() -> void: pass})
	shots.append({"name": prefix + "_journal", "open": func() -> void: journal.open(), "close": journal.close})
	shots.append({"name": prefix + "_journal_end", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


## WU-242: C-154's longest-named lethal foe at Tribulation Transcendence Early: threat prompt, lost fight, message log.
func _start_tt_foes_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.age_days = 300 * Calendar.DAYS_PER_YEAR
	c.realm_index = gs.data.realm_index_of("tribulation_transcendence")
	c.stage = 0
	var foe_id := "lightning_tithe_sovereign"
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var report: Control = hud.get("_combat_report")
	var log_screen: Control = hud.get("_screens")["toggle_message_log"]
	shots.append({"name": "tt_foe_prompt", "open": func() -> void:
		hud.get("_banner").visible = false
		hud.call("_on_threat_sensed", foe_id), "close": func() -> void:
		hud.get("_choice_menu").close()
		gs.pending_threat = ""})
	shots.append({"name": "tt_foe_report", "open": func() -> void:
		hud.get("_banner").visible = false
		gs.fight(foe_id)
		report.skip(), "close": func() -> void:
		report.close()
		hud.get("_respawn").close()})
	shots.append({"name": "tt_foe_log", "open": func() -> void:
		hud.get("_banner").visible = false
		log_screen.open(), "close": log_screen.close})


## WU-196: renown at the first title and halfway to the second, arrival banner and journal.
func _start_renown_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	var tiers: Array = gs.data.renown["tiers"]
	var first_min := int((tiers[1] as Dictionary)["min"])
	var second_min := int((tiers[2] as Dictionary)["min"])
	Renown.add(c, gs.data, gs.current_region, first_min + (second_min - first_min) / 2)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "renown_arrival", "open": func() -> void:
		hud.get("_banner").visible = true
		hud.call("_show_arrival", gs.current_region), "close": func() -> void: pass})
	shots.append({"name": "renown_journal", "open": func() -> void:
		hud.get("_banner").visible = false
		journal.open(), "close": journal.close})
	shots.append({"name": "renown_journal_end", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})


## WU-197: the HUD with a notice banner up (Goal line and hints visible), and a centred window under one.
func _start_banner_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var banner: Control = hud.get("_banner")
	var journal: Control = hud.get("_screens")["toggle_journal"]
	var show_banner := func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("Realm: Qi Refining 2nd Layer", "Your qi runs deeper. New: the shop sells manuals.", Color(0.9, 0.78, 0.4), 60.0)
	shots.append({"name": "banner_hud", "open": show_banner, "close": func() -> void: pass})
	shots.append({"name": "banner_journal", "open": func() -> void:
		show_banner.call()
		journal.open(), "close": journal.close})
	# WU-204: the longest real arrival subtitle (top renown title everywhere) and the longest milestone name.
	var top_tiers: Array = gs.data.renown.get("tiers", [])
	var top_amount: int = int((top_tiers[top_tiers.size() - 1] as Dictionary)["min"]) if not top_tiers.is_empty() else 0
	var long_title := ""
	var long_sub := ""
	for region_id: String in gs.data.regions:
		Renown.add(c, gs.data, region_id, top_amount)
		var qi := Exploration.qi_density(gs.data, region_id, gs.world_flags)
		var danger: String = load("res://src/ui/world_map_screen.gd").danger_name(gs.data, region_id)
		var sub: String = hud.get_script().arrival_subtitle(c, gs.data, region_id, qi, danger, true)
		var name := Exploration.region_name(gs.data, region_id)
		if name.length() + sub.length() > long_title.length() + long_sub.length():
			long_title = name
			long_sub = sub
	var long_milestone := ""
	for m: Dictionary in gs.data.milestones:
		if String(m.get("name", "")).length() > long_milestone.length():
			long_milestone = String(m["name"])
	print("banner-shot arrival: ", long_title, " | ", long_sub, " | milestone: ", long_milestone)
	shots.append({"name": "banner_arrival_long", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce(long_title, long_sub, Color(0.9, 0.78, 0.4), 60.0), "close": func() -> void: pass})
	shots.append({"name": "banner_milestone_long", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("Milestone", long_milestone, Color(0.9, 0.78, 0.4), 60.0), "close": func() -> void: pass})


## WU-211: the HUD hint panel at its maximum setting with the longest crafter hints: the away-region
## herb hint (GUIDE-046/048) and the broke-crafter odd-jobs line (GUIDE-047).
## WU-220: also hint_mortal_nudge (GUIDE-054 "You are still a mortal" line, day 40, open order).
## WU-244: the Wandering Merchant buy tab with an "(upgrade)" armor row and an affordable body-art manual.
func _start_shop_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.equipment = {"armor": "boar_hide_jerkin"}
	c.inventory = {"spirit_stone": 400}
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var shop: Control = hud.get("_shop")
	shots.append({"name": "shop_upgrade_tag", "open": func() -> void:
		shop.open("Wandering Merchant", 0, ["herb", "ore", "equipment", "manual"])
		shop._set_category("All"), "close": shop.close})
	# WU-263: Heavenforge Smithy in Fallen Star Market: affordable "(upgrade)" armor next to unmarked rows (worse or too dear).
	shots.append({"name": "shop_smithy_upgrade", "open": func() -> void:
		gs.current_region = "fallen_star_market"
		shop.open("Heavenforge Smithy", 0, ["equipment", "ore", "smithing"])
		shop._set_category("All"), "close": shop.close})
	# WU-260: a Qingshi merchant that sells no gear points at the smithy.
	shots.append({"name": "shop_gear_elsewhere", "open": func() -> void:
		gs.current_region = "qingshi_village"
		shop.open("Wandering Merchant", 0, ["herb", "ore"])
		shop._set_category("All"), "close": shop.close})


## WU-273: `--techniques-shot` writes techniques_practice.png and techniques_practice_scale115.png (UI scale 115%): a Qi Refining
## 1st-layer player in Qingshi Village with Iron Fist and Basic Breathing at level 1, the Techniques screen on Iron Fist's details.
## Run once per --resolution (1280x720, 1280x800); the file name has no size suffix, so copy it between runs.
func _start_techniques_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	gs.current_region = "qingshi_village"
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}, "basic_breathing": {"level": 1, "xp": 0.0}}
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var techs: Control = hud.get("_screens")["toggle_techniques"]
	var open_iron_fist := func() -> void:
		techs.open()
		techs._select("iron_fist")
		techs._focus_first_action.call_deferred()
	shots.append({"name": "techniques_practice", "open": open_iron_fist, "close": techs.close})
	shots.append({"name": "techniques_practice_scale115", "open": func() -> void:
		root.content_scale_factor = 1.15
		open_iron_fist.call(), "close": func() -> void:
		techs.close()
		root.content_scale_factor = 1.0})


## WU-253: `--map-shot` writes map_sells_<size>.png, the world map with Fallen Star Market selected (its "Sells:" line).
## WU-265: checked at 1280x720 and 1280x800: the full Sells line (all 8 merchants) shows above Places without scrolling; Places scrolls.
func _start_map_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var map: Control = hud.get("_screens")["toggle_map"]
	shots.append({"name": "map_sells", "open": func() -> void:
		gs.current_region = "fallen_star_market"
		map.open(), "close": map.close})


func _start_hint_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	root.get_node("Settings").call("set_value", "hud_hints", 3)
	var clock: Node = root.get_node("GameClock")
	# Find the longest away-region herb hint over every region and season.
	var best := ""
	var best_region := ""
	var best_day := 0
	for region_id: String in gs.data.regions:
		for day in range(0, 4 * Calendar.DAYS_PER_MONTH * 3, Calendar.DAYS_PER_MONTH):
			var text := Guidance.herb_here_hint(c, gs.data, region_id, day)
			if text.contains("a short walk away") and text.length() > best.length():
				best = text
				best_region = region_id
				best_day = day
	assert(best != "", "no away-region herb hint found in data")
	print("hint-shot: ", best_region, " day ", best_day, ": ", best)
	clock.total_days = best_day
	gs.current_region = best_region
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var hint_text := func() -> String:
		return (hud.get("_hint") as Label).text
	shots.append({"name": "hint_herb_away", "open": func() -> void:
		hud.get("_banner").visible = false
		root.get_node("EventBus").player_changed.emit()
		assert(String(hint_text.call()).contains("a short walk away"), "away hint not on screen"), "close": func() -> void: pass})
	# Broke crafter: no stones, nothing craftable, so the odd-jobs line fires (longest region name wins).
	# The herb hint fades at rank CRAFT_HINT_MAX_RANK (GUIDE-049), which is when this line shows. WU-215: checked on screen;
	# the line reads "Short of stones? Odd jobs as X at the <workshop> pay about N a month." and fits at 1280x720 and 1280x800.
	var broke_region := ""
	var ranks_before: Dictionary = {}
	for prof_id: String in c.professions:
		ranks_before[prof_id] = int(c.professions[prof_id]["rank"])
		c.professions[prof_id]["rank"] = Guidance.CRAFT_HINT_MAX_RANK
	for region_id: String in gs.data.regions:
		var listed: PackedStringArray = Guidance.hints(c, gs.data, gs.hint_density(), 5, gs.npcs, gs.world_flags, region_id, best_day, gs.npc_favor)
		var line := ""
		for h: String in listed:
			if h.begins_with("Short of stones?"):
				line = h
		if line != "" and (broke_region == "" or Guidance.workshop_place(gs.data, region_id).length() > Guidance.workshop_place(gs.data, broke_region).length()):
			broke_region = region_id
	for prof_id: String in ranks_before:
		c.professions[prof_id]["rank"] = ranks_before[prof_id]
	assert(broke_region != "", "no odd-jobs hint found in data")
	shots.append({"name": "hint_broke_crafter", "open": func() -> void:
		hud.get("_banner").visible = false
		c.inventory = {}
		for prof_id: String in c.professions:
			c.professions[prof_id]["rank"] = Guidance.CRAFT_HINT_MAX_RANK
		gs.current_region = broke_region
		root.get_node("EventBus").player_changed.emit()
		assert(String(hint_text.call()).contains("Short of stones?"), "odd-jobs hint not on screen: " + String(hint_text.call()))
		print("hint-shot broke: ", hint_text.call()), "close": func() -> void: pass})
	# WU-220: GUIDE-054's Mortal nudge on day 40 in Qingshi with an open order and herbs still to gather, so the
	# panel holds the nudge plus the crafter hints (shows the rank-0 Alchemist; nothing in the pack).
	shots.append({"name": "hint_mortal_nudge", "open": func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 0
		c.inventory = {}
		for prof_id: String in c.professions:
			c.professions[prof_id]["rank"] = 0
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		gs.call("_commissions_month", "alchemist")
		root.get_node("EventBus").player_changed.emit()
		var text: String = hint_text.call()
		assert(text.contains("You are still a mortal"), "mortal nudge not on screen: " + text)
		print("hint-shot mortal (", c.commissions.size(), " orders): ", text), "close": func() -> void: pass})
	# WU-243: GUIDE-065's thin-defence line (Foundation, no body art, no armor, injured) and GUIDE-057's idle-crafter
	# line (Qi Refining Alchemist idle 40 days), each in the HUD hint panel and the journal's Next steps.
	var size_tag := "%dx%d" % [root.size.x, root.size.y]
	var journal: Control = hud.get("_screens")["toggle_journal"]
	var show_journal := func(heading: String) -> void:
		journal.open()
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		for l: Node in journal.find_children("*", "Label", true, false):
			if (l as Label).text == heading:
				journal.get("_scroll").set_deferred("scroll_vertical", int((l as Label).position.y))
	var setup_thin := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 2
		c.stage = 0
		c.equipment.erase("armor")
		c.techniques.clear()
		c.injuries.clear()
		for injury_id: String in gs.data.injuries:
			Injuries.inflict(c, gs.data, injury_id)
			break
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	var setup_idle := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 1
		c.stage = 0
		c.injuries.clear()
		for prof_id: String in c.professions:
			c.professions[prof_id]["rank"] = 0
		c.last_meditated_day = 0
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	# WU-252: GUIDE-066's buy-ingredient line (Array Master in Qingshi, no paper; 20 stones, then none for the odd-jobs
	# suffix) and GUIDE-068's longest thin-defence line (no armor, no body art, injured, 500 stones so both "where"
	# sentences show; the region with the longest line wins).
	var setup_buy := func(stones: int) -> void:
		hud.get("_banner").visible = false
		c.realm_index = 1
		c.stage = 0
		c.injuries.clear()
		c.professions.clear()
		c.professions["array_master"] = {"rank": 0, "xp": 0.0}
		c.inventory = {"spirit_stone": stones, "spirit_herb": 2} if stones > 0 else {"spirit_herb": 2}
		c.last_meditated_day = 40
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	var thin_region := "qingshi_village"
	var thin_len := 0
	c.realm_index = 2
	c.equipment.erase("armor")
	c.techniques.clear()
	c.inventory = {"spirit_stone": 500}
	for region_id: String in gs.data.regions:
		var l := Guidance.thin_defence_hint(c, gs.data, region_id).length()
		if l > thin_len:
			thin_len = l
			thin_region = region_id
	print("hint-shot longest thin-defence region: ", thin_region, " (", thin_len, " chars)")
	var setup_thin_long := func() -> void:
		setup_thin.call()
		c.inventory = {"spirit_stone": 500}
		gs.current_region = thin_region
		root.get_node("EventBus").player_changed.emit()
	for case: Array in [["hint_buy_ingredient_", func() -> void: setup_buy.call(20), "needs Blank Talisman Paper"], ["hint_buy_ingredient_poor_", func() -> void: setup_buy.call(0), "Sell gathered herbs or take odd jobs"], ["hint_thin_defence_long_", setup_thin_long, "Your defence is thin"]]:
		var setup: Callable = case[1]
		var needle: String = case[2]
		shots.append({"name": case[0] + size_tag, "open": func() -> void:
			setup.call()
			assert(String(hint_text.call()).contains(needle), "hint not on screen: " + String(hint_text.call()))
			print("hint-shot ", needle, ": ", hint_text.call()), "close": func() -> void: pass})
		shots.append({"name": case[0] + "journal_" + size_tag, "open": func() -> void:
			setup.call()
			show_journal.call("Next steps"), "close": journal.close})
	# WU-258: GUIDE-074's empty "Fights you can win" note (journal) and GUIDE-075's far-armor line (HUD and Next steps)
	# for a Qi Refining fighter in Qingshi with no armor, 200 stones and nothing fair to fight.
	var setup_armor_far := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 1
		c.stage = 5
		c.injuries.clear()
		c.equipment.erase("armor")
		c.techniques = {"iron_fist": {"level": Techniques.PRACTICE_LEVEL, "xp": 0.0}}
		c.inventory = {"spirit_stone": 200}
		c.last_meditated_day = 40
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	shots.append({"name": "hint_armor_far_" + size_tag, "open": func() -> void:
		setup_armor_far.call()
		print("hint-shot armor far: ", hint_text.call())
		# Qingshi's chore line ranks above the armor line, so the HUD shows the chore; the journal lists both.
		var listed: PackedStringArray = Guidance.hints(c, gs.data, 3, 12, gs.npcs, gs.world_flags, "qingshi_village", 40, gs.npc_favor)
		assert("\n".join(listed).contains("Armor would keep you standing"), "armor hint missing: " + "\n".join(listed)), "close": func() -> void: pass})
	shots.append({"name": "hint_armor_far_journal_" + size_tag, "open": func() -> void:
		setup_armor_far.call()
		show_journal.call("Next steps"), "close": journal.close})
	# The first (realm, stage, region) where an armorless fighter has no fair fight; Qi Refining preferred.
	var empty_realm := 2
	var empty_stage := 0
	var empty_region := "qingshi_village"
	var found_empty := false
	var probe: CharacterData = CharacterData.from_dict(c.to_dict())
	probe.equipment.erase("armor")
	probe.techniques = {"iron_fist": {"level": Techniques.PRACTICE_LEVEL, "xp": 0.0}}
	for realm_try: int in [1, 2]:
		for stage_try in range(0, 9):
			for region_id: String in gs.data.regions:
				if found_empty:
					break
				probe.realm_index = realm_try
				probe.stage = stage_try
				if Guidance.fair_fights(probe, gs.data, gs.world_flags, 40, region_id, gs.npcs, gs.npc_favor).is_empty():
					empty_realm = realm_try
					empty_stage = stage_try
					empty_region = region_id
					found_empty = true
	print("hint-shot empty fights: realm ", empty_realm, " stage ", empty_stage, " ", empty_region, " found ", found_empty)
	shots.append({"name": "hint_empty_fights_journal_" + size_tag, "open": func() -> void:
		setup_armor_far.call()
		c.realm_index = empty_realm
		c.stage = empty_stage
		gs.current_region = empty_region
		await show_journal.call("Fights you can win")
		for _i in 3:
			await root.get_tree().process_frame
		var rich: RichTextLabel = journal.get("_text")
		var parsed := rich.get_parsed_text()
		var at := parsed.find("Fights you can win")
		assert(at >= 0, "journal has no Fights you can win section")
		var scroll: ScrollContainer = journal.get("_scroll")
		scroll.scroll_vertical = int(rich.get_paragraph_offset(parsed.substr(0, at).count("\n")))
		print("hint-shot journal scrolled to ", scroll.scroll_vertical), "close": journal.close})
	for case: Array in [["hint_thin_defence_", setup_thin, "Your defence is thin"], ["hint_idle_crafter_", setup_idle, "You have not cultivated"]]:
		var setup: Callable = case[1]
		var needle: String = case[2]
		shots.append({"name": case[0] + size_tag, "open": func() -> void:
			setup.call()
			assert(String(hint_text.call()).contains(needle), "hint not on screen: " + String(hint_text.call()))
			print("hint-shot ", needle, ": ", hint_text.call()), "close": func() -> void: pass})
		shots.append({"name": case[0] + "journal_" + size_tag, "open": func() -> void:
			setup.call()
			show_journal.call("Next steps"), "close": journal.close})
	# WU-268: the longer GUIDE-081/083/084 hints for an Azure Cloud outer disciple, Qi Refining 1st layer, Iron Fist
	# level 1, meditating at the Spirit Spring: practice days, "(N days away)" better qi and the sect rank's stipend.
	var long_region := "qingshi_village"
	var long_len := 0
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 50}
	for region_id: String in gs.data.regions:
		var qi_line: String = Guidance._better_qi_hint(c, gs.data, region_id, gs.world_flags)
		if qi_line.contains(" away)") and qi_line.length() > long_len:
			long_len = qi_line.length()
			long_region = region_id
	print("hint-shot far-qi region: ", long_region, " (", long_len, " chars)")
	var setup_long := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 1
		c.stage = 0
		c.injuries.clear()
		c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 50}
		c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
		c.inventory = {"spirit_stone": 10}
		c.last_meditated_day = 40
		clock.total_days = 40
		gs.current_region = long_region
		root.get_node("EventBus").player_changed.emit()
	shots.append({"name": "hint_long_" + size_tag, "open": func() -> void:
		setup_long.call()
		print("hint-shot long: ", hint_text.call()), "close": func() -> void: pass})
	shots.append({"name": "hint_long_journal_" + size_tag, "open": func() -> void:
		setup_long.call()
		print("hint-shot long list: ", "\n".join(Guidance.hints(c, gs.data, 3, 12, gs.npcs, gs.world_flags, long_region, 40, gs.npc_favor)))
		await show_journal.call("Next steps")
		for _i in 3:
			await root.get_tree().process_frame
		var long_rich: RichTextLabel = journal.get("_text")
		var long_parsed := long_rich.get_parsed_text()
		var long_at := long_parsed.find("Meditation at")
		assert(long_at >= 0, "journal has no far-qi line")
		var long_scroll: ScrollContainer = journal.get("_scroll")
		long_scroll.scroll_vertical = maxi(0, int(long_rich.get_paragraph_offset(long_parsed.substr(0, long_at).count("\n"))) - 160), "close": journal.close})
	# WU-271: GUIDE-085/087's open sect trial (odds line in the HUD/journal, "Sect trial: Inner Disciple" under
	# Fights you can win) and GUIDE-088's "Sell your ..." armor line. Both in qingshi_village.
	var loot_item := func(tag: String) -> String:
		for id: String in gs.data.items:
			if Items.has_tag(gs.data, id, [tag]) and Items.sell_price(gs.data, id) > 0:
				return id
		return ""
	var setup_trial := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 2
		c.stage = 0
		c.injuries.clear()
		c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 500}
		gs.world_flags[Guidance.ELDER_MO_FLAG] = true
		for attr: String in c.attributes:
			c.attributes[attr] = 4  # a weak disciple, so the trial is a close fight and "Fights you can win" lists it
		c.techniques = {}
		c.inventory = {"spirit_stone": 10}
		c.equipment = {}
		c.last_meditated_day = 40
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	var setup_sell := func() -> void:
		hud.get("_banner").visible = false
		c.realm_index = 1
		c.stage = Guidance.ARMOR_HINT_MIN_STAGE
		c.injuries.clear()
		c.sect = {}
		gs.world_flags[Guidance.ELDER_MO_FLAG] = true
		c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
		c.inventory = {"spirit_stone": 10, loot_item.call("ore"): 100, loot_item.call("beast_material"): 100}
		c.equipment = {}
		c.last_meditated_day = 40
		clock.total_days = 40
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").player_changed.emit()
	for case: Array in [["hint_trial_", setup_trial, "You face the", "Next steps"], ["hint_trial_fights_", setup_trial, "Sect trial", "Fights you can win"], ["hint_sell_armor_", setup_sell, "Sell your", "Next steps"]]:
		var setup: Callable = case[1]
		var needle: String = case[2]
		var heading: String = case[3]
		if case[0] != "hint_trial_fights_" and case[0] != "hint_trial_":  # the trial line is below the HUD's top hints
			shots.append({"name": case[0] + size_tag, "open": func() -> void:
				setup.call()
				print("hint-shot ", needle, " HUD: ", hint_text.call()), "close": func() -> void: pass})
		shots.append({"name": case[0] + "journal_" + size_tag, "open": func() -> void:
			setup.call()
			print("hint-shot ", needle, " list: ", "\n".join(Guidance.hints(c, gs.data, 3, 12, gs.npcs, gs.world_flags, "qingshi_village", 40, gs.npc_favor)))
			await show_journal.call(heading)
			for _i in 3:
				await root.get_tree().process_frame
			var rich: RichTextLabel = journal.get("_text")
			var parsed := rich.get_parsed_text()
			var at := parsed.find(needle if heading == "Next steps" else heading)
			assert(at >= 0, "journal has no " + needle + " line")
			var scroll: ScrollContainer = journal.get("_scroll")
			scroll.scroll_vertical = maxi(0, int(rich.get_paragraph_offset(parsed.substr(0, at).count("\n"))) - 120), "close": journal.close})


## WU-190: the encounter window on real encounters with attribute, profession and enemy choices.
func _start_encounter_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.attributes["charisma"] = 5  # misses the charisma 12 gate
	c.realm_index = gs.data.realm_index_of("core_formation")
	c.stage = 0
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	var enc: Control = hud.get("_encounter")
	for enc_id: String in ["village_field_quarrel", "marsh_yin_ferryman", "wild_wounded_disciple"]:
		shots.append({"name": "encounter_" + enc_id, "open": func() -> void:
			hud.get("_banner").visible = false
			gs.pending_encounter = enc_id
			enc.open(), "close": enc.close})
	# WU-217: the Body Integration choice encounters (C-129), gates missed (low attributes, alignment 0 so the
	# arbiter's min_alignment 20 and max_alignment 10 gates split) and then met.
	for gate_met: bool in [false, true]:
		for enc_id: String in ["wild_body_of_a_drowned_god", "mountain_arbiter_of_one_body", "ruins_bone_court_petition"]:
			shots.append({"name": "encounter_bi_%s_%s" % [enc_id, "met" if gate_met else "missed"], "open": func() -> void:
				hud.get("_banner").visible = false
				c.realm_index = gs.data.realm_index_of("body_integration")
				c.attributes["constitution"] = 60 if gate_met else 5
				c.attributes["spirit"] = 60 if gate_met else 5
				c.alignment = 30 if gate_met else 0
				gs.pending_encounter = enc_id
				enc.open(), "close": enc.close})
	# WU-228: C-149's three Mahayana choice encounters, attribute and alignment gates missed (alignment 0 misses the
	# ancestor's max_alignment -100 seat) and met (alignment -150). The vow lamp has the longest choice label.
	for gate_met: bool in [false, true]:
		for enc_id: String in ["wild_lamp_of_ten_thousand_vows", "mountain_ferryman_of_the_last_river", "ruins_ancestor_who_would_not_ascend"]:
			shots.append({"name": "encounter_maha_%s_%s" % [enc_id, "met" if gate_met else "missed"], "open": func() -> void:
				hud.get("_banner").visible = false
				c.realm_index = gs.data.realm_index_of("mahayana")
				c.attributes["spirit"] = 80 if gate_met else 5
				c.attributes["comprehension"] = 80 if gate_met else 5
				c.alignment = -150 if gate_met else 0
				gs.pending_encounter = enc_id
				enc.open(), "close": enc.close})
	# WU-238: C-155's Tribulation Transcendence choice encounters, gates missed (spirit 5, alignment 0 misses the
	# cairn's and the elder's max_alignment -100, no stones for the paid choices) and met (spirit 80, alignment -150, stones).
	for gate_met: bool in [false, true]:
		for enc_id: String in ["wild_bell_of_the_last_lightning", "mountain_cairn_of_the_failed_ascension", "ruins_elder_waiting_for_the_sky"]:
			shots.append({"name": "encounter_tt_%s_%s" % [enc_id, "met" if gate_met else "missed"], "open": func() -> void:
				hud.get("_banner").visible = false
				c.realm_index = gs.data.realm_index_of("tribulation_transcendence")
				c.attributes["spirit"] = 80 if gate_met else 5
				c.alignment = -150 if gate_met else 0
				c.inventory.erase("spirit_stone")
				if gate_met:
					c.add_item("spirit_stone", 600000)
				gs.pending_encounter = enc_id
				enc.open(), "close": enc.close})
	# WU-221: C-143's crafter encounters. The player has no profession, so the broken forge's blacksmith choice
	# shows its gate missed; the old alchemist's notes choice is gated on comprehension 12 (met via 60).
	for enc_id: String in ["forest_abandoned_herb_cache", "forest_old_alchemists_notes", "village_broken_forge"]:
		shots.append({"name": "encounter_crafter_" + enc_id, "open": func() -> void:
			hud.get("_banner").visible = false
			c.realm_index = gs.data.realm_index_of("qi_refining")
			c.attributes["comprehension"] = 5
			gs.pending_encounter = enc_id
			enc.open(), "close": enc.close})

	# WU-250: C-166's road encounters at both Steam Deck sizes: the choice window and the result line the HUD log
	# shows after the first choice. The peddler's "Buy a bundle" costs 8 stones: shot with 20 and with 7 (disabled).
	var size_tag := "%dx%d" % [root.size.x, root.size.y]
	var road_cases: Array = [["road_talisman_peddler", 20, ""], ["road_talisman_peddler", 7, "_poor"],
			["road_milestone_carver", 20, ""], ["road_rain_shelter", 20, ""]]
	for case: Array in road_cases:
		var enc_id: String = case[0]
		var stones: int = case[1]
		var stem := "encounter_%s%s_%s" % [enc_id, case[2], size_tag]
		var stage := func() -> void:
			hud.get("_banner").visible = false
			c.realm_index = gs.data.realm_index_of("qi_refining")
			c.stage = 0
			c.inventory.erase("spirit_stone")
			c.add_item("spirit_stone", stones)
			gs.pending_encounter = enc_id
		shots.append({"name": stem, "open": func() -> void:
			stage.call()
			enc.open(), "close": enc.close})
		if case[2] == "":
			shots.append({"name": stem + "_result", "open": func() -> void:
				stage.call()
				gs.choose_encounter(0)
				assert(gs.pending_encounter == "", "road choice did not resolve: " + enc_id)
				print("road result ", enc_id, ": ", root.get_node("/root/EventBus").history[-1]["text"])
				if enc_id == "road_milestone_carver":
					# WU-255: ENC-006's renown note reaches the HUD log in the same result.
					var recent := ""
					for entry: Dictionary in root.get_node("/root/EventBus").history.slice(-4):
						recent += String(entry["text"]) + "\n"
					assert(recent.contains("+5 renown"), "no renown note in the log: " + recent)
				root.get_node("/root/EventBus").player_changed.emit()
				hud.get("_banner").visible = false, "close": func() -> void: pass})

	# WU-276: C-178's two first-hour fighting encounters: the choice window with the attribute-tagged choice
	# (gate met via 12 constitution / comprehension, so the tag is shown), and the HUD log after the training choice.
	for enc_id: String in ["village_boxing_yard", "forest_hunter_wolf_lunge"]:
		var fstage := func() -> void:
			hud.get("_banner").visible = false
			c.realm_index = gs.data.realm_index_of("qi_refining")
			c.stage = 0
			c.attributes["constitution"] = 12
			c.attributes["comprehension"] = 12
			c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
			gs.pending_encounter = enc_id
		var fstem := "encounter_%s_%s" % [enc_id, size_tag]
		shots.append({"name": fstem, "open": func() -> void:
			fstage.call()
			enc.open(), "close": enc.close})
		shots.append({"name": fstem + "_result", "open": func() -> void:
			fstage.call()
			gs.choose_encounter(0)
			assert(gs.pending_encounter == "", "fighting choice did not resolve: " + enc_id)
			var recent := ""
			for entry: Dictionary in root.get_node("/root/EventBus").history.slice(-3):
				recent += String(entry["text"]) + "\n"
			assert(recent.contains("Iron Fist"), "no Iron Fist line in the log: " + recent)
			print("fight result ", enc_id, ": ", recent)
			root.get_node("/root/EventBus").player_changed.emit()
			hud.get("_banner").visible = false, "close": func() -> void: pass})


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
	var lines := LifeStats.year_summary({}, {"tribulations_survived": 1, "respawns": 1, "rival_bouts_won": 2,
			"rival_bouts_lost": 1}, "Foundation Establishment Peak", "Core Formation Early")
	shots.append({"name": "year_banner", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("%s of your journey" % LifeStats.review_title(10, 14), "\n".join(lines), Color(0.9, 0.78, 0.4), 60.0),
		"close": func() -> void: pass})
	# WU-200: the newest lines (realm change, lost inheritance, name spread, rank-up) in the four-line cap.
	var newest := LifeStats.year_summary({}, {"inheritances_lost": 2, "renown_titles": 3, "profession_ranks": 2,
			"items_crafted": 5, "stones_earned": 120}, "Qi Refining Peak", "Foundation Establishment Early")
	shots.append({"name": "year_banner_newest", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("%s of your journey" % LifeStats.review_title(3, 21), "\n".join(newest), Color(0.9, 0.78, 0.4), 60.0),
		"close": func() -> void: pass})
	# WU-213: YEAR-010's rival line appended last (as GameState._on_year_changed does) to the longest real lines.
	var rival := CharacterData.new()
	rival.id = "shot_rival"
	rival.name = "Murong Xuanming of the Iron Hall"
	rival.home_region = gs.current_region
	rival.realm_index = c.realm_index + 3
	rival.alive = true
	gs.npcs[rival.id] = rival
	c.rival = rival.id
	var flags := {Rivals.FIRST_MEETING_FLAG: true, Rivals.BOUTS_WON_FLAG: 12, Rivals.BOUTS_LOST_FLAG: 17}
	var with_rival := LifeStats.year_summary({}, {"tribulations_survived": 1, "respawns": 1, "rival_bouts_won": 2,
			"rival_bouts_lost": 1, "inheritances_lost": 2, "renown_titles": 3, "items_crafted": 5, "stones_earned": 120},
			"Foundation Establishment Peak", "Core Formation Early")
	with_rival.append(Rivals.year_line(c, rival, flags))
	print("year lines with rival: ", with_rival)
	shots.append({"name": "year_banner_rival", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("%s of your journey" % LifeStats.review_title(10, 14), "\n".join(with_rival), Color(0.9, 0.78, 0.4), 60.0),
		"close": func() -> void: pass})
	# WU-234: a filled-and-lapsed orders line (YEAR-011) as the fourth of four long lines.
	var with_orders := LifeStats.year_summary({}, {"items_crafted": 14, "profession_ranks": 2, "profession_stones": 340,
			"commissions_done": 12, "commissions_lapsed": 11, "stones_earned": 120}, "", "")
	print("year lines with orders: ", with_orders)
	shots.append({"name": "year_banner_orders", "open": func() -> void:
		banner.set_held(false)
		banner._queue.clear()
		banner.finish_current()
		banner.announce("%s of your journey" % LifeStats.review_title(10, 14), "\n".join(with_orders), Color(0.9, 0.78, 0.4), 60.0),
		"close": func() -> void: pass})
	# WU-234: PROF-013's longest lapse text (the order's item and the shortfall are the longest real ones), in the message log.
	var best_text := ""
	for rid: String in gs.data.recipes:
		var out: Dictionary = gs.data.recipes[rid]["output"]
		var order := {"item": String(out["item"]), "count": 12, "profession": String(gs.data.recipes[rid].get("profession", ""))}
		c.inventory.clear()
		var text: String = Commissions.lapse_text(c, gs.data, order)
		if text.length() > best_text.length():
			best_text = text
	print("longest lapse text (%d chars): %s" % [best_text.length(), best_text])
	for i in 3:
		root.get_node("EventBus").post(best_text, "info")
	var log_screen: Control = hud.get("_screens")["toggle_message_log"]
	shots.append({"name": "lapse_log", "open": func() -> void:
		banner.visible = false
		log_screen.open(), "close": log_screen.close})


## WU-187: the respawn screen with the longest lesson (98% odds) and the longest enemy name.
func _start_respawn_shot(gs: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	shots.append({"name": "respawn_still_fell", "open": func() -> void:
		hud.get("_banner").visible = false
		gs.pending_respawn = {"cause": "Cut down by a Drunk Bully Disciple in a fight you were sure to win.",
				"anchor_id": "qingshi_village", "lives_left": 1, "qi_lost": 340.0,
				"enemy_name": "Drunk Bully Disciple", "win_chance": 0.98}
		hud.get("_respawn").open(), "close": func() -> void:
		hud.get("_respawn").visible = false})


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
	# WU-198: the epilogue's fame line ("Known as <top title> in <region>"), at the top renown tier.
	var top_tier: Dictionary = (gs.data.renown["tiers"] as Array).back()
	Renown.add(c, gs.data, "myriad_peaks_ridge", int(top_tier["min"]))
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
