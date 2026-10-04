class_name TribulationScreen
extends PanelContainer
## Heavenly Tribulation modal (TRIB-001b). Prepare mode (open_prepare) warns
## before a breakthrough that brings a tribulation: waves, heart demon,
## expected damage against health + readied shield talismans, with "Face the
## heavens" / "Not yet". Sequence mode (show_result) plays the waves of a
## Tribulation.endure result one by one with a falling health bar and the
## outcome. Rules live in Tribulation / GameState.attempt_breakthrough.

signal closed

const WAVE_INTERVAL := 0.7

var _title: Label
var _subtitle: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _log: RichTextLabel
var _buttons: HBoxContainer
var _confirm_button: Button
var _continue_button: Button
var _timer: Timer
## Sequence mode state: the endure result, its realm and waves shown so far.
var _result: Dictionary = {}
var _realm_name := ""
var _revealed := 0


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 26, UIStyle.CATEGORY_COLORS["danger"])
	box.add_child(_title)
	_subtitle = UIStyle.label("", 16)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_subtitle)
	_hp_label = UIStyle.label("", 15)
	box.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(596, 16)
	_hp_bar.show_percentage = false
	box.add_child(_hp_bar)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(596, 200)
	_log.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_log)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_buttons)
	_confirm_button = UIStyle.button("Face the heavens", _confirm)
	_confirm_button.name = "Confirm"
	_buttons.add_child(_confirm_button)
	_continue_button = UIStyle.button("Not yet", _on_continue)
	_continue_button.name = "Continue"
	_buttons.add_child(_continue_button)
	_timer = Timer.new()
	_timer.wait_time = WAVE_INTERVAL
	_timer.timeout.connect(_reveal_next)
	add_child(_timer)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue()


## Lines describing the expected tribulation (Tribulation.preview result).
static func preview_lines(preview: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var waves := int(preview.get("waves", 0))
	var heart := bool(preview.get("heart_demon", false))
	lines.append("%d waves of heavenly lightning%s." % [waves - (1 if heart else 0), ", then your heart demon" if heart else ""])
	var guard := int(preview.get("max_hp", 0)) + int(preview.get("shield", 0))
	lines.append("Expected damage: about %d.  Your health: %d%s." % [
		int(preview.get("expected_damage", 0)), int(preview.get("max_hp", 0)),
		"  + %d from shield talismans" % int(preview["shield"]) if int(preview.get("shield", 0)) > 0 else ""])
	var expected := int(preview.get("expected_damage", 0))
	if expected >= guard:
		lines.append("[color=#%s]You are unlikely to survive. Falling to the final bolt means death.[/color]" % UIStyle.CATEGORY_COLORS["danger"].to_html(false))
	elif expected * 4 >= guard * 3:
		lines.append("[color=#%s]It will be close. Ready shield talismans or raise your defense first.[/color]" % UIStyle.CATEGORY_COLORS["warning"].to_html(false))
	else:
		lines.append("[color=#%s]You should endure it.[/color]" % UIStyle.CATEGORY_COLORS["progress"].to_html(false))
	return lines


## "Lightning wave 2: 140 damage" / "Heart demon: 90 damage" for wave `i`.
static func wave_line(wave: Dictionary, i: int) -> String:
	var what := "Heart demon" if String(wave.get("kind", "")) == "heart_demon" else "Lightning wave %d" % (i + 1)
	return "%s: %d damage  (%d left)" % [what, int(wave.get("damage", 0)), int(wave.get("hp_left", 0))]


## Warns about the tribulation awaiting the next breakthrough.
func open_prepare() -> void:
	var p := GameState.player
	var data := GameState.data
	var preview: Dictionary = GameState.tribulation_preview()
	_result = {}
	_timer.stop()
	var next: RealmDef = data.realms[mini(p.realm_index + 1, data.realms.size() - 1)]
	_title.text = "Heavenly Tribulation"
	_subtitle.text = "If your breakthrough to %s succeeds (%d%% chance), heaven will test you." % [next.name, int(Cultivation.breakthrough_chance(p, data) * 100)]
	var max_hp := int(preview.get("max_hp", 0))
	_hp_label.text = "Health %d" % max_hp
	_hp_bar.max_value = maxf(max_hp, 1)
	_hp_bar.value = max_hp
	_log.clear()
	_log.append_text("\n".join(preview_lines(preview)))
	var shields: PackedStringArray = []
	for item_id in CombatTalismans.available(p, data, "shield"):
		shields.append(String(data.items.get(item_id, {}).get("name", item_id)))
	_log.append_text("\nReadied shield talismans: %s" % (", ".join(shields) if not shields.is_empty() else "none"))
	_confirm_button.visible = true
	_continue_button.text = "Not yet"
	visible = true
	_continue_button.grab_focus.call_deferred()


## Plays the waves of a Tribulation.endure result for the breakthrough into `realm_name`.
func show_result(realm_name: String, result: Dictionary) -> void:
	_result = result
	_realm_name = realm_name
	_revealed = 0
	_title.text = "Tribulation of %s" % realm_name
	_subtitle.text = "Tribulation clouds gather. Lightning answers your breakthrough!"
	var max_hp := int(result.get("max_hp", 0))
	_hp_bar.max_value = maxf(max_hp, 1)
	_hp_bar.value = max_hp
	_hp_label.text = "Health %d / %d" % [max_hp, max_hp]
	_log.clear()
	if not (result.get("talismans_used", PackedStringArray()) as PackedStringArray).is_empty():
		_log.append_text("You burn %s to shield yourself.\n" % ", ".join(result["talismans_used"]))
	_confirm_button.visible = false
	_continue_button.text = "Skip"
	visible = true
	_continue_button.grab_focus.call_deferred()
	if is_inside_tree():
		_timer.start()
	else:
		reveal_all()


## Shows every remaining wave and the outcome at once.
func reveal_all() -> void:
	while not _finished():
		_reveal_next()


func _finished() -> bool:
	return _result.is_empty() or _revealed > (_result.get("waves", []) as Array).size()


func _reveal_next() -> void:
	if _finished():
		_timer.stop()
		return
	var waves: Array = _result.get("waves", [])
	if _revealed < waves.size():
		var wave: Dictionary = waves[_revealed]
		_log.append_text("[color=#%s]%s[/color]\n" % [UIStyle.CATEGORY_COLORS["danger"].to_html(false), wave_line(wave, _revealed)])
		_hp_bar.value = int(wave.get("hp_left", 0))
		_hp_label.text = "Health %d / %d" % [int(wave.get("hp_left", 0)), int(_result.get("max_hp", 0))]
		_flash()
	else:
		_log.append_text(_outcome_line())
		_timer.stop()
		_continue_button.text = "Continue"
	_revealed += 1


func _outcome_line() -> String:
	if bool(_result.get("survived", false)):
		return "[color=#%s]You endure the tribulation and are reforged by its lightning. You enter %s![/color]" % [UIStyle.ACCENT.to_html(false), _realm_name]
	if bool(_result.get("died", false)):
		return "[color=#%s]The final bolt tears through you. Your body turns to ash...[/color]" % UIStyle.CATEGORY_COLORS["danger"].to_html(false)
	return "[color=#%s]You are struck down before the tribulation ends. Your breakthrough fails.[/color]" % UIStyle.CATEGORY_COLORS["warning"].to_html(false)


## A brief white flash for each lightning strike (placeholder game feel).
func _flash() -> void:
	if not is_inside_tree():
		return
	modulate = Color(2.0, 2.0, 2.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func _confirm() -> void:
	close()
	GameState.attempt_breakthrough()


func _on_continue() -> void:
	if not _finished():
		reveal_all()
		return
	close()


func close() -> void:
	if not visible:
		return
	_timer.stop()
	modulate = Color.WHITE
	visible = false
	closed.emit()
