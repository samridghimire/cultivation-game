class_name DuelStage
extends Control
## The two fighters above the fight report's hp bars (WU-396). The player stands on the
## left, the foe on the right; `blow()` lunges the striker and flashes the struck one,
## `show_end_pose()` leaves the loser darkened and lying down. Placeholder art drawn in _draw().

const WorldScript := preload("res://src/world/world.gd")
const LUNGE := 24.0
const LUNGE_SECONDS := 0.12
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const FOE_ROBE := Color("3a2f3d")
const FOE_SASH := Color("7a2a2a")
const BEAST_FURS := {"wolf": Color("8a8d92"), "boar": Color("5a4636"), "tiger": Color("b5652a"), "fox": Color("c4702c"),
	"stag": Color("a8854f"), "deer": Color("a8854f"), "elk": Color("a8854f"), "antler": Color("a8854f"),
	"ape": Color("6e665a"), "cloud_crane": Color("eceae4"), "toad": Color("6a8f3c"), "_ram": Color("7d6850"), "python": Color("6b7040")}
const FALLEN_DARKEN := 0.3
const DEFAULT_FUR := Color("6b5a48")
const STAGE_HEIGHT := 182.0
const GROUND_BAND := 56.0
const SCATTER_CLEAR := 80.0
const BEAST_BASE_ZOOM := 4.5
const BEAST_SIZE_SMALL := 0.8
const BEAST_SIZE_LARGE := 1.3
## Fighters stand this far above the stage bottom, mid-grass (GFX-036).
const FEET_INSET := 34.0
## A fallen beast lies on its side: its body squashed to this fraction of its standing height (WU-547).
const BEAST_LIE_SCALE := 0.55
const TAG_GAP := 5.0
const RIM_LIGHTEN := 0.45
## Enemy id keywords -> PixelFigure beast kind, checked in order (GFX-028).
const BEAST_KEYWORDS := [
	["cloud_crane", "crane"], ["toad", "toad"], ["_ram", "ram"], ["ram_", "ram"],
	["wolf", "wolf"], ["alpha", "wolf"], ["fox", "fox"], ["dog", "wolf"], ["hound", "wolf"],
	["boar", "boar"], ["pig", "boar"],
	["stag", "deer"], ["deer", "deer"], ["antler", "deer"], ["elk", "deer"], ["ape", "ape"], ["monkey", "ape"],
	["tiger", "tiger"], ["leopard", "tiger"], ["cat", "tiger"],
	["snake", "snake"], ["caiman", "snake"], ["serpent", "snake"], ["python", "snake"], ["viper", "snake"],
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
var _foe_zoom: float = 3.0  # WU-561: drawn pixels per texture pixel of a generated beast
## WU-501: a backdrop kind that replaces the region's own near layer (pines, reeds, cave, ruins, crags, hills); "" = the region's.
var look_kind: String = ""
## WU-501: {ground: hex, sky: [top hex, horizon hex]} that replaces the region's ground and the clock's sky (the season card); {} = none.
var season_look: Dictionary = {}
var _foe_id: String = ""
var _foe_texture: Texture2D
var _offset: Array[float] = [0.0, 0.0]  # [player, foe] x offsets
var _shake: Array[float] = [0.0, 0.0]
var _flash: Array[float] = [0.0, 0.0]
var _alpha: Array[float] = [1.0, 1.0]
var _tilt: Array[float] = [0.0, 0.0]
var _kneel: Array[bool] = [false, false]  # WU-548: the loser of a friendly bout kneels
var _dark: Array[float] = [0.0, 0.0]  # 0..1 darkening of a fallen fighter
var _tween: Tween
var _stage_shake_start := -1.0  # ticks (s) when the heavy-hit shake began

const STAGE_SHAKE_SECONDS := 0.15
const STAGE_SHAKE_PIXELS := 3.0


## WU-473: blows you can see. `_floaters`: [{who (struck 0 you / 1 foe), text, color, size, start (s), life (s),
## rise (px), banner (bool: a technique name over the attacker)}].
var _floaters: Array[Dictionary] = []
const NUMBER_RISE := 24.0
const NUMBER_SECONDS := 0.6
const BANNER_SECONDS := 0.8


func _init() -> void:
	custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	clip_contents = true
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


## The numbers behind a revealed blow: {side, amount, kind}. `side` as blow_side, `amount` the hp the
## struck figure lost (from the trace, not the text), `kind` crit | solid | glance | hit. `line` only
## classifies the weight. Pure.
static func blow_info(prev: Array, cur: Array, line: String) -> Dictionary:
	var side := blow_side(prev, cur)
	if side == 0:
		return {"side": 0, "amount": 0, "kind": "hit"}
	var struck := 1 if side == 1 else 0
	var kind := "hit"
	if line.contains("critically") or line.contains(Combat.BLOW_WORD_CRUSHING) or line.contains(Combat.BLOW_WORD_SOLID):
		kind = "crit" if line.contains("critically") or line.contains(Combat.BLOW_WORD_CRUSHING) else "solid"
	elif line.contains(Combat.BLOW_WORD_GLANCING):
		kind = "glance"
	return {"side": side, "amount": int(prev[struck]) - int(cur[struck]), "kind": kind}


## The technique a log line names ("You strike with Cloud Palm for 9", "Wolf attacks with Pounce for 4"), or "".
static func technique_of(line: String) -> String:
	for lead in [" strike with ", " attacks with "]:
		var at := line.find(lead)
		if at < 0:
			continue
		var rest := line.substr(at + lead.length())
		var end := rest.length()
		for stop in [" critically", ":", " for "]:
			var k := rest.find(stop)
			if k >= 0:
				end = mini(end, k)
		return rest.substr(0, end).strip_edges()
	return ""


## Floats a damage number over the struck figure and, when `technique` is set, its name over the attacker.
func show_blow(info: Dictionary, technique: String = "") -> void:
	var side := int(info.get("side", 0))
	if side == 0:
		return
	var struck := 1 if side == 1 else 0
	var kind := String(info["kind"])
	var color := Color.WHITE
	var font_size := 16
	if kind == "crit" or kind == "solid":
		color = UIStyle.ACCENT
		font_size = 22
	elif kind == "glance":
		color = Color("9a9a9a")
	var now := Time.get_ticks_msec() / 1000.0
	_floaters.append({"who": struck, "text": str(int(info["amount"])), "color": color, "size": font_size, "start": now, "life": NUMBER_SECONDS, "banner": false})
	if technique != "":
		_floaters.append({"who": 1 - struck, "text": technique, "color": Color("e8d9b0"), "size": 13, "start": now, "life": BANNER_SECONDS, "banner": true})
	set_process(true)


func clear_floaters() -> void:
	_floaters.clear()
	set_process(false)
	queue_redraw()


func floater_count() -> int:
	return _floaters.size()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return now - float(f["start"]) < float(f["life"]))
	if _floaters.is_empty():
		set_process(false)
	queue_redraw()


func _draw_floaters(base_y: float, dx: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var font := ThemeDB.fallback_font
	for f in _floaters:
		var t := clampf((now - float(f["start"])) / float(f["life"]), 0.0, 1.0)
		var cx := size.x * (0.25 if int(f["who"]) == 0 else 0.75) + dx
		var rise := 0.0 if (MotionFx.reduced() or bool(f["banner"])) else NUMBER_RISE * t
		var y := base_y - _body_size(int(f["who"])).y - 8.0 - rise
		if bool(f["banner"]):
			y = base_y - _body_size(int(f["who"])).y - 24.0
		var col: Color = f["color"]
		col.a = 1.0 - t * t
		var fs := int(f["size"])
		var w := font.get_string_size(String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(cx - w / 2.0, maxf(y, float(fs)))
		draw_string_outline(font, pos, String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, col.a))
		draw_string(font, pos, String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Picks the foe's art: a mapped `enemy_<id>`/`enemy` sprite, a beast silhouette for
## enemies tagged "beast", otherwise a robed cultivator. Resets both fighters.
func setup(enemy_id: String, tags: Array) -> void:
	_foe_beast = tags.has("beast")
	_foe_id = enemy_id
	var realm := ""
	if GameState.data != null and GameState.data.enemies.has(enemy_id):
		realm = String((GameState.data.enemies[enemy_id] as Dictionary).get("realm", ""))
	_foe_zoom = beast_zoom(enemy_id, realm)
	_foe_texture = null
	clear_floaters()
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
	_kneel = [false, false]
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
		_tween.tween_method(_redraw_tick, 0.0, 1.0, STAGE_SHAKE_SECONDS)  # WU-557: a method, not a lambda (a freed capture logged errors)


func _redraw_tick(_v: float) -> void:
	queue_redraw()


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()


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
	else:  # WU-548: both stand, the one who lost the bout kneels; no "Defeated" tag
		_kneel[1 if victory else 0] = true
	queue_redraw()


## The loser's tilt (GFX-033): everyone lies on their side (90 degrees), beast or person, so the
## silhouette and its light rim stay readable instead of smearing.
static func toppled_tilt(_beast: bool) -> float:
	return PI / 2.0


## WU-548: true when fighter `who` kneels after losing a friendly bout (for tests).
func is_kneeling(who: int) -> bool:
	return _kneel[who]


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


## WU-561: a generated beast's size class from its id and realm (there is no size field in enemies.json):
## small = fox, dog, porcupine, toad, python-less little things; large = Foundation Establishment and above
## (rhino, bear king, roc...); everything else is medium. Multiplier of the person's height.
static func beast_size_mult(enemy_id: String, realm: String) -> float:
	for kw in ["fox", "dog", "porcupine", "toad_small"]:
		if enemy_id.contains(kw) and realm in ["", "mortal", "qi_refining"]:
			return BEAST_SIZE_SMALL
	if realm in ["", "mortal", "qi_refining"]:
		return 1.0
	return BEAST_SIZE_LARGE


## Pixels per texture pixel for a generated beast: a medium one (a boar) is as tall as the standing person.
static func beast_zoom(enemy_id: String, realm: String) -> float:
	return BEAST_BASE_ZOOM * beast_size_mult(enemy_id, realm)


## The beast silhouette kind for an enemy id ("" = the plain body).
static func beast_kind(enemy_id: String) -> String:
	for pair: Array in BEAST_KEYWORDS:
		if enemy_id.contains(pair[0]):
			return pair[1]
	return ""


var _rim_cache: Dictionary = {}
var _mirror_cache: Dictionary = {}


## `tex` flipped left-right (cached).
func _mirrored(tex: Texture2D) -> Texture2D:
	var id := tex.get_instance_id()
	if not _mirror_cache.has(id):
		var img := tex.get_image().duplicate() as Image
		img.flip_x()
		_mirror_cache[id] = ImageTexture.create_from_image(img)
	return _mirror_cache[id]


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


## WU-553: the world figure's look (robe, hair, sash, accessories) of the NPC `id` fighting as the foe,
## or {} for a beast or a nameless foe.
static func person_look(id: String) -> Dictionary:
	if id == "" or GameState.npcs == null or GameState.data == null or not GameState.npcs.has(id):
		return {}
	return NPC_SCRIPT.look_of(id, FOE_ROBE)


## The generated pixel texture for a fighter without a mapped sprite; the walk frame alternates while lunging.
func _pixel_texture(who: int) -> Texture2D:
	var step := 0
	if absf(_offset[who]) > 0.5:
		step = 1 + int(Time.get_ticks_msec() / 80) % 2
	if who == 1 and _foe_beast:
		var fur := fur_for(_foe_id)
		return _rimmed(PixelFigure.beast_frame(fur, step % 2, beast_kind(_foe_id)), fur.lightened(RIM_LIGHTEN))
	var look := {"robe": FOE_ROBE, "sash": FOE_SASH}
	if who == 1 and person_look(_foe_id).size() > 0:
		look = person_look(_foe_id)
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
		var sh := shadow_rect(who)
		draw_set_transform(Vector2(sh.get_center().x, base_y), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, sh.size.x / 2.0, Color(0, 0, 0, 0.35 * _alpha[who]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fighter(0, Vector2(size.x * 0.25 + dx, base_y))
	_draw_fighter(1, Vector2(size.x * 0.75 + dx, base_y))
	_draw_floaters(base_y, dx)
	for who in 2:
		if is_fallen(who):
			_draw_dust(_feet_of(who), who)
			var plate := defeated_tag_rect(who)
			var pc: Color = UIStyle.PANEL
			pc.a = 0.8
			draw_rect(plate, pc)
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(plate.position.x + 4.0, plate.end.y - 8.0), "Defeated", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8d9b0"))


## WU-561: the ground shadow of fighter `who` as a rect (x = its extent): under the body where it stands, and
## under the lying body once defeated, so it never stays behind as an empty oval.
func shadow_rect(who: int) -> Rect2:
	var cx := size.x * (0.25 if who == 0 else 0.75) + _stage_offset().x + _offset[who]
	var by := size.y - FEET_INSET + _stage_offset().y
	if is_fallen(who):
		var r := fallen_rect(_body_size(who), Vector2(cx, by), who == 1 and _foe_beast)
		return Rect2(r.position.x, by - 2.0, r.size.x, 4.0)
	return Rect2(cx - 30.0, by - 2.0, 60.0, 4.0)


## The ground point of fighter `who` (0 player, 1 foe) as drawn, for the tag and tests.
func _feet_of(who: int) -> Vector2:
	return Vector2(size.x * (0.25 if who == 0 else 0.75) + _stage_offset().x + _offset[who], size.y - FEET_INSET + _stage_offset().y)


## The bounds of the lying body of fighter `who`.
func fallen_body_rect(who: int) -> Rect2:
	return fallen_rect(_body_size(who), _feet_of(who), who == 1 and _foe_beast)


## The "Defeated" plate: centred on the lying body, its bottom TAG_GAP above the body's top (WU-547).
func defeated_tag_rect(who: int) -> Rect2:
	var w := ThemeDB.fallback_font.get_string_size("Defeated", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var body := fallen_body_rect(who)
	return Rect2(body.get_center().x - w / 2.0, body.position.y - TAG_GAP - 20.0, w, 20.0)


## A small puff of dust where a fighter fell: three fading grey blobs on the ground by the body.
func _draw_dust(feet: Vector2, who: int) -> void:
	var half := fallen_body_rect(who).size.x / 2.0
	for i in 3:
		var x := feet.x + (-1.0 if i == 1 else 1.0) * (half + 4.0 + float(i) * 5.0)
		draw_circle(Vector2(x, feet.y - 3.0 - float(i) * 3.0), 5.0 - float(i), Color(0.78, 0.72, 0.62, 0.35 - 0.08 * float(i)))


## The axis-aligned bounds of a fallen fighter (GFX-036). `tex_size` is the standing body in
## drawn pixels, `feet` the ground point. A beast is flipped onto its back (same size, feet on
## the ground); a person is rotated 90 degrees about the body centre and dropped to the ground.
static func fallen_rect(tex_size: Vector2, feet: Vector2, beast: bool) -> Rect2:
	if beast:
		var h := tex_size.y * BEAST_LIE_SCALE
		return Rect2(feet.x - tex_size.x / 2.0, feet.y - h, tex_size.x, h)
	return Rect2(feet.x - tex_size.y / 2.0, feet.y - tex_size.x, tex_size.y, tex_size.x)


## The standing body size in drawn pixels (mapped sprite, generated texture, or the shape fallback).
func _body_size(who: int) -> Vector2:
	var tex: Texture2D = _foe_texture if who == 1 else Sprites.texture("player_right")
	if tex == null:
		tex = _pixel_texture(who)
		return Vector2(tex.get_size()) * (_foe_zoom if who == 1 and _foe_beast else 3.0)
	return Vector2(tex.get_size()) * float(Sprites.scale()) * 2.0


## The backdrop silhouette kind for a region id: pines, roofs, reeds, or the default hills.
static func silhouette_for(region_id: String) -> String:
	return String(SILHOUETTES.get(region_id, DEFAULT_SILHOUETTE))


## True when a real region is loaded, so the backdrop is drawn (false for sims).
func has_backdrop() -> bool:
	return GameState.data != null and GameState.data.regions.has(GameState.current_region)


## Sky gradient (top, horizon) for the season of the current day.
static func sky_colors(season: String) -> Array:
	return SKY_BY_SEASON.get(season.to_lower(), SKY_BY_SEASON["summer"])


## GFX-161: the ground season ("Spring"/"Autumn"/"Winter"/"Summer", "" in a no_snow region's winter) for today.
func backdrop_season(map: Dictionary) -> String:
	return GroundTiles.ground_season(Calendar.season_of(GameClock.total_days), map)


## GFX-161: how the backdrop layers change with the season: {far_lerp: share of the far ridge lerped toward the
## sky haze, snow_caps: draw pale caps on near pieces, ochre: share of hills lerped toward muted ochre}.
static func season_tint(season: String) -> Dictionary:
	match season:
		"Winter":
			return {"far_lerp": 0.35, "snow_caps": true, "ochre": 0.0}
		"Autumn":
			return {"far_lerp": 0.0, "snow_caps": false, "ochre": 0.25}
	return {"far_lerp": 0.0, "snow_caps": false, "ochre": 0.0}


## GFX-169: the grass colour of the fight/encounter ground per season: ochre-olive in autumn, fresher green in spring,
## snow-grey in winter, `base` otherwise.
static func season_grass(base: Color, season: String) -> Color:
	match season:
		"Autumn":
			return base.lerp(Color("8a7a3a"), 0.6)
		"Spring":
			return base.lerp(Color("6fae4a"), 0.35).lightened(0.06)
		"Winter":
			return base.lerp(Color("dfe7ee"), 0.7)
	return base


## GFX-169: seasonal specks on the fight ground as [{x, y, color}] (x in 0..width, y in 0..band): drifts of fallen
## leaves (red, orange, gold) in autumn, a few blossom specks in spring, nothing else. Seeded, so stable.
static func season_specks(season: String, rid: String, width: float, band: float) -> Array:
	var out: Array = []
	if season != "Autumn" and season != "Spring":
		return out
	var leaf_cols := [Color("b83c2a"), Color("d9702a"), Color("e0a83a"), Color("a8481f")]
	var blossom_cols := [Color("f4efe0"), Color("f0a0b8"), Color("f2d24b")]
	var n := int(width / 24.0) if season == "Autumn" else int(width / 60.0)
	for i in n:
		var cx := unit_hash(rid + season + "x", i) * width
		var cy := 6.0 + unit_hash(rid + season + "y", i) * maxf(band - 12.0, 1.0)
		var cluster := 3 if season == "Autumn" else 1
		for j in cluster:
			var pal: Array = leaf_cols if season == "Autumn" else blossom_cols
			out.append({"x": cx + unit_hash(rid + "dx", i * 7 + j) * 14.0 - 7.0, "y": cy + unit_hash(rid + "dy", i * 7 + j) * 6.0 - 3.0,
				"color": pal[int(unit_hash(rid + "c", i * 7 + j) * 0.999 * pal.size())]})
	return out


## True when today's weather (or the pinned screenshot weather) is rain or storm.
func is_raining() -> bool:
	if GameState.data == null:
		return WorldScript.pinned_weather == "rain" or WorldScript.pinned_weather == "storm"
	var weather := WorldScript.weather_today(GameState.data, GameState.current_region, GameClock.total_days)
	return weather == "rain" or weather == "storm"


## The upper half of a circle as a hill outline: starts and ends on `base_y`, never rises above `base_y - max_h`.
static func hill_arc(cx: float, base_y: float, r: float, max_h: float, steps: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := PI * float(i) / float(steps)
		pts.append(Vector2(cx - cos(a) * r, base_y - minf(sin(a) * r, max_h)))
	return pts


func _draw_backdrop(map: Dictionary, rid: String) -> void:
	var top_h := size.y - GROUND_BAND
	var sky := sky_colors(Calendar.season_of(GameClock.total_days))
	if season_look.has("sky"):
		sky = [Color(String(season_look["sky"][0])), Color(String(season_look["sky"][1]))]
	var bands := 12
	for i in bands:
		var c: Color = (sky[0] as Color).lerp(sky[1], float(i) / float(bands - 1))
		draw_rect(Rect2(0.0, top_h * i / bands, size.x, ceilf(top_h / bands) + 1.0), c)
	var haze: Color = sky[1]
	var col := Color(map.get("ground", "4d6b3c")).darkened(0.45).lerp(haze, HAZE)
	var kind := look_kind if look_kind != "" else silhouette_for(rid)
	var horizon := top_h
	if is_raining():
		draw_rect(Rect2(0.0, 0.0, size.x, top_h), Color(0.12, 0.14, 0.2, 0.55))
	else:
		for c in cloud_shapes(rid, size.x, top_h):
			draw_set_transform(Vector2(c["x"], c["y"]), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, c["r"], Color(1, 1, 1, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var gseason := backdrop_season(map)
	if season_look.has("ground"):
		gseason = ""
	var tint := season_tint(gseason)
	var snow := Color("eef2f5")
	var far := far_color(map_ground_color(map), sky)
	far = far.lerp(haze, float(tint["far_lerp"]))
	col = col.darkened(0.2)  # the near layer sits darker than the ridge
	var layers := backdrop_layers(rid, size.x, look_kind)
	var crags := rid in PEAK_REGIONS
	for s in layers["far"]:
		var fr := 60.0 + float(s["h"]) * 0.6
		var fh := minf(float(s["h"]) + 14.0, top_h * 0.45)
		if crags:  # jagged crag line instead of rounded hills
			var cx: float = s["x"]
			draw_colored_polygon(PackedVector2Array([Vector2(cx - fr, horizon), Vector2(cx - fr * 0.3, horizon - fh * 0.7),
				Vector2(cx - fr * 0.1, horizon - fh * 0.55), Vector2(cx + fr * 0.05, horizon - fh), Vector2(cx + fr * 0.4, horizon - fh * 0.5),
				Vector2(cx + fr, horizon)]), far)
		else:  # GFX-157: a ridge line of 2-3 overlapping arcs, not one dome
			var cx2: float = s["x"]
			draw_colored_polygon(hill_arc(cx2 - fr * 0.55, horizon, fr * 0.7, fh * 0.7), far.darkened(0.06))
			draw_colored_polygon(hill_arc(cx2 + fr * 0.6, horizon, fr * 0.6, fh * 0.55), far.darkened(0.06))
			draw_colored_polygon(hill_arc(cx2, horizon, fr, fh), far)
	var piece_i := -1
	var near_pieces: Array = layers["near"]
	if kind == "pines":  # the darker front row draws last
		near_pieces = near_pieces.filter(func(q): return not q.get("dark", false)) + near_pieces.filter(func(q): return q.get("dark", false))
	var snow_caps: bool = tint["snow_caps"]
	for s in near_pieces:
		piece_i += 1
		var x: float = s["x"]
		var w: float = s["w"]
		var h: float = s["h"]
		if kind == "roofs" and x + w + 12.0 > size.x:
			continue
		match kind:
			"pines":  # GFX-157: stacked tiers on a trunk; the dark row stands in front
				var c := col.darkened(0.18) if s.get("dark", false) else col
				var base_y := horizon
				if s.get("back", false):
					c = col.lerp(haze, 0.3)
					base_y = horizon - 5.0
				if s.get("broad", false):  # a round broadleaf crown on a trunk
					var cr := w * 0.3
					draw_rect(Rect2(x - 1.5, base_y - 10.0, 3.0, 10.0), c.darkened(0.3))
					if gseason == "Autumn":  # turning leaves: a gold-orange crown
						c = c.lerp(Color("b8662a") if piece_i % 2 == 0 else Color("c89a34"), 0.7)
					draw_circle(Vector2(x, base_y - 10.0 - cr * 0.6), cr, c.lightened(0.04))
					draw_circle(Vector2(x - cr * 0.7, base_y - 10.0), cr * 0.75, c)
					draw_circle(Vector2(x + cr * 0.7, base_y - 10.0), cr * 0.75, c)
					if snow_caps:
						draw_rect(Rect2(x - cr * 0.6, base_y - 10.0 - cr * 1.6, cr * 1.2, 2.0), snow)
					continue
				var tiers: int = s.get("tiers", 2)
				if gseason == "Autumn" and tiers > 1 and piece_i % 3 == 0:
					tiers -= 1  # thinned, bare-ish top
				var th := h / float(tiers)
				for t in tiers:
					var ty := base_y - 6.0 - th * 0.55 * t
					var tw := w * (0.5 + 0.5 * float(t + 1) / float(tiers)) * 0.5
					var tw2 := w * (0.5 + 0.5 * float(tiers - t) / float(tiers)) * 0.5
					draw_colored_polygon(PackedVector2Array([Vector2(x - tw2, ty), Vector2(x, ty - th * 1.1), Vector2(x + tw2, ty)]), c)
					if snow_caps:  # a pale band on the top of each tier
						draw_colored_polygon(PackedVector2Array([Vector2(x - tw2 * 0.45, ty - th * 0.6), Vector2(x, ty - th * 1.1), Vector2(x + tw2 * 0.45, ty - th * 0.6)]), snow)
				draw_rect(Rect2(x - 1.0, base_y - 8.0, 2.0, 8.0), c.darkened(0.3))  # trunk
			"roofs":
				var wall := 12.0 + h * 0.2
				draw_rect(Rect2(x, horizon - wall, w, wall), col.lightened(0.14))  # lit wall
				var roof_h := h * 0.45
				var rows := int(roof_h / PIXEL)
				for row in rows:  # a trapezoid whose bottom row flares into upturned eaves
					var inset := float(row) * (w * 0.5 / maxf(rows, 1)) * 0.8
					draw_rect(Rect2(x - 6.0 + inset, horizon - wall - (row + 1) * PIXEL, w + 12.0 - inset * 2.0, PIXEL), col.darkened(0.3 if row == 0 else 0.12))  # darker eave band
				draw_rect(Rect2(x - 9.0, horizon - wall - PIXEL - 3.0, 5.0, 3.0), col)
				draw_rect(Rect2(x + w + 4.0, horizon - wall - PIXEL - 3.0, 5.0, 3.0), col)
				if snow_caps:  # a pale strip along the ridge and the eaves
					draw_rect(Rect2(x - 2.0, horizon - wall - rows * PIXEL - 2.0, w + 4.0, 3.0), snow)
					draw_rect(Rect2(x - 6.0, horizon - wall - PIXEL, w + 12.0, 2.0), snow)
				if piece_i == 2:  # one taller two-tier roof
					draw_rect(Rect2(x + w * 0.2, horizon - wall - rows * PIXEL - 10.0, w * 0.6, 10.0), col.darkened(0.1))
					draw_rect(Rect2(x + w * 0.1, horizon - wall - rows * PIXEL - 14.0, w * 0.8, PIXEL), col)
					draw_rect(Rect2(x + w * 0.1 - 4.0, horizon - wall - rows * PIXEL - 17.0, 5.0, 3.0), col)
					draw_rect(Rect2(x + w * 0.9 - 1.0, horizon - wall - rows * PIXEL - 17.0, 5.0, 3.0), col)
				if s.get("lantern", false):
					draw_rect(Rect2(x + w + 8.0, horizon - 34.0, 2.0, 34.0), col)
					draw_rect(Rect2(x + w + 5.0, horizon - 28.0, 8.0, 10.0), Color("e0a040").lerp(haze, 0.3))
			"cave":  # WU-501: a rounded hill with a dark mouth
				draw_colored_polygon(hill_arc(x, horizon, w, h), col)
				draw_colored_polygon(hill_arc(x, horizon, w * 0.3, h * 0.45), Color(0.05, 0.04, 0.06))
			"ruins":  # broken wall stubs with a gap in the top
				draw_rect(Rect2(x, horizon - h * 0.6, w, h * 0.6), col.darkened(0.1))
				draw_rect(Rect2(x, horizon - h * 0.6 - PIXEL, w * 0.35, PIXEL), col)
				draw_rect(Rect2(x + w * 0.65, horizon - h * 0.6 - 2.0 * PIXEL, w * 0.35, 2.0 * PIXEL), col)
				draw_rect(Rect2(x + w * 0.4, horizon - h * 0.25, w * 0.2, h * 0.25), col.darkened(0.5))
			"crags":  # jagged rock
				draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, horizon), Vector2(x - w * 0.2, horizon - h * 0.8),
					Vector2(x, horizon - h * 0.5), Vector2(x + w * 0.2, horizon - h), Vector2(x + w * 0.5, horizon)]), col)
				if snow_caps:
					draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.27, horizon - h * 0.64), Vector2(x - w * 0.2, horizon - h * 0.8),
						Vector2(x, horizon - h * 0.5), Vector2(x + w * 0.2, horizon - h), Vector2(x + w * 0.27, horizon - h * 0.7), Vector2(x, horizon - h * 0.62)]), snow)
			"river":  # WU-552: the far bank, a low grassy rise with the odd round tree
				draw_rect(Rect2(x, horizon - 8.0, w, 8.0), col.lerp(Color("5f7a40"), 0.4))
				if piece_i % 3 == 0:
					draw_rect(Rect2(x + w * 0.5 - 1.0, horizon - 20.0, 3.0, 14.0), col.darkened(0.3))
					draw_circle(Vector2(x + w * 0.5, horizon - 24.0), 9.0, col.lerp(Color("4a6a38"), 0.5))
			"reeds":
				draw_rect(Rect2(x, horizon - h, 2.0, h), col)
				if s.get("tuft", false):  # cattail head
					draw_rect(Rect2(x - 1.0, horizon - h - 6.0, 4.0, 8.0), col.darkened(0.25))
				if s.get("tuft", false):
					draw_rect(Rect2(x - 4.0, horizon - 14.0, 14.0, 14.0), col.lightened(0.15))
			_:
				var hc := col.lerp(Color("a88a52"), float(tint["ochre"]))
				draw_colored_polygon(hill_arc(x, horizon, w, h), hc)
				if snow_caps:  # a pale cap on the top ~20% of the dome
					var arc := hill_arc(x, horizon, w, h)
					var cap := PackedVector2Array()
					for pt in arc:
						if pt.y < horizon - h * 0.8:
							cap.append(pt)
					if cap.size() >= 3:
						draw_colored_polygon(cap, snow)


const HAZE := 0.45
const PEAK_REGIONS := ["azure_peak", "myriad_peaks_ridge"]
## Foreground prop kinds on the ground strip by backdrop kind (GFX-107).
const PROP_KINDS := {"roofs": ["fence", "lantern"], "pines": ["stump", "ferns"], "reeds": ["deadtree", "pool"], "hills": ["rocks", "stump"],
	"cave": ["rocks", "pool"], "ruins": ["rocks", "fence"], "crags": ["rocks", "rocks"], "river": ["pool", "rocks"]}
## GFX-182: leaf-litter colour of a woods floor by ground season ("" = no snow, read as summer).
const LITTER_COLORS := {"Spring": "7a9a48", "Summer": "5f7a34", "Autumn": "b8662a", "Winter": "8a7a5a", "": "5f7a34"}
## Fractions of the stage width where a prop centre may sit: clear of the fighters' feet (15-30% and 70-85%, plus margin).
const PROP_ZONES := [[0.04, 0.12], [0.33, 0.67], [0.88, 0.96]]
const PIXEL := 4.0


## The distant ridge colour (GFX-157): the ground hue, darkened, one haze lerp, and always at least
## 0.12 apart in value from the sky's horizon colour so it never melts into the sky.
static func far_color(ground: Color, sky: Array) -> Color:
	var haze: Color = sky[1]
	var far := ground.darkened(0.35).lerp(haze, 0.45)
	var guard := 0
	while absf(far.v - haze.v) < 0.12 and guard < 20:
		far = far.darkened(0.08) if far.v <= haze.v else far.lightened(0.08)
		guard += 1
	return far


static func map_ground_color(map: Dictionary) -> Color:
	return Color(map.get("ground", "4d6b3c"))


## A stable 0..1 value from a string seed and index (no rng: the same region always draws the same).
static func unit_hash(seed_text: String, k: int) -> float:
	var x: int = hash(seed_text + ":" + str(k))
	x = (x ^ (x >> 30)) * -4658895280553007687  # splitmix64 finaliser: neighbouring indices disperse (GFX-165)
	x = (x ^ (x >> 27)) * -7723592293110705685
	x = x ^ (x >> 31)
	return float((x >> 3) % 1000) / 999.0


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
				piece["h"] = 50.0 * (0.5 + r2 * 1.0)
				if unit_hash(str(k) + rid, 802) < 0.2:  # GFX-161: about 1 in 5 is a broadleaf crown
					piece["broad"] = true
				piece["tiers"] = 2 + int(unit_hash(rid, k * 3 + 400) * 1.99)
				piece["dark"] = unit_hash(rid, k * 3 + 401) < 0.25
				if piece["dark"]:
					piece["h"] = float(piece["h"]) * 0.75
				step = 22.0 + r3 * 34.0
				if unit_hash(str(k) + rid, 903) < 0.25:  # a clearing: no front piece here
					x += step
					k += 1
					continue
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
	if kind == "pines":  # GFX-161: a hazy back row behind the front row
		var bx := 14.0 + unit_hash(rid, 998) * 20.0
		var bk := 0
		while bx < width and bk < 40:
			out.append({"x": bx, "w": 30.0 * (0.8 + unit_hash(rid, 600 + bk) * 0.5), "h": 50.0 * (0.55 + unit_hash(rid, 640 + bk) * 0.2),
				"tiers": 2, "back": true})
			bx += 26.0 + unit_hash(rid, 680 + bk) * 30.0
			bk += 1
		out.sort_custom(func(a, b): return a.get("back", false) and not b.get("back", false))
	return out


## The layered backdrop for a region (GFX-107): {far: ridge pieces, near: silhouette pieces, props: [{kind, x, y}]}.
## Deterministic per region id; no prop centre lies inside a fighter's foot zone.
static func backdrop_layers(rid: String, width: float, kind_override: String = "") -> Dictionary:
	var kind := kind_override if kind_override != "" else silhouette_for(rid)
	var kinds: Array = PROP_KINDS.get(kind, PROP_KINDS["hills"])
	if kind_override == "":
		if rid in PEAK_REGIONS:
			kinds = ["rocks", "rocks"]
		elif rid == "fallen_star_market":
			kinds = ["awning", "fence"]
	var props: Array = []
	var count := 2 + int(unit_hash(rid, 700) * 2.99)
	for i in count:
		var zone: Array = PROP_ZONES[i % PROP_ZONES.size()]
		var t := unit_hash(rid, 710 + i)
		props.append({"kind": kinds[i % kinds.size()], "x": width * lerpf(float(zone[0]), float(zone[1]), t),
			"y": 8.0 + unit_hash(rid, 720 + i) * 18.0})
	var near_seed := rid + kind_override if kind_override != "" else rid
	return {"far": silhouette_shapes(rid + "_far", "hills", width), "near": silhouette_shapes(near_seed, kind, width), "props": props}


## GFX-182: 2-3 tall foreground trunks of a woods scene, {x, w}: centres in the outer prop zones (never a foot zone).
static func foreground_trunks(rid: String, width: float) -> Array:
	var out: Array = []
	var n := 2 + int(unit_hash(rid, 760) * 1.99)
	for i in n:
		var zone: Array = PROP_ZONES[0] if i % 2 == 0 else PROP_ZONES[2]
		var t := unit_hash(rid, 770 + i)
		out.append({"x": width * lerpf(float(zone[0]), float(zone[1]), t), "w": 14.0 + unit_hash(rid, 780 + i) * 8.0})
	return out


func _draw_trunks(band: Rect2, rid: String, col: Color) -> void:
	var dark := col.darkened(0.45)
	for tr in foreground_trunks(rid, size.x):
		var x: float = tr["x"]
		var w: float = tr["w"]
		draw_rect(Rect2(x - w * 0.5, -4.0, w, band.end.y + 4.0), dark)
		draw_rect(Rect2(x - w * 0.5, -4.0, 3.0, band.end.y + 4.0), dark.lightened(0.18))  # sun-side edge
		draw_rect(Rect2(x + w * 0.5 - 4.0, -4.0, 4.0, band.end.y + 4.0), dark.darkened(0.25))
		draw_rect(Rect2(x - w * 0.5 - 4.0, band.position.y + 2.0, w + 8.0, 6.0), dark)  # root flare


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
	var map: Dictionary = GameState.data.regions[rid].get("map", {}).duplicate(true)
	if season_look.has("ground"):
		map["ground"] = season_look["ground"]
		map.get("decor", {}).erase("grass_color")
	_draw_backdrop(map, rid)
	var base := Color(map.get("ground", "4d6b3c"))
	var decor: Dictionary = map.get("decor", {})
	if decor.has("grass_color"):
		base = Color(decor["grass_color"])
	var gseason := "" if season_look.has("ground") else backdrop_season(map)
	if gseason == "Autumn" or gseason == "Spring":
		base = season_grass(base, gseason)
	var woods := look_kind == "pines"
	if woods:  # GFX-182: leaf litter, not meadow
		base = base.lerp(Color(String(LITTER_COLORS.get(gseason, "5f7a34"))), 0.3)
	var tex := GroundTiles.ground_texture(base, rid, Vector2i(ceili(size.x / 3.0), int(GROUND_BAND / 3.0)), false, gseason)
	draw_texture_rect(tex, Rect2(band.position, Vector2(tex.get_size()) * 3.0), false)
	draw_line(band.position, Vector2(size.x, band.position.y), base.darkened(0.5), 2.0)
	if woods:
		_draw_litter(band, rid, base, gseason)
	else:
		for t in stage_scatter(rid, size.x):  # WU-561: tufts and pebbles on the flat band
			var tc := base.lightened(0.22) if t["pebble"] == false else base.darkened(0.2).lerp(Color("9a9486"), 0.5)
			if gseason == "Autumn" and t["pebble"] == false:
				tc = base.lerp(Color("b08a3c"), 0.5).lightened(0.1)
			elif gseason == "Winter":
				tc = Color("eef2f5") if t["pebble"] == false else base.darkened(0.3)
			var tp := Vector2(t["x"], band.position.y + float(t["y"]))
			if t["pebble"]:
				draw_rect(Rect2(tp, Vector2(4.0, 3.0)), tc)
			else:
				draw_rect(Rect2(tp, Vector2(2.0, 4.0)), tc)
				draw_rect(Rect2(tp + Vector2(3.0, 1.0), Vector2(2.0, 3.0)), tc)
	for i in 0 if woods else 14:  # 2-3 pixel tufts, placed deterministically
		var tx := float((i * 97 + 31) % int(maxf(size.x, 1.0)))
		var ty := band.position.y + 6.0 + float((i * 53) % int(GROUND_BAND - 10.0))
		var tuft := base.lightened(0.25)
		if gseason == "Winter":  # sparse dark stalks poking through the snow
			if i % 2 == 1:
				continue
			tuft = base.darkened(0.45)
			draw_rect(Rect2(tx, ty, 1.0, 4.0), tuft)
			draw_rect(Rect2(tx + 3.0, ty + 1.0, 1.0, 3.0), tuft)
			continue
		if gseason == "Autumn":
			tuft = base.lerp(Color("b08a3c"), 0.5).lightened(0.15)
		draw_rect(Rect2(tx, ty, 2.0, 4.0), tuft)
		draw_rect(Rect2(tx + 4.0, ty + 2.0, 2.0, 3.0), tuft)
	if not woods:
		for sp in season_specks(gseason, rid, size.x, GROUND_BAND):
			draw_rect(Rect2(float(sp["x"]), band.position.y + float(sp["y"]), 3.0, 2.0), sp["color"])
	if look_kind == "river":
		_draw_river(band, rid, gseason)
		return
	for p in backdrop_layers(rid, size.x, look_kind)["props"]:
		_draw_prop(String(p["kind"]), Vector2(p["x"], band.position.y + float(p["y"])), base)
	if woods:
		_draw_trunks(band, rid, Color(map.get("ground", "4d6b3c")))


## WU-561: 8-14 seeded tufts/pebbles for the stage ground, as {x, y (in the band), pebble}. Never within
## SCATTER_CLEAR px of either fighter's feet. Deterministic per region.
static func stage_scatter(rid: String, width: float) -> Array:
	var out: Array = []
	var n := 8 + int(unit_hash(rid + "sc", 99) * 7.0)
	for i in n * 4:
		if out.size() >= n:
			break
		var x := 4.0 + unit_hash(rid + "sc", i * 3) * (width - 12.0)
		var y := 6.0 + unit_hash(rid + "sc", i * 3 + 1) * (GROUND_BAND - 14.0)
		if absf(x - width * 0.25) < SCATTER_CLEAR or absf(x - width * 0.75) < SCATTER_CLEAR:
			continue
		out.append({"x": x, "y": y, "pebble": unit_hash(rid + "sc", i * 3 + 2) < 0.35})
	return out


## GFX-182: 2 px leaves on a woods floor, and a few snow patches in winter. Deterministic per region.
func _draw_litter(band: Rect2, rid: String, base: Color, season: String) -> void:
	var leaf := Color(String(LITTER_COLORS.get(season, "5f7a34")))
	for i in 46:
		var lx := unit_hash(rid + "lt", i * 2) * size.x
		var ly := band.position.y + 4.0 + unit_hash(rid + "lt", i * 2 + 1) * (GROUND_BAND - 8.0)
		var c := leaf.lightened(0.15) if i % 3 == 0 else (leaf.darkened(0.2) if i % 3 == 1 else base.darkened(0.15))
		draw_rect(Rect2(lx, ly, 2.0, 2.0), c)
	if season == "Winter":
		for i in 4:
			var px := unit_hash(rid + "sn", i * 2) * size.x
			var py := band.position.y + 8.0 + unit_hash(rid + "sn", i * 2 + 1) * (GROUND_BAND - 22.0)
			draw_rect(Rect2(px, py, 30.0 + 14.0 * float(i % 2), 7.0), Color("eef2f5"))


## WU-552: the water of a river encounter: a band across the top of the ground strip (season-tinted), a muddy near bank
## below it, reeds and a mooring post as props. Deterministic per region.
static func river_water_color(season: String) -> Color:
	match season:
		"Spring":
			return Color("8a6a46")  # snowmelt: brown and churning
		"Autumn":
			return Color("6f7c80")
		"Winter":
			return Color("9fb6c4")
		_:
			return Color("3f7fa8")


func _draw_river(band: Rect2, rid: String, season: String) -> void:
	var water := river_water_color(season)
	var top := band.position.y + 2.0
	var wh := 24.0
	draw_rect(Rect2(0.0, top, size.x, wh), water)
	draw_rect(Rect2(0.0, top + wh, size.x, 5.0), Color("5c4a36"))  # the wet mud edge of the near bank
	for i in 22:
		var rx := unit_hash(rid + "rv", i) * size.x
		var ry := top + 3.0 + unit_hash(rid + "rw", i) * (wh - 8.0)
		var rl := 14.0 + unit_hash(rid + "rl", i) * 18.0
		var foam := water.lightened(0.3 if season != "Spring" else 0.4)
		draw_rect(Rect2(rx, ry, rl, 2.0), foam)
		if season == "Spring":  # churning: a second broken streak
			draw_rect(Rect2(rx + rl * 0.5, ry + 5.0, rl * 0.6, 2.0), water.darkened(0.25))
	if season == "Winter":  # ice grows in from both banks
		draw_rect(Rect2(0.0, top, size.x, 4.0), Color("e4eef4"))
		draw_rect(Rect2(0.0, top + wh - 4.0, size.x, 4.0), Color("e4eef4"))
		for i in 6:
			draw_rect(Rect2(unit_hash(rid + "ice", i) * size.x, top + 8.0, 36.0, 8.0), Color("d3e2ec"))
	for i in 10:  # stones and pebbles on the near bank
		var px := unit_hash(rid + "st", i) * size.x
		var py := top + wh + 8.0 + unit_hash(rid + "sy", i) * (band.size.y - wh - 16.0)
		draw_rect(Rect2(px, py, 6.0, 3.0), Color("8a8780") if i % 2 == 0 else Color("6b645a"))
	var wood := Color("6b4a2e")
	var post_x := size.x * (0.46 + unit_hash(rid + "post", 0) * 0.08)  # a mooring post between the fighters
	draw_rect(Rect2(post_x, top + wh - 22.0, 5.0, 28.0), wood)
	draw_rect(Rect2(post_x - 1.0, top + wh - 24.0, 7.0, 3.0), wood.lightened(0.2))
	var reed := Color("6e7a3a") if season != "Winter" else Color("8a7a5a")
	for cx: float in [size.x * 0.08, size.x * 0.92]:  # reed clumps at both ends
		for j in 5:
			var hh := 14.0 + unit_hash(rid + "rd", j + int(cx)) * 12.0
			draw_rect(Rect2(cx + j * 4.0 - 8.0, top + wh - hh + 4.0, 2.0, hh), reed)
			if j % 2 == 0:
				draw_rect(Rect2(cx + j * 4.0 - 9.0, top + wh - hh, 4.0, 5.0), reed.darkened(0.35))


func _draw_prop(kind: String, at: Vector2, ground: Color) -> void:
	var dark := ground.darkened(0.6)
	var wood := Color("6b4a2e")
	match kind:
		"fence":
			for i in 3:
				draw_rect(Rect2(at.x - 12.0 + i * 10.0, at.y - 10.0, 4.0, 14.0), wood)
			draw_rect(Rect2(at.x - 12.0, at.y - 6.0, 24.0, 3.0), wood.lightened(0.15))
		"lantern":
			draw_rect(Rect2(at.x - 1.0, at.y - 26.0, 3.0, 28.0), wood)
			draw_rect(Rect2(at.x - 5.0, at.y - 26.0, 11.0, 10.0), Color("c8503c"))
			draw_rect(Rect2(at.x - 3.0, at.y - 24.0, 7.0, 6.0), Color("f0c060"))
		"stump":
			draw_rect(Rect2(at.x - 8.0, at.y - 8.0, 16.0, 12.0), wood.darkened(0.2))
			draw_rect(Rect2(at.x - 8.0, at.y - 10.0, 16.0, 4.0), wood.lightened(0.2))
		"ferns":
			for i in 4:
				draw_rect(Rect2(at.x - 8.0 + i * 4.0, at.y - 4.0 - (i % 2) * 5.0, 3.0, 8.0 + (i % 2) * 5.0), ground.lightened(0.2))
		"deadtree":
			draw_rect(Rect2(at.x - 2.0, at.y - 24.0, 4.0, 28.0), dark)
			draw_rect(Rect2(at.x - 10.0, at.y - 20.0, 9.0, 3.0), dark)
			draw_rect(Rect2(at.x + 1.0, at.y - 14.0, 9.0, 3.0), dark)
		"pool":
			draw_set_transform(at, 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, 16.0, Color("3a5a5c"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rocks":
			draw_rect(Rect2(at.x - 10.0, at.y - 6.0, 14.0, 10.0), Color("7a7a78"))
			draw_rect(Rect2(at.x + 2.0, at.y - 10.0, 10.0, 14.0), Color("8e8c88"))
			draw_rect(Rect2(at.x - 10.0, at.y - 6.0, 14.0, 2.0), Color("a8a6a0"))
		"awning":
			draw_rect(Rect2(at.x - 12.0, at.y - 4.0, 3.0, 8.0), wood)
			draw_rect(Rect2(at.x + 9.0, at.y - 4.0, 3.0, 8.0), wood)
			for i in 6:
				draw_rect(Rect2(at.x - 14.0 + i * 5.0, at.y - 12.0, 5.0, 8.0), Color("b83c3c") if i % 2 == 0 else Color("e8d9b0"))


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
	elif on_back:  # on its side: squashed flat, feet on the ground, legs stuck out stiff
		draw_set_transform(pos, 0.0, Vector2(1.0, BEAST_LIE_SCALE))
	elif _kneel[who]:  # a kneeling bow: shorter, a little forward
		draw_set_transform(pos + Vector2(8.0 if who == 0 else -8.0, 0.0), 0.12 * (1.0 if who == 0 else -1.0), Vector2(1.0, 0.8))
	else:
		draw_set_transform(pos, 0.0, Vector2.ONE)
	var generated := tex == null
	if generated:
		tex = _pixel_texture(who)
	if tex != null:
		var z := (_foe_zoom if who == 1 and _foe_beast else 3.0) if generated else float(Sprites.scale()) * 2.0
		var w := tex.get_width() * z
		var h := tex.get_height() * z
		if generated and who == 1:  # the foe faces left: a mirrored copy (WU-561: a negative-width rect drew a lying body off its spot)
			tex = _mirrored(tex)
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -h), Vector2(w, h)), false, tint)
	elif who == 1 and _foe_beast:
		_draw_beast(tint)
	else:
		_draw_person(who, tint)
	if on_back:  # four stiff legs poking out along the ground
		draw_set_transform(pos, 0.0, Vector2.ONE)
		var lc := _tinted(DEFAULT_FUR.darkened(0.35), tint)
		var half := body.x / 2.0
		for lx in [-0.3, -0.1, 0.12, 0.32]:
			draw_rect(Rect2(half * float(lx) * 2.0 - 2.0, -5.0, 4.0, 10.0 * BEAST_LIE_SCALE + 3.0), lc)
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
