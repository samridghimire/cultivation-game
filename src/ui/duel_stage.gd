class_name DuelStage
extends Control
## The two fighters above the fight report's hp bars (WU-396). The player stands on the
## left, the foe on the right; `blow()` lunges the striker and flashes the struck one,
## `show_end_pose()` leaves the loser dimmed and toppled. Placeholder art drawn in _draw().

const LUNGE := 24.0
const LUNGE_SECONDS := 0.12
const FOE_ROBE := Color("3a2f3d")

var _foe_beast: bool = false
var _foe_texture: Texture2D
var _offset: Array[float] = [0.0, 0.0]  # [player, foe] x offsets
var _shake: Array[float] = [0.0, 0.0]
var _flash: Array[float] = [0.0, 0.0]
var _alpha: Array[float] = [1.0, 1.0]
var _tilt: Array[float] = [0.0, 0.0]
var _tween: Tween
var _stage_shake_start := -1.0  # ticks (s) when the heavy-hit shake began

const STAGE_SHAKE_SECONDS := 0.15
const STAGE_SHAKE_PIXELS := 3.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 96)
	visible = false


## 1 when the foe's hp dropped (the player hit), -1 when the player's dropped, else 0.
static func blow_side(prev: Array, cur: Array) -> int:
	if prev.size() < 2 or cur.size() < 2:
		return 0
	if int(cur[1]) < int(prev[1]):
		return 1
	if int(cur[0]) < int(prev[0]):
		return -1
	return 0


## Picks the foe's art: a mapped `enemy_<id>`/`enemy` sprite, a beast silhouette for
## enemies tagged "beast", otherwise a robed cultivator. Resets both fighters.
func setup(enemy_id: String, tags: Array) -> void:
	_foe_beast = tags.has("beast")
	_foe_texture = null
	if enemy_id != "":
		_foe_texture = Sprites.first(PackedStringArray(["enemy_" + enemy_id, "enemy"]))
	reset_pose()


func reset_pose() -> void:
	if _tween != null:
		_tween.kill()
	_offset = [0.0, 0.0]
	_shake = [0.0, 0.0]
	_flash = [0.0, 0.0]
	_alpha = [1.0, 1.0]
	_tilt = [0.0, 0.0]
	_stage_shake_start = -1.0
	queue_redraw()


## `side` as from blow_side: 1 the player strikes, -1 the foe strikes, 0 nothing.
func blow(side: int, crit: bool = false, heavy: bool = false) -> void:
	if side == 0 or not is_inside_tree():
		return
	var striker := 0 if side == 1 else 1
	var struck := 1 - striker
	var dir := 1.0 if striker == 0 else -1.0
	if _tween != null:
		_tween.kill()
	_offset = [0.0, 0.0]
	_flash = [0.0, 0.0]
	_shake = [0.0, 0.0]
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_offset.bind(striker), 0.0, dir * LUNGE, LUNGE_SECONDS / 2.0)
	_tween.tween_method(_set_offset.bind(striker), dir * LUNGE, 0.0, LUNGE_SECONDS / 2.0).set_delay(LUNGE_SECONDS / 2.0)
	if MotionFx.reduced():
		return
	_tween.tween_method(_set_flash.bind(struck), 1.0, 0.0, LUNGE_SECONDS * 2.0)
	_tween.tween_method(_set_shake.bind(struck), 6.0 if crit else 3.0, 0.0, LUNGE_SECONDS * 2.0)
	if heavy:
		_stage_shake_start = Time.get_ticks_msec() / 1000.0
		_tween.tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, STAGE_SHAKE_SECONDS)


func _set_offset(v: float, who: int) -> void:
	_offset[who] = v
	queue_redraw()


func _set_flash(v: float, who: int) -> void:
	_flash[who] = v
	queue_redraw()


func _set_shake(v: float, who: int) -> void:
	_shake[who] = v
	queue_redraw()


## The end pose: the loser at 40% alpha and toppled; on a friendly spar both stand.
func show_end_pose(victory: bool, friendly: bool) -> void:
	reset_pose()
	if not friendly:
		var loser := 1 if victory else 0
		_alpha[loser] = 0.4
		_tilt[loser] = PI / 2.0
	queue_redraw()


## The loser's alpha, for tests: 0 = player, 1 = foe.
func alpha_of(who: int) -> float:
	return _alpha[who]


func _draw() -> void:
	var base_y := size.y - 14.0 + _stage_offset().y
	var dx := _stage_offset().x
	_draw_fighter(0, Vector2(size.x * 0.25 + dx, base_y))
	_draw_fighter(1, Vector2(size.x * 0.75 + dx, base_y))


## The whole-stage offset of a heavy hit's 3 px, 0.15 s shake.
func _stage_offset() -> Vector2:
	if _stage_shake_start < 0.0:
		return Vector2.ZERO
	var elapsed := Time.get_ticks_msec() / 1000.0 - _stage_shake_start
	return MotionFx.shake_offset(elapsed, STAGE_SHAKE_SECONDS, STAGE_SHAKE_PIXELS, MotionFx.reduced())


func _draw_fighter(who: int, feet: Vector2) -> void:
	var jitter := _shake[who] * sin(Time.get_ticks_msec() * 0.09)
	var pos := feet + Vector2(_offset[who] + jitter, 0.0)
	var tex: Texture2D = _foe_texture if who == 1 else Sprites.texture("player_right")
	var tint := Color(1, 1, 1, _alpha[who]).lerp(Color(3, 3, 3, _alpha[who]), _flash[who])
	draw_set_transform(pos, _tilt[who] * (-1.0 if who == 1 else 1.0), Vector2.ONE)
	if tex != null:
		var z := float(Sprites.scale()) * 2.0
		draw_texture_rect(tex, Rect2(Vector2(-tex.get_width() * z / 2.0, -tex.get_height() * z), tex.get_size() * z), false, tint)
	elif who == 1 and _foe_beast:
		_draw_beast(tint)
	else:
		_draw_person(who, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tinted(c: Color, tint: Color) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a)


func _draw_person(who: int, tint: Color) -> void:
	var robe := FOE_ROBE
	var sash := Color("7a2a2a")
	if who == 0:
		robe = PlayerLook.ROGUE_ROBE
		sash = PlayerLook.SASH_COLORS["neutral"]
		if GameState.player != null and GameState.data != null:
			var look := PlayerLook.of(GameState.player, GameState.data)
			robe = look["robe"]
			sash = look["sash"]
	draw_rect(Rect2(-14, -52, 28, 38), _tinted(robe, tint))
	draw_rect(Rect2(-14, -36, 28, 5), _tinted(sash, tint))
	draw_rect(Rect2(-9, -14, 7, 14), _tinted(robe.darkened(0.3), tint))
	draw_rect(Rect2(2, -14, 7, 14), _tinted(robe.darkened(0.3), tint))
	draw_circle(Vector2(0, -62), 10.0, _tinted(Color("e0b890"), tint))


func _draw_beast(tint: Color) -> void:
	var fur := Color("6b5a48")
	draw_rect(Rect2(-26, -38, 52, 22), _tinted(fur, tint))
	draw_circle(Vector2(-26, -34), 11.0, _tinted(fur.lightened(0.08), tint))
	for x in [-22.0, -10.0, 10.0, 20.0]:
		draw_rect(Rect2(x, -16, 6, 16), _tinted(fur.darkened(0.3), tint))
	draw_rect(Rect2(24, -42, 12, 5), _tinted(fur, tint))
