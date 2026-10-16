extends SceneTree
## First-hour screenshots (WU-077): a FRESH character in Qingshi Village, day 0, no sect,
## for eyeballing what a new player sees at 1280x800 without a display.
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_first_hour.gd
## WU-218: append `-- --crafter` for a new Alchemist's first hour (workshop, hint, gather site, crafting,
## journal Commissions, Deliver) as crafter_*.png.
## PNGs go to user://screenshots/first_hour/<name>.png. Never writes saves.
## (The mid-game sibling is screenshot_screens.gd.)

const OUT_DIR := "user://screenshots/first_hour"
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var c := CharacterFactory.create("Lin Feng", gs.data, rng, "male")
	gs.start_session(c)
	gs.pending_event = ""
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	if OS.get_cmdline_user_args().has("--crafter"):
		_crafter_shots(gs, c)
		return
	shots.append({"name": "hud_arrival", "open": func() -> void: pass, "close": func() -> void: pass})
	shots.append({"name": "elder_mo_dialogue", "open": func() -> void: gs.start_dialogue("elder_mo"), "close": func() -> void: gs.end_dialogue()})
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
	var report: Control = hud.get("_combat_report")
	# A real fight through GameState.fight (WU-181): the boar is rated and resolved
	# like in play; seed 11 is a newcomer win. The HUD opens the report itself.
	shots.append({"name": "combat_report", "open": func() -> void:
		gs.rng.seed = 11
		gs.fight("wild_boar"), "close": report.close})
	for action: String in ["toggle_journal", "toggle_inventory", "toggle_character_sheet"]:
		if hud.get("_screens").has(action):
			var s: Control = hud.get("_screens")[action]
			shots.append({"name": action.trim_prefix("toggle_"), "open": s.open, "close": s.close})


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
