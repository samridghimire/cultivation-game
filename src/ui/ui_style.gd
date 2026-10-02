class_name UIStyle
extends RefCounted
## Shared colors and small widget helpers so UI built in code looks consistent.

const BG := Color("1b1d2b")
const PANEL := Color(0.08, 0.09, 0.13, 0.88)
const ACCENT := Color("e8c76a")
const CATEGORY_COLORS := {
	"info": Color("dddddd"),
	"progress": Color("e8c76a"),
	"warning": Color("e8a04a"),
	"danger": Color("e85a4a"),
	"karma": Color("b58ae8"),
}


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.border_color = ACCENT.darkened(0.5)
	style.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = min_size
	return p


static func label(text: String = "", font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_pressed)
	return b


## A full-screen container that centers its child without blocking the mouse.
static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c
