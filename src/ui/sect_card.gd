class_name SectCard
extends PanelContainer
## WU-602: the card shown once when you join a sect. A code-drawn banner on a pole beside the sect's name,
## "You are now <rank>", rows for home, duty and up to 3 perks, the first step in the accent colour, and a
## Continue button that takes focus. Confirm/cancel also closes it. Time does not pass.

signal closed

const WRAP_WIDTH := 520
const BANNER_SCALE := 3  # 8x11 art px drawn at 3x ~ 24x33 px

var _banner: SectBanner
var _title: Label
var _subtitle: Label
var _rows: VBoxContainer
var _step: Label
var _button: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_banner = SectBanner.new()
	_banner.custom_minimum_size = Vector2(26, 34)
	head.add_child(_banner)
	_title = UIStyle.label("", 26, UIStyle.ACCENT)
	head.add_child(_title)
	_subtitle = UIStyle.label("", 18)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_step = UIStyle.label("", 17, UIStyle.ACCENT)
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	box.add_child(_step)
	_button = UIStyle.button("Continue", close)
	box.add_child(_button)


## "Home: Azure Peak, 3 days' walk" / "You are at the sect's home" / "Home: Azure Peak". Pure.
static func home_line(welcome: Dictionary) -> String:
	var days := int(welcome.get("home_days", -1))
	var home := String(welcome.get("home_region_name", ""))
	if days == 0:
		return "You are at the sect's home"
	if days > 0:
		return "Home: %s, %d days' walk" % [home, days] if days != 1 else "Home: %s, 1 day's walk" % home
	return "Home: %s" % home


## WU-604: "gather qi x1.5" -> "Gather qi 1.5x faster"; other perks just get a capital. Pure.
static func perk_line(perk: String) -> String:
	if perk.begins_with("gather qi x"):
		perk = "gather qi %sx faster" % perk.trim_prefix("gather qi x")
	return perk.substr(0, 1).to_upper() + perk.substr(1)


## `welcome` comes from Guidance.sect_welcome; `color` is the sect's robe colour (white-ish when none).
func open(welcome: Dictionary, color: Color = UIStyle.ACCENT) -> void:
	_title.text = String(welcome.get("name", ""))
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "You are now %s" % String(welcome.get("rank_name", ""))
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	var lines := PackedStringArray()
	if String(welcome.get("home_region_name", "")) != "":
		lines.append(home_line(welcome))
	lines.append(String(welcome.get("duty", "")))
	for perk in welcome.get("perks", PackedStringArray()):
		lines.append("- %s" % perk_line(String(perk)))
	for line in lines:
		var l := UIStyle.label(line, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
		_rows.add_child(l)
	_step.text = "First step: %s" % String(welcome.get("first_step", ""))
	_step.visible = true
	visible = true
	_button.grab_focus.call_deferred()


## WU-603: promotion mode. `summary` is Sects.promotion_summary; `sect_name` leads the card; `has_next` is false at the top rank.
func open_promotion(sect_name: String, summary: Dictionary, has_next: bool, color: Color = UIStyle.ACCENT) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Promoted: %s" % String(summary.get("rank_name", ""))
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	var perks: PackedStringArray = summary.get("perks_new", PackedStringArray())
	var lines := PackedStringArray()
	if perks.is_empty():
		lines.append("Your standing in the sect rises")
	for perk in perks:
		lines.append("- %s" % perk)
	for line in lines:
		var l := UIStyle.label(line, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
		_rows.add_child(l)
	var needs := String(summary.get("next_needs", ""))
	if has_next:
		_step.text = "Next rank: %s" % (needs if needs != "" else "a trial awaits")
	else:
		_step.text = ""
	_step.visible = has_next
	visible = true
	_button.grab_focus.call_deferred()


## WU-604: welcome mode after reporting at the hall. `items` is [[item_id, "2 x Qi Gathering Pill"], ...]; `services` from Guidance.hall_services.
func open_report(sect_name: String, rank_name: String, line: String, items: Array, services: PackedStringArray, data: GameData, color: Color = UIStyle.ACCENT) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Welcome to the hall, %s" % rank_name
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	if line != "":
		_add_row("\"%s\"" % line)
	if not items.is_empty():
		_add_row("Received:")
		for it: Array in items:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var icon := TextureRect.new()
			icon.texture = ItemIcon.for_id(data, String(it[0]))
			icon.custom_minimum_size = Vector2(24, 24)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h.add_child(icon)
			var l := UIStyle.label(String(it[1]), 16)
			h.add_child(l)
			_rows.add_child(h)
	if not services.is_empty():
		_add_row("This hall offers:")
		for sv in services:
			_add_row("- %s" % sv)
	_step.text = ""
	_step.visible = false
	visible = true
	_button.grab_focus.call_deferred()


func _add_row(text: String) -> void:
	var l := UIStyle.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	_rows.add_child(l)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func button() -> Button:
	return _button


func all_text() -> String:
	var t := "%s\n%s\n" % [_title.text, _subtitle.text]
	for l in _rows.get_children():
		if l is Label:
			t += (l as Label).text + "\n"
		else:
			for k in l.get_children():
				if k is Label:
					t += (k as Label).text + "\n"
	return t + _step.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


## A small pole with a hanging pennant, drawn in code at BANNER_SCALE.
class SectBanner extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var s := SectCard.BANNER_SCALE
		var pole := Color(0.45, 0.32, 0.2)
		draw_rect(Rect2(0, 0, s, 11 * s), pole)
		draw_rect(Rect2(0, 0, 2 * s, s), Color(0.9, 0.75, 0.3))
		draw_rect(Rect2(s, s, 7 * s, 7 * s), color)
		draw_rect(Rect2(s, 8 * s, 7 * s, s), color.darkened(0.25))  # swallow-tail
		draw_rect(Rect2(4 * s, 8 * s, s, s), Color(0, 0, 0, 0))
		draw_rect(Rect2(3 * s, 3 * s, 3 * s, 3 * s), color.lightened(0.5))
