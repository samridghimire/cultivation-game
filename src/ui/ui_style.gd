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


static func panel_style() -> StyleBoxFlat:
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


## Swaps the fill colour of a UIStyle.bar.
static func set_bar_fill(b: ProgressBar, fill: Color) -> void:
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(2)
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
