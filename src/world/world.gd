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
	"deed_giver": preload("res://src/world/interactables/deed_giver.gd"),
	"explore": preload("res://src/world/interactables/explore_site.gd"),
	"travel": preload("res://src/world/interactables/travel_point.gd"),
	"gather": preload("res://src/world/interactables/gather_site.gd"),
}
## Place keys that are layout, not script properties.
const LAYOUT_KEYS := ["type", "pos"]
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")

var map_size := Vector2(1600, 1000)
var _region: Dictionary = {}

@onready var player: Player = $Player


func _ready() -> void:
	if not GameState.has_session():
		GameState.rng.randomize()
		GameState.start_session(CharacterFactory.create("Debug Disciple", GameState.data, GameState.rng))
	_region = GameState.data.regions.get(GameState.current_region, {})
	var map: Dictionary = _region.get("map", {})
	map_size = _vec(map.get("size", [map_size.x, map_size.y]))
	player.position = _vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))
	_build_places()
	_build_npcs()
	_build_bounds()
	_limit_camera()
	EventBus.ui_modal_changed.connect(func(is_open: bool): player.input_enabled = not is_open)
	EventBus.region_changed.connect(func(_id: String): get_tree().reload_current_scene.call_deferred())


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


func _build_places() -> void:
	for place: Dictionary in _region.get("places", []):
		var node: Interactable = PLACE_SCRIPTS[place["type"]].new()
		node.position = _vec(place.get("pos", [0, 0]))
		for key in place:
			if LAYOUT_KEYS.has(key):
				continue
			node.set(key, _convert(place[key], node.get(key)))
		# Add before the player so the player draws on top.
		add_child(node)
		move_child(node, player.get_index())


func _build_npcs() -> void:
	for c in Npcs.in_region(GameState.npcs, GameState.data, GameState.current_region):
		# Generated NPCs (Npcs.spawn) have no def or placement yet.
		if not GameState.data.npcs.has(c.id):
			continue
		var def: Dictionary = GameState.data.npcs[c.id]
		var node: Interactable = NPC_SCRIPT.new()
		node.npc_id = c.id
		node.display_name = "%s (%s)" % [c.name, def["title"]] if def.has("title") else c.name
		node.position = _vec(def.get("pos", [0, 0]))
		node.size = _vec(def.get("size", [30, 30]))
		node.color = Color(def.get("color", "e6bf99"))
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
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("border", "2a3a20")), false, 6.0)
