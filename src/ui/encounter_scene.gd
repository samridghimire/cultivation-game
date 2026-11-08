class_name EncounterScene
extends DuelStage
## WU-488: the 600x120 scene strip at the top of the encounter card. Reuses DuelStage's region
## backdrop (sky, silhouettes, ground), adds the day's rain or snow, and one centre figure chosen
## from the encounter's tags: a beast, a robed stranger, a glowing treasure, or the player alone.

const STRIP_SIZE := Vector2(600, 120)
const BEAST_TAGS := ["beast", "beast_tide", "hunt"]
const ROBED_TAGS := ["cultivator", "npc", "spirit", "recruiter", "disciple", "elder", "stranger", "tournament"]
const TREASURE_TAGS := ["treasure", "herb", "herbs", "chest"]

var _figure: String = "player"
var _snowing: bool = false


func _init() -> void:
	super._init()
	custom_minimum_size = STRIP_SIZE
	size = STRIP_SIZE
	visible = true


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


## Points the strip at an encounter.
func show_encounter(enc: Dictionary) -> void:
	_figure = figure_for(tokens_for(enc))
	_foe_id = String(enc.get("id", ""))
	_foe_beast = _figure == "beast"
	_snowing = GameState.data != null and WorldScript.weather_today(GameState.data, GameState.current_region, GameClock.total_days) == "snow"
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
