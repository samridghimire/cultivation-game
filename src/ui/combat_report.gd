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
var _player_bar: ProgressBar
var _enemy_bar: ProgressBar
var _skip_button: Button
var _timer: Timer

# Playback state (WU-036): lines revealed so far and what to show once done.
var _lines: PackedStringArray = PackedStringArray()
var _trace: Array = []
var _shown: int = 0
var _color: Color = Color.WHITE
var _victory: bool = false
var _advice: String = ""
var _spoils: PackedStringArray = PackedStringArray()
var playing: bool = false

const TICK_SECONDS: float = 0.25


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24)
	box.add_child(_title)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 12)
	box.add_child(bars)
	_player_bar = _make_bar(bars, "You", UIStyle.ACCENT)
	_enemy_bar = _make_bar(bars, "Foe", UIStyle.CATEGORY_COLORS["danger"])
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
	_skip_button = UIStyle.button("Skip", skip)
	_skip_button.name = "Skip"
	box.add_child(_skip_button)
	_close_button = UIStyle.button("Continue", close)
	box.add_child(_close_button)
	_timer = Timer.new()
	_timer.wait_time = TICK_SECONDS
	_timer.timeout.connect(tick)
	add_child(_timer)


func _make_bar(parent: Control, caption: String, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(290, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("caption", caption)
	parent.add_child(bar)
	return bar


func _set_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	bar.max_value = maxi(max_hp, 1)
	bar.value = hp
	bar.tooltip_text = "%s: %d / %d hp" % [bar.get_meta("caption"), hp, max_hp]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if playing:
			skip()
		else:
			close()


## `trace`: Combat.resolve's per-line [your hp, foe hp]; with it (and the
## "Animate fights" setting) the lines are revealed one at a time. Without
## it, or with the setting off, the report is complete at once.
func show_fight(enemy_name: String, victory: bool, lines: PackedStringArray, advice: String = "", spoils: PackedStringArray = PackedStringArray(), trace: Array = [], player_max: int = 0, enemy_max: int = 0) -> void:
	_color = UIStyle.ACCENT if victory else UIStyle.CATEGORY_COLORS["danger"]
	_victory = victory
	_advice = advice
	_spoils = spoils
	_lines = lines
	_trace = trace
	_title.text = "%s: %s" % ["Victory" if victory else "Defeat", enemy_name]
	_title.add_theme_color_override("font_color", _color)
	_log.clear()
	_shown = 0
	var has_bars := trace.size() >= lines.size() and not trace.is_empty() and player_max > 0 and enemy_max > 0
	_player_bar.get_parent().visible = has_bars
	if has_bars:
		_player_bar.set_meta("max", player_max)
		_enemy_bar.set_meta("max", enemy_max)
		_set_bar(_player_bar, player_max, player_max)
		_set_bar(_enemy_bar, enemy_max, enemy_max)
		_enemy_bar.set_meta("caption", enemy_name)
	playing = has_bars and bool(Settings.get_value("animate_fights"))
	visible = true
	_devour_button.visible = false
	if playing:
		_close_button.disabled = true
		_skip_button.visible = true
		_timer.start()
		_skip_button.grab_focus.call_deferred()
	else:
		skip()


## One more line (and the bars it leads to). Public so tests can step it.
func tick() -> void:
	if not playing:
		return
	_reveal(_shown)
	_shown += 1
	if _shown >= _lines.size():
		_finish()


func _reveal(i: int, sound: bool = true) -> void:
	var line := _lines[i]
	if i == 0 or i == _lines.size() - 1:
		line = "[color=#%s]%s[/color]" % [_color.to_html(false), line]
	_log.append_text(line + "\n")
	if i < _trace.size() and _player_bar.get_parent().visible:
		_set_bar(_player_bar, int(_trace[i][0]), int(_player_bar.get_meta("max")))
		_set_bar(_enemy_bar, int(_trace[i][1]), int(_enemy_bar.get_meta("max")))
	if sound and _is_hit(_lines[i]):
		Audio.play(_sound_for_line(_lines[i]))


## Sound name for a log line by blow weight (hits only; callers check _is_hit).
static func _sound_for_line(line: String) -> String:
	if line.contains(Combat.BLOW_WORD_CRUSHING):
		return "hit_heavy"
	if line.contains(Combat.BLOW_WORD_GLANCING):
		return "hit_light"
	return "hit"


func _is_hit(line: String) -> bool:
	return line.contains(" for ")


## Shows everything at once (Skip, accept/cancel, or animation off).
func skip() -> void:
	if not visible:
		return
	if _shown < _lines.size():
		while _shown < _lines.size():
			_reveal(_shown, false)
			_shown += 1
	_finish()


func _finish() -> void:
	playing = false
	_timer.stop()
	_skip_button.visible = false
	_close_button.disabled = false
	if not _victory and _advice != "":
		_log.append_text("[color=#%s]%s[/color]\n" % [UIStyle.CATEGORY_COLORS["warning"].to_html(false), _advice])
	if _victory and not _spoils.is_empty():
		_log.append_text("[color=#%s]Spoils: %s[/color]\n" % [UIStyle.ACCENT.to_html(false), ", ".join(_spoils)])
	_show_devour(_victory)
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
	if playing:
		return
	visible = false
	_timer.stop()
	GameState.devour_target = {}
	closed.emit()
