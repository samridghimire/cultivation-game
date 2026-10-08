extends Control
## Name your character (surname + given name), pick a gender and roll
## attributes and spiritual roots.

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const WORLD := "res://src/world/world.tscn"

var _candidate: CharacterData
var _surname_edit: LineEdit
var _name_edit: LineEdit
var _gender: OptionButton
var _summary: RichTextLabel
var _begin_button: Button


func _ready() -> void:
	GameState.rng.randomize()
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var panel := UIStyle.panel(Vector2(560, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UIStyle.label("A New Life", 30, UIStyle.ACCENT))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_surname_edit = LineEdit.new()
	_surname_edit.placeholder_text = "Surname"
	_surname_edit.text = "Han"
	_surname_edit.max_length = 12
	_surname_edit.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(_surname_edit)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Given name"
	_name_edit.text = "Li"
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	_gender = OptionButton.new()
	for g in Names.genders(GameState.data):
		_gender.add_item(g.capitalize())
		_gender.set_item_metadata(_gender.item_count - 1, g)
	name_row.add_child(_gender)
	box.add_child(name_row)

	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.custom_minimum_size = Vector2(536, 0)
	box.add_child(_summary)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var reroll := UIStyle.button("Reroll Fate", _reroll)
	buttons.add_child(reroll)
	_begin_button = UIStyle.button("Begin", _begin)
	buttons.add_child(_begin_button)
	buttons.add_child(UIStyle.button("Back", func(): get_tree().change_scene_to_file(MAIN_MENU)))
	box.add_child(buttons)
	add_child(UIStyle.centered(panel))

	_roll()
	reroll.grab_focus.call_deferred()


## Reroll button: new fate, then focus Begin so a gamepad player can start at once.
func _reroll() -> void:
	_roll()
	_begin_button.grab_focus()


## "1.60x, Earth Root (average is 1.0x)" for the talent line.
static func talent_text(roots: Dictionary, data: GameData) -> String:
	return "%.2fx, %s (average is 1.0x)" % [SpiritualRoots.cultivation_multiplier(roots, data), SpiritualRoots.grade_for(roots, data).get("name", "Unknown")]


func _roll() -> void:
	var data := GameState.data
	_candidate = CharacterFactory.create(_name_edit.text, data, GameState.rng, _selected_gender())
	var t := "Spiritual Root: [color=#%s]%s[/color]\n" % [UIStyle.ACCENT.to_html(false), SpiritualRoots.describe(_candidate.spiritual_roots, data)]
	t += "Cultivation talent: %s\n\n" % talent_text(_candidate.spiritual_roots, data)
	for attr in data.attributes:
		t += "%s: %d   [color=#888888]%s[/color]\n" % [attr["name"], _candidate.attribute(attr["id"]), attr["description"]]
	_summary.text = t


func _begin() -> void:
	var given := _name_edit.text.strip_edges()
	Names.apply(_candidate, _surname_edit.text, given if given != "" else "Nameless")
	_candidate.gender = _selected_gender()
	GameState.start_session(_candidate)
	get_tree().change_scene_to_file(WORLD)


func _selected_gender() -> String:
	if _gender.selected < 0:
		return ""
	return String(_gender.get_item_metadata(_gender.selected))
