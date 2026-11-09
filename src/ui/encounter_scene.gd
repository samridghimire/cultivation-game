class_name EncounterScene
extends DuelStage
## WU-488: the 600x120 scene strip at the top of the encounter card. Reuses DuelStage's region
## backdrop (sky, silhouettes, ground), adds the day's rain or snow, and one centre figure chosen
## from the encounter's tags: a beast, a robed stranger, a glowing treasure, or the player alone.

const STRIP_SIZE := Vector2(600, 120)
## WU-491: a card with more than this many choices gets the short strip so the last button stays on screen.
const SHORT_STRIP_HEIGHT := 72.0
const SHORT_STRIP_CHOICES := 3
const BEAST_TAGS := ["beast", "beast_tide", "hunt"]
const ROBED_TAGS := ["cultivator", "npc", "spirit", "recruiter", "disciple", "elder", "stranger", "tournament"]
const TREASURE_TAGS := ["treasure", "herb", "herbs", "chest"]
## ENC-014: the figures an encounter may name in encounters.json `figure` (GameData.ENCOUNTER_FIGURES).
const FIGURES: Array = GameData.ENCOUNTER_FIGURES
const VILLAGER_LOOK := {"robe": Color("8a6a46"), "sash": Color("5a4630")}
const ELDER_LOOK := {"robe": Color("7d8794"), "sash": Color("c9c2a8"), "hair": Color("d8d8d8"), "style": "long"}
const SPIRIT_TINT := Color(0.8, 0.95, 1.0, 0.6)
const SPIRIT_LOOK := {"robe": Color("cfe8f0"), "sash": Color("ffffff"), "hair": Color("e8f4f8")}
const CORPSE_LOOK := {"robe": Color("5a4a40"), "sash": Color("3a2f2f")}

var _figure: String = "player"
var _snowing: bool = false
var _force_snow: bool = false  # WU-495: the season card's winter strip


func _init() -> void:
	super._init()
	custom_minimum_size = STRIP_SIZE
	size = STRIP_SIZE
	visible = true


## Strip height for a card with `choices` buttons.
static func strip_height_for(choices: int) -> float:
	return SHORT_STRIP_HEIGHT if choices > SHORT_STRIP_CHOICES else STRIP_SIZE.y


func set_choice_count(choices: int) -> void:
	var h := strip_height_for(choices)
	custom_minimum_size = Vector2(STRIP_SIZE.x, h)
	size = custom_minimum_size
	queue_redraw()


## The figure an encounter shows (ENC-014): its own `figure` first, else the tag/id guess.
## Returns a drawn kind: "player" (for `none` or no match), "beast", "robed", "treasure",
## "villager", "child", "elder", "spirit" or "corpse".
static func figure_of(enc: Dictionary) -> String:
	var named := String(enc.get("figure", ""))
	if named == "none":
		return "player"
	if named in FIGURES:
		return named
	return figure_for(tokens_for(enc))


## "beast", "robed", "treasure" or "player" for an encounter's tags (first matching group wins).
static func figure_for(tags: Array) -> String:
	for group: Array in [[BEAST_TAGS, "beast"], [ROBED_TAGS, "robed"], [TREASURE_TAGS, "treasure"]]:
		for t in tags:
			if String(t) in (group[0] as Array):
				return group[1]
	return "player"


## The words figure_for looks at: the encounter's tags plus the words of its id.
static func tokens_for(enc: Dictionary) -> Array:
	var out: Array = (enc.get("tags", []) as Array).duplicate()
	out.append_array(String(enc.get("id", "")).split("_"))
	return out


## WU-501: the backdrop kind for an explore place's PlaceLooks look ("" = keep the region's own backdrop,
## e.g. in a settlement or for an unknown look). Pure.
const LOOK_BACKDROPS := {"cave": "cave", "woods": "pines", "ruins": "ruins", "reeds": "reeds", "ridge": "crags", "trail": "hills"}


static func backdrop_for_look(look: String) -> String:
	return String(LOOK_BACKDROPS.get(look, ""))


## Points the strip at an encounter. `look` is the explore place's look, "" when it did not come from one.
func show_encounter(enc: Dictionary, look: String = "") -> void:
	look_kind = backdrop_for_look(look)
	_figure = figure_of(enc)
	_foe_id = String(enc.get("id", ""))
	_foe_beast = _figure == "beast"
	_snowing = _force_snow or GameState.data != null and WorldScript.weather_today(GameState.data, GameState.current_region, GameClock.total_days) == "snow"
	queue_redraw()


## WU-495: snow on the strip whatever the day's weather.
func set_snow(on: bool) -> void:
	_force_snow = on
	_snowing = on or _snowing
	queue_redraw()


func figure() -> String:
	return _figure


## Falling drops/flakes as points seeded by index (no rng; the same every frame).
static func particles(width: float, height: float, count: int = 40) -> Array:
	var out: Array = []
	for i in count:
		out.append(Vector2(unit_hash("wet", i * 2) * width, unit_hash("wet", i * 2 + 1) * height))
	return out


func _draw() -> void:
	_draw_ground()
	var feet := Vector2(size.x * 0.5, size.y - 18.0)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _figure == "treasure":
		_draw_treasure(feet)
	elif _figure in ["villager", "child", "elder", "spirit", "corpse"]:
		_draw_plain_figure(feet)
	else:
		var tex := _pixel_texture(1 if _figure != "player" else 0)
		var z := 2.0
		var w := tex.get_width() * z
		var h := tex.get_height() * z
		if _figure != "player":
			draw_texture_rect(tex, Rect2(Vector2(w / 2.0, -h) + feet, Vector2(-w, h)), false)
		else:
			draw_texture_rect(tex, Rect2(feet + Vector2(-w / 2.0, -h), Vector2(w, h)), false)
	if is_raining():
		for p: Vector2 in particles(size.x, size.y):
			draw_line(p, p + Vector2(-2, 7), Color(0.75, 0.85, 0.95, 0.6), 1.0)
	elif _snowing:
		for p: Vector2 in particles(size.x, size.y):
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.85))


func _draw_treasure(feet: Vector2) -> void:
	draw_circle(feet + Vector2(0, -14), 20.0, Color(1.0, 0.9, 0.45, 0.25))
	draw_circle(feet + Vector2(0, -14), 12.0, Color(1.0, 0.9, 0.45, 0.35))
	draw_rect(Rect2(feet + Vector2(-12, -18), Vector2(24, 16)), Color("7a4a24"))
	draw_rect(Rect2(feet + Vector2(-12, -18), Vector2(24, 5)), Color("a8703a"))
	draw_rect(Rect2(feet + Vector2(-2, -15), Vector2(4, 5)), UIStyle.ACCENT)


## ENC-014: the plain-person kinds, drawn from PixelFigure looks.
func _draw_plain_figure(feet: Vector2) -> void:
	var look: Dictionary = VILLAGER_LOOK
	match _figure:
		"child":
			look = {"robe": Color("a85a3a"), "sash": Color("e8d9b0"), "child": true}
		"elder":
			look = ELDER_LOOK
		"spirit":
			look = SPIRIT_LOOK
		"corpse":
			look = CORPSE_LOOK
	var tex := PixelFigure.frame(look, "right", 0)
	var z := 2.0
	var w := tex.get_width() * z
	var h := tex.get_height() * z
	var tint := Color.WHITE
	if _figure == "spirit":
		tint = SPIRIT_TINT
		for i in 3:
			var g := feet + Vector2(-26.0 + 26.0 * i, -h * (0.9 - 0.25 * (i % 2)))
			draw_rect(Rect2(g, Vector2(3, 3)), Color(1, 1, 1, 0.9))
			draw_rect(Rect2(g + Vector2(-2, 1), Vector2(7, 1)), Color(1, 1, 1, 0.45))
	if _figure == "corpse":
		draw_set_transform(feet + Vector2(0, -w / 2.0), PI / 2.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), false, Color(0.7, 0.7, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_texture_rect(tex, Rect2(feet + Vector2(-w / 2.0, -h), Vector2(w, h)), false, tint)
