class_name SeasonBoard
extends PanelContainer
## WU-466: the season's three village tasks as a modal opened from Qingshi's Hunters' Bounty Board:
## check icons, progress, the reward line and the old shrine's stage. Esc/B or Close leaves.

signal closed

const WIDTH := 640
const DIM := Color(0.6, 0.6, 0.6)

var _title: Label
var _rows: VBoxContainer
var _reward: Label
var _shrine: Label
var _button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_reward = UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"])
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_reward)
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


## "Old shrine: 2 of 4 stages restored", "" when the data has no shrine.
static func shrine_line(c: CharacterData, data: GameData) -> String:
	var rest := SeasonTasks.restoration(data)
	var total := (rest.get("stages", []) as Array).size()
	if total == 0:
		return ""
	var name := String(rest.get("name", "Shrine"))
	return "%s: %d of %d stages restored" % [name.substr(0, 1).to_upper() + name.substr(1), SeasonTasks.restoration_stage(c, data), total]


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
	for t: Dictionary in tasks:
		var b := Button.new()
		b.text = ("[x] " if bool(t["done"]) else "[ ] ") + JournalScreen.season_task_text(t)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color("a8e08a") if bool(t["done"]) else Color.WHITE)
		var hint := String(t.get("where", ""))
		b.tooltip_text = hint
		if hint != "":
			b.text += "  - " + hint
		_rows.add_child(b)
	_reward.text = reward_done if reward_done != "" else ("Reward: %s." % reward_text if reward_text != "" else "")
	_shrine.text = shrine
	_shrine.visible = shrine != ""


func _focus_first() -> void:
	if not visible or not is_inside_tree():
		return
	var first: Control = _rows.get_child(0) if _rows.get_child_count() > 0 else _button
	first.grab_focus()


func first_row() -> Control:
	return _rows.get_child(0) if _rows.get_child_count() > 0 else _button


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
