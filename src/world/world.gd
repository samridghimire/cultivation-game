extends Node2D
## The current region, built from data/regions.json: ground, paths and every
## interactable place. Travelling reloads this scene for the new region.
## Placeholder art is drawn in _draw().
## Running this scene directly (F6) starts a debug session automatically.

## Script for each place 'type' in data/regions.json.
const PLACE_SCRIPTS := {
	"meditation": preload("res://src/world/interactables/meditation_spot.gd"),
	"merchant": preload("res://src/world/interactables/merchant.gd"),
	"sect_hall": preload("res://src/world/interactables/sect_hall.gd"),
	"workshop": preload("res://src/world/interactables/workshop.gd"),
	"clinic": preload("res://src/world/interactables/clinic.gd"),
	"orphanage": preload("res://src/world/interactables/orphanage.gd"),
	"deed_giver": preload("res://src/world/interactables/deed_giver.gd"),
	"explore": preload("res://src/world/interactables/explore_site.gd"),
	"travel": preload("res://src/world/interactables/travel_point.gd"),
	"gather": preload("res://src/world/interactables/gather_site.gd"),
	"secret_realm": preload("res://src/world/interactables/secret_realm_entrance.gd"),
}
## Place keys that are layout, not script properties.
const LAYOUT_KEYS := ["type", "pos"]
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const ABODE_SCRIPT := preload("res://src/world/interactables/abode.gd")
## Placeholder body color of generated NPCs by gender.
const GENDER_COLORS := {"male": Color("8fb3e0"), "female": Color("e6a3c4")}

var map_size := Vector2(1600, 1000)
var _region: Dictionary = {}
## Scenery.place() output, drawn under everything else.
var _decor: Array[Dictionary] = []

@onready var player: Player = $Player


func _ready() -> void:
	if not GameState.has_session():
		GameState.rng.randomize()
		GameState.start_session(CharacterFactory.create("Debug Disciple", GameState.data, GameState.rng))
	_region = GameState.data.regions.get(GameState.current_region, {})
	var map: Dictionary = _region.get("map", {})
	map_size = _vec(map.get("size", [map_size.x, map_size.y]))
	player.position = _vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))
	_build_decor()
	_build_places()
	_place_at_spawn_anchor()
	_build_npcs()
	_build_bounds()
	_limit_camera()
	EventBus.ui_modal_changed.connect(func(is_open: bool): player.input_enabled = not is_open)
	EventBus.region_changed.connect(_on_region_changed)


## Travel or an artifact respawn moved the player: rebuild the world for the
## new region (only when this world is the running scene, not a preview or test).
func _on_region_changed(_region_id: String) -> void:
	if get_tree().current_scene == self:
		get_tree().reload_current_scene.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		if SaveManager.save_game():
			EventBus.post("Game saved.")
	elif event.is_action_pressed("quick_load"):
		if SaveManager.load_game():
			get_tree().reload_current_scene()


func _build_bounds() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	var t := 40.0
	for rect in [
		Rect2(-t, -t, map_size.x + 2 * t, t),
		Rect2(-t, map_size.y, map_size.x + 2 * t, t),
		Rect2(-t, 0, t, map_size.y),
		Rect2(map_size.x, 0, t, map_size.y),
	]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size / 2.0
		walls.add_child(shape)


## Scenery is seeded from the region id, so a region always looks the same.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.current_region)
	_decor = Scenery.place(_region, rng)
	_decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)


func _build_places() -> void:
	for place: Dictionary in _region.get("places", []):
		var node: Interactable = PLACE_SCRIPTS[place["type"]].new()
		node.position = _vec(place.get("pos", [0, 0]))
		node.art_kind = place["type"]
		for key in place:
			if LAYOUT_KEYS.has(key):
				continue
			node.set(key, _convert(place[key], node.get(key)))
		# Add before the player so the player draws on top.
		add_child(node)
		move_child(node, player.get_index())
	_build_abodes()


## Claimable cave abodes (region "abodes", G-010b).
func _build_abodes() -> void:
	for abode: Dictionary in _region.get("abodes", []):
		var node: Interactable = ABODE_SCRIPT.new()
		node.abode_id = String(abode.get("id", ""))
		node.display_name = String(abode.get("display_name", node.abode_id))
		node.anchor_id = String(abode.get("anchor_id", ""))
		node.position = _vec(abode.get("pos", [0, 0]))
		node.size = _vec(abode.get("size", [80, 60]))
		node.color = Color(String(abode.get("color", "6f6a5a")))
		add_child(node)
		move_child(node, player.get_index())


## After an artifact respawn the player awakens beside their anchor place.
func _place_at_spawn_anchor() -> void:
	var anchor_id := GameState.spawn_anchor
	GameState.spawn_anchor = ""
	if anchor_id == "":
		return
	for node in get_children():
		if node is Interactable and node.anchor_id == anchor_id:
			player.position = node.position + Vector2(0, node.size.y / 2.0 + 48.0)
			return


func _build_npcs() -> void:
	for c in Npcs.in_region(GameState.npcs, GameState.data, GameState.current_region):
		if not GameState.data.npcs.has(c.id):
			continue  # Generated NPCs are placed by _build_generated_npcs().
		var def: Dictionary = GameState.data.npcs[c.id]
		var node: Interactable = NPC_SCRIPT.new()
		node.art_kind = "npc"
		node.npc_id = c.id
		node.display_name = "%s (%s)" % [c.name, def["title"]] if def.has("title") else c.name
		node.position = _vec(def.get("pos", [0, 0]))
		node.size = _vec(def.get("size", [30, 30]))
		node.color = Color(def.get("color", "e6bf99"))
		add_child(node)
		move_child(node, player.get_index())
	_build_generated_npcs()


## Generated NPCs (Npcs.spawn, no def) stand at the region's npc_spots,
## colored by gender; children are drawn smaller.
func _build_generated_npcs() -> void:
	var data := GameState.data
	var people := Npcs.generated_in_region(GameState.npcs, data, GameState.current_region)
	var spots := Npcs.spot_positions(people.size(), _region.get("npc_spots", []), player.position)
	for i in people.size():
		var c := people[i]
		var node: Interactable = NPC_SCRIPT.new()
		node.art_kind = "npc"
		node.npc_id = c.id
		node.display_name = "%s (%s)" % [c.name, Npcs.world_title(c, GameState.player, data)]
		node.position = spots[i]
		var adult := c.age_years() >= int(data.family.get("adult_age", 16))
		node.size = Vector2(28, 28) if adult else Vector2(20, 20)
		node.color = GENDER_COLORS.get(c.gender, Color("e6bf99"))
		add_child(node)
		move_child(node, player.get_index())


func _limit_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)


## Converts a JSON value to the type of the property it is assigned to.
func _convert(value: Variant, current: Variant) -> Variant:
	match typeof(current):
		TYPE_VECTOR2:
			return _vec(value)
		TYPE_COLOR:
			return Color(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
	return value


func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _draw() -> void:
	var map: Dictionary = _region.get("map", {})
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("ground", "4d6b3c")))
	var path_color := Color(map.get("path_color", "8a7350"))
	for r in map.get("paths", []):
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), path_color)
	for d in _decor:
		_draw_decor(d)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("border", "2a3a20")), false, 6.0)


func _draw_decor(d: Dictionary) -> void:
	var p: Vector2 = d["pos"]
	var k: float = d["scale"]
	var c: Color = d["color"]
	match d["kind"]:
		"tree":
			draw_circle(p + Vector2(4, 6) * k, 20.0 * k, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(p + Vector2(-3, 2) * k, Vector2(6, 14) * k), Color("4a3524"))
			draw_circle(p + Vector2(0, -6) * k, 18.0 * k, c)
			draw_circle(p + Vector2(-8, -2) * k, 12.0 * k, c.darkened(0.15))
			draw_circle(p + Vector2(6, -14) * k, 9.0 * k, c.lightened(0.15))
		"rock":
			var pts := PackedVector2Array([Vector2(-12, 6), Vector2(-9, -5), Vector2(-1, -9), Vector2(10, -4), Vector2(12, 6)])
			for i in pts.size():
				pts[i] = p + pts[i] * k
			draw_colored_polygon(pts, c)
			draw_line(p + Vector2(-9, -5) * k, p + Vector2(-1, -9) * k, c.lightened(0.3), 2.0)
		"grass":
			for x in [-4.0, 0.0, 4.0]:
				draw_line(p + Vector2(x, 4) * k, p + Vector2(x * 1.6, -5 + absf(x) * 0.5) * k, c, 1.5)
		"flower":
			draw_line(p, p + Vector2(0, 6) * k, Color("4f7a3a"), 1.5)
			for i in 5:
				draw_circle(p + Vector2.from_angle(TAU * i / 5.0) * 3.0 * k, 2.2 * k, c)
			draw_circle(p, 1.6 * k, Color("f2d24b"))
