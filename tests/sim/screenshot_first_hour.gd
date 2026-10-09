extends SceneTree
## First-hour screenshots (WU-077): a FRESH character in Qingshi Village, day 0, no sect,
## for eyeballing what a new player sees at 1280x800 without a display.
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_first_hour.gd
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
	var lines := PackedStringArray(["Round 1: you strike the Wild Boar for 3. (Wild Boar: 12 hp)", "Round 2: the Wild Boar gores you for 2."])
	shots.append({"name": "combat_report", "open": func() -> void: report.show_fight("Wild Boar", false, lines), "close": report.close})
	for action: String in ["toggle_journal", "toggle_inventory", "toggle_character_sheet"]:
		if hud.get("_screens").has(action):
			var s: Control = hud.get("_screens")[action]
			shots.append({"name": action.trim_prefix("toggle_"), "open": s.open, "close": s.close})


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
