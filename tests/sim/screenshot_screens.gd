extends SceneTree
## Screenshots of every HUD screen for a mid-game character, for eyeballing
## layout at 1280x800 without a display (WU-021). Needs a GPU-less X server:
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_screens.gd
## PNGs go to user://screenshots/screens/<name>.png (OUT_DIR). Never writes saves.

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
	for i in 30:
		root.get_node("EventBus").post("Message %d: a line of news that is long enough to wrap across the log panel." % i)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	hud = world.get_node("HUD")
	_build_shots(gs)


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
	_build_deck_shots(gs)
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
