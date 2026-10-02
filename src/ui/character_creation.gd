extends Control
## Name your character and roll attributes and spiritual roots.

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const WORLD := "res://src/world/world.tscn"

var _candidate: CharacterData
var _name_edit: LineEdit
var _summary: RichTextLabel


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

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.text = "Han Li"
	_name_edit.max_length = 24
	box.add_child(_name_edit)

	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.custom_minimum_size = Vector2(536, 0)
	box.add_child(_summary)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var reroll := UIStyle.button("Reroll Fate", _roll)
	buttons.add_child(reroll)
	buttons.add_child(UIStyle.button("Begin", _begin))
	buttons.add_child(UIStyle.button("Back", func(): get_tree().change_scene_to_file(MAIN_MENU)))
	box.add_child(buttons)
	add_child(UIStyle.centered(panel))

	_roll()
	reroll.grab_focus.call_deferred()


func _roll() -> void:
	var data := GameState.data
	_candidate = CharacterFactory.create(_name_edit.text, data, GameState.rng)
	var t := "Spiritual Root: [color=#%s]%s[/color]\n" % [UIStyle.ACCENT.to_html(false), SpiritualRoots.describe(_candidate.spiritual_roots, data)]
	t += "Cultivation talent: %.2fx\n\n" % SpiritualRoots.cultivation_multiplier(_candidate.spiritual_roots, data)
	for attr in data.attributes:
		t += "%s: %d   [color=#888888]%s[/color]\n" % [attr["name"], _candidate.attribute(attr["id"]), attr["description"]]
	_summary.text = t


func _begin() -> void:
	var chosen_name := _name_edit.text.strip_edges()
	_candidate.name = chosen_name if chosen_name != "" else "Nameless"
	GameState.start_session(_candidate)
	get_tree().change_scene_to_file(WORLD)
