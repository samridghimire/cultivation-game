class_name Interactable
extends Area2D
## Base class for anything the player can walk up to and use.
##
## Subclasses override get_options() to return menu entries:
##   {"label": String, "action": Callable, "disabled": bool (optional),
##    "keep_open": bool (optional, re-show the menu after the action)}
## Actions should call GameState methods, not change data directly.

@export var display_name := "Object"
@export var size := Vector2(64, 64)
@export var color := Color.WHITE
## How far beyond its footprint the player can be and still interact.
@export var reach := 28.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size + Vector2(reach, reach) * 2.0
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.player_changed.connect(_refresh)
	_refresh()


func get_options() -> Array[Dictionary]:
	return []


## Whether this can currently be interacted with (e.g. a dead NPC cannot).
func is_available() -> bool:
	return true


func _refresh() -> void:
	visible = is_available()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.add_interactable(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.remove_interactable(self)


func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), color)
	draw_rect(Rect2(-size / 2.0, size), color.darkened(0.5), false, 2.0)
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(-text_width / 2.0, -size.y / 2.0 - 8.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
