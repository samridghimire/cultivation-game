class_name BreakthroughScreen
extends PanelContainer
## The window before a major breakthrough without a tribulation (WU-134): the
## chance and its terms, the risk of failing, "Take <pill>" buttons for held
## breakthrough items and the pill source when none is held. Focus never
## starts on Attempt. Rules live in Cultivation / Guidance / GameState.

signal closed

var _title: Label
var _blurb: Label
var _chance: Label
var _terms: Label
var _risk: Label
var _hint: Label
var _pills: VBoxContainer
var _vision_box: VBoxContainer
var _vision_text: Label
var _vision_choices: VBoxContainer
var _vision_outcome: Label
var _push_on_asked: bool = false
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
	_blurb = UIStyle.label("", 15, UIStyle.HINT)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(520, 0)
	box.add_child(_blurb)
	_vision_box = VBoxContainer.new()
	_vision_box.add_theme_constant_override("separation", 6)
	box.add_child(_vision_box)
	_vision_text = UIStyle.label("", 16, UIStyle.ACCENT)
	_vision_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vision_text.custom_minimum_size = Vector2(520, 0)
	_vision_box.add_child(_vision_text)
	_vision_choices = VBoxContainer.new()
	_vision_choices.add_theme_constant_override("separation", 6)
	_vision_box.add_child(_vision_choices)
	_vision_outcome = UIStyle.label("", 15)
	_vision_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vision_outcome.custom_minimum_size = Vector2(520, 0)
	_vision_outcome.visible = false
	_vision_box.add_child(_vision_outcome)
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


## "[Comprehension 14, 64%] Face it and let it pass"; choices without a check keep their label.
static func vision_choice_label(p: CharacterData, data: GameData, choice: Dictionary) -> String:
	var label := String(choice["label"])
	var check: Dictionary = choice.get("check", {})
	if check.is_empty():
		return label
	var attr_id := String(check["attribute"])
	var attr_name := attr_id.capitalize()
	for a: Dictionary in data.attributes:
		if String(a.get("id", "")) == attr_id:
			attr_name = String(a.get("name", attr_name))
	return "[%s %d, %d%%] %s" % [attr_name, int(check["target"]), roundi(Exploration.check_chance(p, choice) * 100), label]


## The description of the realm being reached; "" past the final realm.
static func realm_blurb(data: GameData, realm_index: int) -> String:
	if realm_index + 1 >= data.realms.size():
		return ""
	return data.realms[realm_index + 1].description


## The pill source plus how many stones you have against its price.
static func pill_hint(p: CharacterData, data: GameData) -> String:
	var claim := Guidance.sect_pill_claim(p, data)
	if claim != "":
		return claim
	var text := Guidance.pill_source_hint(p, data)
	var price := Guidance.next_realm_pill_price(p, data)
	if text == "" or price <= 0:
		return text
	var stones := p.item_count("spirit_stone")
	if stones >= price:
		return text + " You can afford it." + Guidance.sect_pill_rank_clause(p, data)
	return text + " You have %d of %d stones." % [stones, price] + Guidance.sect_pill_rank_clause(p, data)


func open() -> void:
	_push_on_asked = false
	_vision_outcome.visible = false
	_attempt_button.text = "Attempt"
	_refresh()
	visible = true
	_focus_first.call_deferred()


func _refresh() -> void:
	var p := GameState.player
	var data := GameState.data
	var next: RealmDef = data.realms[mini(p.realm_index + 1, data.realms.size() - 1)]
	_title.text = "Breakthrough: %s" % next.name
	_blurb.text = realm_blurb(data, p.realm_index)
	_blurb.visible = _blurb.text != ""
	_refresh_vision(p, data)
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
	_hint.text = pill_hint(p, data) if _pills.get_child_count() == 0 else ""
	_hint.visible = _hint.text != ""


func _refresh_vision(p: CharacterData, data: GameData) -> void:
	var vision := GameState.heart_vision()
	_vision_box.visible = not vision.is_empty() or _vision_outcome.visible
	for child in _vision_choices.get_children():
		_vision_choices.remove_child(child)
		child.queue_free()
	_vision_text.visible = not vision.is_empty()
	if vision.is_empty():
		return
	_vision_text.text = String(vision["text"])
	var choices: Array = vision["choices"]
	for i in choices.size():
		var b := UIStyle.button(vision_choice_label(p, data, choices[i]), _face.bind(i))
		b.name = "Vision_%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_vision_choices.add_child(b)


## Faces vision choice `index`, then shows the outcome line the log also got.
func _face(index: int) -> void:
	var before := GameState.player.heart_bonus
	GameState.face_heart_vision(index)
	var bonus := GameState.player.heart_bonus
	_vision_outcome.text = "Your heart is steadied." if bonus > before else ("Your heart is shaken." if bonus < before else "Your heart is unmoved.")
	_vision_outcome.visible = true
	_push_on_asked = false
	_attempt_button.text = "Attempt"
	_refresh()
	_focus_first.call_deferred()


func _focus_first() -> void:
	if not visible:
		return
	if _vision_choices.get_child_count() > 0:
		(_vision_choices.get_child(0) as Button).grab_focus()
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
	if _vision_choices.get_child_count() > 0 and not _push_on_asked:
		_push_on_asked = true
		_attempt_button.text = "Push on without facing it?"
		return
	close()
	GameState.attempt_breakthrough()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
