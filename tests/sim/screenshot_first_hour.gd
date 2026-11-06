extends SceneTree
## First-hour screenshots (WU-077): a FRESH character in Qingshi Village, day 0, no sect,
## for eyeballing what a new player sees at 1280x800 without a display.
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_first_hour.gd
## WU-218: append `-- --crafter` for a new Alchemist's first hour (workshop, hint, gather site, crafting,
## journal Commissions, Deliver) as crafter_*.png.
## WU-418: append `-- --friend` for friend.png (a villager menu with the heart row).
## WU-414: append `-- --book` for village_book.png.
## WU-430: `-- --great` (with --region=) starts on the region's next great-beast day.
## WU-450: `-- --great --tracks` starts the day before it, so the trail of prints shows.
## GFX-033: append `-- --storm` to render the first-hour shots under a storm.  GFX-051: `-- --rain` forces rain.
## GFX-037: append `-- --season=Winter` (Spring/Summer/Autumn/Winter) to start on that season's first day.
## GFX-029: append `-- --field` for field.png (a growing field).
## GFX-023: append `-- --celebration` for celebration.png (wedding lanterns and red sashes).
## WU-223: append `-- --gather-note` for the Village Herb Slope menu in each season: gather_note_<season>.png.
## WU-404: shots open through the HUD's _update_modal, so the dim backdrop and hidden prompt show.
## append `-- --fight=cultivator` for combat_report_cultivator.png (GFX-020).
## QA-187: `--region=a,b,...` renders only the arrival shot of each region as region_<id>.png (one world build per
## region); with one id the normal shot set is rendered in that region and the arrival shot is also named region_<id>.png.
## QA-187: append `-- --companion` (a Qingshi friend invited along, WU-413): companion.png (the HUD chip) and
## field_menu.png (the rented field's menu with the tool icons).
## WU-452: `-- --road-card [--road-encounter]` renders road_card.png (and road_encounter.png).
## GFX-065: append `-- --arrival-card` for arrival_card.png, right after a new game starts, the card still up.
## GFX-081: `-- --shrine=N` sets the old shrine's stage (0..4).
## QA-198: `-- --festival` (festival_qingshi), `--contest` (contest_card), `--practice` (practice_menu), `--regular` (shop_regular), `--journal` (journal_today); one flag per run.
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
	if not region_list.is_empty():
		gs.current_region = region_list[0]
	for arg in OS.get_cmdline_user_args():  # GFX-081: --shrine=N sets the old shrine's restoration stage (0..4)
		if arg.begins_with("--shrine="):
			gs.player.seasons_completed.clear()
			for i in clampi(int(arg.substr(9)), 0, 4):
				gs.player.seasons_completed.append("shot_%d" % i)
	if OS.get_cmdline_user_args().has("--great") or OS.get_cmdline_user_args().has("--tracks"):  # WU-430: jump to the region's next great-beast day
		var clock: Node = root.get_node("GameClock")
		var walk: int = Wildlife.next_great_day(gs.data, gs.current_region, clock.total_days, gs.player.realm_index)
		if walk >= 0:
			clock.total_days = walk - (1 if OS.get_cmdline_user_args().has("--tracks") else 0)  # WU-450: --tracks = the day before
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
	if region_list.size() > 1:  # QA-187: one arrival shot per region, rebuilding the world between them
		for id in region_list:
			shots.append({"name": "region_" + id, "open": func() -> void: _rebuild_world(gs, id), "close": func() -> void: pass})
			if OS.get_cmdline_user_args().has("--great"):  # GFX-060: and a close-up of the great roamer
				shots.append({"name": "great_" + id, "open": func() -> void: _great_closeup(id), "close": func() -> void: pass})
		return
	if OS.get_cmdline_user_args().has("--companion"):  # QA-187: the invited friend's chip and the field menu with tool icons
		_companion_shots(gs, c)
		special = true
	if _has_festival_flag():  # QA-198
		_festival_shots(gs)
		special = true
	if OS.get_cmdline_user_args().has("--field"):  # GFX-029: a rented field with a young and a nearly ripe crop
		_field_shots(gs, c)
		special = true
	if OS.get_cmdline_user_args().has("--quarrel"):  # QA-182: a FOLK-004 quarrel between two villagers
		_quarrel_shots(gs, c)
		special = true
	if OS.get_cmdline_user_args().has("--friend"):  # WU-418: a Qingshi villager at favor 65 and their menu
		_friend_shots(gs)
		special = true
	if OS.get_cmdline_user_args().has("--cast"):  # QA-182: the CastBar on the jetty, marker frozen mid-sweep
		_cast_shots(gs)
		special = true
	if OS.get_cmdline_user_args().has("--calendar"):  # WU-419: the month calendar, a festival-free market month
		var cal: Control = hud.get("_screens")["open_calendar"]
		shots.append({"name": "calendar", "open": func() -> void:
			hud.get("_banner").visible = false
			cal.open(), "close": cal.close})
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
	shots.append({"name": "hud_arrival", "open": func() -> void: pass, "close": func() -> void: pass})
	if region_list.size() == 1:
		shots.append({"name": "region_" + region_list[0], "open": func() -> void: pass, "close": func() -> void: pass})
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
	var report: Control = hud.get("_combat_report")
	# A real fight through GameState.fight (WU-181): the boar is rated and resolved
	# like in play; seed 11 is a newcomer win. The HUD opens the report itself.
	shots.append({"name": "combat_report" + ("_cultivator" if _fight_foe() != "wild_boar" else ""), "open": func() -> void:
		gs.rng.seed = 11
		gs.fight(_fight_foe())
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


## `--fight=beast|cultivator` picks the combat_report foe (default: the boar).
func _fight_foe() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg == "--fight=cultivator":
			return "rogue_cultivator"
	return "wild_boar"


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
	for kind in ["storm", "rain"]:  # GFX-055: the rebuilt world keeps the forced weather (--rain/--storm)
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
	for f in ["--festival", "--contest", "--practice", "--regular", "--journal"]:
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
	if args.has("--festival"):
		shots.append({"name": "festival_qingshi", "open": func() -> void:
			hud.get("_banner").visible = false
			var stalls: Array = world.get("_stalls")
			print("festival: %d stall(s), caption=%s" % [stalls.size(), stalls[0].get("caption") if not stalls.is_empty() else "-"])
			if not stalls.is_empty():
				_teleport_player(stalls[0].position + Vector2(0, 90)), "close": func() -> void: pass})
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


## WU-418: a generated Qingshi villager at favor 65 (Close friend); their menu shows the tier and hearts.
func _friend_shots(gs: Node) -> void:
	shots.append({"name": "friend", "open": func() -> void:
		hud.get("_banner").visible = false
		gs.current_region = "qingshi_village"
		for node in world.find_children("*", "Interactable", true, false):
			var id := String(node.get("npc_id") if node.get("npc_id") != null else "")
			if id != "" and gs.npcs.has(id) and not gs.data.npcs.has(id):
				gs.npc_favor[id] = 65
				hud.get("_choice_menu").open_for(node)
				return
		print("friend shot: no generated villager found"), "close": hud.get("_choice_menu").close})


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
		cast.get("_bar").queue_redraw(), "close": cast.close})


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
	# WU-386: after a fight a milestone banner is still fading; wait it out (at most ~3 s) so it never dims a screen shot.
	if frames >= SETTLE_FRAMES and hud.get("_banner").visible and (shot.get("wait_banner", false) or shot["name"] not in ["hud_arrival", "arrival_card"]):  # QA-182: queued notices covered the modals
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
	if frames >= SETTLE_FRAMES:
		banner_wait_start = -1
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var file := "%s/%s.png" % [OUT_DIR, shot["name"]]
		root.get_viewport().get_texture().get_image().save_png(file)
		print("saved %s" % ProjectSettings.globalize_path(file))
		(shot["close"] as Callable).call()
		opened = false
		index += 1
	return false
