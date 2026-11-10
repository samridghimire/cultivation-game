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
var _camera_shake_left := 0.0

const CAMERA_SHAKE_SECONDS := 0.3
const CAMERA_SHAKE_PIXELS := 4.0


func _ready() -> void:
	add_to_group("player")
	EventBus.player_changed.connect(refresh_look)
	EventBus.session_started.connect(refresh_look)
	EventBus.breakthrough_attempted.connect(_on_breakthrough_attempted)
	refresh_look.call_deferred()


## Re-reads the player's sect, alignment and realm for the placeholder art.
func refresh_look() -> void:
	if GameState.has_session():
		_look = PlayerLook.of(GameState.player, GameState.data)
	queue_redraw()


func _process(delta: float) -> void:
	var phase := int(_time * 2.0) % 2
	_time += delta
	if int(_time * 2.0) % 2 != phase and not MotionFx.reduced():
		queue_redraw()  # GFX-117: idle bob frame changed
	_update_camera_shake(delta)
	if _celebrate_left > 0.0:
		_celebrate_left = maxf(0.0, _celebrate_left - delta)
		queue_redraw()
	if velocity != Vector2.ZERO or int(_look.get("aura_rings", 0)) > 0:
		queue_redraw()


## A successful breakthrough shakes the camera 4 px for 0.3 s (WU-397).
func _update_camera_shake(delta: float) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null or (_camera_shake_left <= 0.0 and camera.offset == Vector2.ZERO):
		return
	_camera_shake_left = maxf(0.0, _camera_shake_left - delta)
	camera.offset = MotionFx.shake_offset(CAMERA_SHAKE_SECONDS - _camera_shake_left, CAMERA_SHAKE_SECONDS, CAMERA_SHAKE_PIXELS, MotionFx.reduced())


## Breakthrough effect (WU-063): a gold ring and rays on success, a dull
## contracting ring and a sideways shake on failure. Drawn only; never moves `position`.
func _on_breakthrough_attempted(success: bool, _realm: String) -> void:
	celebrate(success)


func celebrate(success: bool) -> void:
	_celebrate_ok = success
	if success and not MotionFx.reduced():
		_camera_shake_left = CAMERA_SHAKE_SECONDS
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
		if _target.use_directly():  # WU-427: a pickup is used without a menu
			return
		EventBus.interaction_menu_requested.emit(_target)


## The interactable the interact prompt names right now (null when none).
func current_target() -> Interactable:
	return _target if is_instance_valid(_target) else null


func add_interactable(i: Interactable) -> void:
	if not _nearby.has(i):
		_nearby.append(i)


func remove_interactable(i: Interactable) -> void:
	_nearby.erase(i)


func _update_target() -> void:
	_nearby = _nearby.filter(func(i: Interactable) -> bool: return is_instance_valid(i) and not i.is_queued_for_deletion())
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
		EventBus.interaction_target_changed.emit(best.prompt_text() if best else "")


## GFX-117: set by the world when the ground is snowy (snow-blue shadow).
var snowy := false


## GFX-117: a gentle 2-frame idle bob (0 or -1 px, about once a second); none when motion is reduced.
static func idle_bob(t: float, reduced: bool) -> float:
	return 0.0 if reduced or int(t * 2.0) % 2 == 0 else -1.0


## GFX-101: the player figure's 1 px silhouette outline.
const OUTLINE_COLOR := Color("f3e6c4")


func _draw() -> void:
	_draw_celebration()
	var shake := 0.0
	if not MotionFx.reduced() and _celebrate_left > 0.0 and not _celebrate_ok and _celebrate_t() * CELEBRATE_SECONDS < SHAKE_SECONDS:
		shake = sin(_celebrate_t() * CELEBRATE_SECONDS * 80.0) * 4.0
	_draw_companion()
	var sash: Color = _look.get("sash", PlayerLook.SASH_COLORS["neutral"])
	_draw_aura()
	# Shadow stays on the ground; the body bobs while walking.
	var sh := Scenery.figure_shadow(Vector2(RADIUS * 2.0 + 8.0, RADIUS * 2.0), snowy)  # GFX-117: same helper as villagers
	var shc := Scenery.figure_shadow_color(snowy)
	PlaceArt.ellipse(self, Vector2(0, 11.0), sh.size / 2.0 * 1.15, Color(shc, 0.18))
	PlaceArt.ellipse(self, Vector2(0, 11.0), sh.size / 2.0, shc)
	var bob := -absf(sin(_time * BOB_SPEED)) * BOB_PIXELS if velocity != Vector2.ZERO else idle_bob(_time, MotionFx.reduced())
	var o := Vector2(shake, bob)
	_draw_cake(o)
	if _draw_sprite(o, sash):
		return
	# Generated pixel figure (GFX-011), feet on the hem line.
	var tex := PixelFigure.frame(_look, _dir_name(), int(_time * 6.0) if velocity != Vector2.ZERO else 0)
	var s := float(Sprites.scale())
	var size := Vector2(tex.get_size()) * s
	var body := Rect2(o + Vector2(-size.x / 2.0, 12.0 - size.y), size)
	var sil := PixelFigure.silhouette(tex, OUTLINE_COLOR)  # GFX-101: pale outline so you can find yourself in a crowd
	for d: Vector2 in [Vector2(s, 0), Vector2(-s, 0), Vector2(0, s), Vector2(0, -s)]:
		draw_texture_rect(sil, Rect2(body.position + d, size), false)
	draw_texture_rect(tex, body, false)


## WU-494: true on the player's own birthday (FOLK-027); pure so tests can pass any day.
static func shows_cake(c: CharacterData, data: GameData, day: int) -> bool:
	return c != null and Folk.player_birthday_today(c, data, day)


## WU-494: the friend cake marker (WU-482, same art) over the player's head on their birthday.
func _draw_cake(o: Vector2) -> void:
	if not GameState.has_session() or not shows_cake(GameState.player, GameState.data, GameClock.total_days):
		return
	var tex := HudIcons.calendar_kind("birthday")
	if tex == null:
		return
	var w := tex.get_width() * 2.0
	draw_texture_rect(tex, Rect2(o + Vector2(-w / 2.0, -58.0), Vector2(w, tex.get_height() * 2.0)), false)


## "down", "up", "left" or "right" from the facing vector.
func _dir_name() -> String:
	if absf(_facing.x) > absf(_facing.y):
		return "right" if _facing.x > 0.0 else "left"
	return "up" if _facing.y < 0.0 else "down"


## Draws the pixel-art player sprite (GFX-001) when data/sprites.json maps one for the facing; false means "use the placeholder".
func _draw_sprite(o: Vector2, sash: Color) -> bool:
	var key := "player_" + _dir_name()
	var index := int(_time * Sprites.fps(key)) if velocity != Vector2.ZERO else 0
	var tex := Sprites.frame(key, index)
	if tex == null:
		return false
	var s := float(Sprites.scale())
	var size := tex.get_size() * s
	# Centred on the feet (the placeholder robe hem sits at y=12); the sash line keeps sect and alignment readable.
	draw_texture_rect(tex, Rect2(o + Vector2(-size.x / 2.0, 12.0 - size.y), size), false)
	draw_line(o + Vector2(-size.x * 0.3, 12.0 - size.y * 0.35), o + Vector2(size.x * 0.3, 12.0 - size.y * 0.35), sash, 2.0)
	return true


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
