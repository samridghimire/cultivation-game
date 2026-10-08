class_name Banner
extends Control
## Full-screen, non-blocking announcement: a brief colored flash and a large
## line of text that fades out. Used for breakthroughs.

const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.6
const MAX_QUEUE := 4

var _flash: ColorRect
var _title: Label
var _subtitle: Label
var _tween: Tween
var _queue: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_right = 1.0
	box.anchor_top = 0.25
	box.anchor_bottom = 0.45
	add_child(box)
	_title = UIStyle.label("", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_title)
	_subtitle = UIStyle.label("", 20)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_subtitle)


func title_text() -> String:
	return _title.text


func subtitle_text() -> String:
	return _subtitle.text


func announce(title: String, subtitle: String, color: Color, hold: float = HOLD_SECONDS) -> void:
	if visible and _tween != null:
		_queue.append([title, subtitle, color, hold])
		while _queue.size() > MAX_QUEUE:
			_drop_oldest()
		return
	_play(title, subtitle, color, hold)


func queued_count() -> int:
	return _queue.size()


## Test hook and tween end: show the next queued banner, or hide.
func finish_current() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _queue.is_empty():
		hide()
		return
	var next: Array = _queue.pop_front()
	_play(next[0], next[1], next[2], next[3])


func _drop_oldest() -> void:
	for i in _queue.size():
		if str(_queue[i][0]) == "Milestone":
			_queue.remove_at(i)
			return
	_queue.remove_at(0)


func _play(title: String, subtitle: String, color: Color, hold: float) -> void:
	if _tween != null:
		_tween.kill()
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_flash.color = Color(color, 0.35)
	modulate.a = 1.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.0, 0.5)
	_tween.tween_interval(maxf(hold - 0.5, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(finish_current)
