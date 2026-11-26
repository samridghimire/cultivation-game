class_name RealmCard
extends PanelContainer
## Centered card shown at a major breakthrough (WU-137): the new realm's name and
## description, plus up to three lines of what it brings (lifespan, new features).
## Replaces the "Breakthrough!" banner for that event. Closes on confirm/cancel,
## its button, or after AUTO_CLOSE_SECONDS.

signal closed

const MAX_EXTRA_LINES := 3
const AUTO_CLOSE_SECONDS := 8.0
const WRAP_WIDTH := 640

var _stage: BreakthroughStage  ## GFX-260: the risen / scattered header
var _title: Label
var _desc: Label
var _extra: VBoxContainer
var _button: Button
var _timer: Timer


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	_stage = BreakthroughStage.new()
	_stage.visible = false
	_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_stage)
	_title = UIStyle.label("", 32, UIStyle.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_desc = UIStyle.label("", 18)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_desc)
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 4)
	box.add_child(_extra)
	_button = UIStyle.button("Continue", close)
	box.add_child(_button)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(close)
	add_child(_timer)


## Up to MAX_EXTRA_LINES lines: the surpassed rival first, then the lifespan details, then the notices; empty ones are skipped.
static func card_lines(_realm_desc: String, details: String, notices: Array, surpassed: String = "") -> Array[String]:
	var lines: Array[String] = []
	if surpassed != "":
		lines.append("You have surpassed %s." % surpassed)
	if details != "":
		lines.append(details)
	for n in notices:
		if String(n) != "":
			lines.append(String(n))
	while lines.size() > MAX_EXTRA_LINES:
		lines.pop_back()
	return lines


## The staged header is shown when `look` (a PlayerLook dictionary) is given.
func open(realm_name: String, realm_desc: String, details: String, notices: Array, surpassed: String = "", look: Dictionary = {}, realm_index: int = 1) -> void:
	_stage.visible = not look.is_empty()
	if _stage.visible:
		_stage.set_pose(look, realm_index, "risen")  # WU-632: the title already names the realm
	_title.add_theme_color_override("font_color", UIStyle.ACCENT)
	_title.text = realm_name
	_desc.text = realm_desc
	_desc.visible = realm_desc != ""
	for child in _extra.get_children():
		_extra.remove_child(child)
		child.queue_free()
	for line in card_lines(realm_desc, details, notices, surpassed):
		var l := UIStyle.label(line, 16, UIStyle.CATEGORY_COLORS["progress"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(l)
	visible = true
	_timer.start(AUTO_CLOSE_SECONDS)
	_button.grab_focus.call_deferred()


## GFX-260: a failed gate. `lines` are the qi lost, any injury and the lessons bonus (shown whole, danger-coloured title).
func open_failed(realm_name: String, lines: Array, look: Dictionary, realm_index: int) -> void:
	open("Breakthrough Failed", "Your qi scatters before the gate of %s." % realm_name, "", lines, "", {}, realm_index)
	_stage.visible = true
	_stage.set_pose(look, realm_index, "scattered")
	_title.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS["danger"])


## The lines of a failed card from GameState's details text ("\n"-separated); empty ones dropped.
static func failed_lines(details: String) -> Array[String]:
	var lines: Array[String] = []
	for l in details.split("\n"):
		if l.strip_edges() != "":
			lines.append(l.strip_edges())
	return lines


func close() -> void:
	if not visible:
		return
	visible = false
	_timer.stop()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()
