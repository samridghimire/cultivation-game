class_name InheritanceGrounds
extends Interactable
## Inheritance grounds (W-006b, data/inheritances.json): lists each discovered
## inheritance in the current region with its status and, while it can still
## be claimed, "Attempt the <trial>" (GameState.attempt_inheritance) with what
## the trial tests, the danger of a fight trial and the refusal reason.
## GFX-087: the Founder's Old Well is drawn as a well whose look follows the well project's stage (0..3), labelled "(n/3)" until whole;
## a stage change plays a confetti puff; the shimmer on a finished well holds still under reduce_motion.

const WELL_NAME := "Founder's Old Well"
const STONE := Color("8a8478")
const WOOD := Color("7a5636")
const WOOD_OLD := Color("5a4636")
const TILE := Color("3f6d76")
const RED := Color("d9503a")
const WATER := Color("5fa8d8")
const OUTLINE := Color("2a2018")

var _time := 0.0
var _last_stage := -1


func is_founder_well() -> bool:
	return display_name == WELL_NAME


## The well's stage and total as [stage, total] (zeros with no session).
static func well_progress() -> Array[int]:
	return Well.progress(GameState.player, GameState.data)


## "Founder's Old Well (n/3)" while unfinished, the plain name once whole or with no project.
static func well_label(base: String, stage: int, total: int) -> String:
	return base if total == 0 or stage >= total else "%s (%d/%d)" % [base, stage, total]


## Which drawing a stage uses: "choked", "rope", "roofed" or "ribboned".
static func well_variant(stage: int) -> String:
	return ["choked", "rope", "roofed", "ribboned"][clampi(stage, 0, 3)]


func label_text() -> String:
	if not is_founder_well():
		return super()
	var p := well_progress()
	return well_label(display_name, p[0], p[1])


func _refresh() -> void:
	super()
	if not is_founder_well():
		return
	var stage := well_progress()[0]
	if _last_stage >= 0 and stage > _last_stage and is_inside_tree() and not MotionFx.reduced():
		var puff := ConfettiPuff.new()
		puff.position = position + Vector2(0, -size.y * 0.3)
		get_parent().add_child(puff)
	_last_stage = stage
	set_process(highlighted or (stage >= 3 and not MotionFx.reduced()))


func _process(delta: float) -> void:
	_time += delta
	super(delta)


func draw_generated_art() -> bool:
	if not is_founder_well():
		return false
	draw_well(self, size / 2.0, well_progress()[0], 0.0 if MotionFx.reduced() else _time)
	return true


## Draws the well for `stage` into `ci`; `h` is half the footprint; `t` drives the 2-frame water shimmer.
static func draw_well(ci: CanvasItem, h: Vector2, stage: int, t: float) -> void:
	var r := minf(h.x * 0.55, h.y * 0.9)
	var c := Vector2(0, h.y * 0.35)
	PlaceArt.ellipse(ci, c + Vector2(0, r * 0.35), Vector2(r * 1.25, r * 0.4), Color(0, 0, 0, 0.3))
	PlaceArt.ellipse(ci, c, Vector2(r, r * 0.55), STONE)
	PlaceArt.ellipse(ci, c, Vector2(r, r * 0.55), OUTLINE, 1.5)
	PlaceArt.ellipse(ci, c, Vector2(r * 0.7, r * 0.36), Color("1d2a33"))
	if stage == 0:
		for i in 7:  # weeds choking the ring and a broken plank lid
			var a := float(i) / 7.0 * TAU
			var b := c + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.45)
			ci.draw_line(b, b + Vector2(cos(a) * 3.0, -9.0 - float(i % 3) * 3.0), Color("4d7a36"), 2.0)
		ci.draw_line(c + Vector2(-r * 0.6, -2), c + Vector2(r * 0.2, -r * 0.35), WOOD_OLD, 4.0)
		ci.draw_line(c + Vector2(-r * 0.1, r * 0.1), c + Vector2(r * 0.6, -r * 0.1), WOOD_OLD, 4.0)
		return
	if stage >= 3:  # a water glint, two frames
		var gx := r * 0.25 * (1.0 if int(t * 2.0) % 2 == 0 else -1.0)
		ci.draw_line(c + Vector2(gx - 5, 0), c + Vector2(gx + 5, 0), WATER.lightened(0.4), 2.0)
	var post_top := c.y - r * 1.5
	if stage >= 2:
		for x in [-1.0, 1.0]:
			ci.draw_line(Vector2(x * r * 0.9, c.y), Vector2(x * r * 0.9, post_top), WOOD, 5.0)
		var roof := PackedVector2Array([Vector2(-r * 1.3, post_top + 6), Vector2(0, post_top - r * 0.55), Vector2(r * 1.3, post_top + 6)])
		ci.draw_colored_polygon(roof, TILE)
		roof.append(roof[0])
		ci.draw_polyline(roof, OUTLINE, 1.5)
		if stage >= 3:
			ci.draw_line(Vector2(r * 1.0, post_top + 6), Vector2(r * 1.0, post_top + 22), RED, 3.0)
			ci.draw_circle(Vector2(r * 1.0, post_top + 23), 3.0, RED)
	else:
		ci.draw_line(Vector2(-r * 0.9, c.y), Vector2(-r * 0.9, post_top + r * 0.2), WOOD, 4.0)
		ci.draw_line(Vector2(r * 0.9, c.y), Vector2(r * 0.9, post_top + r * 0.2), WOOD, 4.0)
		ci.draw_line(Vector2(-r * 0.9, post_top + r * 0.2), Vector2(r * 0.9, post_top + r * 0.2), WOOD, 3.0)
	var bx := post_top + r * 0.2 if stage < 2 else post_top + 8
	ci.draw_line(Vector2(0, bx), Vector2(0, c.y - 4), Color("c8b48a"), 1.5)  # the new rope
	ci.draw_rect(Rect2(-4, c.y - 8, 8, 7), WOOD)  # the bucket
	ci.draw_rect(Rect2(-4, c.y - 8, 8, 7), OUTLINE, false, 1.0)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c := GameState.player
	var data := GameState.data
	var today: int = GameClock.total_days
	if is_founder_well() and Well.progress(c, data)[1] > 0:
		options.append_array(Well.project_options())  # RV-018 review: the well project's draw lives on this place
	for id in Inheritances.in_region(data, GameState.current_region):
		var def := Inheritances.inheritance(data, id)
		if today < int(def.get("appears_years", 0)) * Calendar.DAYS_PER_YEAR:
			continue  # undiscovered grounds stay hidden
		options.append({"label": "%s: %s" % [def["name"], Inheritances.status_text(c, data, id, today, GameState.world_flags)], "action": func(): pass, "disabled": true})
		var attempt := attempt_option(c, data, id, today)
		if not attempt.is_empty():
			options.append(attempt)
	if options.is_empty():
		options.append({"label": "Weathered stones and silence. Nothing here calls to you yet.", "action": func(): pass, "disabled": true})
	return options


## "Attempt the <trial> (<test>, <days>)" for an inheritance that can still be
## claimed; {} once it is claimed or lost.
static func attempt_option(c: CharacterData, data: GameData, id: String, today: int) -> Dictionary:
	var def := Inheritances.inheritance(data, id)
	if Inheritances.is_claimed(id, GameState.world_flags) or Inheritances.is_lost(def, today, GameState.world_flags):
		return {}
	var stage := Inheritances.next_stage(c, def)
	if stage.is_empty():
		return {}
	var notes: PackedStringArray = [trial_note(c, data, id), Calendar.format_duration(int(stage.get("days", 1)))]
	var label := "Attempt the %s (%s)" % [Inheritances.stage_title(String(stage.get("name", ""))), ", ".join(notes)]
	var reason := Inheritances.check_attempt(c, data, id, GameState.current_region, today, GameState.world_flags)
	return {"label": label, "action": GameState.attempt_inheritance.bind(id), "disabled": reason != "", "reason": reason, "keep_open": true}


## What the next trial of `id` asks, e.g. "Grave Guardian Ape: Dangerous",
## "needs Constitution 11, yours 9" or "needs Qi Refining, 5th Layer" ("" when no trial is left).
static func trial_note(c: CharacterData, data: GameData, id: String) -> String:
	var stage := Inheritances.next_stage(c, Inheritances.inheritance(data, id))
	return "" if stage.is_empty() else test_text(c, data, stage)


## What a trial tests, for one stage.
static func test_text(c: CharacterData, data: GameData, stage: Dictionary) -> String:
	match String(stage.get("test", "")):
		"fight":
			var enemy := Inheritances.stage_enemy(data, stage)
			return "%s: %s" % [enemy.get("name", "?"), UIStyle.fight_label(c, data, enemy)] if not enemy.is_empty() else "a fight"
		"realm":
			return "needs %s" % Inheritances.realm_requirement(data, stage)
		"attribute":
			var attr := String(stage.get("attribute", ""))
			return "needs %s %d, yours %d" % [Inheritances._attribute_name(data, attr), int(stage.get("min", 0)), c.attribute(attr)]
		"alignment":
			return "a test of the heart"
	return "a trial"
