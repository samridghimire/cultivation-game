class_name Banner
extends Control
## Full-screen, non-blocking announcement: a brief colored flash and a large
## line of text that fades out. Used for breakthroughs.

const HOLD_SECONDS := 1.6
## WU-409: a notice waiting behind another one is shown for this long, so a pair finishes in under 3 s.
const QUEUED_HOLD_SECONDS := 1.0
## Widest the ribbon grows (the 960 px column minus its padding).
const MAX_TEXT_WIDTH := 920.0
const FADE_SECONDS := 0.6
const MAX_QUEUE := 4

var _flash: ColorRect
var _ribbon: PanelContainer
var _title: Label
var _subtitle: Label
var _tween: Tween
var _queue: Array = []
## While held (a combat report or similar window is open) announcements wait in the queue.
var held: bool = false
var _current: Array = []
var _played_msec: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.anchor_left = 0.125  # WU-202: a 960 px column, so a long subtitle trims instead of wrapping into a window title
	holder.anchor_right = 0.875
	holder.anchor_top = 0.03  # WU-158: above the centred windows (menus, shop) so a notice never covers their title
	holder.anchor_bottom = 0.2
	add_child(holder)
	# WU-409: a dark ribbon behind the text, sized to it, so it never fights the place labels.
	_ribbon = PanelContainer.new()
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := UIStyle.panel_style()
	style.bg_color = Color(style.bg_color, 0.85)
	style.set_corner_radius_all(6)
	style.border_color = UIStyle.ACCENT
	style.set_border_width_all(2)
	_ribbon.add_theme_stylebox_override("panel", style)
	holder.add_child(_ribbon)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_child(box)
	_title = UIStyle.label("", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_title)
	_subtitle = UIStyle.label("", 20)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF  # WU-202: one line per "\n"; never grows downward over a window
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.clip_text = true
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_subtitle)


## Seconds a banner is held: a notice with others waiting behind it is shortened (WU-409).
static func hold_for(hold: float, queued: int) -> float:
	if queued <= 0:
		return hold
	return minf(hold, QUEUED_HOLD_SECONDS)


## Whether the ribbon is on screen (test hook).
func ribbon_size() -> Vector2:
	return _ribbon.size


func title_text() -> String:
	return _title.text


func subtitle_text() -> String:
	return _subtitle.text


## `low` banners (the turn of the seasons) never wait in the queue: if something is showing they are dropped.
func announce(title: String, subtitle: String, color: Color, hold: float = HOLD_SECONDS, low: bool = false) -> void:
	if low and (visible or held):
		return
	if held or (visible and _tween != null):
		_queue.append([title, subtitle, color, hold])
		while _queue.size() > MAX_QUEUE:
			_drop_oldest()
		_shorten_current()
		return
	_play(title, subtitle, color, hold)


## Hold or release the banner. Releasing plays the next queued banner if none is showing.
func set_held(value: bool) -> void:
	held = value
	if held and visible and not _current.is_empty():
		# GFX-014: a banner already on screen when a report opens steps back to the front of the queue.
		if _tween != null:
			_tween.kill()
			_tween = null
		_queue.push_front(_current)
		_current = []
		hide()
		return
	if not held and not visible and not _queue.is_empty():
		finish_current()


func queued_count() -> int:
	return _queue.size()


## Test hook and tween end: show the next queued banner, or hide (queued banners keep waiting while held).
func finish_current() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_current = []
	if _queue.is_empty() or held:
		hide()
		return
	var next: Array = _queue.pop_front()
	_play(next[0], next[1], next[2], hold_for(float(next[3]), _queue.size()))


## WU-409: a banner on screen with another waiting behind it fades after QUEUED_HOLD_SECONDS in total.
func _shorten_current() -> void:
	if held or _tween == null or _current.is_empty() or float(_current[3]) <= QUEUED_HOLD_SECONDS:
		return
	var elapsed := float(Time.get_ticks_msec() - _played_msec) / 1000.0
	_current[3] = QUEUED_HOLD_SECONDS
	_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(QUEUED_HOLD_SECONDS - elapsed, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(finish_current)


func _drop_oldest() -> void:
	for i in _queue.size():
		if str(_queue[i][0]) == "Milestone":
			_queue.remove_at(i)
			return
	_queue.remove_at(0)


func _play(title: String, subtitle: String, color: Color, hold: float) -> void:
	_current = [title, subtitle, color, hold]
	_played_msec = Time.get_ticks_msec()
	if _tween != null:
		_tween.kill()
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	var widest := 0.0
	var font := _subtitle.get_theme_font("font")
	for line in subtitle.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	_subtitle.custom_minimum_size.x = minf(widest + 12.0, MAX_TEXT_WIDTH)
	_ribbon.reset_size()
	_flash.color = Color(color, 0.35)
	modulate.a = 1.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.0, 0.5)
	_tween.tween_interval(maxf(hold - 0.5, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(finish_current)
