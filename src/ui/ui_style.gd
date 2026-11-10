class_name UIStyle
extends RefCounted
## Shared colors and small widget helpers so UI built in code looks consistent.

const BG := Color("1b1d2b")
const PANEL := Color(0.08, 0.09, 0.13, 1.0)  # GFX-017: opaque, so world labels never show through a window
const ACCENT := Color("e8c76a")
## A dimmer gold for hints that are not yet confirmed.
const HINT := Color("b5a46a")
const CATEGORY_COLORS := {
	"info": Color("dddddd"),
	"progress": Color("e8c76a"),
	"warning": Color("e8a04a"),
	"danger": Color("e85a4a"),
	"karma": Color("b58ae8"),
	"people": Color("e8a0b4"),
}
## Colors for Combat.danger_label ratings.
const DANGER_COLORS := {
	"Weak": Color("8fd18a"),
	"Even": Color("dddddd"),
	"Risky": Color("e8b04a"),
	"Dangerous": Color("e8a04a"),
	"Deadly": Color("e85a4a"),
}


## The shared panel look, for Controls that are themselves the panel (screens
## extending PanelContainer): add_theme_stylebox_override("panel", UIStyle.panel_style()).
## "Dangerous, to the death" / "Even": Combat.danger_label of `enemy`, plus
## ", to the death" when losing the fight is lethal.
static func fight_label(c: CharacterData, data: GameData, enemy: Dictionary, with_odds: bool = true) -> String:
	var label := Appraisal.danger_text(c, data, enemy) if with_odds else Combat.danger_label(c, data, enemy)
	if bool(enemy.get("lethal", false)):
		label += ", to the death"
	return label


## "Even, 80 in 100, to the death": the label and win chance of fighting `enemy`.
static func odds_text(c: CharacterData, data: GameData, enemy: Dictionary, lethal: bool) -> String:
	return odds_wording(Combat.win_chance(c, data, enemy), lethal)


## odds_text for a known win `chance` (0..1).
static func odds_wording(chance: float, lethal: bool) -> String:
	return "%s, %d in 100%s" % [Combat.label_for_chance(chance), roundi(chance * 100.0), ", to the death" if lethal else ""]


## The color for a Combat.danger_label rating (white for anything else).
static func danger_color(danger: String) -> Color:
	return DANGER_COLORS.get(danger, Color.WHITE)


## Recolors a button's text in every state (normal, hover, focus, pressed).
static func tint_button_text(b: Button, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, color)


static var _theme: Theme


## WU-432: one Theme for the controls screens do not style themselves (LineEdit, OptionButton + its popup,
## CheckBox/CheckButton, HSlider, SpinBox, scrollbars), in the panel/accent colours with a gold focus ring.
## Cached; Settings sets it on the root window so every screen inherits it.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var field := _box(PANEL.lightened(0.06), ACCENT.darkened(0.5), 1, 4, 8)
	var field_hover := _box(PANEL.lightened(0.1), ACCENT.darkened(0.2), 1, 4, 8)
	var focus := _box(PANEL.lightened(0.1), ACCENT, 2, 4, 8)
	focus.draw_center = false
	for type in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, focus)
	t.set_stylebox("read_only", "LineEdit", _box(PANEL, ACCENT.darkened(0.6), 1, 4, 8))
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", ACCENT.darkened(0.55))
	t.set_color("font_placeholder_color", "LineEdit", HINT.darkened(0.2))
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "OptionButton", field)
	t.set_stylebox("hover", "OptionButton", field_hover)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_color("font_color", "OptionButton", Color.WHITE)
	t.set_color("font_hover_color", "OptionButton", ACCENT)
	t.set_color("font_focus_color", "OptionButton", ACCENT)
	var popup := _box(PANEL, ACCENT.darkened(0.3), 1, 4, 6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _box(ACCENT.darkened(0.7), ACCENT.darkened(0.7), 0, 3, 4))
	t.set_color("font_color", "PopupMenu", Color.WHITE)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	for type in ["CheckBox", "CheckButton"]:
		t.set_stylebox("focus", type, focus)
		t.set_color("font_hover_color", type, ACCENT)
		t.set_color("font_focus_color", type, ACCENT)
	var track := _box(PANEL.darkened(0.4), ACCENT.darkened(0.5), 1, 3, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT.darkened(0.2), ACCENT.darkened(0.2), 0, 3, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, ACCENT, 0, 3, 0))
	t.set_stylebox("focus", "HSlider", focus)
	for type in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", type, _box(PANEL.darkened(0.4), PANEL.darkened(0.4), 0, 3, 0))
		t.set_stylebox("grabber", type, _box(ACCENT.darkened(0.45), ACCENT.darkened(0.45), 0, 3, 0))
		t.set_stylebox("grabber_highlight", type, _box(ACCENT.darkened(0.2), ACCENT.darkened(0.2), 0, 3, 0))
		t.set_stylebox("grabber_pressed", type, _box(ACCENT, ACCENT, 0, 3, 0))
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


## GFX-099: the framed look (FramedPanel) every HUD panel and modal uses.
static func panel_style() -> FramedPanel:
	var style := FramedPanel.new()
	style.bg_color = PANEL
	style.border_color = ACCENT
	style.set_content_margin_all(12)
	return style


## The plain flat box, for callers that tweak borders, radii or fill (banner, calendar, key bar).
static func flat_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.border_color = ACCENT.darkened(0.5)
	style.set_border_width_all(1)
	return style


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.custom_minimum_size = min_size
	return p


## GFX-031: a progress bar with a visible trough (darkened panel colour, 1 px border) and a rounded fill.
static func bar(size: Vector2, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	var trough := StyleBoxFlat.new()
	trough.bg_color = PANEL.darkened(0.4)
	trough.border_color = ACCENT.darkened(0.5)
	trough.set_border_width_all(1)
	trough.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", trough)
	set_bar_fill(b, fill)
	return b


## WU-485: x of the 1 px gold end cap at the right edge of a bar's fill; -1 when the bar is empty.
static func end_cap_x(width: float, value: float, max_value: float) -> float:
	if value <= 0.0 or max_value <= 0.0:
		return -1.0
	return clampf(roundf(width * minf(value / max_value, 1.0)) - 1.0, 0.0, maxf(width - 1.0, 0.0))


## WU-485: gives a UIStyle.bar a 1 px gold cap at the end of its fill.
static func add_end_cap(b: ProgressBar) -> void:
	b.draw.connect(func() -> void:
		var x := end_cap_x(b.size.x, b.value, b.max_value)
		if x >= 0.0:
			b.draw_rect(Rect2(x, 1, 1, maxf(b.size.y - 2.0, 1.0)), ACCENT))


## Swaps the fill colour of a UIStyle.bar.
static func set_bar_fill(b: ProgressBar, fill: Color) -> void:
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(2)
	f.border_color = fill.lightened(0.35)  # GFX-099: 1 px inner highlight
	f.set_border_width_all(1)
	b.add_theme_stylebox_override("fill", f)


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
	# An empty Callable means the caller connects its own handler (e.g. one bound to the button).
	b.pressed.connect(func() -> void: Audio.play("press"))  # first, so the action's own sound plays over it
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## A full-screen container that centers its child without blocking the mouse.
static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c


## GFX-099: rects (in the label's local space, right-aligned with `margin_right`) of each "[X]" key in `text`,
## so the key bar can draw them as small key caps.
static func key_cap_rects(font: Font, font_size: int, text: String, width: float, margin_right: float, height: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x0 := width - margin_right - total
	var from := 0
	while true:
		var a := text.find("[", from)
		if a < 0:
			break
		var b := text.find("]", a)
		if b < 0:
			break
		var left := font.get_string_size(text.substr(0, a), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var w := font.get_string_size(text.substr(a, b - a + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		rects.append(Rect2(roundf(x0 + left) - 2, 3.0, roundf(w) + 4, height - 6))
		from = b + 1
	return rects
