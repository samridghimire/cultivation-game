extends Control
## Name your character (surname + given name), pick a gender and roll
## attributes and spiritual roots.

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const WORLD := "res://src/world/world.tscn"

var _candidate: CharacterData
var _surname_edit: LineEdit
var _name_edit: LineEdit
var _gender: OptionButton
var _portrait: TextureRect
var _root_title: Label
var _root_box: VBoxContainer
var _talent_box: HBoxContainer
var _attr_box: VBoxContainer
var _bars: Array[ProgressBar] = []
var _begin_button: Button
var _reroll_button: Button


func _ready() -> void:
	GameState.rng.randomize()
	add_child(TitleBackdrop.new())  # GFX-048: same night-mountain backdrop as the title screen

	var panel := UIStyle.panel(Vector2(860, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UIStyle.label("A New Life", 30, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PixelFigure.SIZE * 6)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_portrait)
	var framed := CenterContainer.new()
	framed.add_child(frame)
	left.add_child(framed)
	_surname_edit = _field(left, "Surname", "Han", 12)
	_name_edit = _field(left, "Given name", "Li", 16)
	left.add_child(UIStyle.label("Sex", 14, Color(0.75, 0.75, 0.75)))
	_gender = OptionButton.new()
	for g in Names.genders(GameState.data):
		_gender.add_item(g.capitalize())
		_gender.set_item_metadata(_gender.item_count - 1, g)
	_gender.item_selected.connect(func(_i: int) -> void: _on_gender_changed())
	left.add_child(_gender)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_root_title = UIStyle.label("", 20, UIStyle.ACCENT)
	right.add_child(_root_title)
	_root_box = VBoxContainer.new()
	_root_box.add_theme_constant_override("separation", 4)
	right.add_child(_root_box)
	_talent_box = HBoxContainer.new()
	_talent_box.add_theme_constant_override("separation", 8)
	right.add_child(_talent_box)
	right.add_child(UIStyle.label("Attributes", 20, UIStyle.ACCENT))
	_attr_box = VBoxContainer.new()
	_attr_box.add_theme_constant_override("separation", 4)
	right.add_child(_attr_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_reroll_button = UIStyle.button("Reroll Fate", _reroll)
	_begin_button = UIStyle.button("Begin", _begin)
	var back := UIStyle.button("Back", func(): get_tree().change_scene_to_file(MAIN_MENU))
	for b: Button in [_reroll_button, _begin_button, back]:  # GFX-048: equal, finger-sized buttons
		b.custom_minimum_size = Vector2(160, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	box.add_child(buttons)
	# Gamepad/keyboard path: name fields, sex and buttons are all reachable.
	add_child(UIStyle.centered(panel))
	_gender.focus_neighbor_bottom = _reroll_button.get_path()
	_reroll_button.focus_neighbor_top = _gender.get_path()

	_roll(false)
	_reroll_button.grab_focus.call_deferred()


func _field(parent: Control, caption: String, text: String, max_len: int) -> LineEdit:
	parent.add_child(UIStyle.label(caption, 14, Color(0.75, 0.75, 0.75)))
	var edit := LineEdit.new()
	edit.placeholder_text = caption
	edit.text = text
	edit.max_length = max_len
	parent.add_child(edit)
	return edit


## Reroll button: new fate, then focus Begin so a gamepad player can start at once.
func _reroll() -> void:
	_roll()
	_begin_button.grab_focus()


## "1.60x, Earth Root (average is 1.0x)" for the talent line.
static func talent_text(roots: Dictionary, data: GameData) -> String:
	return "%.2fx, %s (average is 1.0x)" % [SpiritualRoots.cultivation_multiplier(roots, data), SpiritualRoots.grade_for(roots, data).get("name", "Unknown")]


## GFX-048: how good a talent multiplier is, as {"label", "color"}, so the reroll shows the root's quality at a glance.
static func talent_verdict(multiplier: float) -> Dictionary:
	if multiplier < 0.8:
		return {"label": "Poor", "color": Color("d98a6a")}
	if multiplier < 1.2:
		return {"label": "Average", "color": Color("d6d6d6")}
	if multiplier < 1.8:
		return {"label": "Good", "color": Color("9bd67a")}
	if multiplier < 2.6:
		return {"label": "Excellent", "color": Color("6fd0e8")}
	return {"label": "Heaven-sent", "color": UIStyle.ACCENT}


## Rolls a new candidate and rebuilds the portrait, root rows, talent badge and attribute rows.
func _roll(animate: bool = true) -> void:
	var data := GameState.data
	_candidate = CharacterFactory.create(_name_edit.text, data, GameState.rng, _selected_gender())
	_bars.clear()
	_refresh_portrait()
	_root_title.text = String(SpiritualRoots.grade_for(_candidate.spiritual_roots, data).get("name", "Spiritual Root"))
	_clear(_root_box)
	for e in data.root_elements:
		var purity := int(_candidate.spiritual_roots.get(e["id"], 0))
		if purity <= 0:
			continue
		var row := HBoxContainer.new()
		row.name = "root_" + String(e["id"])
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = CharacterSheet.ELEMENT_COLORS.get(String(e["id"]), Color.WHITE)
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := UIStyle.label(String(e["name"]), 15)
		name_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(name_label)
		row.add_child(_bar_for(swatch.color, purity, 100, Vector2(200, 12)))
		var num := UIStyle.label(str(purity), 15)
		num.custom_minimum_size = Vector2(32, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		_root_box.add_child(row)
	_clear(_talent_box)
	var mult := SpiritualRoots.cultivation_multiplier(_candidate.spiritual_roots, data)
	var verdict := talent_verdict(mult)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = (verdict["color"] as Color).darkened(0.65)
	sb.border_color = verdict["color"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	badge.add_theme_stylebox_override("panel", sb)
	badge.add_child(UIStyle.label(String(verdict["label"]), 15, verdict["color"]))
	badge.name = "talent_badge"
	_talent_box.add_child(badge)
	_talent_box.add_child(UIStyle.label("%.2fx cultivation speed (average is 1.0x)" % mult, 14, Color(0.6, 0.6, 0.6)))
	_clear(_attr_box)
	for attr in data.attributes:
		var row := HBoxContainer.new()
		row.name = "attr_" + String(attr["id"])
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = String(attr["description"])
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var name_label := UIStyle.label(String(attr["name"]), 15)
		name_label.custom_minimum_size = Vector2(108, 0)
		row.add_child(name_label)
		var value := _candidate.attribute(attr["id"])
		var num := UIStyle.label(str(value), 15)
		num.custom_minimum_size = Vector2(26, 0)
		row.add_child(num)
		row.add_child(_bar_for(UIStyle.ACCENT, value, maxi(int(attr.get("roll_max", 20)), 20), Vector2(110, 10)))
		var hint := UIStyle.label(String(attr["description"]).get_slice(".", 1).strip_edges().trim_suffix("."), 13, Color(0.55, 0.55, 0.55))
		hint.clip_text = true
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
		_attr_box.add_child(row)
	if animate:
		_animate()


func _bar_for(color: Color, value: int, max_value: int, size: Vector2) -> ProgressBar:
	var bar := UIStyle.bar(size, color)
	bar.max_value = max_value
	bar.value = value
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bars.append(bar)
	return bar


## Bars grow from 0 and the portrait flashes (0.25 s) after a reroll.
func _animate() -> void:
	var tween := create_tween().set_parallel(true)
	for bar in _bars:
		var target := bar.value
		bar.value = 0
		tween.tween_property(bar, "value", target, 0.25)
	_portrait.modulate = Color(2, 2, 2)
	tween.tween_property(_portrait, "modulate", Color.WHITE, 0.15)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh_portrait() -> void:
	_candidate.gender = _selected_gender()
	_portrait.texture = PixelFigure.frame(PlayerLook.of(_candidate, GameState.data), "down", 0)


func _on_gender_changed() -> void:
	_refresh_portrait()


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
