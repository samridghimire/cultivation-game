class_name BreakthroughStage
extends Control
## GFX-258: the picture at the top of the breakthrough window: the player seated on a mat under a night sky while qi
## motes spiral in, a dim ghost of the heart vision while one is pending, and a short success or failure beat when
## the attempt is made. Drawn in code at 2x; mote positions are a pure function of the phase (no rng).

signal attempt_finished

const W := 480
const H := 128
const SEAT_X := 240.0
const BASE := 112.0
const MOTES := 16
const ATTEMPT_TIME := 1.4
const GATHER_END := 0.55  ## fraction of the attempt spent pulling motes in
const GHOST_FADE := 0.6

var _look: Dictionary = {}
var _target_realm := 1
var _vision := false
var _ghost_alpha := 0.0
var _phase := 0.0
var _mote_color := Color(0.95, 0.85, 0.5)
var _t := -1.0  ## attempt progress in seconds; < 0 when idle
var _success := true
var _frozen := false  ## debug_set_phase holds the picture still for screenshots
var _result := 0  ## 0 none, 1 success, -1 failure: how the player is drawn after the beat


func _init() -> void:
	custom_minimum_size = Vector2(W, H)


## `look` is a PlayerLook dictionary, `target_realm` the realm index being reached.
func setup(look: Dictionary, target_realm: int, vision: bool, mote_color: Color = Color(0.95, 0.85, 0.5)) -> void:
	_look = look
	_target_realm = target_realm
	_vision = vision
	_ghost_alpha = 0.45 if vision else 0.0
	_mote_color = mote_color
	_frozen = false
	_t = -1.0
	_result = 0
	queue_redraw()


func ghost_visible() -> bool:
	return _ghost_alpha > 0.0


func fade_vision() -> void:
	_vision = false


func is_playing() -> bool:
	return _t >= 0.0


func play_attempt(success: bool) -> void:
	_success = success
	_t = 0.0
	_vision = false
	_ghost_alpha = 0.0


## Ends the beat at once (the player pressed confirm or cancel).
func skip() -> void:
	if _t >= 0.0:
		_finish()


func debug_set_phase(t: float, success: bool) -> void:
	_success = success
	_t = t
	_frozen = true
	_ghost_alpha = 0.0
	queue_redraw()


func _finish() -> void:
	_t = -1.0
	_result = 1 if _success else -1
	queue_redraw()
	attempt_finished.emit()


func _process(delta: float) -> void:
	if _frozen:
		return
	_phase += delta
	if not _vision and _ghost_alpha > 0.0:
		_ghost_alpha = maxf(0.0, _ghost_alpha - delta * 0.45 / GHOST_FADE)
	if _t >= 0.0:
		_t += delta
		if _t >= ATTEMPT_TIME:
			_finish()
			return
	queue_redraw()


## Centre of mote `i` at `phase` seconds; `pull` 0..1 draws them into the player, `burst` 0..1 throws them out.
static func mote_pos(i: int, phase: float, pull: float, burst: float) -> Vector2:
	var a := phase * (0.6 + 0.05 * (i % 4)) + i * TAU / float(MOTES)
	var r := 40.0 + 14.0 * float(i % 5) + 6.0 * sin(phase + i)
	r = r * (1.0 - pull) + r * burst * 2.5
	var pos := Vector2(SEAT_X + cos(a) * r * 1.6, 70.0 + sin(a) * r * 0.55 - float(i % 3) * 6.0)
	pos.x = clampf(pos.x, 2.0, W - 6.0)
	pos.y = clampf(pos.y, 2.0, H - 6.0)
	return pos


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.13))
	for i in 18:  # stars
		var sx := float((i * 97 + 31) % W)
		var sy := float((i * 53 + 7) % 56)
		draw_rect(Rect2(sx, sy, 2, 2), Color(0.8, 0.85, 1.0, 0.45 + 0.35 * float(i % 3) / 2.0))
	if _target_realm >= 2:  # a faint ridge from Foundation Establishment up
		var ridge := PackedVector2Array([Vector2(0, 96), Vector2(60, 70), Vector2(120, 88), Vector2(200, 56), Vector2(280, 84), Vector2(360, 62), Vector2(430, 82), Vector2(W, 66), Vector2(W, 96)])
		draw_colored_polygon(ridge, Color(0.1, 0.11, 0.2))
	draw_rect(Rect2(0, 96, W, H - 96), Color(0.09, 0.09, 0.14))
	var pull := 0.0
	var burst := 0.0
	if _t >= 0.0:
		pull = clampf(_t / (ATTEMPT_TIME * GATHER_END), 0.0, 1.0)
		if not _success and _t > ATTEMPT_TIME * GATHER_END:
			burst = clampf((_t - ATTEMPT_TIME * GATHER_END) / (ATTEMPT_TIME * (1.0 - GATHER_END)), 0.0, 1.0)
			pull = 0.0
	var fade := 1.0 - burst if _success or burst == 0.0 else 1.0 - burst
	if _result == 0:
		for i in MOTES:
			var p := mote_pos(i, _phase, pull, burst)
			draw_rect(Rect2(p.x, p.y, 4, 4), Color(_mote_color, 0.85 * fade))
	# The mat and the seated player (standing frame cropped above the knees, darker lap band).
	var s := 3.0
	var tex := PixelFigure.frame(_look if _look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, "down", 0)
	var shade := Color.WHITE
	if _result == 1 or (_t >= 0.0 and _success and _t > ATTEMPT_TIME * GATHER_END):
		shade = Color(1.25, 1.2, 1.0)
	elif _result == -1 or (_t >= 0.0 and not _success and _t > ATTEMPT_TIME * GATHER_END):
		shade = Color(0.55, 0.5, 0.55)
	draw_rect(Rect2(SEAT_X - 34, BASE - 6, 68, 10), Color(0.55, 0.2, 0.18))
	draw_rect(Rect2(SEAT_X - 34, BASE - 6, 68, 3), Color(0.7, 0.35, 0.25))
	draw_texture_rect_region(tex, Rect2(SEAT_X - 24, BASE - 15 * s - 3, 16 * s, 15 * s), Rect2(0, 0, 16, 15), shade)
	draw_rect(Rect2(SEAT_X - 28, BASE - 12, 56, 6), Color(0, 0, 0, 0.3))  # lap band
	if _ghost_alpha > 0.0:  # the heart vision, facing the player from the right
		var gt := PixelFigure.frame({"robe": Color(0.5, 0.4, 0.7), "hair": Color(0.7, 0.7, 0.85)}, "left", 0)
		draw_texture_rect(gt, Rect2(SEAT_X + 70, BASE - 20 * s, 16 * s, 20 * s), false, Color(0.7, 0.6, 1.0, _ghost_alpha))
	if _t >= 0.0 and _t > ATTEMPT_TIME * GATHER_END:  # the flash
		var k := clampf((_t - ATTEMPT_TIME * GATHER_END) / (ATTEMPT_TIME * (1.0 - GATHER_END)), 0.0, 1.0)
		var flash := Color(1.0, 0.95, 0.7, 0.9 * (1.0 - k)) if _success else Color(0.8, 0.1, 0.1, 0.5 * (1.0 - k))
		draw_rect(Rect2(0, 0, W, H), flash)
