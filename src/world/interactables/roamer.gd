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
const GREAT_SCALE := 1.6  # GFX-077
const GREAT_LABEL_GAP := 6.0
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
var great := false  # WU-430: the WILD-006 great beast: 1.6x, aura ring, gold "(great)" name
var charged := false  # WU-426: the open menu came from this beast's own charge
var asked := false  # a bold beast opens its menu once per beast per day (nodes are rebuilt daily)


## Setup before add_child: the beast `enemy_id` of roamer `slot` standing at `pos`.
func setup(p_slot: int, p_enemy: String, pos: Vector2, seed_value: int, p_great: bool = false) -> void:
	slot = p_slot
	great = p_great
	if great:
		add_to_group("great_roamer")  # GFX-075: the edge arrow looks for it
	enemy_id = p_enemy
	position = pos
	home = pos
	_target = pos
	_rng.seed = seed_value
	_wait = _rng.randf_range(0.5, 3.0)
	size = box_size(great)
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
	var threat := ""
	if GameState.has_session() and GameState.data.enemies.has(enemy_id):
		threat = Wildlife.threat(GameState.player, GameState.data, enemy_id)
	display_name = label_for(String(def.get("name", enemy_id)), threat, great)
	_redraw_label()


## GFX-077: the interaction/highlight box; a great beast's matches its larger drawn sprite.
static func box_size(is_great: bool) -> Vector2:
	return Vector2(48, 32) * (GREAT_SCALE if is_great else 1.0)


## GFX-077: a great beast's label sits GREAT_LABEL_GAP higher so it never touches a neighbour's.
func label_rect(text: String = "") -> Rect2:
	var r := super.label_rect(text)
	if great:
		r.position.y -= GREAT_LABEL_GAP
	return r


## GFX-057: "Wolf (Easy)"; a great beast reads "Great Cloud Crane (Deadly)" (the threat stays in one bracket).
static func label_for(beast_name: String, threat: String, is_great: bool) -> String:
	var title := ("Great " + beast_name) if is_great else beast_name
	return "%s (%s)" % [title, threat] if threat != "" else title


## GFX-075: the beast's plain name for the edge arrow ("Cloud Crane").
func short_name() -> String:
	return String(GameState.data.enemies.get(enemy_id, {}).get("name", enemy_id))


## GFX-075: the danger colour of this beast against the player.
func danger_color() -> Color:
	if not GameState.has_session() or not GameState.data.enemies.has(enemy_id):
		return Color.WHITE
	return UIStyle.danger_color(Wildlife.threat(GameState.player, GameState.data, enemy_id))


func label_text() -> String:
	return display_name


func label_color() -> Color:
	return GREAT_GOLD if great else Color.WHITE


func get_options() -> Array[Dictionary]:
	var was_charge := charged
	charged = false
	var desc := "Take the beast on now."
	if GameState.has_session():
		var notes := Wildlife.quarry_notes(GameState.player, GameState.data, enemy_id)
		if notes != "":
			desc += " " + notes + "."
	return [
		{"label": "Fight", "description": desc, "action": GameState.engage_roamer.bind(slot, was_charge)},
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
		var tint := danger_color()
		var pulse := 0.0 if MotionFx.reduced() else sin(_pulse_time * 1.2) * 0.5 + 0.5
		draw_circle(Vector2.ZERO, 40.0, Color(tint, 0.06 + 0.05 * pulse))
		draw_arc(Vector2.ZERO, 40.0 + 3.0 * pulse, 0.0, TAU, 48, Color(tint, 0.35 + 0.2 * pulse), 2.0)
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, 16.0 * (GREAT_SCALE if great else 1.0), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	draw_texture_rect(tex, Rect2(-s.x / 2.0, 12.0 - s.y, s.x, s.y), false)
	draw_set_transform(Vector2.ZERO)
	if noticed:
		draw_string(ThemeDB.fallback_font, Vector2(-4, 12.0 - s.y - 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1.0, 0.35, 0.25))
	return true


const KEEP_CLEAR := 90.0
const PICK_TRIES := 60


## GFX-062: rects (grown by KEEP_CLEAR) and points a roamer must not spawn near: every place and NPC home point.
static func keep_clear_zones(region: Dictionary) -> Dictionary:
	var rects: Array[Rect2] = []
	for place: Dictionary in region.get("places", []):
		var sz := Vector2(float(place.get("size", [64, 64])[0]), float(place.get("size", [64, 64])[1]))
		var pos := Vector2(float(place.get("pos", [0, 0])[0]), float(place.get("pos", [0, 0])[1]))
		rects.append(Rect2(pos - sz / 2.0, sz).grow(KEEP_CLEAR))
	var points: Array[Vector2] = []
	for spot: Array in region.get("npc_spots", []):
		points.append(Vector2(float(spot[0]), float(spot[1])))
	return {"rects": rects, "points": points}


## Spot for `slot`: >= MIN_GAP from every blocked rect, kept inside the map. Same inputs, same spot.
## GFX-062: also outside `clear_rects` and KEEP_CLEAR from `clear_points` (soft: when no try clears them, the try
## farthest from them wins, but only among tries that respect `blocked` and `avoid`).
## REVIEW: the fallback used to ignore `blocked`, so a beast could stand inside a house or wall.
static func pick_spot(region_id: String, day: int, slot: int, map_size: Vector2, blocked: Array[Rect2], avoid: Array[Vector2], clear_rects: Array[Rect2] = [], clear_points: Array[Vector2] = []) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [region_id, day, slot])
	var best := Vector2(map_size.x / 2.0, map_size.y / 2.0)
	var best_score := -1e9
	var best_hard := false
	for i in PICK_TRIES:
		var spot := Vector2(rng.randf_range(100.0, map_size.x - 100.0), rng.randf_range(100.0, map_size.y - 100.0))
		var hard := true
		for r in blocked:
			if r.grow(MIN_GAP).has_point(spot):
				hard = false
		for p in avoid:
			if spot.distance_to(p) < MIN_GAP + 60.0:
				hard = false
		var score := 1e9
		for r in clear_rects:
			score = minf(score, maxf(maxf(r.position.x - spot.x, spot.x - r.end.x), maxf(r.position.y - spot.y, spot.y - r.end.y)))
		for p in clear_points:
			score = minf(score, spot.distance_to(p) - KEEP_CLEAR)
		if hard and score >= 0.0:
			return spot
		if (hard and not best_hard) or (hard == best_hard and score > best_score):
			best_hard = hard
			best_score = score
			best = spot
	return best
