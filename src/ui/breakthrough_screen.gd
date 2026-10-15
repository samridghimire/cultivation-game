class_name BreakthroughScreen
extends PanelContainer
## The window before a major breakthrough without a tribulation (WU-134): the
## chance and its terms, the risk of failing, "Take <pill>" buttons for held
## breakthrough items and the pill source when none is held. Focus never
## starts on Attempt. Rules live in Cultivation / Guidance / GameState.

signal closed

var _title: Label
var _chance: Label
var _terms: Label
var _risk: Label
var _hint: Label
var _pills: VBoxContainer
var _attempt_button: Button
var _later_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 26, UIStyle.ACCENT)
	box.add_child(_title)
	_chance = UIStyle.label("", 22)
	box.add_child(_chance)
	_terms = UIStyle.label("", 16)
	box.add_child(_terms)
	_risk = UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["danger"])
	_risk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_risk)
	_hint = UIStyle.label("", 15, UIStyle.HINT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	_pills = VBoxContainer.new()
	_pills.add_theme_constant_override("separation", 6)
	box.add_child(_pills)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_attempt_button = UIStyle.button("Attempt", _attempt)
	_attempt_button.name = "Attempt"
	row.add_child(_attempt_button)
	_later_button = UIStyle.button("Not yet", close)
	_later_button.name = "NotYet"
	row.add_child(_later_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## "Base (Foundation Establishment)  +35%" per term; negatives read "-N%".
static func term_line(term: Dictionary) -> String:
	var pct := roundi(float(term["value"]) * 100)
	return "%s  %s%d%%" % [term["label"], "+" if pct >= 0 else "-", absi(pct)]


func open() -> void:
	_refresh()
	visible = true
	_focus_first.call_deferred()


func _refresh() -> void:
	var p := GameState.player
	var data := GameState.data
	var next: RealmDef = data.realms[mini(p.realm_index + 1, data.realms.size() - 1)]
	_title.text = "Breakthrough: %s" % next.name
	_chance.text = "%d%% chance" % roundi(Cultivation.breakthrough_chance(p, data) * 100)
	var lines: PackedStringArray = []
	for term in Cultivation.chance_breakdown(p, data):
		lines.append(term_line(term))
	_terms.text = "\n".join(lines)
	_risk.text = Guidance.breakthrough_risk_text(p, data)
	_risk.visible = _risk.text != ""
	for child in _pills.get_children():
		_pills.remove_child(child)
		child.queue_free()
	for item_id in Guidance.breakthrough_item_ids(p, data):
		var bonus := roundi(float(data.items[item_id]["effects"]["breakthrough_bonus"]) * 100)
		var b := UIStyle.button("Take %s (+%d%%)" % [data.items[item_id]["name"], bonus], _take.bind(item_id))
		b.name = "Take_" + item_id
		_pills.add_child(b)
	_hint.text = Guidance.pill_source_hint(p, data) if _pills.get_child_count() == 0 else ""
	_hint.visible = _hint.text != ""


func _focus_first() -> void:
	if not visible:
		return
	if _pills.get_child_count() > 0:
		(_pills.get_child(0) as Button).grab_focus()
	else:
		_later_button.grab_focus()


func _take(item_id: String) -> void:
	GameState.use_item(item_id)
	_refresh()
	_focus_first.call_deferred()


func _attempt() -> void:
	close()
	GameState.attempt_breakthrough()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
