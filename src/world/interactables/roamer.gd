class_name Roamer
extends Interactable
## WU-423: a wild beast you can see (Wildlife.roamers). It wanders slowly near its spot, faces its
## movement and stays put in storms. Walking up offers Fight / Leave; Fight calls GameState.engage_roamer.
## Spots are seeded from region, day and slot with a local rng (never GameState.rng).

const WANDER_RADIUS := 80.0
const WALK_SPEED := 22.0
const MIN_GAP := 48.0
const FADE_SECONDS := 0.4
const FLEE_RANGE := 120.0
const FLEE_SPEED := 132.0  # 0.6x the player's 220
const NOTICE_RANGE := 160.0
const CHARGE_SPEED := 110.0
const TOUCH_RANGE := 44.0
const GREAT_GOLD := Color("f2c94c")
const GREAT_SCALE := 1.5
const WORLD_SCRIPT := preload("res://src/world/world.gd")

var slot := 0
var enemy_id := ""
var home := Vector2.ZERO
var facing := 1.0
var _rng := RandomNumberGenerator.new()
var _target := Vector2.ZERO
var _wait := 0.0
var _time := 0.0
var _fading := false
var _alpha := 1.0
## WU-424: how the beast reacts to the player (flees/wary/bold), read from GameState.roamer_temper.
var temper := ""
var player_ref: Node2D
var map_bounds := Vector2(100000, 100000)
var blocked_rects: Array[Rect2] = []  # WU-429: houses, ponds and paths a fleeing beast will not enter
var noticed := false
var great := false  # WU-430: the WILD-006 great beast: 1.5x, gold ring, gold "(great)" name
var charged := false  # WU-426: the open menu came from this beast's own charge
var asked := false  # a bold beast opens its menu once per beast per day (nodes are rebuilt daily)


## Setup before add_child: the beast `enemy_id` of roamer `slot` standing at `pos`.
func setup(p_slot: int, p_enemy: String, pos: Vector2, seed_value: int, p_great: bool = false) -> void:
	slot = p_slot
	great = p_great
	enemy_id = p_enemy
	position = pos
	home = pos
	_target = pos
	_rng.seed = seed_value
	_wait = _rng.randf_range(0.5, 3.0)
	size = Vector2(48, 32)
	reach = 22.0
	art_kind = "roamer"
	_update_name()
	if GameState.has_session():
		temper = GameState.roamer_temper(slot)


func _ready() -> void:
	super._ready()
	EventBus.player_changed.connect(_update_name)


func _update_name() -> void:
	var def: Dictionary = GameState.data.enemies.get(enemy_id, {})
	var title := String(def.get("name", enemy_id))
	if GameState.has_session() and GameState.data.enemies.has(enemy_id):
		title = "%s (%s)" % [title, Wildlife.threat(GameState.player, GameState.data, enemy_id)]
	if great:
		title += " (great)"
	display_name = title
	_redraw_label()


func label_text() -> String:
	return display_name


func label_color() -> Color:
	return GREAT_GOLD if great else Color.WHITE


func get_options() -> Array[Dictionary]:
	var was_charge := charged
	charged = false
	return [
		{"label": "Fight", "description": "Take the beast on now.", "action": GameState.engage_roamer.bind(slot, was_charge)},
		{"label": "Leave", "description": "Walk away and let it be."},
	]


func _physics_process(delta: float) -> void:
	_wander(delta)
	if _fading:
		_alpha = maxf(0.0, _alpha - delta / FADE_SECONDS)
		modulate.a = _alpha
		if _alpha <= 0.0:
			queue_free()


## Starts the short fade after the beast is gone for the day; the node frees itself.
func fade_out() -> void:
	_fading = true
	monitoring = false
	if MotionFx.reduced():
		queue_free()


## Wanders slowly within WANDER_RADIUS of home. Still in a storm, while fading or with a modal open.
func _wander(delta: float) -> void:
	if _fading or storm_still():
		return
	_time += delta
	if _react(delta):
		return
	if position.distance_to(_target) < 2.0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = _rng.randf_range(1.5, 4.0)
			var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, WANDER_RADIUS)
			_target = home + offset
			_target = Vector2(maxf(24.0, _target.x), maxf(24.0, _target.y))
		return
	var step := (_target - position).normalized() * minf(WALK_SPEED * delta, position.distance_to(_target))
	position += step
	if absf(step.x) > 0.01:
		facing = 1.0 if step.x > 0.0 else -1.0
	queue_redraw()


## WU-424: temper-driven movement. Returns true when it moved the beast this frame.
func _react(delta: float) -> bool:
	if player_ref == null or not is_instance_valid(player_ref):
		return false
	var to_player := player_ref.position - position
	var dist := to_player.length()
	match temper:
		"flees":
			if dist < FLEE_RANGE and dist > 0.01:
				var step := -to_player.normalized() * FLEE_SPEED * delta
				position = flee_position(position, step, map_bounds, blocked_rects)
				home = position
				_target = position
				facing = 1.0 if step.x > 0.0 else -1.0
				queue_redraw()
				return true
		"wary":
			if dist < NOTICE_RANGE and absf(to_player.x) > 1.0:
				var f := 1.0 if to_player.x > 0.0 else -1.0
				if f != facing:
					facing = f
					queue_redraw()
		"bold":
			if not asked and dist < NOTICE_RANGE:
				if not noticed:
					noticed = true
					queue_redraw()
				if dist <= TOUCH_RANGE:
					asked = true
					noticed = false
					queue_redraw()
					if bool(player_ref.get("input_enabled")):
						charged = true
						EventBus.interaction_menu_requested.emit(self)
					return true
				position += to_player.normalized() * minf(CHARGE_SPEED * delta, dist)
				home = position
				_target = position
				facing = 1.0 if to_player.x > 0.0 else -1.0
				queue_redraw()
				return true
			elif noticed and dist >= NOTICE_RANGE:
				noticed = false
				queue_redraw()
	return false


## WU-429: `pos` moved by `step`, kept in the map and out of `blocked`. A blocked step slides along the other axis, else stops.
static func flee_position(pos: Vector2, step: Vector2, bounds: Vector2, blocked: Array[Rect2]) -> Vector2:
	var full := Vector2(clampf(pos.x + step.x, 24.0, bounds.x - 24.0), clampf(pos.y + step.y, 24.0, bounds.y - 24.0))
	if not _in_blocked(full, blocked):
		return full
	var sx := Vector2(full.x, pos.y)
	if not _in_blocked(sx, blocked):
		return sx
	var sy := Vector2(pos.x, full.y)
	if not _in_blocked(sy, blocked):
		return sy
	return pos


static func _in_blocked(p: Vector2, blocked: Array[Rect2]) -> bool:
	for r in blocked:
		if r.has_point(p):
			return true
	return false


## Beasts stay put when the world has a storm today.
func storm_still() -> bool:
	if not GameState.has_session():
		return false
	return WORLD_SCRIPT.weather_today(GameState.data, GameState.current_region, GameClock.total_days) == "storm"


func draw_generated_art() -> bool:
	var fur := DuelStage.fur_for(enemy_id)
	var frame := int(_time * 3.0) % 2 if position.distance_to(_target) >= 2.0 else 0
	var tex := PixelFigure.beast_frame(fur, frame, DuelStage.beast_kind(enemy_id))
	var k := 2.0 * (GREAT_SCALE if great else 1.0)
	var s := tex.get_size() * k
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.4))
	if great:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(GREAT_GOLD, 0.7), 2.5)
		draw_circle(Vector2.ZERO, 30.0, Color(GREAT_GOLD, 0.12))
	draw_circle(Vector2.ZERO, 16.0 * (GREAT_SCALE if great else 1.0), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	draw_texture_rect(tex, Rect2(-s.x / 2.0, 12.0 - s.y, s.x, s.y), false)
	draw_set_transform(Vector2.ZERO)
	if noticed:
		draw_string(ThemeDB.fallback_font, Vector2(-4, 12.0 - s.y - 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1.0, 0.35, 0.25))
	return true


## Spot for `slot`: >= MIN_GAP from every blocked rect, kept inside the map. Same inputs, same spot.
static func pick_spot(region_id: String, day: int, slot: int, map_size: Vector2, blocked: Array[Rect2], avoid: Array[Vector2]) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [region_id, day, slot])
	var spot := Vector2(map_size.x / 2.0, map_size.y / 2.0)
	for i in 60:
		spot = Vector2(rng.randf_range(100.0, map_size.x - 100.0), rng.randf_range(100.0, map_size.y - 100.0))
		var ok := true
		for r in blocked:
			if r.grow(MIN_GAP).has_point(spot):
				ok = false
				break
		for p in avoid:
			if ok and spot.distance_to(p) < MIN_GAP + 60.0:
				ok = false
		if ok:
			return spot
	return spot
