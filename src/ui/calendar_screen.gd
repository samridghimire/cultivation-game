class_name CalendarScreen
extends PanelContainer
## WU-419: the village calendar. A 6x5 grid of the current month (or the next): today framed in gold, past days dimmed,
## up to two kind icons per day, and the focused day's entries listed in full below. PgUp/PgDn, LB/RB or Tab switch
## between this month and the next; Esc/B closes. Logic lives in VillageCalendar; this only draws it.

signal closed

const COLUMNS := 6
const CELL_SIZE := Vector2(150, 64)
const GOLD := Color("e8c76a")
const DIM := Color(0.5, 0.5, 0.55)

var _title: Label
var _grid: GridContainer
var _detail: Label
var _close_button: Button
var _offset := 0  ## 0 = this month, 1 = next month
var _grid_entries: Dictionary = {}


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(980, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("Calendar", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_detail = UIStyle.label("", 16)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(940, 84)
	box.add_child(_detail)
	var hint := UIStyle.label("PgUp/PgDn or LB/RB: switch month", 14, DIM)
	box.add_child(hint)
	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
	(_grid.get_child(day - 1) as Control).grab_focus()


func _build() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var today := GameClock.total_days
	var start := _month_start()
	# 30 days of this month plus the window that reaches the end of the displayed month.
	var span := start + Calendar.DAYS_PER_MONTH - today
	_grid_entries = VillageCalendar.month_grid(GameState.upcoming_days(maxi(span, 1)), start)
	var season := Calendar.season_of(start)
	_title.text = "Calendar: Year %d, Month %d (%s)" % [Calendar.year_of(start), Calendar.month_of(start), season]
	for d in range(1, Calendar.DAYS_PER_MONTH + 1):
		var total := start + d - 1
		var cell := Button.new()
		cell.name = "Day_%d" % d
		cell.custom_minimum_size = CELL_SIZE
		cell.text = str(d)
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_theme_font_size_override("font_size", 18)
		cell.set_meta("day", d)
		var is_today := total == today
		var past := total < today
		if past:
			cell.add_theme_color_override("font_color", DIM)
		if is_today:
			cell.add_theme_stylebox_override("normal", _today_style())
			cell.add_theme_color_override("font_color", GOLD)
		var icons := HBoxContainer.new()
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		icons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		icons.grow_vertical = Control.GROW_DIRECTION_BEGIN
		icons.offset_right = -6
		icons.offset_bottom = -4
		icons.add_theme_constant_override("separation", 2)
		cell.add_child(icons)
		var shown := 0
		for e: Dictionary in _grid_entries.get(d, []):
			if shown >= 2:
				break
			var tex := HudIcons.calendar_kind(String(e["kind"]), season)
			if tex == null:
				continue
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(24, 24)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.modulate = Color(1, 1, 1, 0.55) if past else Color.WHITE
			rect.name = "Icon_%s" % e["kind"]
			rect.set_meta("kind", e["kind"])
			icons.add_child(rect)
			shown += 1
		cell.set_meta("icons", shown)
		cell.focus_entered.connect(_show_day.bind(d))
		cell.pressed.connect(_show_day.bind(d))
		_grid.add_child(cell)
	_show_day(Calendar.day_of(today) if _offset == 0 else 1)


func _today_style() -> StyleBoxFlat:
	var sb := UIStyle.panel_style()
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.bg_color = Color(0.2, 0.17, 0.08)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	return sb


func _show_day(d: int) -> void:
	var total := _month_start() + d - 1
	var lines: Array[String] = [Calendar.format_date(total) + ("  (today)" if total == GameClock.total_days else "")]
	var entries: Array = _grid_entries.get(d, [])
	if entries.is_empty():
		lines.append("Nothing planned." if total >= GameClock.total_days else "")
	for e: Dictionary in entries:
		lines.append("- " + String(e["text"]))
	_detail.text = "\n".join(lines)
