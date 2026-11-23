class_name SectContestCard
extends PanelContainer
## WU-611: the yearly outer-sect contest as a moment. Entry mode (opened from the hall before the first bout): the
## sect banner, "<Sect> outer-sect contest", the round ladder (foe and prize per round) and your odds for the next bout.
## "Enter the contest" emits `confirmed` (the HUD then runs GameState.enter_sect_contest); "Not yet" or cancel closes.
## Result mode (one per bout, through the moments queue): won -> prize and the next foe; lost -> "You placed in round N".

signal closed
signal confirmed

const WRAP_WIDTH := 520

var _banner: SectCard.SectBanner
var _title: Label
var _subtitle: Label
var _ladder: Label
var _odds: Label
var _note: Label
var _enter_button: Button
var _back_button: Button


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
	_banner = SectCard.SectBanner.new()
	_banner.custom_minimum_size = Vector2(26, 34)
	head.add_child(_banner)
	_title = UIStyle.label("", 26, UIStyle.ACCENT)
	head.add_child(_title)
	_subtitle = UIStyle.label("", 18)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_ladder = _wrapped(box, 18)
	_odds = _wrapped(box, 18)
	_note = _wrapped(box, 16, Color(0.75, 0.85, 0.7))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_enter_button = UIStyle.button("Enter the contest", _on_enter)
	row.add_child(_enter_button)
	_back_button = UIStyle.button("Not yet", close)
	row.add_child(_back_button)


func _wrapped(box: Control, size: int, color: Color = Color.WHITE) -> Label:
	var l := UIStyle.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	box.add_child(l)
	return l


## "Prize: 10 contribution, 15 spirit stones". Pure.
static func prize_text(prize: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(prize.get("contribution", 0)) > 0:
		parts.append("%d contribution" % int(prize["contribution"]))
	if int(prize.get("spirit_stones", 0)) > 0:
		parts.append("%d spirit stones" % int(prize["spirit_stones"]))
	return ", ".join(parts) if not parts.is_empty() else "no prize"


## One line per round: "Round 1: Village Boxer (Prize: ...)". `marks` is the index of the next bout (earlier rounds are
## shown as won). Pure.
static func ladder_lines(c: CharacterData, data: GameData, next_index: int = 0) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while true:
		var round_def := Sects.contest_round(c, data, i)
		if round_def.is_empty():
			break
		var foe := Sects.trial_opponent(data, String(round_def["foe"]))
		var mark := "won" if i < next_index else ("next" if i == next_index else "")
		out.append("Round %d: %s (%s)%s" % [i + 1, String(foe.get("name", "a rival")), prize_text(round_def["prize"]), " - " + mark if mark != "" else ""])
		i += 1
	return out


## Entry mode. Returns false (and stays closed) when the contest cannot be entered.
func open(c: CharacterData, data: GameData, today: int, color: Color = UIStyle.ACCENT) -> bool:
	if Sects.check_contest(c, data, today) != "":
		return false
	var sect: SectDef = data.sects[c.sect["id"]]
	_style(sect.name, color)
	_subtitle.text = "%s outer-sect contest" % sect.name
	_ladder.text = "\n".join(ladder_lines(c, data))
	var first := Sects.contest_round(c, data, 0)
	var foe := Sects.trial_opponent(data, String(first["foe"]))
	var chance := Combat.win_chance(c, data, foe)  # once, on open
	_odds.text = "First bout vs %s. %s" % [String(foe.get("name", "a rival")), TrialCard.odds_line(chance)]
	_odds.add_theme_color_override("font_color", TrialCard.odds_color(chance))
	_note.text = TrialCard.SAFE_LINE + " You fight until you lose; each win pays its prize."
	_enter_button.visible = true
	_back_button.text = "Not yet"
	visible = true
	if TrialCard.default_to_wait(chance):
		_back_button.grab_focus.call_deferred()
	else:
		_enter_button.grab_focus.call_deferred()
	return true


## Result mode for one bout. `info`: round (1-based), rounds, won, foe, prize, next_foe ("" when none), next_chance.
func open_result(sect_name: String, info: Dictionary, color: Color = UIStyle.ACCENT) -> void:
	_style(sect_name, color)
	_subtitle.text = result_subtitle(info)
	_ladder.text = result_text(info)
	_odds.text = ""
	_odds.remove_theme_color_override("font_color")
	if bool(info.get("won", false)) and String(info.get("next_foe", "")) != "":
		_odds.text = "Next: %s. %s" % [String(info["next_foe"]), TrialCard.odds_line(float(info.get("next_chance", 0.0)))]
	_note.text = ""
	_enter_button.visible = false
	_back_button.text = "OK"
	visible = true
	_back_button.grab_focus.call_deferred()


static func result_subtitle(info: Dictionary) -> String:
	return "Round %d of %d: %s" % [int(info.get("round", 1)), int(info.get("rounds", 1)), "won" if bool(info.get("won", false)) else "lost"]


static func result_text(info: Dictionary) -> String:
	var foe := String(info.get("foe", "your foe"))
	if not bool(info.get("won", false)):
		return "%s beats you. You placed in round %d." % [foe, int(info.get("round", 1))]
	var line := "You defeat %s. Prize: %s." % [foe, prize_text(info.get("prize", {}))]
	if String(info.get("next_foe", "")) == "":
		line += " You have won every round!"
	return line


func _style(sect_name: String, color: Color) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()


func _on_enter() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()
	closed.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func enter_button() -> Button:
	return _enter_button


func back_button() -> Button:
	return _back_button


func all_text() -> String:
	return "\n".join([_title.text, _subtitle.text, _ladder.text, _odds.text, _note.text])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
