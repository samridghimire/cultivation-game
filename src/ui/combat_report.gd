class_name CombatReport
extends PanelContainer
## Modal blow-by-blow report shown after a fight (EventBus.combat_finished).
## After beating a cultivator it offers "Devour their cultivation"
## (GameState.devour, DEM-001); the chance passes when the report closes.

signal closed

var _title: Label
var _log: RichTextLabel
var _devour_button: Button
var _close_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24)
	box.add_child(_title)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(596, 360)
	_log.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(_log)
	_devour_button = UIStyle.button("", _devour)
	_devour_button.name = "Devour"
	UIStyle.tint_button_text(_devour_button, UIStyle.CATEGORY_COLORS["danger"])
	box.add_child(_devour_button)
	_close_button = UIStyle.button("Continue", close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func show_fight(enemy_name: String, victory: bool, lines: PackedStringArray, advice: String = "", spoils: PackedStringArray = PackedStringArray()) -> void:
	var color: Color = UIStyle.ACCENT if victory else UIStyle.CATEGORY_COLORS["danger"]
	_title.text = "%s: %s" % ["Victory" if victory else "Defeat", enemy_name]
	_title.add_theme_color_override("font_color", color)
	_log.clear()
	for i in lines.size():
		var line := lines[i]
		if i == 0 or i == lines.size() - 1:
			line = "[color=#%s]%s[/color]" % [color.to_html(false), line]
		_log.append_text(line + "\n")
	if not victory and advice != "":
		_log.append_text("[color=#%s]%s[/color]\n" % [UIStyle.CATEGORY_COLORS["warning"].to_html(false), advice])
	if victory and not spoils.is_empty():
		_log.append_text("[color=#%s]Spoils: %s[/color]\n" % [UIStyle.ACCENT.to_html(false), ", ".join(spoils)])
	_show_devour(victory)
	visible = true
	_close_button.grab_focus.call_deferred()


## "Devour their cultivation (+N qi, alignment -100, heart demon risk 25%)".
static func devour_label(c: CharacterData, data: GameData, enemy: Dictionary) -> String:
	return "Devour their cultivation (+%d qi, alignment %+d, heart demon risk %d%%)" % [
		Devouring.qi_gain(data, enemy), int(Devouring.rules(data).get("alignment", 0)), roundi(Devouring.heart_demon_chance(c, data) * 100.0)]


func _show_devour(victory: bool) -> void:
	var enemy: Dictionary = GameState.devour_target
	_devour_button.visible = victory and not enemy.is_empty()
	if not _devour_button.visible:
		return
	_devour_button.text = devour_label(GameState.player, GameState.data, enemy)
	var reason := Devouring.check_devour(GameState.player, GameState.data, enemy)
	_devour_button.disabled = reason != ""
	_devour_button.tooltip_text = reason
	if reason != "":
		_devour_button.text += " (%s)" % reason


func _devour() -> void:
	GameState.devour()
	_devour_button.visible = false
	_close_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.devour_target = {}
	closed.emit()
