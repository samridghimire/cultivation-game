class_name CalendarScreen
extends PanelContainer
## WU-419: the village calendar. A 7-column week grid (GFX-078: weekday header, spacers before day 1) of the current month
## (or the next): today framed in gold, past days dimmed, up to two 20 px kind icons and a short label per day, and the
## focused day's entries listed in full below. PgUp/PgDn, LB/RB or Tab switch
## between this month and the next; Enter/A on a day with entries marks it (WU-459, a ChoiceMenu of that day's labels; a marked
## day shows a red seal and offers Unmark); Esc/B closes. Logic lives in VillageCalendar; this only draws it.

signal closed

const COLUMNS := Calendar.DAYS_PER_WEEK
const CELL_SIZE := Vector2(126, 58)
const GOLD := Color("e8c76a")
const MAX_ICONS := 2
const ICON_PX := 20
const LEGEND_PX := 12
const KIND_NAMES := {"market": "Market", "festival_active": "Festival", "festival_day": "Festival", "festival_month": "Festival month", "birthday": "Birthday",
	"field": "Crop", "rent": "Rent", "request": "Request", "secret_realm": "Secret realm", "event": "Event", "great_beast": "Great beast", "hunt": "Village hunt", "forage": "Forage", "season": "Season"}
const SEASON_TINT := {"Spring": Color("f2a7c3"), "Summer": Color("f0c33c"), "Autumn": Color("e0873a"), "Winter": Color("9fd0f0")}
const DIM := Color(0.5, 0.5, 0.55)
const FESTIVAL_BG := Color(0.55, 0.22, 0.2, 0.35)
const FESTIVAL_BAND := Color("d9553f")
const SEAL := Color("c8372d")

var _title: Label
var _grid: GridContainer
var _header: GridContainer
var _cells: Dictionary = {}  ## day of month -> its Button (the grid also holds spacers)
var _detail: Label
var _legend: HBoxContainer
var _omen_legend: HBoxContainer  ## WU-513: the almanac glyph legend row
var _close_button: Button
var _offset := 0  ## 0 = this month, 1 = next month
var _grid_entries: Dictionary = {}
var _menu: ChoiceMenu
var _mark_source: MarkSource
var _focus_day := 1  ## the day cell last focused


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(980, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("Calendar", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_header = GridContainer.new()
	_header.name = "WeekdayHeader"
	_header.columns = COLUMNS
	_header.add_theme_constant_override("h_separation", 8)
	for i in COLUMNS:
		var wd := UIStyle.label(Calendar.weekday_label(i), 14, DIM)
		wd.custom_minimum_size = Vector2(CELL_SIZE.x, 0)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_header.add_child(wd)
	box.add_child(_header)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_legend = HBoxContainer.new()
	_legend.add_theme_constant_override("separation", 14)
	box.add_child(_legend)
	_omen_legend = HBoxContainer.new()
	_omen_legend.add_theme_constant_override("separation", 14)
	box.add_child(_omen_legend)
	_detail = UIStyle.label("", 16)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(940, 84)
	box.add_child(_detail)
	var hint := UIStyle.label("PgUp/PgDn or LB/RB: switch month", 14, DIM)
	box.add_child(hint)
	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	_mark_source = MarkSource.new()
	add_child(_mark_source)
	_menu = ChoiceMenu.new()
	_menu.closed.connect(_on_menu_closed)
	add_child(_menu)
	_menu.set_anchors_preset(Control.PRESET_CENTER)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _menu.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_focus_next") or _is_shoulder(event, JOY_BUTTON_RIGHT_SHOULDER):
		get_viewport().set_input_as_handled()
		set_month_offset(1)
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_focus_prev") or _is_shoulder(event, JOY_BUTTON_LEFT_SHOULDER):
		get_viewport().set_input_as_handled()
		set_month_offset(0)


static func _is_shoulder(event: InputEvent, button: int) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func open() -> void:
	_offset = 0
	_build()
	visible = true
	_grab_focus_day.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## 0 shows this month, 1 the next (past months are not shown).
func set_month_offset(offset: int) -> void:
	offset = clampi(offset, 0, 1)
	if offset == _offset:
		return
	_offset = offset
	_build()
	_grab_focus_day.call_deferred()


func _month_start() -> int:
	return VillageCalendar.month_start(GameClock.total_days) + _offset * Calendar.DAYS_PER_MONTH


func _grab_focus_day() -> void:
	if not visible or not is_inside_tree() or _grid.get_child_count() == 0:
		return
	var today := GameClock.total_days
	var day := Calendar.day_of(today) if _offset == 0 else 1
	_cell(day).grab_focus()


## The Button of day `d` of the shown month.
func _cell(d: int) -> Button:
	return _cells[d] as Button


func _build() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cells.clear()
	var today := GameClock.total_days
	var start := _month_start()
	# 30 days of this month plus the window that reaches the end of the displayed month.
	var span := start + Calendar.DAYS_PER_MONTH - today
	_grid_entries = VillageCalendar.month_grid(GameState.upcoming_days(maxi(span, 1)), start)
	var season := Calendar.season_of(start)
	_title.add_theme_color_override("font_color", SEASON_TINT.get(season, UIStyle.ACCENT))
	_title.text = "Calendar: Year %d, Month %d (%s)" % [Calendar.year_of(start), Calendar.month_of(start), season]
	for i in lead_spacers(start):
		var spacer := Control.new()
		spacer.name = "Spacer_%d" % i
		spacer.custom_minimum_size = CELL_SIZE
		spacer.focus_mode = Control.FOCUS_NONE
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(spacer)
	for d in range(1, Calendar.DAYS_PER_MONTH + 1):
		var total := start + d - 1
		var cell := Button.new()
		cell.name = "Day_%d" % d
		cell.custom_minimum_size = CELL_SIZE
		cell.set_meta("day", d)
		var is_today := total == today
		var past := total < today
		var body := VBoxContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		body.offset_left = 8
		body.offset_top = 3
		body.offset_right = -4
		body.add_theme_constant_override("separation", 0)
		cell.add_child(body)
		var top := HBoxContainer.new()  # WU-470: number and icons share one row so the label below fits whole
		top.name = "TopRow"
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 6)
		body.add_child(top)
		var num := UIStyle.label(str(d), 18, GOLD if is_today else (DIM if past else Color.WHITE))
		num.name = "DayNumber"
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(num)
		var day_entries: Array = _grid_entries.get(d, [])
		var in_festival := festival_in_span(day_entries)
		if is_today:
			cell.add_theme_stylebox_override("normal", _today_style())
		elif in_festival:
			cell.add_theme_stylebox_override("normal", _festival_style())
			cell.set_meta("festival", true)
			var band := ColorRect.new()
			band.name = "FestivalBand"
			band.color = FESTIVAL_BAND
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			band.offset_top = -3
			cell.add_child(band)
		var icons := HBoxContainer.new()
		icons.name = "Icons"
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_theme_constant_override("separation", 2)
		top.add_child(icons)
		var omen := GameState.today_omen(total - today)
		var omen_tex := HudIcons.omen_glyph(omen)
		if omen_tex != null:  # WU-513: the day's almanac omen, first in the icon row
			var orect := TextureRect.new()
			orect.name = "Omen"
			orect.texture = omen_tex
			orect.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
			orect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			orect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			orect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			orect.modulate = Color(1, 1, 1, 0.55) if past else Color.WHITE
			orect.set_meta("omen", String(omen.get("id", "")))
			icons.add_child(orect)
		var shown := 0
		for e: Dictionary in day_entries:
			if shown >= MAX_ICONS:
				break
			var tex := HudIcons.calendar_kind(String(e["kind"]), season)
			if tex == null:
				continue
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.modulate = Color(1, 1, 1, 0.55) if past else Color.WHITE
			rect.name = "Icon_%s" % e["kind"]
			rect.set_meta("kind", e["kind"])
			icons.add_child(rect)
			shown += 1
		if not day_entries.is_empty():
			var more := day_entries.size() - shown
			if more > 0:
				var plus := UIStyle.label("+%d" % more, 12, DIM)
				plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icons.add_child(plus)
			var text := day_label(day_entries)
			if text != "":
				var lbl := UIStyle.label(text, 12, DIM if past else Color(0.82, 0.84, 0.9))
				lbl.name = "ShortLabel"
				lbl.clip_text = true
				lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				body.add_child(lbl)
		cell.set_meta("icons", shown)
		cell.focus_entered.connect(_show_day.bind(d))
		cell.pressed.connect(_on_cell_pressed.bind(d))
		if GameState.player.marked_days.has(total):
			cell.set_meta("marked", true)
			cell.add_child(_seal())
		_grid.add_child(cell)
		_cells[d] = cell
	_build_legend(season)
	_add_omen_legend()
	_show_day(Calendar.day_of(today) if _offset == 0 else 1)


## Legend under the grid: one icon + name per kind present this month (festival kinds share a glyph and a name).
func _build_legend(season: String) -> void:
	for c in _legend.get_children():
		_legend.remove_child(c)
		c.queue_free()
	var present := {}
	for d: int in _grid_entries:
		for e: Dictionary in _grid_entries[d]:
			present[String(e["kind"])] = true
	var names_done := {}
	for kind: String in VillageCalendar.KIND_ORDER:
		if not present.has(kind):
			continue
		var nm: String = "Festival" if kind.begins_with("festival") else String(KIND_NAMES.get(kind, kind))
		if names_done.has(nm):
			continue
		names_done[nm] = true
		var item := HBoxContainer.new()
		item.name = "Legend_%s" % kind
		item.add_theme_constant_override("separation", 4)
		var rect := TextureRect.new()
		rect.texture = HudIcons.calendar_kind(kind, season)
		rect.custom_minimum_size = Vector2(LEGEND_PX, LEGEND_PX)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item.add_child(rect)
		item.add_child(UIStyle.label(nm, 13, DIM))
		item.set_meta("kind", kind)
		_legend.add_child(item)


## Empty grid cells before day 1 so each column is one weekday every month.
static func lead_spacers(month_start_day: int) -> int:
	return Calendar.weekday_of(month_start_day)


## True when any entry belongs to a festival's span (its first day or a later day, CAL-007).
static func festival_in_span(entries: Array) -> bool:
	for e: Dictionary in entries:
		var k := String(e.get("kind", ""))
		if k == "festival_active" or k == "festival_day":
			return true
	return false


## The label a cell prints: the first entry's short word, but nothing for a later day of a running festival
## (WU-470: the name sits on the first day only; the tint and band join the rest).
static func day_label(entries: Array) -> String:
	for e: Dictionary in entries:
		if String(e.get("kind", "")) != "festival_day":
			return short_label(String(e["kind"]))
	return ""


func _festival_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FESTIVAL_BG
	sb.set_corner_radius_all(3)
	return sb


## The short word a cell prints under its icons for an entry kind.
static func short_label(kind: String) -> String:
	if kind.begins_with("festival"):
		return "Festival"
	return String(KIND_NAMES.get(kind, kind.capitalize()))


## "Next: <label> on days 10 and 25; <other> on day 12." for entries [{day, text}] (day of month), identical labels grouped.
static func next_summary(entries: Array) -> String:
	var order: Array[String] = []
	var days: Dictionary = {}
	for e: Dictionary in entries:
		var t := String(e["text"])
		if not days.has(t):
			days[t] = []
			order.append(t)
		if not (days[t] as Array).has(int(e["day"])):
			(days[t] as Array).append(int(e["day"]))
	if order.is_empty():
		return ""
	var parts: PackedStringArray = []
	for t in order:
		var ds: Array = days[t]
		var strs: PackedStringArray = []
		for d in ds:
			strs.append(str(d))
		var when := strs[0] if strs.size() == 1 else "%s and %s" % [", ".join(strs.slice(0, strs.size() - 1)), strs[strs.size() - 1]]
		parts.append("%s on day%s %s" % [t, "" if strs.size() == 1 else "s", when])
	return "Next: " + "; ".join(parts) + "."


func _today_style() -> StyleBoxFlat:
	var sb := UIStyle.flat_panel_style()
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.bg_color = Color(0.2, 0.17, 0.08)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	return sb


## A small red ring in the cell's lower right (draw-only).
func _seal() -> Control:
	var seal := Control.new()
	seal.name = "Seal"
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	seal.position = Vector2(CELL_SIZE.x - 20, CELL_SIZE.y - 20)
	seal.size = Vector2(14, 14)
	seal.draw.connect(func() -> void:
		seal.draw_arc(Vector2(7, 7), 6, 0.0, TAU, 20, SEAL, 2.0)
		seal.draw_circle(Vector2(7, 7), 2.5, SEAL))
	return seal


## The labels one can mark `day` (a total-day number) with: the texts of that day's entries, without repeats.
static func mark_options(entries: Array, day: int) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in entries:
		var text := String(e["text"])
		if int(e["day"]) == day and not out.has(text):
			out.append(text)
	return out


func _on_cell_pressed(d: int) -> void:
	_show_day(d)
	var total := _month_start() + d - 1
	var marks: Dictionary = GameState.player.marked_days
	var opts: Array[Dictionary] = []
	if marks.has(total):
		_mark_source.display_name = "Marked: %s" % String(marks[total])
		opts.append({"label": "Unmark", "action": func() -> void:
			GameState.unmark_day(total)
			_refresh_keep_focus(d)})
	elif total <= GameClock.total_days:
		_detail.text += "\nOnly a future day can be marked."
		return
	else:
		var labels := mark_options(_grid_entries.get(d, []), total)
		if labels.is_empty():
			return
		_mark_source.display_name = "Mark %s" % Calendar.format_date(total)
		for label in labels:
			opts.append({"label": label, "action": func() -> void:
				GameState.mark_day(total, label)
				_refresh_keep_focus(d)})
	_mark_source.options = opts
	_menu.open_for(_mark_source)


func _refresh_keep_focus(d: int) -> void:
	_focus_day = d
	_build()
	_show_day(d)


func _on_menu_closed() -> void:
	if visible and _cells.has(_focus_day):
		_cell(_focus_day).grab_focus.call_deferred()


## ChoiceMenu source for the mark / unmark choice.
class MarkSource extends Node:
	var display_name := ""
	var options: Array[Dictionary] = []

	func menu_options() -> Array[Dictionary]:
		return options


func _show_day(d: int) -> void:
	_focus_day = d
	var total := _month_start() + d - 1
	var lines: Array[String] = [Calendar.format_date_weekday(total) + ("  (today)" if total == GameClock.total_days else "")]
	var entries: Array = _grid_entries.get(d, [])
	if entries.is_empty():
		if total >= GameClock.total_days:
			lines.append(_next_text(total))
	for e: Dictionary in entries:
		lines.append("- " + String(e["text"]))
	var omen := GameState.today_omen(total - GameClock.total_days)
	if not omen.is_empty() and not Almanac.is_plain(omen):
		lines.append("Almanac: " + String(omen.get("name", "")))
	var marked: Dictionary = GameState.player.marked_days
	if marked.has(total):
		lines.append("Marked: %s  [Enter] Unmark" % String(marked[total]))
	elif total > GameClock.total_days and not _grid_entries.get(d, []).is_empty():
		lines.append("[Enter] Mark")
	_detail.text = "\n".join(lines)


## "Next: ..." for an empty day: the next entries after it, identical labels grouped (this month's window only).
func _next_text(total: int) -> String:
	var found: Array = []
	var start := _month_start()
	for d in range(total - start + 2, Calendar.DAYS_PER_MONTH + 1):
		for e: Dictionary in _grid_entries.get(d, []):
			found.append({"day": d, "text": String(e["text"])})
	if found.is_empty():
		return "Nothing planned."
	return next_summary(found)


## WU-513: a one-row legend of the omen glyphs (one per boost key the data uses) under the kind legend.
func _add_omen_legend() -> void:
	for c in _omen_legend.get_children():
		_omen_legend.remove_child(c)
		c.queue_free()
	var seen := {}
	for o: Dictionary in GameState.data.almanac.get("omens", []):
		var key := Almanac.boost_key(o)
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		var tex := HudIcons.omen_glyph(o)
		if tex == null:
			continue
		var item := HBoxContainer.new()
		item.name = "Omen_%s" % key
		item.add_theme_constant_override("separation", 4)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(LEGEND_PX, LEGEND_PX)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item.add_child(rect)
		item.add_child(UIStyle.label(String(o.get("name", "")).trim_prefix("Good for ").capitalize(), 13, DIM))
		_omen_legend.add_child(item)
