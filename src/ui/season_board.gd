class_name SeasonBoard
extends PanelContainer
## WU-466: the season's three village tasks as a modal opened from Qingshi's Hunters' Bounty Board:
## check icons, progress, the reward line and the old shrine's stage. Esc/B or Close leaves.

signal closed

const MIN_WIDTH := 520
const MAX_WIDTH := 760
const BOX_SIZE := 14
const DIM := Color(0.6, 0.6, 0.6)

var _title: Label
var _rows: VBoxContainer
var _reward: Label
var _shrine: Label
var _button: Button
var _box: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(MIN_WIDTH, 0)
	_box = box
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_reward = UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"])
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_reward)
	_reward.custom_minimum_size.x = 100
	_shrine = UIStyle.label("", 16, DIM)
	box.add_child(_shrine)
	_button = UIStyle.button("Close", close)
	box.add_child(_button)


## "Village tasks this spring (1 of 3 done)" or "Village tasks this spring: all done".
static func option_label(tasks: Array, season_name: String) -> String:
	var done := tasks.filter(func(t: Dictionary) -> bool: return bool(t["done"])).size()
	if done >= tasks.size():
		return "Village tasks this %s: all done" % season_name
	return "Village tasks this %s (%d of %d done)" % [season_name, done, tasks.size()]


## The current village project's line, e.g. "Old shrine: 2 of 4 stages restored" or "The Founder's Old Well: 1 of 3 stages restored";
## "all whole" when every project stands, "" when the data has none.
static func shrine_line(c: CharacterData, data: GameData) -> String:
	if SeasonTasks.project_list(data).is_empty():
		return ""
	var cur := SeasonTasks.current_project(c, data)
	if cur.is_empty():
		return "The village projects are whole"
	var proj: Dictionary = cur["project"]
	var name := String(proj.get("name", "Project"))
	return "%s: %d of %d stages restored" % [name.substr(0, 1).to_upper() + name.substr(1), int(cur["stage"]), (proj.get("stages", []) as Array).size()]


## True where the season's one-left line belongs: Qingshi or a region one road away (WU-466).
static func near_village(data: GameData, region_id: String) -> bool:
	return region_id == SeasonTasks.REGION or Exploration.is_nearby(data, region_id, SeasonTasks.REGION)


func open() -> void:
	var day := GameClock.total_days
	build(GameState.season_tasks(), SeasonTasks.season_name(day), GameState.season_reward_line(), shrine_line(GameState.player, GameState.data), SeasonTasks.reward_text(GameState.data, day))
	visible = true
	_focus_first.call_deferred()


## Fills the card from plain values (used by open() and the tests).
func build(tasks: Array, season_name: String, reward_done: String, shrine: String, reward_text: String) -> void:
	for ch in _rows.get_children():
		_rows.remove_child(ch)
		ch.queue_free()
	_title.text = "Village tasks this %s" % season_name
	var widest := 0.0
	var font := ThemeDB.fallback_font
	for t: Dictionary in tasks:
		var done := bool(t["done"])
		var text := JournalScreen.season_task_text(t)
		var where := where_line(text, String(t.get("where", "")))
		widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 50.0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cb := CheckBoxIcon.new()
		cb.checked = done
		cb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cb)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var b := Button.new()
		b.text = text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.flat = true
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", DIM if done else Color.WHITE)
		b.tooltip_text = String(t.get("where", ""))
		col.add_child(b)
		if where != "":
			var wl := UIStyle.label(where, 14, DIM)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(wl)
		row.modulate = Color(1, 1, 1, 0.7) if done else Color.WHITE
		_rows.add_child(row)
	_box.custom_minimum_size.x = clampf(widest, MIN_WIDTH, MAX_WIDTH)
	_reward.text = reward_done if reward_done != "" else ("Reward: %s." % reward_text if reward_text != "" else "")
	_shrine.text = shrine
	_shrine.visible = shrine != ""


## The place line shown under a task: "" when the task text already names the place.
static func where_line(text: String, where: String) -> String:
	if where == "" or text.to_lower().contains(where.to_lower()):
		return ""
	return "at " + where


## Row button of task `i` (what takes focus).
func row_button(i: int) -> Button:
	return _rows.get_child(i).get_child(1).get_child(0) as Button


func row_check(i: int) -> CheckBoxIcon:
	return _rows.get_child(i).get_child(0) as CheckBoxIcon


func _focus_first() -> void:
	if not visible or not is_inside_tree():
		return
	first_row().grab_focus()


func first_row() -> Control:
	return row_button(0) if _rows.get_child_count() > 0 else _button


func row_count() -> int:
	return _rows.get_child_count()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## A drawn 14 px check box: outlined square, filled green with a tick when done.
class CheckBoxIcon extends Control:
	var checked: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(SeasonBoard.BOX_SIZE, SeasonBoard.BOX_SIZE + 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(0, 6, SeasonBoard.BOX_SIZE, SeasonBoard.BOX_SIZE)
		if checked:
			draw_rect(r, Color("5fae4a"))
			draw_polyline(PackedVector2Array([Vector2(3, 13), Vector2(6, 16), Vector2(11, 9)]), Color.WHITE, 2.0)
		draw_rect(r, Color("a8e08a") if checked else UIStyle.HINT, false, 1.0)
