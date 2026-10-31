class_name DuelStage
extends Control
## The two fighters above the fight report's hp bars (WU-396). The player stands on the
## left, the foe on the right; `blow()` lunges the striker and flashes the struck one,
## `show_end_pose()` leaves the loser darkened and lying down. Placeholder art drawn in _draw().

const LUNGE := 24.0
const LUNGE_SECONDS := 0.12
const FOE_ROBE := Color("3a2f3d")
const FOE_SASH := Color("7a2a2a")
const BEAST_FURS := {"wolf": Color("8a8d92"), "boar": Color("5a4636"), "tiger": Color("b5652a"), "fox": Color("b5652a")}
const FALLEN_DARKEN := 0.3
const DEFAULT_FUR := Color("6b5a48")
const STAGE_HEIGHT := 182.0
const GROUND_BAND := 56.0
## Fighters stand this far above the stage bottom, mid-grass (GFX-036).
const FEET_INSET := 34.0
const RIM_LIGHTEN := 0.45
## Enemy id keywords -> PixelFigure beast kind, checked in order (GFX-028).
const BEAST_KEYWORDS := [
	["wolf", "wolf"], ["fox", "wolf"], ["dog", "wolf"], ["hound", "wolf"],
	["boar", "boar"], ["pig", "boar"],
	["tiger", "tiger"], ["leopard", "tiger"], ["cat", "tiger"],
	["snake", "snake"], ["serpent", "snake"], ["python", "snake"], ["viper", "snake"],
	["bird", "bird"], ["crow", "bird"], ["hawk", "bird"], ["crane", "bird"], ["eagle", "bird"], ["roc", "bird"], ["condor", "bird"],
]

## Region id -> backdrop silhouette kind (GFX-035); anything else gets low hills.
const SILHOUETTES := {
	"misty_forest": "pines", "azure_peak": "pines", "myriad_peaks_ridge": "pines",
	"qingshi_village": "roofs", "fallen_star_market": "roofs",
	"withered_bone_marsh": "reeds",
}
const DEFAULT_SILHOUETTE := "hills"
const SKY_BY_SEASON := {
	"spring": [Color("a9cde0"), Color("e3efe2")], "summer": [Color("7fb4dc"), Color("d6ebf2")],
	"autumn": [Color("c98a5e"), Color("f0d3a0")], "winter": [Color("c9d6e0"), Color("eef2f5")],
}

var _foe_beast: bool = false
var _foe_id: String = ""
var _foe_texture: Texture2D
var _offset: Array[float] = [0.0, 0.0]  # [player, foe] x offsets
var _shake: Array[float] = [0.0, 0.0]
var _flash: Array[float] = [0.0, 0.0]
var _alpha: Array[float] = [1.0, 1.0]
var _tilt: Array[float] = [0.0, 0.0]
var _dark: Array[float] = [0.0, 0.0]  # 0..1 darkening of a fallen fighter
var _tween: Tween
var _stage_shake_start := -1.0  # ticks (s) when the heavy-hit shake began

const STAGE_SHAKE_SECONDS := 0.15
const STAGE_SHAKE_PIXELS := 3.0


func _init() -> void:
	custom_minimum_size = Vector2(0, STAGE_HEIGHT)
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
	_foe_id = enemy_id
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
	_dark = [0.0, 0.0]
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


## The end pose: the loser lies on its side at full alpha, darkened 30%; on a friendly spar both stand.
func show_end_pose(victory: bool, friendly: bool) -> void:
	reset_pose()
	if not friendly:
		var loser := 1 if victory else 0
		_dark[loser] = FALLEN_DARKEN
		_tilt[loser] = toppled_tilt(loser == 1 and _foe_beast)
	queue_redraw()


## The loser's tilt (GFX-033): everyone lies on their side (90 degrees), beast or person, so the
## silhouette and its light rim stay readable instead of smearing.
static func toppled_tilt(_beast: bool) -> float:
	return PI / 2.0


## True when fighter `who` (0 player, 1 foe) is lying defeated, for the "Defeated" tag and tests.
func is_fallen(who: int) -> bool:
	return _dark[who] > 0.0


## The tilt of a fighter, for tests: 0 = player, 1 = foe.
func tilt_of(who: int) -> float:
	return _tilt[who]


## The fur colour of a beast by id: grey wolves, dark boars, rust tigers and foxes, brown otherwise.
static func fur_for(enemy_id: String) -> Color:
	for key in BEAST_FURS:
		if enemy_id.contains(key):
			return BEAST_FURS[key]
	return DEFAULT_FUR


## The beast silhouette kind for an enemy id ("" = the plain body).
static func beast_kind(enemy_id: String) -> String:
	for pair: Array in BEAST_KEYWORDS:
		if enemy_id.contains(pair[0]):
			return pair[1]
	return ""


var _rim_cache: Dictionary = {}


## `tex` with its top-edge outline pixels lightened to `rim`, so a dark fighter reads on the dark panel.
func _rimmed(tex: Texture2D, rim: Color) -> Texture2D:
	var key := "%d|%s" % [tex.get_instance_id(), rim.to_html()]
	if not _rim_cache.has(key):
		var img := tex.get_image()
		var out := img.duplicate() as Image
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and (y == 0 or img.get_pixel(x, y - 1).a == 0.0):
					out.set_pixel(x, y, rim)
		_rim_cache[key] = ImageTexture.create_from_image(out)
	return _rim_cache[key]


## The generated pixel texture for a fighter without a mapped sprite; the walk frame alternates while lunging.
func _pixel_texture(who: int) -> Texture2D:
	var step := 0
	if absf(_offset[who]) > 0.5:
		step = 1 + int(Time.get_ticks_msec() / 80) % 2
	if who == 1 and _foe_beast:
		var fur := fur_for(_foe_id)
		return _rimmed(PixelFigure.beast_frame(fur, step % 2, beast_kind(_foe_id)), fur.lightened(RIM_LIGHTEN))
	var look := {"robe": FOE_ROBE, "sash": FOE_SASH}
	if who == 0:
		look = {"robe": PlayerLook.ROGUE_ROBE, "sash": PlayerLook.SASH_COLORS["neutral"]}
		if GameState.player != null and GameState.data != null:
			look = PlayerLook.of(GameState.player, GameState.data)
	return _rimmed(PixelFigure.frame(look, "right", step), (look["robe"] as Color).lightened(RIM_LIGHTEN))


## How dark a fighter is drawn (0 = normal), for tests: 0 = player, 1 = foe.
func dark_of(who: int) -> float:
	return _dark[who]


## The loser's alpha, for tests: 0 = player, 1 = foe.
func alpha_of(who: int) -> float:
	return _alpha[who]


func _draw() -> void:
	_draw_ground()
	var base_y := size.y - FEET_INSET + _stage_offset().y
	var dx := _stage_offset().x
	for who in 2:
		var cx := size.x * (0.25 if who == 0 else 0.75) + dx + _offset[who]
		draw_set_transform(Vector2(cx, base_y), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.35 * _alpha[who]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fighter(0, Vector2(size.x * 0.25 + dx, base_y))
	_draw_fighter(1, Vector2(size.x * 0.75 + dx, base_y))
	for who in 2:
		if is_fallen(who):
			var font := ThemeDB.fallback_font
			var text := "Defeated"
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var cx2 := size.x * (0.25 if who == 0 else 0.75) + dx
			var top := fallen_rect(_body_size(who), Vector2(cx2, base_y), who == 1 and _foe_beast).position.y
			draw_string(font, Vector2(cx2 - w / 2.0, top - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8d9b0"))


## The axis-aligned bounds of a fallen fighter (GFX-036). `tex_size` is the standing body in
## drawn pixels, `feet` the ground point. A beast is flipped onto its back (same size, feet on
## the ground); a person is rotated 90 degrees about the body centre and dropped to the ground.
static func fallen_rect(tex_size: Vector2, feet: Vector2, beast: bool) -> Rect2:
	if beast:
		return Rect2(feet.x - tex_size.x / 2.0, feet.y - tex_size.y, tex_size.x, tex_size.y)
	return Rect2(feet.x - tex_size.y / 2.0, feet.y - tex_size.x, tex_size.y, tex_size.x)


## The standing body size in drawn pixels (mapped sprite, generated texture, or the shape fallback).
func _body_size(who: int) -> Vector2:
	var tex: Texture2D = _foe_texture if who == 1 else Sprites.texture("player_right")
	if tex == null:
		tex = _pixel_texture(who)
		return Vector2(tex.get_size()) * 3.0
	return Vector2(tex.get_size()) * float(Sprites.scale()) * 2.0


## The backdrop silhouette kind for a region id: pines, roofs, reeds, or the default hills.
static func silhouette_for(region_id: String) -> String:
	return String(SILHOUETTES.get(region_id, DEFAULT_SILHOUETTE))


## True when a real region is loaded, so the backdrop is drawn (false for sims).
func has_backdrop() -> bool:
	return GameState.data != null and GameState.data.regions.has(GameState.current_region)


## Sky gradient (top, horizon) for the season of the current day.
static func sky_colors(season: String) -> Array:
	return SKY_BY_SEASON.get(season, SKY_BY_SEASON["summer"])


func _draw_backdrop(map: Dictionary, rid: String) -> void:
	var top_h := size.y - GROUND_BAND
	var sky := sky_colors(Calendar.season_of(GameClock.total_days))
	var bands := 12
	for i in bands:
		var c: Color = (sky[0] as Color).lerp(sky[1], float(i) / float(bands - 1))
		draw_rect(Rect2(0.0, top_h * i / bands, size.x, ceilf(top_h / bands) + 1.0), c)
	var haze: Color = sky[1]
	var col := Color(map.get("ground", "4d6b3c")).darkened(0.45).lerp(haze, HAZE)
	var kind := silhouette_for(rid)
	var horizon := top_h
	var raining := false
	if get_tree() != null:
		var weather := Weather.of(GameState.data, rid, GameClock.total_days) if GameState.data != null else "clear"
		raining = weather == "rain" or weather == "storm"
	if raining:
		draw_rect(Rect2(0.0, 0.0, size.x, top_h), Color(0.12, 0.14, 0.2, 0.35))
	else:
		for c in cloud_shapes(rid, size.x, top_h):
			draw_set_transform(Vector2(c["x"], c["y"]), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, c["r"], Color(1, 1, 1, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var far := (map_ground_color(map).darkened(0.35)).lerp(haze, 0.7)  # distant mountain line
	for s in silhouette_shapes(rid + "_far", "hills", size.x):
		draw_circle(Vector2(s["x"], horizon + 34.0 - float(s["h"]) * 0.5), 60.0 + float(s["h"]) * 0.6, far)
	for s in silhouette_shapes(rid, kind, size.x):
		var x: float = s["x"]
		var w: float = s["w"]
		var h: float = s["h"]
		match kind:
			"pines":
				for row in int(h / PIXEL):
					var rw := (float(row) + 1.0) * PIXEL * 0.5 * (w / 34.0)
					draw_rect(Rect2(x - rw / 2.0, horizon - h + row * PIXEL, rw, PIXEL), col)
			"roofs":
				var wall := 12.0 + h * 0.2
				draw_rect(Rect2(x, horizon - wall, w, wall), col.darkened(0.15))
				var roof_h := h * 0.45
				var rows := int(roof_h / PIXEL)
				for row in rows:  # a trapezoid whose bottom row flares into upturned eaves
					var inset := float(row) * (w * 0.5 / maxf(rows, 1)) * 0.8
					draw_rect(Rect2(x - 6.0 + inset, horizon - wall - (row + 1) * PIXEL, w + 12.0 - inset * 2.0, PIXEL), col)
				draw_rect(Rect2(x - 9.0, horizon - wall - PIXEL - 3.0, 5.0, 3.0), col)
				draw_rect(Rect2(x + w + 4.0, horizon - wall - PIXEL - 3.0, 5.0, 3.0), col)
				if s.get("lantern", false):
					draw_rect(Rect2(x + w + 8.0, horizon - 34.0, 2.0, 34.0), col)
					draw_rect(Rect2(x + w + 5.0, horizon - 28.0, 8.0, 10.0), Color("e0a040").lerp(haze, 0.3))
			"reeds":
				draw_rect(Rect2(x, horizon - h, 2.0, h), col)
				if s.get("tuft", false):
					draw_rect(Rect2(x - 4.0, horizon - 14.0, 14.0, 14.0), col.lightened(0.15))
			_:
				draw_circle(Vector2(x, horizon + 20.0), w, col)


const HAZE := 0.45
const PIXEL := 4.0


static func map_ground_color(map: Dictionary) -> Color:
	return Color(map.get("ground", "4d6b3c"))


## A stable 0..1 value from a string seed and index (no rng: the same region always draws the same).
static func unit_hash(seed_text: String, k: int) -> float:
	return float(absi(hash(seed_text + ":" + str(k))) % 1000) / 999.0


## The backdrop silhouette pieces for a region (GFX-036): irregular widths, heights and gaps,
## varied per region id, identical on every call. Each piece is {x, w, h} (+ extras per kind).
static func silhouette_shapes(rid: String, kind: String, width: float) -> Array:
	var out: Array = []
	var x := 6.0 + unit_hash(rid, 999) * 30.0
	var k := 0
	while x < width and k < 80:
		var r1 := unit_hash(rid, k * 3)
		var r2 := unit_hash(rid, k * 3 + 1)
		var r3 := unit_hash(rid, k * 3 + 2)
		var piece := {"x": x}
		var step := 0.0
		match kind:
			"pines":
				piece["w"] = 34.0 * (0.7 + r1 * 0.6)
				piece["h"] = 50.0 * (0.6 + r2 * 0.6)
				step = 22.0 + r3 * 34.0
			"roofs":
				piece["w"] = 62.0 * (0.7 + r1 * 0.6)
				piece["h"] = 60.0 * (0.6 + r2 * 0.6)
				piece["lantern"] = k == 1
				step = piece["w"] + 10.0 + r3 * 70.0
			"reeds":
				piece["w"] = 2.0
				piece["h"] = 28.0 * (0.6 + r2 * 0.6)
				piece["tuft"] = k % 4 == 0
				step = 7.0 + r3 * 9.0
			_:
				piece["w"] = 70.0 * (0.7 + r1 * 0.6)
				piece["h"] = 40.0 * (0.6 + r2 * 0.6)
				step = size_hills_step(r3)
		out.append(piece)
		x += step
		k += 1
	return out


static func size_hills_step(r: float) -> float:
	return 120.0 + r * 160.0


## 2-3 soft cloud ellipses {x, y, r} for clear skies, seeded by the region id.
static func cloud_shapes(rid: String, width: float, sky_h: float) -> Array:
	var out: Array = []
	for i in 2 + int(unit_hash(rid, 500) * 1.99):
		out.append({
			"x": width * (0.1 + 0.8 * unit_hash(rid, 510 + i)),
			"y": sky_h * (0.15 + 0.3 * unit_hash(rid, 520 + i)),
			"r": 40.0 + 40.0 * unit_hash(rid, 530 + i),
		})
	return out


## The current region's grass as a strip along the bottom (flat dark band when no region is loaded).
func _draw_ground() -> void:
	var band := Rect2(0.0, size.y - GROUND_BAND, size.x, GROUND_BAND)
	var rid := GameState.current_region
	if GameState.data == null or not GameState.data.regions.has(rid):
		draw_rect(band, Color("33402a"))
		return
	var map: Dictionary = GameState.data.regions[rid].get("map", {})
	_draw_backdrop(map, rid)
	var base := Color(map.get("ground", "4d6b3c"))
	var decor: Dictionary = map.get("decor", {})
	if decor.has("grass_color"):
		base = Color(decor["grass_color"])
	var tex := GroundTiles.ground_texture(base, rid, Vector2i(ceili(size.x / 3.0), int(GROUND_BAND / 3.0)), false)
	draw_texture_rect(tex, Rect2(band.position, Vector2(tex.get_size()) * 3.0), false)
	draw_line(band.position, Vector2(size.x, band.position.y), base.darkened(0.5), 2.0)
	for i in 14:  # 2-3 pixel tufts, placed deterministically
		var tx := float((i * 97 + 31) % int(maxf(size.x, 1.0)))
		var ty := band.position.y + 6.0 + float((i * 53) % int(GROUND_BAND - 10.0))
		draw_rect(Rect2(tx, ty, 2.0, 4.0), base.lightened(0.25))
		draw_rect(Rect2(tx + 4.0, ty + 2.0, 2.0, 3.0), base.lightened(0.25))


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
	var base := 1.0 - _dark[who]
	var tint := Color(base, base, base, _alpha[who]).lerp(Color(3, 3, 3, _alpha[who]), _flash[who])
	var fallen := absf(_tilt[who]) > 0.01
	var beast := who == 1 and _foe_beast
	var on_back := fallen and beast  # a beast lies flipped on its back: it stays flat, feet on the ground
	var body := _body_size(who)
	if fallen and not beast:  # rotate about the body centre, then rest the side on the ground
		var rot := _tilt[who] * (-1.0 if who == 1 else 1.0)
		var pivot := pos + Vector2(0.0, -body.x / 2.0)
		draw_set_transform_matrix(Transform2D(rot, pivot) * Transform2D(0.0, Vector2(0.0, body.y / 2.0)))
	elif on_back:
		draw_set_transform(pos + Vector2(0.0, -body.y), 0.0, Vector2(1.0, -1.0))
	else:
		draw_set_transform(pos, 0.0, Vector2.ONE)
	var generated := tex == null
	if generated:
		tex = _pixel_texture(who)
	if tex != null:
		var z := 3.0 if generated else float(Sprites.scale()) * 2.0
		var w := tex.get_width() * z
		var h := tex.get_height() * z
		if generated and who == 1:  # the foe faces left: a negative width mirrors the texture
			draw_texture_rect(tex, Rect2(Vector2(w / 2.0, -h), Vector2(-w, h)), false, tint)
		else:
			draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -h), Vector2(w, h)), false, tint)
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
