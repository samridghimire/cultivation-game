class_name Player
extends CharacterBody2D
## Top-down player avatar: movement and choosing which interactable to use.
## Placeholder art is drawn in _draw() until real sprites exist: a robed
## cultivator facing the walking direction, colored by PlayerLook.

const SPEED := 220.0
const RADIUS := 14.0

## Walking bob height and speed, aura pulse speed.
const BOB_PIXELS := 2.0
const BOB_SPEED := 14.0
const AURA_SPEED := 2.5
const CELEBRATE_SECONDS := 1.6
const SHAKE_SECONDS := 0.3

var input_enabled := true
var _nearby: Array[Interactable] = []
var _target: Interactable
var _look: Dictionary = {}
var _facing := Vector2.DOWN
var _time := 0.0
var _celebrate_left := 0.0
var _celebrate_ok := true


func _ready() -> void:
	add_to_group("player")
	EventBus.player_changed.connect(refresh_look)
	EventBus.session_started.connect(refresh_look)
	EventBus.breakthrough_attempted.connect(func(success: bool, _realm: String) -> void: celebrate(success))
	refresh_look.call_deferred()


## Re-reads the player's sect, alignment and realm for the placeholder art.
func refresh_look() -> void:
	if GameState.has_session():
		_look = PlayerLook.of(GameState.player, GameState.data)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _celebrate_left > 0.0:
		_celebrate_left = maxf(0.0, _celebrate_left - delta)
		queue_redraw()
	if velocity != Vector2.ZERO or int(_look.get("aura_rings", 0)) > 0:
		queue_redraw()


## Breakthrough effect (WU-063): a gold ring and rays on success, a dull
## contracting ring and a sideways shake on failure. Drawn only; never moves `position`.
func celebrate(success: bool) -> void:
	_celebrate_ok = success
	_celebrate_left = CELEBRATE_SECONDS
	queue_redraw()


func is_celebrating() -> bool:
	return _celebrate_left > 0.0


func _celebrate_t() -> float:
	return 1.0 - _celebrate_left / CELEBRATE_SECONDS


func _draw_celebration() -> void:
	if _celebrate_left <= 0.0:
		return
	var t := _celebrate_t()
	var fade := 1.0 - t
	if _celebrate_ok:
		var gold := UIStyle.ACCENT
		draw_arc(Vector2.ZERO, lerpf(8.0, 90.0, t), 0, TAU, 48, Color(gold, fade), 3.0)
		for i in 16:
			var a := TAU * i / 16.0 + t * 1.5
			var dir := Vector2.from_angle(a)
			var r0 := lerpf(10.0, 70.0, t)
			draw_line(dir * r0, dir * (r0 + 14.0), Color(gold, fade), 2.0)
	else:
		draw_arc(Vector2.ZERO, lerpf(70.0, 8.0, t), 0, TAU, 48, Color(0.55, 0.15, 0.12, fade), 3.0)


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	if direction != Vector2.ZERO:
		_facing = direction.normalized()
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
	_draw_celebration()
	var shake := 0.0
	if _celebrate_left > 0.0 and not _celebrate_ok and _celebrate_t() * CELEBRATE_SECONDS < SHAKE_SECONDS:
		shake = sin(_celebrate_t() * CELEBRATE_SECONDS * 80.0) * 4.0
	_draw_companion()
	var robe: Color = _look.get("robe", PlayerLook.ROGUE_ROBE)
	var sash: Color = _look.get("sash", PlayerLook.SASH_COLORS["neutral"])
	var outline := Color("3b2f1e")
	_draw_aura()
	# Shadow stays on the ground; the body bobs while walking.
	draw_set_transform(Vector2(0, RADIUS - 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var bob := -absf(sin(_time * BOB_SPEED)) * BOB_PIXELS if velocity != Vector2.ZERO else 0.0
	var o := Vector2(shake, bob)
	# Robe: a flared trapezoid with a sash across the waist.
	var robe_shape := PackedVector2Array([o + Vector2(-7, -6), o + Vector2(7, -6), o + Vector2(12, 12), o + Vector2(-12, 12)])
	draw_colored_polygon(robe_shape, robe)
	robe_shape.append(robe_shape[0])
	draw_polyline(robe_shape, outline, 1.5)
	draw_line(o + Vector2(-9, 2), o + Vector2(9, 2), sash, 3.0)
	# Head, hair bun and a face that looks where the player walks.
	var head := o + Vector2(0, -12)
	draw_circle(head, 7.0, Color("e8d9a8"))
	draw_arc(head, 7.0, 0, TAU, 24, outline, 1.5)
	var away := -_facing * 4.0 if _facing.y > -0.5 else Vector2(0, -2)
	draw_circle(head + away + Vector2(0, -3), 3.5, Color("2a2018"))
	if _facing.y > -0.5:
		var eyes := head + Vector2(_facing.x * 3.0, 1.0 + _facing.y)
		draw_circle(eyes + Vector2(-2.5, 0), 1.0, outline)
		draw_circle(eyes + Vector2(2.5, 0), 1.0, outline)


## A spirit beast companion trots a step behind the player (BEAST-001b).
func _draw_companion() -> void:
	if not GameState.has_session() or GameState.player.companions.is_empty():
		return
	var at := -_facing * 22.0 + Vector2(10, 6)
	var hop := -absf(sin(_time * BOB_SPEED + 1.0)) * 2.0 if velocity != Vector2.ZERO else 0.0
	at.y += hop
	draw_set_transform(at + Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var fur := Color("b9a07a")
	draw_circle(at, 6.0, fur)
	draw_circle(at + Vector2(signf(-_facing.x + 0.01) * -5.0, -4.0), 4.0, fur.lightened(0.15))
	draw_arc(at, 6.0, 0, TAU, 16, Color("3b2f1e"), 1.2)


## Pulsing qi rings at the feet: one per realm above mortal (PlayerLook).
func _draw_aura() -> void:
	var rings := int(_look.get("aura_rings", 0))
	if rings <= 0:
		return
	var aura: Color = _look["aura"]
	var pulse := 0.5 + 0.5 * sin(_time * AURA_SPEED)
	var glow := 0.35 if _celebrate_left > 0.0 and _celebrate_ok else 0.0
	draw_set_transform(Vector2(0, RADIUS - 2), 0.0, Vector2(1.0, 0.45))
	for i in rings:
		var r := RADIUS + 4.0 + i * 5.0 + pulse * 2.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(aura, minf(1.0, 0.55 - 0.1 * i + glow)), 2.0)
	draw_set_transform(Vector2.ZERO)
