extends SceneTree
## First-hour screenshots (WU-077): a FRESH character in Qingshi Village, day 0, no sect,
## for eyeballing what a new player sees at 1280x800 without a display.
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_first_hour.gd
## WU-218: append `-- --crafter` for a new Alchemist's first hour (workshop, hint, gather site, crafting,
## journal Commissions, Deliver) as crafter_*.png.
## WU-487: add `-- --realm-open` (with --region=) to jump to a day the region's secret realm is open; shots are named region_<id>_open.png.
## WU-496: `-- --trophies` hangs three trophies at the Family Home.
## WU-603: `-- --sect-promote` renders sect_promote.png (join azure_cloud_sect, promoted one rank).
## WU-604: `-- --sect-report=<sect_id>` renders sect_report.png (join, report at the home hall: the welcome card).
## WU-602: `-- --sect-join=<sect_id>` renders sect_join.png (the joining card, e.g. azure_cloud_sect).
## WU-495: append `-- --season-end` for the season card (season_card.png).
## WU-494: append `-- --jetty=N` (0..3) for the Village Pond Jetty build stage (like --well=N).
## WU-502: append `-- --terraces=N` (0..3) for the Herb Slope terrace stage.
## WU-482: append `-- --birthday=<npc_id>` to put the clock on that villager's birthday (cake marker over their head).
## WU-553: add `-- --spar=<npc_id>` for spar_<id>.png (a friendly spar with that NPC, favor raised; finished report with the duel stage).
## WU-486: add `-- --emote=love` (or happy, sweat) to --friend for a bubble over the friend.
## WU-542: add `--knows=<tech_id>` to learn that technique first.
## WU-546: add `--first-visit` (with --region=) to show the first-visit arrival banner with the region's teacher lines.
## WU-543: `--friend=<id> --region=<region>` keeps that region and finds the villager there; `--flag=<key>[=<value>]` sets a world flag
##   (true, or the int/string value); `--realm=<index>` sets the player's realm (stage 0).
## WU-537: `--friend=hunter_ma` opens that named villager instead.
## WU-418: append `-- --friend` for friend.png (a villager menu with the heart row).
## WU-414: append `-- --book` for village_book.png.
## WU-430: `-- --great` (with --region=) starts on the region's next great-beast day.
## WU-450: `-- --great --tracks` starts the day before it, so the trail of prints shows.
## GFX-033: append `-- --storm` to render the first-hour shots under a storm.  GFX-051: `-- --rain` forces rain.  GFX-120: `-- --fog` forces fog.
## GFX-212: `-- --walk=<px>` walks the player along the first road before the arrival shot (footprints show).
## GFX-037: append `-- --season=Winter` (Spring/Summer/Autumn/Winter) to start on that season's first day.
## GFX-029: append `-- --field` for field.png (a growing field).
## GFX-023: append `-- --celebration` for celebration.png (wedding lanterns and red sashes).
## WU-223: append `-- --gather-note` for the Village Herb Slope menu in each season: gather_note_<season>.png.
## WU-404: shots open through the HUD's _update_modal, so the dim backdrop and hidden prompt show.
## append `-- --fight=cultivator` for combat_report_cultivator.png (GFX-020); GFX-211: `--fight=<enemy_id>[,<id>...]` renders combat_report_<id>.png per foe.
## GFX-221: `--lend=<npc_id>[,<id>...]` renders lend_<id>.png, the "Helping ..." card with the player beside the villager.
## GFX-213: `--meditate` renders meditate.png, mid time-skip overlay (seated player, qi motes, glow).
## GFX-217: `--skip-dusk` (with --region=a,b) also renders skip_night_<id>.png: the world frozen at night (phase 0.5) behind a time-skip card.
## GFX-110: add `--edge` to stand at the bottom map edge in the multi-region shots.
## QA-187: `--region=a,b,...` renders only the arrival shot of each region as region_<id>.png (one world build per
## region); with one id the normal shot set is rendered in that region and the arrival shot is also named region_<id>.png.
## FOLK-016: append `-- --friend-scene` for friend_scene.png (a friend scene card with a gift line).  GFX-234: `--friend-scene=<npc_id>[,<favor>]` stages that villager's scene (favor default 60), e.g. old_monster_gui.
## QA-187: append `-- --companion` (a Qingshi friend invited along, WU-413): companion.png (the HUD chip) and
## field_menu.png (the rented field's menu with the tool icons).
## WU-452: `-- --road-card [--road-encounter]` renders road_card.png (and road_encounter.png).
## GFX-065: append `-- --arrival-card` for arrival_card.png, right after a new game starts, the card still up.
## GFX-081: `-- --shrine=N` sets the old shrine's stage (0..4).
## QA-198: `-- --festival` (festival_qingshi), `--contest` (contest_card), `--practice` (practice_menu), `--regular` (shop_regular), `--journal` (journal_today); one flag per run.
## WU-565: `-- --shop-manual` opens the shop selling the first fighting-style manual (shop_manual.png).
## QA-200: `-- --calendar-month=N` (calendar_month_N, month N of year 1).
## QA-215: `--focus=<id>` centres the camera on the villager whose npc_id is <id>, or the place whose display name slug is <id>
##   ("Reed Mat Scroll Seller" -> reed_mat_scroll_seller) for the arrival shot (hud_arrival / the region shot).
## WU-582: `--explore=<place slug>[,<slug>...]|all` (GFX-222: all = every explore place of the --region) opens that explore place's menu (explore_<slug>.png; use --region= for its region).
## WU-558: `--dialogue=<id>[,<id>...]` opens a story-event dialogue (dialogue_<id>.png), e.g. rival_first_meeting.
## WU-550: `--threat=<enemy_id>[,<id>...]` stages the sensed-foe prompt (threat_<id>.png; `--realm=<index>` sets the realm first);
##   `--encounter=<id>[,<id>...]` opens that encounter card (encounter_<id>.png) on the first day of its season (its `seasons`),
##   honouring its `scene`; `--encounter=seasons` renders the eight C-376 season encounters.
## PNGs go to user://screenshots/first_hour/<name>.png. Never writes saves.
## (The mid-game sibling is screenshot_screens.gd.)

const OUT_DIR := "user://screenshots/first_hour"
const SETTLE_FRAMES := 6
const BANNER_WAIT_MSEC := 3000

var world: Node = null
var hud: CanvasLayer = null
var shots: Array[Dictionary] = []  # {name, open: Callable, close: Callable}
var index := 0
var frames := 0
var banner_wait_start := -1
var started := false
var region_list: Array[String] = []  ## QA-187: --region= ids
var opened := false


## GFX-065: drop the Qingshi arrival line start_session posted, so a --region shot shows one line for its day.
func _drop_start_line() -> void:
	root.get_node("EventBus").clear_history()


func _start() -> void:
	root.get_node("Settings").set("persist", false)  # QA-232: a shot run never touches user://settings.cfg
	started = true
	var gs: Node = root.get_node("GameState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	for arg in OS.get_cmdline_user_args():  # GFX-037: start on a season's first day
		if arg.begins_with("--season="):
			var idx := ["Spring", "Summer", "Autumn", "Winter"].find(arg.substr(9).capitalize())
			if idx >= 0:
				var clock: Node = root.get_node("GameClock")
				clock.total_days = idx * 3 * Calendar.DAYS_PER_MONTH
	for arg in OS.get_cmdline_user_args():  # GFX-041: start in a region (--region=misty_forest)
		if arg.begins_with("--region="):
			for id in arg.substr(9).split(",", false):
				if gs.data.regions.has(id):
					region_list.append(id)
				else:
					push_warning("--region: unknown region %s" % id)
	for arg in OS.get_cmdline_user_args():  # WU-583: --favor=<n> gives every villager that favor (pips, markers)
		if arg.begins_with("--favor="):
			var spec := arg.substr(8)
			if spec.contains("="):  # WU-594: --favor=<npc_id>=<n> sets one villager
				gs.npc_favor[spec.get_slice("=", 0)] = int(spec.get_slice("=", 1))
			else:
				for nid in gs.data.npcs:
					gs.npc_favor[String(nid)] = int(spec)
	if not region_list.is_empty():
		gs.current_region = region_list[0]
	for arg in OS.get_cmdline_user_args():  # GFX-081: --shrine=N sets the old shrine's restoration stage (0..4)
		if arg.begins_with("--shrine="):
			gs.player.seasons_completed.clear()
			for i in clampi(int(arg.substr(9)), 0, 4):
				gs.player.seasons_completed.append("shot_%d" % i)
	for arg in OS.get_cmdline_user_args():  # GFX-087: --jetty=N (WU-494), --well=N sets the Founder's Old Well stage (0..3)
		if arg.begins_with("--well="):
			gs.player.seasons_completed.clear()
			var idx := SeasonTasks.project_index(gs.data, "well")
			var before := 0
			for i in idx:
				before += (SeasonTasks.project_list(gs.data)[i].get("stages", []) as Array).size()
			for i in before + clampi(int(arg.substr(7)), 0, 3):
				gs.player.seasons_completed.append("shot_%d" % i)
	for arg in OS.get_cmdline_user_args():  # WU-494: --jetty=N sets the Village Pond Jetty stage (0..3); it follows the well in the order
		if arg.begins_with("--jetty="):
			gs.player.seasons_completed.clear()
			var jidx := SeasonTasks.project_index(gs.data, "jetty")
			var jbefore := 0
			for i in jidx:
				jbefore += (SeasonTasks.project_list(gs.data)[i].get("stages", []) as Array).size()
			for i in jbefore + clampi(int(arg.substr(8)), 0, 3):
				gs.player.seasons_completed.append("shot_%d" % i)
	for arg in OS.get_cmdline_user_args():  # WU-502: --terraces=N sets the Herb Slope terrace stage (0..3); it follows the jetty
		if arg.begins_with("--terraces="):
			gs.player.seasons_completed.clear()
			var tidx := SeasonTasks.project_index(gs.data, "terraces")
			var tbefore := 0
			for i in tidx:
				tbefore += (SeasonTasks.project_list(gs.data)[i].get("stages", []) as Array).size()
			for i in tbefore + clampi(int(arg.substr(11)), 0, 3):
				gs.player.seasons_completed.append("shot_%d" % i)
	for arg in OS.get_cmdline_user_args():  # WU-482: --birthday=<npc_id> moves the clock to that villager's birthday (favor 40)
		if arg.begins_with("--birthday="):
			var bid := arg.substr(11)
			if gs.npcs.has(bid):
				var clock_b: Node = root.get_node("GameClock")
				var bday: int = Folk.birthday_day(gs.npcs[bid], gs.data)
				clock_b.total_days = (clock_b.total_days / Calendar.DAYS_PER_YEAR) * Calendar.DAYS_PER_YEAR + bday
				gs.npc_favor[bid] = 40
	if OS.get_cmdline_user_args().has("--trophies"):  # WU-496: three trophies hung at the Family Home
		gs.player.hung_trophies.clear()
		for id: String in ["old_tuskers_broken_tusk", "cloud_cranes_crown_plume", "tuskers_sow_bristle"]:
			gs.player.hung_trophies.append(id)
		var home_abodes: Array[String] = Abodes.in_region(gs.data, gs.current_region)
		if not home_abodes.is_empty():  # the abode is the home the plaques hang on (use --region=misty_forest)
			gs.player.abode = home_abodes[0]
	if OS.get_cmdline_user_args().has("--incense"):  # GFX-084: the incense burns today
		gs.world_flags["shrine_incense"] = {"until": gs.get_node("/root/GameClock").total_days + 1}
	if OS.get_cmdline_user_args().has("--great") or OS.get_cmdline_user_args().has("--tracks"):  # WU-430: jump to the region's next great-beast day
		var clock: Node = root.get_node("GameClock")
		var walk: int = Wildlife.next_great_day(gs.data, gs.current_region, clock.total_days, gs.player.realm_index)
		if walk >= 0:
			clock.total_days = walk - (1 if OS.get_cmdline_user_args().has("--tracks") else 0)  # WU-450: --tracks = the day before
	if OS.get_cmdline_user_args().has("--realm-open") and region_list.size() <= 1:  # WU-487: a day a realm here is open
		var clock_r: Node = root.get_node("GameClock")
		var open_day: int = SecretRealms.next_open_day_in_region(gs.data, gs.current_region, clock_r.total_days)
		if open_day >= 0:
			clock_r.total_days = open_day
	_festival_clock(gs)  # QA-198: --festival/--contest/--practice/--regular/--journal pick the day before the world is built
	if not region_list.is_empty():
		_drop_start_line()
		gs.call("_post_arrival_line")  # GUIDE-210: the region's own arrival line, once, after the day is final
	gs.pending_event = ""
	if OS.get_cmdline_user_args().has("--arrival-card"):
		gs.arrival_banner_pending = true  # GFX-065: as a new game from the title screen sets it
	var party := OS.get_cmdline_user_args().has("--celebration")
	if party:  # GFX-023: a wedding for a Qingshi villager, before the world is built
		var bride := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 24, "region": "qingshi_village", "realm": "mortal", "gender": "female"})
		Folk.start_celebration(gs.world_flags, [bride.id], gs.get_node("/root/GameClock").total_days, gs.data, Folk.WEDDING)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	if OS.get_cmdline_user_args().has("--storm"):  # GFX-033: force today's weather to storm
		world.call("force_weather", "storm")
	if OS.get_cmdline_user_args().has("--rain"):  # GFX-051: force today's weather to rain
		world.call("force_weather", "rain")
	if OS.get_cmdline_user_args().has("--fog"):  # GFX-120: force today's weather to fog
		world.call("force_weather", "fog")
	if OS.get_cmdline_user_args().has("--crafter"):
		_crafter_shots(gs, c)
		return
	if OS.get_cmdline_user_args().has("--gather-note"):
		_gather_note_shots(gs)
		return
	var special := false
	if OS.get_cmdline_user_args().has("--arrival-card"):  # GFX-065: the new-game region card, before it fades
		shots.append({"name": "arrival_card", "open": func() -> void: pass, "close": func() -> void: pass})
		return
	var threat_ids: Array[String] = []  # WU-550
	var enc_ids: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--realm="):
			gs.player.realm_index = int(a.substr(8))
			gs.player.stage = 0
		if a.begins_with("--threat="):
			for id in a.substr(9).split(",", false):
				threat_ids.append(id)
		if a.begins_with("--encounter="):
			for id in a.substr(12).split(",", false):
				if id == "seasons":
					enc_ids.append_array(["village_spring_kite_day", "road_spring_swollen_ford", "village_summer_firefly_night", "village_summer_hailstorm", "village_autumn_persimmon_harvest", "wild_autumn_migrating_geese", "forest_winter_frozen_pond", "road_winter_snowbound_traveller"])
				else:
					enc_ids.append(id)
	for a in OS.get_cmdline_user_args():  # WU-558: `--dialogue=<id>[,<id>...]` opens an event dialogue (dialogue_<id>.png)
		if a.begins_with("--dialogue="):
			for id in a.substr(11).split(",", false):
				if not gs.data.dialogues.has(id):
					push_warning("--dialogue: unknown dialogue %s" % id)
					continue
				shots.append({"name": "dialogue_" + id, "open": func() -> void:
					hud.get("_banner").visible = false
					if gs.player.rival == "" and not gs.npcs.is_empty():
						gs.player.rival = String(gs.npcs.keys()[0])
					gs.world_flags.erase("rival_meeting_from")
					gs.start_event(id), "close": func() -> void: gs.end_dialogue()})
	for id in threat_ids:
		if not gs.data.enemies.has(id):
			push_warning("--threat: unknown enemy %s" % id)
			continue
		shots.append({"name": "threat_" + id, "open": func() -> void:
			hud.get("_banner").visible = false
			gs.pending_threat = id
			hud.call("_on_threat_sensed", id)
			var menu_buttons: Node = hud.get("_choice_menu").get("_buttons")  # focus "Fight it" so its Why: line shows
			if menu_buttons.get_child_count() > 1:
				menu_buttons.get_child(1).call_deferred("grab_focus"), "close": func() -> void:
				gs.pending_threat = ""
				hud.get("_choice_menu").close()})
	for a in OS.get_cmdline_user_args():  # WU-582
		if a.begins_with("--explore="):
			var slugs: PackedStringArray = a.substr(10).split(",", false)
			if slugs.has("all"):  # GFX-222: every explore place in the loaded region
				slugs = _explore_slugs()
			for slug in slugs:
				var site := _find_explore_by_slug(slug)
				if site == null:
					push_warning("--explore: no explore place %s" % slug)
					continue
				shots.append({"name": "explore_" + slug, "open": func() -> void:
					hud.get("_banner").visible = false
					hud.get("_choice_menu").open_for(site), "close": hud.get("_choice_menu").close})
	for id in enc_ids:
		if not gs.data.encounters.has(id):
			push_warning("--encounter: unknown encounter %s" % id)
			continue
		shots.append({"name": "encounter_" + id, "open": func() -> void:
			hud.get("_banner").visible = false
			var seasons: Array = gs.data.encounters[id].get("seasons", [])
			if not seasons.is_empty():
				var sidx := ["spring", "summer", "autumn", "winter"].find(String(seasons[0]))
				root.get_node("GameClock").total_days = maxi(sidx, 0) * 3 * Calendar.DAYS_PER_MONTH
			gs.pending_encounter = id
			gs.pending_cast = Folk.pick(gs.data.encounters[id], gs.npcs, gs.data, gs.player, gs.current_region, gs.npc_favor, gs.rng)  # fills {villager}
			hud.call("_on_encounter_choice_requested", id), "close": hud.get("_encounter").close})
	if not threat_ids.is_empty() or not enc_ids.is_empty():
		return
	if OS.get_cmdline_user_args().has("--road-card"):  # WU-452: the road card mid-fill; with --road-encounter, then the encounter after it
		var card_script: GDScript = load("res://src/ui/road_card.gd")  # loaded late: it needs the autoloads
		shots.append({"name": "road_card", "open": func() -> void:
			var card: Node = card_script.show_over(self, card_script.text_for("Qingshi Village", "Misty Forest", 3, 0), false, card_script.detail_for("Lost Child"))
			card.set("_elapsed", 1.2)  # QA-197: dots filled, fade-out (1.5 s) not begun
			card.call("_apply", 1.2), "close": func() -> void: pass})
		if OS.get_cmdline_user_args().has("--road-encounter"):
			shots.append({"name": "road_encounter", "open": func() -> void:
				if is_instance_valid(card_script.current):
					card_script.current.queue_free()
					card_script.current = null
				gs.pending_encounter = "road_lost_child"
				gs.last_travel_road_encounter = "road_lost_child"
				hud.call("_on_encounter_choice_requested", "road_lost_child"), "close": func() -> void: pass})
		return
	if region_list.size() == 1 and OS.get_cmdline_user_args().has("--skip-dusk"):  # QA-238: works with one --region too
		shots.append(_skip_night_shot(gs, region_list[0]))
		special = true
	if region_list.size() > 1:  # QA-187: one arrival shot per region, rebuilding the world between them
		for id in region_list:
			shots.append({"name": "region_" + id + ("_open" if OS.get_cmdline_user_args().has("--realm-open") else ""), "open": func() -> void:
				if OS.get_cmdline_user_args().has("--realm-open"):  # WU-487
					var od: int = SecretRealms.next_open_day_in_region(gs.data, id, gs.get_node("/root/GameClock").total_days)
					if od >= 0:
						gs.get_node("/root/GameClock").total_days = od
				_rebuild_world(gs, id)
				if OS.get_cmdline_user_args().has("--edge-goal"):  # WU-569: bottom-left, so the goal person is off screen
					_teleport_player(Vector2(40.0, world.map_size.y - 20.0))
				if OS.get_cmdline_user_args().has("--edge"):  # GFX-110: stand at the bottom path end
					_teleport_player(Vector2(float(world.map_size.x) - 40.0 if gs.data.regions[id]["map"]["paths"].size() < 2 else 800.0, world.map_size.y - 20.0))
				root.get_node("EventBus").clear_history()
				_first_visit_card(gs, id), "close": func() -> void: pass})  # QA-203: no previous region's log lines
			if OS.get_cmdline_user_args().has("--skip-dusk"):  # GFX-217
				shots.append(_skip_night_shot(gs, id))
			if OS.get_cmdline_user_args().has("--great"):  # GFX-060: and a close-up of the great roamer
				shots.append({"name": "great_" + id, "open": func() -> void: _great_closeup(id), "close": func() -> void: pass})
		return
	if OS.get_cmdline_user_args().has("--companion"):  # QA-187: the invited friend's chip and the field menu with tool icons
		_companion_shots(gs, c)
		special = true
	if _has_festival_flag():  # QA-198
		_festival_shots(gs)
		special = true
	if OS.get_cmdline_user_args().has("--critters"):  # GFX-088: stand beside the west farmhouse hens, wait 0.5 s
		shots.append({"name": "critters_hens", "open": func() -> void:
			hud.get("_banner").visible = false
			_teleport_player(Vector2(180, 424)), "close": func() -> void: pass, "settle": 40})
		special = true
	if OS.get_cmdline_user_args().has("--field"):  # GFX-029: a rented field with a young and a nearly ripe crop
		_field_shots(gs, c)
		special = true
	if OS.get_cmdline_user_args().has("--quarrel"):  # QA-182: a FOLK-004 quarrel between two villagers
		_quarrel_shots(gs, c)
		special = true
	var friend_arg := false
	for a in OS.get_cmdline_user_args():
		if a == "--friend" or a.begins_with("--friend="):  # WU-537: --friend=<npc_id> opens that named villager's menu
			friend_arg = true
	for a in OS.get_cmdline_user_args():  # GFX-221: --lend=<npc_id>[,<id>...] shoots the "Helping" card mid-way
		if a.begins_with("--lend="):
			for id in a.substr(7).split(",", false):
				_lend_shots(gs, id)
			special = true
	for a in OS.get_cmdline_user_args():  # GFX-226: --tea=<npc_id>[,<id>...] shoots the "Tea with" card (favor 45 first)
		if a.begins_with("--tea="):
			for id in a.substr(6).split(",", false):
				_tea_shots(gs, id)
			special = true
	for a in OS.get_cmdline_user_args():  # WU-599: --tend=<npc_id> shoots the "tends your wounds" card (favor 90, injured)
		if a.begins_with("--tend="):
			for id in a.substr(7).split(",", false):
				_tend_shots(gs, id)
			special = true
	for a in OS.get_cmdline_user_args():  # WU-600: --drop-by=<npc_id> shoots the "From <Name>" gift card (favor 70, cooldown cleared)
		if a.begins_with("--drop-by="):
			for id in a.substr(10).split(",", false):
				_drop_by_shots(gs, id)
			special = true
	for a in OS.get_cmdline_user_args():  # GFX-225: --tier-up=<npc_id> shoots the hearts after a lend crosses a tier
		if a.begins_with("--tier-up="):
			for id in a.substr(10).split(",", false):  # WU-589: a comma list, like --lend/--tea
				_tier_up_shots(gs, id, false)
			special = true
		elif a.begins_with("--tier-up-far="):  # GFX-233: the friend 700 px away (off screen): the banner icon pulses instead of hearts
			for id in a.substr(14).split(",", false):
				_tier_up_shots(gs, id, true)
			special = true
	for a in OS.get_cmdline_user_args():  # GFX-235: --sworn=<npc_id> shoots the Sworn-friend oath at its bow
		if a.begins_with("--sworn="):
			for id in a.substr(8).split(",", false):
				_sworn_shots(gs, id)
			special = true
	for a in OS.get_cmdline_user_args():  # WU-553: --spar=<npc_id> shoots a friendly spar with that NPC
		if a.begins_with("--spar="):
			_spar_shots(gs, a.substr(7))
	if friend_arg:  # WU-418: a Qingshi villager at favor 65 and their menu
		_friend_shots(gs)
		special = true
	var fs_npc := ""  # FOLK-016 / GFX-234: --friend-scene[=<npc_id>[,<favor>]] (default xiao_ling at 45)
	var fs_favor := 45
	for a in OS.get_cmdline_user_args():
		if a == "--friend-scene":
			fs_npc = "xiao_ling"
		elif a.begins_with("--friend-scene="):
			var fs_parts := a.substr(15).split(",")
			fs_npc = fs_parts[0]
			fs_favor = int(fs_parts[1]) if fs_parts.size() > 1 else 60
	if fs_npc != "":  # the villager's scene card with its gift line, in their own region
		shots.append({"name": "friend_scene", "open": func() -> void:
			hud.get("_banner").visible = false
			var fs_cd: CharacterData = gs.npcs[fs_npc]
			gs.current_region = String(gs.data.npcs[fs_npc].get("region", "qingshi_village")) if gs.data.npcs.has(fs_npc) else "qingshi_village"
			gs.npc_favor[fs_npc] = fs_favor
			c.scene_day = -1
			var gclock: Node = gs.get_node("/root/GameClock")  # autoloads are not compile-time names in a -s script
			var fs_scene := {}
			for _i in 40:  # FOLK-021: advance to a day the scene's weather allows
				fs_scene = Folk.scene_due(c, gs.data, fs_npc, fs_favor, fs_cd, gs.current_region, Weather.of(gs.data, gs.current_region, gclock.total_days))
				if not fs_scene.is_empty():
					break
				gclock.total_days += 1
			gs._friend_scene(fs_npc), "close": func() -> void: hud.get("_friend_card").close()})
		special = true
	if OS.get_cmdline_user_args().has("--cast"):  # QA-182: the CastBar on the jetty, marker frozen mid-sweep
		_cast_shots(gs)
		special = true
	if OS.get_cmdline_user_args().has("--hud-panel"):  # WU-471: the Next-steps panel, cropped at 2x
		shots.append({"name": "hud_panel", "open": func() -> void: hud.get("_banner").visible = false, "close": func() -> void: pass, "crop": true})
		special = true
	if OS.get_cmdline_user_args().has("--season-end"):  # WU-495: the season card across a season boundary
		var scard: Control = hud.get("_season_card")
		shots.append({"name": "season_card", "open": func() -> void:
			hud.get("_banner").visible = false
			Engine.get_main_loop().root.get_node("EventBus").season_reviewed.emit("Autumn", 1, PackedStringArray(["You won 3 fights.", "Your cultivation advanced a stage.", "You gathered 12 herbs."]))
			Engine.get_main_loop().root.get_node("EventBus").season_began.emit("Winter", 1, PackedStringArray(["Winter tasks are up at the village board.", "The Lantern Festival is coming."]))
			hud.call("_flush_year_review"), "close": scard.close})
		special = true
	for a in OS.get_cmdline_user_args():  # WU-602: the sect joining card
		if a.begins_with("--sect-join="):
			var jid := a.substr(12)
			var jcard: Control = hud.get("_sect_card")
			shots.append({"name": "sect_join", "open": func() -> void:
				hud.get("_banner").visible = false
				c.alignment = 0
				c.realm_index = maxi(c.realm_index, 1)
				gs.join_sect(jid), "close": jcard.close})
			special = true
	for a in OS.get_cmdline_user_args():  # WU-604: join, report at the home hall, capture the welcome card
		if a.begins_with("--sect-report="):
			var rid := a.substr(14)
			var rcard: Control = hud.get("_sect_card")
			shots.append({"name": "sect_report", "open": func() -> void:
				hud.get("_banner").visible = false
				c.alignment = 0
				c.realm_index = maxi(c.realm_index, 1)
				gs.join_sect(rid)
				hud.call("_drain_moments")
				rcard.close()
				gs.current_region = Sects.home_region(gs.data, rid)
				gs.report_to_sect()
				hud.call("_drain_moments"), "close": rcard.close})
			special = true
	if OS.get_cmdline_user_args().has("--sect-promote"):  # WU-603: join azure_cloud_sect, then promote one rank
		var pcard: Control = hud.get("_sect_card")
		shots.append({"name": "sect_promote", "open": func() -> void:
			hud.get("_banner").visible = false
			c.alignment = 0
			c.realm_index = maxi(c.realm_index, 1)
			gs.join_sect("azure_cloud_sect")
			(hud.get("_pending_moments") as Array).clear()  # skip the queued join card (WU-604)
			pcard.close()
			Sects.add_contribution(c, gs.data, 100000)
			gs.call("_post_promotion"), "close": pcard.close})
		special = true
	if OS.get_cmdline_user_args().has("--season-board"):  # WU-466: the village board's season task card
		var sboard: Control = hud.get("_season_board")
		shots.append({"name": "season_board", "open": func() -> void:
			hud.get("_banner").visible = false
			sboard.open(), "close": sboard.close})
		special = true
	if OS.get_cmdline_user_args().has("--calendar"):  # WU-419: the month calendar, a festival-free market month
		var cal: Control = hud.get("_screens")["open_calendar"]
		shots.append({"name": "calendar", "open": func() -> void:
			hud.get("_banner").visible = false
			cal.open(), "close": cal.close})
		special = true
	for a in OS.get_cmdline_user_args():  # QA-200: the calendar paged to month N (see _festival_clock)
		if a.begins_with("--calendar-month="):
			var month_cal: Control = hud.get("_screens")["open_calendar"]
			shots.append({"name": "calendar_month_" + a.substr(17), "open": func() -> void:
				hud.get("_banner").visible = false
				month_cal.open(), "close": month_cal.close})
			special = true
	if OS.get_cmdline_user_args().has("--digest"):  # WU-416: the "While you were away" card
		shots.append({"name": "digest_card", "open": func() -> void:
			hud.get("_banner").visible = false
			gs.last_digest = {"days": 15, "lines": ["Your spirit field is ready to harvest.", "Xiao Ling drops by to visit.", "A storm passes over the village.", "You are close to a breakthrough."]}
			hud.call("_poll_digest"), "close": func() -> void: hud.get("_digest_card").dismiss()})
		special = true
	if OS.get_cmdline_user_args().has("--book"):  # WU-414: the village book with two fish caught
		Fishing.record_catch(gs.player, "silver_carp", 3)
		Fishing.record_catch(gs.player, "marsh_eel", 1)
		var book: Control = hud.get("_village_book")
		shots.append({"name": "village_book", "open": func() -> void:
			hud.get("_banner").visible = false
			book.open()
			book.get("_detail").text = book.call("hint_for", "mist_koi", gs.data, gs.player), "close": book.close})
		shots.append({"name": "village_book_festivals", "open": func() -> void:
			hud.get("_banner").visible = false
			book.open()
			book.call("set_page", "festivals"), "close": book.close})
		var herbs := HerbLore.findable(gs.data)
		HerbLore.record_find(gs.player, herbs[0], 4)
		HerbLore.record_find(gs.player, herbs[1], 1)
		shots.append({"name": "village_book_herbs", "open": func() -> void:
			hud.get("_banner").visible = false
			book.open()
			book.call("set_page", "herbs")
			book.get("_detail").text = book.call("hint_for", herbs[2], gs.data, gs.player), "close": book.close})
		shots.append({"name": "village_book_hunts", "open": func() -> void:  # WU-437: the trophy shelf, one trophy won
			hud.get("_banner").visible = false
			Wildlife.record_hunt(c, "wild_boar")
			Wildlife.record_great(c, gs.data, "old_tusker_boar", "misty_forest", 11)
			book.open()
			book.call("set_page", "hunts"), "close": book.close})
		var host_region: String = gs.current_region
		shots.append({"name": "village_book_people", "open": func() -> void:
			hud.get("_banner").visible = false
			var shown := 0
			for npc: CharacterData in Npcs.in_region(gs.npcs, gs.data, host_region):
				gs.npc_favor[npc.id] = 30 + shown * 25
				shown += 1
				if shown >= 3:
					break
			var first: CharacterData = Npcs.in_region(gs.npcs, gs.data, host_region)[0]
			gs.world_flags["taste_%s_%s" % [first.id, "silver_carp"]] = 1
			book.open()
			book.call("set_page", "people"), "close": book.close})
		special = true
	if party:
		special = true
		shots.append({"name": "celebration", "open": func() -> void:
			hud.get("_banner").visible = false
			for node in world.get_children():
				if node.get_script() != null and String(node.get_script().resource_path).ends_with("celebration_lanterns.gd"):
					world.get_node("Player").position = node.position + Vector2(0, 50), "close": func() -> void: pass})
	if special:
		return
	shots.append({"name": "hud_arrival", "open": func() -> void:
		_walk_along()
		_focus_on(), "close": func() -> void: pass})
	if region_list.size() == 1:
		shots.append({"name": "region_" + region_list[0] + ("_open" if OS.get_cmdline_user_args().has("--realm-open") else ""), "open": func() -> void:
			_first_visit_card(gs, region_list[0])
			_focus_on(), "close": func() -> void: pass})
	# WU-406: a generated villager's greeting bubble, and one with the gold "!" for a folk request.
	var villager := _generated_villager()
	if villager != null:
		shots.append({"name": "greeting_bubble", "open": func() -> void:
			# A stranger at favor 0 says nothing, so warm every villager up to speak.
			for id: String in gs.npcs:
				gs.npc_favor[id] = int(gs.data.family["folk_greetings"]["warm"]["min_favor"])
			_teleport_player(villager.position + Vector2(40, 30))
			world.set("_greeted", {})
			world.call("_check_greetings"), "close": func() -> void: _clear_bubble()})
		shots.append({"name": "folk_asker", "open": func() -> void:
			c.letter_requests.append({"npc_id": villager.npc_id, "item": "spirit_herb", "count": 3, "until": root.get_node("GameClock").total_days + 20, "favor": 5, "effects": {}, "source": "folk", "text": ""})
			villager.call("refresh_request")
			_teleport_player(villager.position + Vector2(40, 30))
			world.set("_greeted", {})
			world.call("_check_greetings"), "close": func() -> void:
			_clear_bubble()
			c.letter_requests.clear()
			villager.call("refresh_request")})
	# WU-411: a visiting friend with the tea tray beside them.
	if villager != null:
		var visitor_ref: WeakRef = weakref(villager)  # a freed lambda capture errors on call; a WeakRef does not
		shots.append({"name": "visitor", "open": func() -> void:
			villager.set("_visiting", true)
			villager.queue_redraw()
			_teleport_player(villager.position + Vector2(60, 40)), "close": func() -> void:
			var who: Node = visitor_ref.get_ref()  # QA-198: the world may have rebuilt (and freed them) by now
			if who != null:
				who.set("_visiting", false)
				who.queue_redraw()})
	# WU-385: the HUD of a brand-new sect member (Azure Cloud Outer Disciple, Qi Refining 1, Qingshi Village).
	var sect_saved: Array = []
	# QA-198: join_sect here moves the player to Qingshi without rebuilding the world, so a --region run
	# (world = another region) made freed lambda captures fire; this shot is only for the default Qingshi start.
	if region_list.is_empty():
		shots.append({"name": "hud_after_sect", "open": func() -> void:
			sect_saved.append_array([c.sect.duplicate(), c.realm_index, c.stage, c.qi])
			c.realm_index = gs.data.realm_index_of("qi_refining")
			c.stage = 0
			c.qi = 0.0
			gs.current_region = "qingshi_village"
			gs.join_sect("azure_cloud_sect")
			assert(c.sect.get("id", "") == "azure_cloud_sect", "join_sect did not make the player a member")
			hud.get("_banner").visible = false
			if gs.in_dialogue():  # WU-558: the rival's first meeting must not cover the HUD
				gs.end_dialogue()
			hud.get("_dialogue").close()
			root.get_node("EventBus").player_changed.emit(), "close": func() -> void:
				c.sect = sect_saved[0]
				c.realm_index = sect_saved[1]
				c.stage = sect_saved[2]
				c.qi = sect_saved[3]
				sect_saved.clear()
				root.get_node("EventBus").player_changed.emit()})
	shots.append({"name": "elder_mo_dialogue", "open": func() -> void:
		for node in world.get_children():  # WU-408: the HUD remembers whose menu was opened, for the portrait
			if node.has_method("portrait_texture") and node.get("npc_id") == "elder_mo":
				root.get_node("EventBus").interaction_menu_requested.emit(node)
		gs.start_dialogue("elder_mo"), "close": func() -> void: gs.end_dialogue()})
	var explore_site := _find_explore()
	if explore_site != null:
		var menu: Control = hud.get("_choice_menu")
		shots.append({"name": "explore_menu", "open": func() -> void: menu.open_for(explore_site), "close": menu.close})
	for enc_id: String in gs.data.encounters:
		if gs.data.encounters[enc_id].has("choices"):
			shots.append({"name": "encounter", "open": func() -> void:
				gs.pending_encounter = enc_id
				hud.get("_encounter").open(), "close": hud.get("_encounter").close})
			break
	# WU-404: the Wandering Merchant's list with its GFX-019 icons.
	var merchant := _find_script("merchant.gd")
	if merchant != null:
		var shop_menu: Control = hud.get("_choice_menu")
		shots.append({"name": "shop_menu", "open": func() -> void: shop_menu.open_for(merchant), "close": shop_menu.close})
	# QA-182: the ShopScreen itself (the merchant's menu above only lists its entries).
	var shop: Control = hud.get("_shop")
	shots.append({"name": "shop", "open": func() -> void:
		hud.get("_banner").visible = false
		root.get_node("EventBus").shop_requested.emit("Wandering Merchant", 0, [], "", []), "close": shop.close})
	if OS.get_cmdline_user_args().has("--meditate"):  # GFX-213
		var skip: Control = hud.get("_time_skip")
		shots.append({"name": "meditate", "open": func() -> void:
			hud.get("_banner").visible = false
			gs.player.qi = 0.0
			gs.cultivate(30, 1.0)
			if not skip.visible:
				hud.call("_show_time_skip", {"title": "Meditating", "days": 30, "lines": ["+0 qi"]}),
			"settle": 30, "close": skip.close})
	var report: Control = hud.get("_combat_report")
	# A real fight through GameState.fight (WU-181): the boar is rated and resolved
	# like in play; seed 11 is a newcomer win. The HUD opens the report itself.
	for foe: String in _fight_foes():  # GFX-211: --fight=<id>[,<id>...] renders one won fight per foe
		shots.append({"name": "combat_report" + ("" if foe == "wild_boar" else "_" + ("cultivator" if foe == "rogue_cultivator" else foe)), "open": func() -> void:
			gs.rng.seed = 11
			gs.player.injuries.clear()  # GFX-211: a lost fight must not wound the next foe's shot
			gs.fight(foe)
			if OS.get_cmdline_user_args().has("--blows"):  # WU-473: capture mid-playback with the numbers up
				for _i in 4:
					report.tick()
				return
			report.skip(),  # WU-262: close() refuses while the playback runs, so the report covered later shots
			"close": report.close})
	for action: String in ["toggle_journal", "toggle_inventory", "toggle_character_sheet"]:
		if hud.get("_screens").has(action):
			var s: Control = hud.get("_screens")[action]
			shots.append({"name": action.trim_prefix("toggle_"), "open": s.open, "close": s.close, "wait_banner": true})
	if OS.get_cmdline_user_args().has("--great"):  # GFX-060; QA-197: last, since it may rebuild the world and free the HUD the shots above captured
		var rid: String = gs.current_region
		shots.append({"name": "great_" + rid, "open": func() -> void: _great_closeup(rid), "close": func() -> void: pass})


## The generated (non-data) villager of the world standing nearest the player's start, so the shot
## frames them clear of the HUD cards (WU-411); null when none spawned.
func _generated_villager() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var start: Vector2 = world.get_node("Player").position
	for node in world.get_children():
		if node.has_method("get_options") and node.get("npc_id") != null and not root.get_node("GameState").data.npcs.has(node.npc_id):
			var d := start.distance_to(node.position)
			if d >= 100.0 and d < best_dist:
				best_dist = d
				best = node
	return best


## Moves the player and snaps the smoothed camera there, so the shot frames the spot at once (WU-411).
## WU-478: the first spot (scanning outward from `want`) at least 40 px from every villager.
func _free_spot_near(want: Vector2) -> Vector2:
	var figures: Array[Vector2] = []
	for node in world.find_children("*", "Interactable", true, false):
		figures.append((node as Node2D).position)
	for r in [0.0, 40.0, 80.0, 120.0]:
		for k in 8:
			var p: Vector2 = want + Vector2.from_angle(TAU * k / 8.0) * r
			if figures.all(func(f: Vector2) -> bool: return f.distance_to(p) >= 40.0):
				return p
	return want


## QA-215: `--focus=<id>`: the player (and camera) moves beside the matching villager or place; prints a note when none matches.
func _focus_on() -> void:
	var want := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			want = arg.substr(8)
	if want == "":
		return
	for node in world.find_children("*", "Interactable", true, false):
		var slug := str((node as Node).get("display_name")).to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
		if str(node.get("npc_id")) == want or slug == want:
			_teleport_player((node as Node2D).position + Vector2(0, 90))
			return
	print("focus: nothing named %s here" % want)


## GFX-212: `--walk=<px>` walks the player that far along the road (feeding the footprint layer) before the arrival shot.
func _walk_along() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--walk="):
			continue
		var player: Node2D = world.get_node("Player")
		var fp: Footprints = world.get("_footprints")
		var dist := float(a.substr(7))
		var start: Vector2 = player.position
		var paths: Array = gs_paths()
		if not paths.is_empty():
			var r: Array = paths[0]
			start = Vector2(float(r[0]) + 20.0, float(r[1]) + float(r[3]) * 0.5 - 14.0)
		var x := 0.0
		while x < dist:
			player.position = start + Vector2(x, 0)
			fp.track(player.position)
			x += 4.0
		_teleport_player(player.position)


func gs_paths() -> Array:
	return world.get("_region").get("map", {}).get("paths", [])


func _teleport_player(pos: Vector2) -> void:
	var player: Node2D = world.get_node("Player")
	player.position = pos
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()


func _clear_bubble() -> void:
	var bubble: Variant = world.get("_greet_bubble")
	if bubble != null and is_instance_valid(bubble):
		(bubble as Node).queue_free()
	world.set("_greet_bubble", null)


## `--fight=cultivator|<enemy_id>` picks the combat_report foe (default: the boar); GFX-196: any enemy id, e.g. mist_wolf.
func _fight_foes() -> Array[String]:
	var out: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg == "--fight=cultivator":
			out.append("rogue_cultivator")
		elif arg.begins_with("--fight=") and arg != "--fight=beast":  # GFX-211: a comma list
			for id in arg.trim_prefix("--fight=").split(",", false):
				out.append(id)
	if out.is_empty():
		out.append("wild_boar")
	return out


## The node under the world whose script file ends with `script_name` (for a gather site, one whose
## menu offers a "Used in:" line), or null.
func _find_script(script_name: String, needs_used_in := false) -> Node:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with(script_name):
			if not needs_used_in or String(node.get_options()[0].get("description", "")).contains("Used in:"):
				return node
	return null


## WU-218: a new Alchemist's first hour in the order the player meets it.
func _crafter_shots(gs: Node, c: CharacterData) -> void:
	root.get_node("Settings").call("set_value", "hud_hints", 3)
	# The first refine is what takes a craft up (GameState.refine then posts the first order).
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	Alchemy.grant_rank_recipes(c, gs.data)
	gs.call("_commissions_month", "alchemist")
	c.inventory = {}
	var menu: Control = hud.get("_choice_menu")
	var workshop: Node = _find_script("workshop.gd")
	var no_banner := func() -> void: hud.get("_banner").visible = false
	shots.append({"name": "crafter_workshop_menu", "open": func() -> void:
		no_banner.call()
		root.get_node("EventBus").player_changed.emit()  # the emptied pack shows in the vitals
		menu.open_for(workshop), "close": menu.close})
	shots.append({"name": "crafter_hud_hint", "open": func() -> void:
		no_banner.call()
		root.get_node("EventBus").player_changed.emit(), "close": func() -> void: pass})
	var site: Node = _find_script("gather_site.gd", true)
	if site != null:
		shots.append({"name": "crafter_gather_site", "open": func() -> void:
			no_banner.call()
			menu.open_for(site), "close": menu.close})
	# One ingredient short of the first recipe, then the gather that fills the gap.
	var recipe_id: String = Alchemy.known_recipes(c, gs.data, "alchemist")[0]
	var ingredients: Dictionary = gs.data.recipes[recipe_id]["ingredients"]
	var missing: String = ingredients.keys()[ingredients.size() - 1]
	var crafting: Control = hud.get("_crafting")
	shots.append({"name": "crafter_crafting_missing", "open": func() -> void:
		no_banner.call()
		c.inventory = {}
		for item_id: String in ingredients:
			if item_id != missing:
				c.add_item(item_id, int(ingredients[item_id]))
		crafting.open("alchemist"), "close": crafting.close})
	shots.append({"name": "crafter_crafting_gathered", "open": func() -> void:
		no_banner.call()
		gs.gather([{"item": missing, "weight": 100, "min": int(ingredients[missing]), "max": int(ingredients[missing])}], 1)
		assert(c.item_count(missing) >= int(ingredients[missing]), "gather did not fill the missing ingredient")
		crafting.open("alchemist"), "close": crafting.close})
	var journal: Control = hud.get("_screens")["toggle_journal"]
	shots.append({"name": "crafter_journal_commissions", "open": func() -> void:
		journal.open()
		journal.get("_scroll").set_deferred("scroll_vertical", 100000), "close": journal.close})
	shots.append({"name": "crafter_workshop_deliver", "open": func() -> void:
		no_banner.call()
		gs.refine(recipe_id)
		if not c.commissions.is_empty():  # the order may ask for another pill: hand it over
			c.add_item(String(c.commissions[0]["item"]), int(c.commissions[0]["count"]))
		root.get_node("EventBus").player_changed.emit()
		menu.open_for(workshop), "close": menu.close})


## WU-223: the Village Herb Slope menu once per season, so the "Grows here / In season / Out of season" note wraps.
func _gather_note_shots(gs: Node) -> void:
	var menu: Control = hud.get("_choice_menu")
	var slope: Node = _find_gather_site("Village Herb Slope")
	for k in 4:
		var day := k * 3 * Calendar.DAYS_PER_MONTH
		var season := Calendar.season_of(day)
		shots.append({"name": "gather_note_" + season.to_lower(), "open": func() -> void:
			root.get_node("GameClock").total_days = day
			hud.get("_banner").visible = false
			menu.open_for(slope)
			print("%s: %s" % [season, slope.get_options()[0].get("description", "")]), "close": menu.close})
	# WU-227: C-151's Old Quarry Tailings menu with its gather note.
	var quarry: Node = _find_gather_site("Old Quarry Tailings")
	shots.append({"name": "gather_note_quarry", "open": func() -> void:
		hud.get("_banner").visible = false
		menu.open_for(quarry)
		print("Quarry: %s" % quarry.get_options()[0].get("description", "")), "close": menu.close})


## GFX-060: moves the player beside the region's great roamer and snaps the camera there (prints a note when none is out).
func _great_closeup(id: String) -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	gs.player.realm_index = maxi(gs.player.realm_index, gs.data.realm_index_of("foundation_establishment"))  # the ram walks only for Foundation
	var walk: int = Wildlife.next_great_day(gs.data, id, clock.total_days, gs.player.realm_index)
	if walk >= 0:  # each region has its own great day: jump there and rebuild
		clock.total_days = walk
		_rebuild_world(gs, id)
	hud.get("_banner").visible = false
	for node in world.get_children():
		if node.get("great") == true and node is Node2D:  # not `is Roamer`: naming the class compiles it before the autoloads exist
			_teleport_player(node.position + Vector2(0, 90))
			return
	print("great_%s: no great beast out today" % id)


## QA-187: frees the world and builds a fresh one for region `id` (the HUD is the world's child).
func _rebuild_world(gs: Node, id: String) -> void:
	if world != null:
		root.remove_child(world)
		world.free()
	gs.current_region = id
	gs.call("_post_arrival_line")  # GUIDE-210
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	hud.get("_banner").visible = false
	for kind in ["storm", "rain", "fog"]:  # GFX-055: the rebuilt world keeps the forced weather (--rain/--storm)
		if OS.get_cmdline_user_args().has("--" + kind):
			world.call("force_weather", kind)


## QA-187: a Qingshi friend invited along (the HUD chip), then the rented field's menu (tool icons).
func _companion_shots(gs: Node, c: CharacterData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var friend := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 30, "region": "qingshi_village", "realm": "mortal", "gender": "male"})
	var today: int = root.get_node("GameClock").total_days
	shots.append({"name": "companion", "open": func() -> void:
		Folk.invite(c, friend.id, today)
		hud.get("_banner").visible = false
		root.get_node("EventBus").player_changed.emit(), "close": func() -> void: pass})
	var place := FieldPlots.place_def(gs.data, "qingshi_village")
	c.field_plots[FieldPlots.key("qingshi_village", place)] = {"paid_until": 90, "crops": [{"item": "spirit_herb", "days_left": 20}]}
	var field := _find_script("field_plot.gd")
	shots.append({"name": "field_menu", "open": func() -> void:
		hud.get("_banner").visible = false
		hud.get("_choice_menu").open_for(field), "close": hud.get("_choice_menu").close})


func _field_shots(gs: Node, c: CharacterData) -> void:
	var field: Node = null
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("field_plot.gd"):
			field = node
	var place := FieldPlots.place_def(gs.data, "qingshi_village")
	var key := FieldPlots.key("qingshi_village", place)
	c.field_plots[key] = {"paid_until": 90, "crops": [{"item": "spirit_herb", "days_left": 20}, {"item": "dew_grass", "days_left": 3}]}
	shots.append({"name": "field", "open": func() -> void:
		hud.get("_banner").visible = false
		world.get_node("Player").position = field.position + Vector2(0, 70)
		field.queue_redraw(), "close": func() -> void: pass})


const FESTIVAL_ID := "dragon_boat_festival"  ## QA-198: Qingshi's May festival (contest, practice at the jetty)


func _has_festival_flag() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--festival-stall="):
			return true
	for f in ["--festival", "--contest", "--practice", "--regular", "--shop-manual", "--journal"]:
		if OS.get_cmdline_user_args().has(f):
			return true
	return false


## QA-198: the Qingshi market stall that has a `wanted` block (WU-453), or {}.
func _wanted_stall(gs: Node) -> Dictionary:
	for place: Dictionary in gs.data.regions["qingshi_village"].get("places", []):
		if place.has("wanted") and place.has("rotating_stock"):
			return place
	return {}


## QA-198: sets the clock (and the festival, via the month roll) before the world is built.
func _festival_clock(gs: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var clock: Node = root.get_node("GameClock")
	var may_first := 4 * Calendar.DAYS_PER_MONTH  # month 5, day 1: the dragon boat festival starts
	for a in args:  # GFX-083: --festival-stall=<event id> starts that festival's first day in its region
		if a.begins_with("--festival-stall="):
			var ev: Dictionary = gs.data.world_events.get(a.substr(17), {})
			if ev.is_empty():
				push_warning("--festival-stall: unknown event %s" % a.substr(17))
				break
			var region_id := String(ev["regions"][0])
			gs.current_region = region_id
			var month := int(ev["months"][0])
			clock.total_days = (month - 1) * Calendar.DAYS_PER_MONTH
			gs.world_events = [{"id": a.substr(17), "region": region_id, "start_day": clock.total_days, "end_day": clock.total_days + int(ev["min_days"]), "done": false}]
	for a in args:  # QA-200: --calendar-month=N opens the calendar on month N of year 1
		if a.begins_with("--calendar-month="):
			clock.total_days = (clampi(int(a.substr(17)), 1, 12) - 1) * Calendar.DAYS_PER_MONTH
			gs.call("_world_events_month")
	if args.has("--festival") or args.has("--contest"):
		clock.total_days = may_first
		gs.call("_world_events_month")
	elif args.has("--practice"):
		clock.total_days = may_first - 3  # inside the 7-day practice window
	elif args.has("--regular"):
		var stall := _wanted_stall(gs)
		var day: int = clock.total_days
		while not Places.is_market_day_stall(stall, day) and day < 400:
			day += 1
		clock.total_days = day
	elif args.has("--journal"):
		var walk: int = Wildlife.next_great_day(gs.data, gs.current_region, clock.total_days, gs.player.realm_index)
		if walk >= 0:
			clock.total_days = walk
		var entries: Array[Dictionary] = gs.upcoming_days(40)  # CAL-006: mark the first real calendar entry after today
		var marked := false
		for e: Dictionary in entries:
			if int(e["day"]) > int(clock.total_days):
				marked = gs.mark_day(int(e["day"]), String(e["text"]))
				print("journal: mark day %d '%s' -> %s" % [int(e["day"]), String(e["text"]), marked])
				if marked:
					clock.total_days = int(e["day"])  # stand on the marked day, so its line is in today_lines
				break
		if not marked:
			push_warning("--journal: nothing to mark in the next 40 days")


func _festival_shots(gs: Node) -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:  # GFX-083: stand 120 px from the festival_only stall
		if a.begins_with("--festival-stall="):
			var id := a.substr(17)
			shots.append({"name": "festival_stall_" + id, "open": func() -> void:
				hud.get("_banner").visible = false
				for place: Dictionary in gs.data.regions[gs.current_region]["places"]:
					if String(place.get("festival_only", "")) == id:
						var pos := Vector2(float(place["pos"][0]), float(place["pos"][1]))
						_teleport_player(pos + Vector2(-100, 70))
						return
				print("festival-stall: no stall for %s" % id), "close": func() -> void: pass})
	if args.has("--festival"):
		shots.append({"name": "festival_qingshi", "open": func() -> void:
			hud.get("_banner").visible = false
			var stalls: Array = world.get("_stalls")
			print("festival: %d stall(s), caption=%s" % [stalls.size(), stalls[0].get("caption") if not stalls.is_empty() else "-"])
			if not stalls.is_empty():
				_teleport_player(_free_spot_near(stalls[0].position + Vector2(0, 90))), "close": func() -> void: pass})
	if args.has("--contest"):
		shots.append({"name": "contest_card", "open": func() -> void:
			hud.get("_banner").visible = false
			var res: Dictionary = gs.festival_contest(FESTIVAL_ID)
			print("contest: result keys=%s" % [res.keys()]), "close": func() -> void: hud.get("_contest_card").close()})
	if args.has("--practice"):
		shots.append({"name": "practice_menu", "open": func() -> void:
			hud.get("_banner").visible = false
			for node in world.find_children("*", "Interactable", true, false):
				var tags: Variant = node.get("tags")
				if tags is Array and (tags as Array).has("jetty"):
					_teleport_player(node.position + Vector2(0, 60))
					hud.get("_choice_menu").open_for(node)
					return
			print("practice shot: no jetty place found"), "close": hud.get("_choice_menu").close})
	if args.has("--regular"):
		var stall := _wanted_stall(gs)
		var key := Places.place_key(String(stall["display_name"]))
		gs.player.market_regular[key] = Places.regular_after(stall)
		var shop: Control = hud.get("_shop")
		shots.append({"name": "shop_regular", "open": func() -> void:
			hud.get("_banner").visible = false
			root.get_node("EventBus").shop_requested.emit(String(stall["display_name"]), 0, [], "", []), "close": shop.close})
	if args.has("--shop-manual"):  # WU-565: the shop that sells the first fighting-style manual
		var found := Guidance.first_combat_manual(gs.player, gs.data, gs.current_region)
		if found.is_empty():
			push_warning("--shop-manual: no first combat manual in %s" % gs.current_region)
		else:
			var shop_m: Control = hud.get("_shop")
			shots.append({"name": "shop_manual", "open": func() -> void:
				hud.get("_banner").visible = false
				root.get_node("EventBus").shop_requested.emit(String(found["merchant"]), 0, [], "", []), "close": shop_m.close})
	if args.has("--journal"):
		var journal: Control = hud.get("_screens")["toggle_journal"]
		shots.append({"name": "journal_today", "open": func() -> void:
			hud.get("_banner").visible = false
			journal.open()
			print("journal today_lines: %s" % [gs.today_lines()]), "close": journal.close})


## QA-182: two Qingshi villagers in a quarrel, the window opened through the HUD's signal.
func _quarrel_shots(gs: Node, c: CharacterData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 35, "region": "qingshi_village", "realm": "mortal", "gender": "male"})
	var b := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 31, "region": "qingshi_village", "realm": "mortal", "gender": "female"})
	var topic: Dictionary = Folk.quarrel_rules(gs.data)["topics"][0]
	var today: int = root.get_node("GameClock").total_days
	gs.world_flags[Folk.quarrel_flag("qingshi_village")] = {"a": a.id, "b": b.id, "topic": String(topic["id"]), "until": today + 20}
	shots.append({"name": "quarrel", "open": func() -> void:
		hud.get("_banner").visible = false
		gs.current_region = "qingshi_village"
		root.get_node("EventBus").quarrel_requested.emit(a.id), "close": hud.get("_quarrel").close})


## WU-546: `--first-visit` makes the region's arrival a real first visit and shows the arrival banner with its teacher lines.
func _first_visit_card(gs: Node, id: String) -> void:
	if not OS.get_cmdline_user_args().has("--first-visit"):
		return
	gs.player.visited_regions.erase(id)
	gs.last_arrival_first_visit = Exploration.visit(gs.player, id)
	var banner: Control = hud.get("_banner")
	banner.visible = true
	hud.call("_show_arrival", id)


## WU-418: a generated Qingshi villager at favor 65 (Close friend); their menu shows the tier and hearts.
func _friend_shots(gs: Node) -> void:
	shots.append({"name": "friend", "open": func() -> void:
		hud.get("_banner").visible = false
		if region_list.is_empty():
			gs.current_region = "qingshi_village"
		var want := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--friend="):
				want = arg.substr(9)
			if arg.begins_with("--realm="):  # WU-543: set the realm, stage 0
				gs.player.realm_index = int(arg.substr(8))
				gs.player.stage = 0
			if arg.begins_with("--flag="):  # WU-543: --flag=key (true) or --flag=key=value
				var kv := arg.substr(7).split("=", false, 1)
				if kv.size() == 1:
					gs.world_flags[kv[0]] = true
				elif kv[1].is_valid_int():
					gs.world_flags[kv[0]] = int(kv[1])
				else:
					gs.world_flags[kv[0]] = kv[1]
			if arg.begins_with("--knows="):  # WU-542: learn this technique first
				Techniques.learn(gs.player, gs.data, arg.substr(8))
		for node in world.find_children("*", "Interactable", true, false):
			var id := String(node.get("npc_id") if node.get("npc_id") != null else "")
			if want != "" and id == want:
				gs.npc_favor[id] = 65
				hud.get("_choice_menu").open_for(node)
				return
			if want != "":
				continue
			if id != "" and gs.npcs.has(id) and not gs.data.npcs.has(id):
				gs.npc_favor[id] = 65
				hud.get("_choice_menu").open_for(node)
				for arg in OS.get_cmdline_user_args():  # WU-486: --emote=love|happy|sweat shows a bubble over the friend
					if arg.begins_with("--emote="):
						root.get_node("EventBus").npc_reaction.emit(id, arg.substr(8))
				return
		if want != "":
			push_error("friend shot: npc '%s' not found in region %s" % [want, gs.current_region])
		else:
			print("friend shot: no generated villager found"), "close": hud.get("_choice_menu").close})


## WU-553: a friendly spar with NPC `npc_id` (favor raised); shoots the finished report as spar_<id>.png.
func _spar_shots(gs: Node, npc_id: String) -> void:
	shots.append({"name": "spar_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		gs.npc_favor[npc_id] = 30
		gs.player.realm_index = maxi(1, maxi(gs.player.realm_index, gs.npcs[npc_id].realm_index - 1))
		for tid: String in Mentorship.taught_styles(npc_id, gs.data):  # a villager spars as a teacher: learn their style
			Techniques.learn(gs.player, gs.data, tid)
		var why: String = gs.check_spar(npc_id)
		if why != "":
			push_error("spar shot: " + why)
		gs.spar_with(npc_id)
		var rep: Control = hud.get("_combat_report")
		rep.call("skip"), "close": func() -> void: hud.get("_combat_report").call("close")})


## GFX-221: the lend-a-hand card with the player beside the villager (lend_<id>.png).
func _lend_shots(gs: Node, npc_id: String) -> void:
	var skip: Control = hud.get("_time_skip")
	shots.append({"name": "lend_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		_clear_bubble()
		var npc: Node2D = null
		for n in world.get_tree().get_nodes_in_group("npc"):
			if n.get("npc_id") == npc_id:
				npc = n
		if npc == null:
			push_error("lend shot: no %s in the region" % npc_id)
			return
		_teleport_player(npc.position + Vector2(-120, 0))
		hud.get("_prompt").visible = false
		gs.lend_a_hand(npc_id)
		_teleport_player(world.get_node("Player").position),
		"settle": 40, "close": skip.close})


## GFX-226: tea with a friend: the card, both figures seated either side of the table (tea_<id>.png).
func _tea_shots(gs: Node, npc_id: String) -> void:
	var skip: Control = hud.get("_time_skip")
	shots.append({"name": "tea_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		_clear_bubble()
		var npc: Node2D = null
		for n in world.get_tree().get_nodes_in_group("npc"):
			if n.get("npc_id") == npc_id:
				npc = n
		if npc == null:
			push_error("tea shot: no %s in the region" % npc_id)
			return
		gs.player.lessons_taught[npc_id + ":shot"] = int(gs.get_node("/root/GameClock").total_days)  # WU-589: no lesson card over the tea card
		skip.close()  # WU-589: an earlier shot's card must be gone before this one opens
		gs.world_flags.erase("tea_" + npc_id)  # and its cooldown must not refuse the visit
		gs.npc_favor[npc_id] = 45
		gs.player.scene_day = int(gs.get_node("/root/GameClock").total_days)  # no friend-scene card over the pair
		_teleport_player(npc.position + Vector2(-120, 0))
		hud.get("_prompt").visible = false
		gs.call_on(npc_id)
		hud.get("_banner").visible = false  # WU-589: a queued banner would make the capture wait until the card is gone
		_teleport_player(world.get_node("Player").position),
		"settle": 40, "close": skip.close})


## WU-599: a Sworn friend tends the player's wounds: the card with the pair seated (tend_<id>.png).
func _tend_shots(gs: Node, npc_id: String) -> void:
	var skip: Control = hud.get("_time_skip")
	shots.append({"name": "tend_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		_clear_bubble()
		var npc: Node2D = null
		for n in world.get_tree().get_nodes_in_group("npc"):
			if n.get("npc_id") == npc_id:
				npc = n
		if npc == null:
			push_error("tend shot: no %s in the region" % npc_id)
			return
		skip.close()
		gs.npc_favor[npc_id] = 90
		gs.player.injuries["broken_ribs"] = 20
		gs.world_flags.erase("tended_" + npc_id)
		_teleport_player(npc.position + Vector2(-120, 0))
		hud.get("_prompt").visible = false
		gs.receive_sworn_tending()
		hud.get("_banner").visible = false,
		"settle": 40, "close": skip.close})


## WU-600: a friend left a gift for the player on arrival (drop_by_<id>.png).
func _drop_by_shots(gs: Node, npc_id: String) -> void:
	var card: Control = hud.get("_gift_left")
	shots.append({"name": "drop_by_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		_clear_bubble()
		gs.npc_favor[npc_id] = 70
		var clock: Node = gs.get_node("/root/GameClock")
		for i in 40:  # the roll is a stable hash of the day: step the day until this friend leaves something
			gs.world_flags.erase("drop_by_" + npc_id)
			gs.receive_drop_by_gifts()
			if card.visible:
				break
			clock.total_days += 1
		if card.queued_count() == 0 and not card.visible:
			push_error("drop-by shot: %s left no gift (try another day/friend)" % npc_id),
		"settle": 30, "close": func() -> void: card.skip()})


## GFX-225: favor just under the next tier, one lend, then the shot waits for the card to close and the hearts to rise.
func _tier_up_shots(gs: Node, npc_id: String, far: bool) -> void:
	var skip: Control = hud.get("_time_skip")
	shots.append({"name": ("tier_up_far_" if far else "tier_up_") + npc_id, "open": func() -> void:
		var arrival: Control = hud.get("_banner")  # WU-589: the arrival banner must not queue the tier-up banner behind it
		gs.check_milestones()  # GFX-233: announce every milestone already earned now, so none is queued behind the tier-up banner
		while arrival.queued_count() > 0:
			arrival.finish_current()
		arrival.finish_current()
		var npc: Node2D = null
		for n in world.get_tree().get_nodes_in_group("npc"):
			if n.get("npc_id") == npc_id:
				npc = n
		if npc == null:
			push_error("tier-up shot: no %s in the region" % npc_id)
			return
		for i in Folk.lessons_of(gs.data, npc_id).size():  # GFX-233: every lesson counts as taught (the lend passes days, so a per-day mark is not enough)
			gs.player.lessons_taught["%s:%d" % [npc_id, i]] = 0
		gs.player.scene_day = int(gs.get_node("/root/GameClock").total_days)
		var favor := int(gs.npc_favor.get(npc_id, 0))
		var next_min := 20
		for t: Dictionary in gs.data.family["folk_tiers"]:
			if int(t["min"]) > favor and t.has("line"):  # WU-589: only a tier with a line raises the banner
				next_min = int(t["min"])
				break
		gs.npc_favor[npc_id] = next_min - 1
		gs.world_flags.erase("tea_" + npc_id)  # WU-589: no cooldown from an earlier shot
		gs.world_flags.erase("lend_" + npc_id)
		gs.check_friendships()
		gs.player.folk_tier_seen[npc_id] = Folk.tier_index(gs.data, next_min - 1)
		_teleport_player(npc.position + Vector2(-700 if far else -70, 0))  # GFX-231: beside the friend so hearts and banner share the frame
		gs.player.scene_day = int(gs.get_node("/root/GameClock").total_days)
		if next_min - 1 >= int(gs.data.family["lend_a_hand"]["max_favor"]):
			gs.call_on(npc_id)  # WU-589: a lend is capped below this tier; tea grows it instead
		else:
			gs.lend_a_hand(npc_id)
		if not far:
			_teleport_player(world.get_node("Player").position)
		skip.close()  # the card closes first, then the hearts play
		await world.get_tree().create_timer(0.3 if not far else 0.2).timeout,  # GFX-233: capture at the hearts' peak / the pulse's peak
		"settle": 20, "keep_banner": true, "close": func() -> void: pass})  # WU-589: the banner is what this shot is for


## GFX-235: the oath at the bow (about 0.8 s in).
func _sworn_shots(gs: Node, npc_id: String) -> void:
	var oath: Control = hud.get("_sworn_oath")
	shots.append({"name": "sworn_" + npc_id, "open": func() -> void:
		hud.get("_banner").visible = false
		var def: CharacterData = gs.npcs.get(npc_id)
		oath.begin(npc_id, def.name if def != null else npc_id, gs.data.family["folk_tiers"].back())
		oath.set("_time", 0.8),
		"settle": 2, "close": func() -> void: oath.end()})


## QA-182: the cast bar with the marker held mid-sweep (processing off so it stays put).
func _cast_shots(gs: Node) -> void:
	var cast: Control = hud.get("_cast_bar")
	shots.append({"name": "cast", "open": func() -> void:
		hud.get("_banner").visible = false
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		cast.open_for([{"item": "spirit_herb", "weight": 100, "min": 1, "max": 1}], 1, "Qingshi Jetty", rng)
		cast.set("marker", 0.45)
		cast.set_process(false)
		cast.get("_bar").queue_redraw(), "close": func() -> void:
		cast.set("_finished", true)  # FISH-010: closing a shot must never resolve a trip
		cast.close()})


func _find_gather_site(site_name: String) -> Node:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("gather_site.gd") \
				and str(node.get("display_name")) == site_name:
			return node
	assert(false, "no %s in the world" % site_name)
	return null


func _explore_slugs() -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("explore_site.gd"):
			out.append(String(node.get("display_name")).to_lower().replace(" ", "_").replace("'", ""))
	return out


func _find_explore_by_slug(slug: String) -> Node:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node.get_script() != null and String(node.get_script().resource_path).ends_with("explore_site.gd") \
				and String(node.get("display_name")).to_lower().replace(" ", "_").replace("'", "") == slug:
			return node
	return null


func _find_explore() -> Node:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Node2D and node.has_method("menu_options") and node.get_script() != null \
				and String(node.get_script().resource_path).ends_with("explore_site.gd"):
			return node
	return null


func _process(_d: float) -> bool:
	if not started:
		_start()
		return false
	if index >= shots.size():
		return true
	var shot: Dictionary = shots[index]
	if not opened:
		(shot["open"] as Callable).call()
		hud.call("_update_modal")  # WU-404: the dim backdrop and hidden prompt, as in play
		opened = true
		frames = 0
		return false
	frames += 1
	if shot["name"] != "season_card" and hud.get("_season_card").visible:  # WU-534: a season-start card queued behind a screen
		hud.get("_season_card").close()
		frames = 0
		return false
	# WU-386: after a fight a milestone banner is still fading; wait it out (at most ~3 s) so it never dims a screen shot.
	if frames >= SETTLE_FRAMES and hud.get("_banner").visible and not shot.get("keep_banner", false) and (shot.get("wait_banner", false) or shot["name"] not in ["hud_arrival", "arrival_card"]) and not (OS.get_cmdline_user_args().has("--first-visit") and String(shot["name"]).begins_with("region_")):  # QA-182: queued notices covered the modals
		if banner_wait_start < 0:
			banner_wait_start = Time.get_ticks_msec()
		if Time.get_ticks_msec() - banner_wait_start < BANNER_WAIT_MSEC:
			return false
		var banner: Control = hud.get("_banner")
		push_warning("%s: banner still showing after %d ms (queued=%d); hidden by hand" % [shot["name"], BANNER_WAIT_MSEC, banner.queued_count()])
		while banner.queued_count() > 0:
			banner.finish_current()  # each call plays the next queued banner
		banner.finish_current()
		frames = 0  # let a frame render without it before the capture
		banner_wait_start = -1
		return false
	if frames >= int(shot.get("settle", SETTLE_FRAMES)):
		banner_wait_start = -1
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var file := "%s/%s.png" % [OUT_DIR, shot["name"]]
		var img: Image = root.get_viewport().get_texture().get_image()
		if shot.get("crop", false):  # WU-471: the guide panel at 2x
			var panel: Control = hud.get("_guide_panel")
			var r := panel.get_global_rect().grow(6.0)
			var vp_size: Vector2 = root.get_viewport().get_visible_rect().size  # QA-203: image is in window pixels
			var k: float = float(img.get_width()) / maxf(vp_size.x, 1.0)
			r = Rect2(r.position * k, r.size * k)
			img = img.get_region(Rect2i(r).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
			img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(file)
		print("saved %s" % ProjectSettings.globalize_path(file))
		(shot["close"] as Callable).call()
		opened = false
		index += 1
	return false


## GFX-217: the world frozen at night behind a time-skip card.
func _skip_night_shot(gs: Node, id: String) -> Dictionary:
	return {"name": "skip_night_" + id, "open": func() -> void:
		_rebuild_world(gs, id)
		world.call("_on_time_skipped", 3, {})
		world.get("_day_tween").kill()
		world.call("_apply_day_phase", 0.5, 1.0)
		hud.call("_show_time_skip", {"title": "Meditating", "days": 3, "lines": ["+0 qi"]})
		, "settle": 20, "close": func() -> void: hud.get("_time_skip").close()}
