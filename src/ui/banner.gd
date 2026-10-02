class_name Banner
extends Control
## Full-screen, non-blocking announcement: a brief colored flash and a large
## line of text that fades out. Used for breakthroughs.

const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.6

var _flash: ColorRect
var _title: Label
var _subtitle: Label
var _tween: Tween


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


func announce(title: String, subtitle: String, color: Color) -> void:
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
	_tween.tween_interval(HOLD_SECONDS - 0.5)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)
