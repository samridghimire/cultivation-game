class_name RoadCard
extends CanvasLayer
## WU-443: the road between regions. Travel rebuilds the world, so this card lives under the
## tree root: it fades to dark (~0.3 s), shows "From -> To · 3 days" with a dotted line that
## fills over ~1 s, then fades out onto the new region. Any key or button skips it; with
## `reduce_motion` it is a 0.2 s cut with no line animation. It swallows input while it shows.

const FADE_IN := 0.3
const LINE_SECONDS := 1.0
const FADE_OUT := 0.3
const TOTAL_SECONDS := 1.8
const REDUCED_SECONDS := 0.2
const DOTS := 24

var _elapsed: float = 0.0
var _total: float = TOTAL_SECONDS
var _reduced: bool = false
var _dim: ColorRect
var _box: VBoxContainer
var _line: Label


## "Qingshi Village -> Misty Forest · 3 days", "+1 day, snow" when the snow slowed the road.
static func text_for(from_name: String, to_name: String, days: int, snow_days: int) -> String:
	var text := "%s -> %s · %d %s" % [from_name, to_name, days, "day" if days == 1 else "days"]
	if snow_days > 0:
		text += " (+%d %s, snow)" % [snow_days, "day" if snow_days == 1 else "days"]
	return text


## How many of `total` dots are filled `t` seconds in (0 before the fade-in ends).
static func dots_filled(t: float, total: int) -> int:
	return clampi(int(floor((t - FADE_IN) / LINE_SECONDS * total)), 0, total)


## Black alpha at `t` for a card of `total_s` seconds (fade in, hold, fade out).
static func dim_alpha(t: float, total_s: float, fade_in: float, fade_out: float) -> float:
	if t < fade_in:
		return clampf(t / maxf(fade_in, 0.001), 0.0, 1.0)
	if t > total_s - fade_out:
		return clampf((total_s - t) / maxf(fade_out, 0.001), 0.0, 1.0)
	return 1.0


## Shows the card over the running game; returns null when there is no tree to hold it.
static func show_over(tree: SceneTree, text: String, reduce_motion: bool) -> RoadCard:
	if tree == null:
		return null
	var card := RoadCard.new()
	card._setup(text, reduce_motion)
	tree.root.add_child(card)
	return card


func _setup(text: String, reduce_motion: bool) -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reduced = reduce_motion
	_total = REDUCED_SECONDS if reduce_motion else TOTAL_SECONDS
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 1.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)
	var title := UIStyle.label(text, 26, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_line = UIStyle.label("", 22, Color.WHITE)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_line)
	_apply(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _total:
		queue_free()
		return
	_apply(_elapsed)


func _apply(t: float) -> void:
	var fade_in := 0.0 if _reduced else FADE_IN
	var fade_out := 0.0 if _reduced else FADE_OUT
	var a := dim_alpha(t, _total, fade_in, fade_out) if not _reduced else 1.0
	_dim.color.a = a
	_box.modulate.a = a
	var filled := DOTS if _reduced else dots_filled(t, DOTS)
	_line.text = "•".repeat(filled) + "·".repeat(DOTS - filled)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
			queue_free()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
