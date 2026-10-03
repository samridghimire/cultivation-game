class_name Player
extends CharacterBody2D
## Top-down player avatar: movement and choosing which interactable to use.
## Placeholder art is drawn in _draw() until real sprites exist.

const SPEED := 220.0
const RADIUS := 14.0

var input_enabled := true
var _nearby: Array[Interactable] = []
var _target: Interactable


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
	_update_target()


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("interact") and _target != null:
		get_viewport().set_input_as_handled()
		EventBus.interaction_menu_requested.emit(_target)


func add_interactable(i: Interactable) -> void:
	if not _nearby.has(i):
		_nearby.append(i)


func remove_interactable(i: Interactable) -> void:
	_nearby.erase(i)


func _update_target() -> void:
	var best: Interactable = null
	var best_dist := INF
	for i in _nearby:
		if not i.is_available():
			continue
		var d := global_position.distance_squared_to(i.global_position)
		if d < best_dist:
			best = i
			best_dist = d
	if best != _target:
		if is_instance_valid(_target):
			_target.highlighted = false
		_target = best
		if best:
			best.highlighted = true
		EventBus.interaction_target_changed.emit(best.display_name if best else "")


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("e8d9a8"))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color("3b2f1e"), 2.0)
