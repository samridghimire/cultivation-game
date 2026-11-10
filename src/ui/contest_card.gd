class_name ContestCard
extends PanelContainer
## WU-454: the contest podium. A centred card shown when a festival contest ends (EventBus.contest_finished):
## the contest name, the standings (the player's row highlighted), the prize line and the win/lose text,
## tinted with the festival's colours. Any confirm/cancel or its button closes it; no fade (no motion at all).

signal closed

const WRAP_WIDTH := 520
const DEFAULT_TINT := Color(0.95, 0.8, 0.35)
## Festival colours: red lanterns, gold for the harvest moon, willow green for Qingming.
const TINTS := {
	"lantern_festival": Color(0.9, 0.3, 0.25),
	"mid_autumn_festival": Color(0.95, 0.8, 0.3),
	"qingming_festival": Color(0.5, 0.78, 0.4),
}

var _title: Label
var _place: Label
var _rows: VBoxContainer
var _prize: Label
var _text: Label
var _cheer: Label
var _remark: Label
var _button: Button
var _style: StyleBoxFlat


func _init() -> void:
	_style = UIStyle.flat_panel_style()
	add_theme_stylebox_override("panel", _style)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	_title = UIStyle.label("", 28, DEFAULT_TINT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_place = UIStyle.label("", 20)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_place)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	_cheer = UIStyle.label("", 16, Color(0.8, 0.9, 0.7))
	_cheer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cheer)
	_prize = UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"])
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_prize)
	_text = UIStyle.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_remark = UIStyle.label("", 16, Color(0.85, 0.7, 0.55))
	_remark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_remark)
	_button = UIStyle.button("Continue", close)
	box.add_child(_button)


## "Lan and Wei cheered you on (+2)." from the result's `cheerers` names, "" when nobody cheered.
static func cheer_text(result: Dictionary) -> String:
	var names: Array = result.get("cheerers", [])
	if names.is_empty():
		return ""
	var joined := String(names[0]) if names.size() == 1 else ", ".join(names.slice(0, names.size() - 1)) + " and " + String(names[names.size() - 1])
	return "%s cheered you on (+%d)." % [joined, names.size()]


## The rival's remark in quotes, "" without one.
static func remark_text(result: Dictionary) -> String:
	var line := String(result.get("rival_remark", ""))
	return "\"%s\"" % line if line != "" else ""


static func tint_for(event_id: String) -> Color:
	return TINTS.get(event_id, DEFAULT_TINT)


## "You place 1st of 3." / "You place 3rd of 3."
static func place_line(result: Dictionary) -> String:
	return "You place %s of %d." % [FestivalContest.ordinal(int(result.get("place", 1))), int(result.get("total", 1))]


## "Prize: 2 x Spirit Herb, +2 renown, villagers like you more." or "" when the place won nothing.
static func prize_line(result: Dictionary, data: GameData) -> String:
	var prize: Dictionary = result.get("prize", {})
	var parts := PackedStringArray()
	for item_id: String in prize.get("items", {}):
		var item_name := String(data.items[item_id].name) if data != null and data.items.has(item_id) else item_id
		parts.append("%d x %s" % [int(prize["items"][item_id]), item_name])
	if int(prize.get("renown", 0)) > 0:
		parts.append("+%d renown" % int(prize["renown"]))
	if int(prize.get("favor_all", 0)) > 0:
		parts.append("the villagers think better of you")
	return "Prize: " + ", ".join(parts) + "." if not parts.is_empty() else ""


func open(result: Dictionary, data: GameData) -> void:
	var tint := tint_for(String(result.get("event_id", "")))
	_style.border_color = tint
	_title.text = String(result.get("name", "Contest"))
	_title.add_theme_color_override("font_color", tint)
	_place.text = place_line(result)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var scores: Array = result.get("scores", [])
	var lines := FestivalContest.standings_lines(result)
	for i in lines.size():
		var you: bool = i < scores.size() and bool(scores[i].get("you", false))
		var rival: bool = i < scores.size() and bool(scores[i].get("rival", false))
		var col := tint if you else (Color(0.95, 0.6, 0.35) if rival else Color(0.85, 0.85, 0.85))
		var l := UIStyle.label(("> " if you else "  ") + lines[i], 18, col)
		_rows.add_child(l)
	_cheer.text = cheer_text(result)
	_cheer.visible = _cheer.text != ""
	_remark.text = remark_text(result)
	_remark.visible = _remark.text != ""
	var prize_text := prize_line(result, data)
	_prize.text = prize_text
	_prize.visible = prize_text != ""
	_text.text = String(result.get("text", ""))
	_text.visible = _text.text != ""
	visible = true
	_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func button() -> Button:
	return _button


func rows_text() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _rows.get_children():
		out.append((c as Label).text)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()
