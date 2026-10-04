class_name TimeSkipOverlay
extends Control
## Short overlay after a long action skips time (UI-010): "Meditating... 1 month",
## a progress bar that fills over FILL_SECONDS, then the TimeSkip.summarize lines.
## World and menu input is locked while it shows; any key/button press dismisses it.

signal closed

const FILL_SECONDS := 0.6
const HOLD_SECONDS := 1.8

var _title: Label
var _bar: ProgressBar
var _lines: Label
var _hint: Label
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := UIStyle.panel(Vector2(440, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(400, 16)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	box.add_child(_bar)
	_lines = UIStyle.label("", 18)
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_lines)
	_hint = UIStyle.label("Press any button to continue", 14, Color(0.7, 0.7, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	var center := UIStyle.centered(panel)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)


## Show a TimeSkip.summarize() result: {title, days, lines}.
func show_skip(summary: Dictionary) -> void:
	if _tween != null:
		_tween.kill()
	_title.text = "%s... %s" % [summary.get("title", "Time passes"), Calendar.format_duration(int(summary.get("days", 0)))]
	_lines.text = "\n".join(PackedStringArray(summary.get("lines", [])))
	_lines.modulate.a = 0.0
	_bar.value = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(_bar, "value", 1.0, FILL_SECONDS)
	_tween.tween_property(_lines, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_callback(close)


## The summary text currently shown (for tests).
func summary_text() -> String:
	return _lines.text


func close() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if not visible:
		return
	visible = false
	closed.emit()


## Runs before GUI input: swallow everything so the menu underneath and the
## world stay locked, and let any fresh press dismiss the overlay.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if is_dismiss_event(event):
		close()


## A press (not a release, echo or stick motion) of a key, gamepad or mouse button.
static func is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.pressed
	return false
