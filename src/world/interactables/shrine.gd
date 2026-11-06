class_name Shrine
extends Interactable
## GFX-081: Qingshi's old shrine, repaired one stage per finished season (SeasonTasks.restoration_stage, 0..4).
## Stage 0 a broken roof and fallen stones, 1 cleared stones, 2 new posts, 3 the roof back, 4 painted and lit with
## incense smoke (static under reduce_motion). Redraws whenever the player or the day changes.

const STONE := Color("8a8478")
const DARK := Color("3a342c")
const WOOD_OLD := Color("5a4636")
const WOOD_NEW := Color("a8452f")
const TILE_OLD := Color("4a4a48")
const TILE_NEW := Color("3f6d76")
const GOLD := Color("e0b84a")
const OUTLINE := Color("2a2018")

var _time := 0.0


func _refresh() -> void:
	super()
	set_process(highlighted or (stage_now() >= 4 and not MotionFx.reduced()))


## The restoration stage reached (0 with no session).
static func stage_now() -> int:
	if GameState.player == null:
		return 0
	return SeasonTasks.restoration_stage(GameState.player, GameState.data)


## Total stages in data/season_tasks.json.
static func stage_total() -> int:
	return (SeasonTasks.restoration(GameState.data).get("stages", []) as Array).size()


## Which drawing a stage uses: "broken", "cleared", "posts", "roofed" or "lit".
static func variant(stage: int) -> String:
	return ["broken", "cleared", "posts", "roofed", "lit"][clampi(stage, 0, 4)]


## The one line shown on interaction: the next stage's need, or the finished text.
static func need_line(stage: int, total: int) -> String:
	if total > 0 and stage >= total:
		return "The shrine stands whole again. Incense rises, and the village's qi runs warmer."
	return "Finish this season's three village tasks to %s." % ["clear the fallen stones", "set new posts", "repair the roof", "paint it and light the incense"][clampi(stage, 0, 3)]


func label_text() -> String:
	var total := stage_total()
	var stage := stage_now()
	return display_name if total == 0 or stage >= total else "%s (%d/%d)" % [display_name, stage, total]


func get_options() -> Array[Dictionary]:
	var inc := SeasonTasks.incense(GameState.data)
	if GameState.player != null and not inc.is_empty() and stage_total() > 0 and stage_now() >= stage_total():
		var why := SeasonTasks.can_offer_incense(GameState.player, GameState.data, GameState.world_flags, GameClock.total_days)
		var item_name := String(GameState.data.items.get(String(inc["item"]), {}).get("name", "incense"))
		return [{"label": "Light incense (1 %s)" % item_name, "action": GameState.offer_incense, "disabled": why != "", "reason": why}]
	return [{"label": need_line(stage_now(), stage_total()), "action": func(): pass, "disabled": true}]


func _process(delta: float) -> void:
	_time += delta
	super(delta)


func draw_generated_art() -> bool:
	draw_stage(self, size / 2.0, stage_now(), 0.0 if MotionFx.reduced() else _time)
	return true


## Draws the shrine for `stage` into `ci`; `h` is half the footprint; `t` animates the incense smoke.
static func draw_stage(ci: CanvasItem, h: Vector2, stage: int, t: float) -> void:
	PlaceArt.ellipse(ci, Vector2(0, h.y * 0.8), Vector2(h.x * 0.9, h.y * 0.2), Color(0, 0, 0, 0.3))
	var altar := Rect2(-h.x * 0.35, h.y * 0.25, h.x * 0.7, h.y * 0.55)
	ci.draw_rect(altar, STONE)
	ci.draw_rect(altar, OUTLINE, false, 1.5)
	var post_col := WOOD_NEW if stage >= 4 else WOOD_OLD
	if stage == 0:
		# Fallen stones and one leaning post; a shattered half roof on the ground.
		for p in [Vector2(-0.8, 0.7), Vector2(0.7, 0.8), Vector2(0.2, 0.9), Vector2(-0.4, 0.95)]:
			ci.draw_rect(Rect2(Vector2(p.x * h.x, p.y * h.y), Vector2(h.x * 0.25, h.y * 0.18)), STONE.darkened(0.15))
		ci.draw_line(Vector2(-h.x * 0.6, h.y * 0.3), Vector2(-h.x * 0.45, -h.y * 0.3), WOOD_OLD, 4.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-h.x * 0.7, -h.y * 0.3), Vector2(-h.x * 0.2, -h.y * 0.55), Vector2(-h.x * 0.1, -h.y * 0.35)]), TILE_OLD)
		return
	if stage >= 2:
		for x in [-0.6, 0.6]:
			ci.draw_line(Vector2(x * h.x, h.y * 0.3), Vector2(x * h.x, -h.y * 0.45), post_col, 5.0)
	else:
		ci.draw_line(Vector2(-h.x * 0.6, h.y * 0.3), Vector2(-h.x * 0.55, -h.y * 0.1), WOOD_OLD, 4.0)
	if stage >= 3:
		var tile := TILE_NEW if stage >= 4 else TILE_OLD.lightened(0.1)
		var roof := PackedVector2Array([Vector2(-h.x * 0.9, -h.y * 0.4), Vector2(0, -h.y * 0.95), Vector2(h.x * 0.9, -h.y * 0.4), Vector2(h.x * 0.7, -h.y * 0.3), Vector2(-h.x * 0.7, -h.y * 0.3)])
		ci.draw_colored_polygon(roof, tile)
		roof.append(roof[0])
		ci.draw_polyline(roof, OUTLINE, 1.5)
	if stage >= 4:
		ci.draw_rect(Rect2(-h.x * 0.12, h.y * 0.05, h.x * 0.24, h.y * 0.2), GOLD)
		for x in [-0.6, 0.6]:
			ci.draw_circle(Vector2(x * h.x, -h.y * 0.2), 4.0, Color("d9503a"))
		for i in 3:
			var rise := fmod(t * 14.0 + i * 12.0, 36.0)
			var p := Vector2(sin(t * 1.5 + i) * 4.0, h.y * 0.2 - rise)
			ci.draw_circle(p, 3.0 + rise / 18.0, Color(0.9, 0.9, 0.9, 0.55 * (1.0 - rise / 36.0)))
