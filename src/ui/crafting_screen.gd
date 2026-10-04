class_name CraftingScreen
extends PanelContainer
## Modal crafting overview for the workshop (alchemy, forging, talisman inscription):
## known recipes on the left; ingredients (have/need), output, odds and a Craft
## button on the right. All rules live in Alchemy / GameState.refine.

signal closed

const TITLES := {"alchemist": "Alchemy", "blacksmith": "Forge", "talisman_master": "Talisman Inscription"}
const BATCH_SIZE := 5
const VERBS := {"alchemist": "Refine", "blacksmith": "Forge", "talisman_master": "Inscribe"}

var _title: Label
var _list: VBoxContainer
var _name: Label
var _info: Label
var _ingredients: Label
var _output: Label
var _odds: Label
var _status: Label
var _actions: HBoxContainer
var _close_button: Button
var _prof_id := "alchemist"
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(800, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(440, 0)
	details.add_theme_constant_override("separation", 8)
	columns.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	details.add_child(_info)
	_ingredients = _wrapped(UIStyle.label("", 16))
	details.add_child(_ingredients)
	_output = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_output)
	_odds = _wrapped(UIStyle.label("", 16))
	details.add_child(_odds)
	_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_status)
	_actions = HBoxContainer.new()
	details.add_child(_actions)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Opens the screen for the recipes of `prof_id`; plain open() shows alchemy.
func open(prof_id: String = "alchemist") -> void:
	_prof_id = prof_id
	_selected = ""
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## "2 / 3 Spirit Grass" style lines, one per ingredient, plus whether all are held.
static func ingredient_lines(c: CharacterData, data: GameData, recipe_id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		lines.append("%d / %d %s" % [c.item_count(item_id), int(ingredients[item_id]), data.items[item_id].get("name", item_id)])
	return lines


## "2x Qi Gathering Pill" for a recipe output block ({item, count}).
static func output_text(data: GameData, output: Dictionary) -> String:
	return "%dx %s" % [int(output.get("count", 1)), data.items[output["item"]].get("name", output["item"])]


func _rebuild() -> void:
	var data := GameState.data
	_title.text = TITLES.get(_prof_id, "Crafting")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := Alchemy.known_recipes(GameState.player, data, _prof_id)
	var scrolls := Alchemy.scroll_recipes(GameState.player, data, _prof_id)
	var all_ids := ids.duplicate()
	for recipe_id in scrolls:
		all_ids.append(recipe_id)
	if not all_ids.has(_selected):
		_selected = all_ids[0] if not all_ids.is_empty() else ""
	if all_ids.is_empty():
		var hint := _wrapped(UIStyle.label("You know no recipes. Recipe scrolls can be bought or found while exploring.", 16, Color(0.7, 0.7, 0.7)))
		hint.custom_minimum_size = Vector2(300, 0)
		_list.add_child(hint)
	for recipe_id in all_ids:
		var label: String = data.recipes[recipe_id]["name"]
		if scrolls.has(recipe_id):
			label += " (scroll)"
		var b := UIStyle.button(label, _select.bind(recipe_id))
		b.name = recipe_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = recipe_id == _selected
		b.focus_entered.connect(_select.bind(recipe_id))
		_list.add_child(b)
	_show_details()


func _select(recipe_id: String) -> void:
	if recipe_id == _selected:
		return
	_selected = recipe_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == recipe_id)
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var recipe: Dictionary = data.recipes.get(_selected, {})
	for c in [_name, _info, _ingredients, _output, _odds, _status]:
		c.visible = not recipe.is_empty()
	if recipe.is_empty():
		return
	_name.text = recipe["name"]
	var scroll_item: String = Alchemy.scroll_recipes(p, data, _prof_id).get(_selected, "")
	var min_rank := int(recipe.get("min_rank", 0))
	var prof: ProfessionDef = data.professions[recipe["profession"]]
	_info.text = "Requires %s %s  |  takes %s" % [data.profession_rank_names[min_rank], prof.name, Calendar.format_duration(int(recipe["days"]))]
	_ingredients.text = "Ingredients:\n  " + "\n  ".join(ingredient_lines(p, data, _selected))
	var out := "Yields: %s" % output_text(data, recipe["output"])
	if recipe.has("great_output"):
		out += "\nGreat success: %s" % output_text(data, recipe["great_output"])
	_output.text = out
	var odds := "Success chance: %d%%" % roundi(Alchemy.success_chance(p, data, _selected) * 100)
	if recipe.has("great_output"):
		odds += "   Great: %d%%" % roundi(Alchemy.great_chance(p, data, _selected) * 100)
	_odds.text = odds
	if scroll_item != "":
		_odds.text = "You carry a scroll for this recipe but have not studied it yet."
		var study := UIStyle.button("Study scroll", _study.bind(scroll_item))
		study.name = "Study"
		_actions.add_child(study)
		return
	var reason := Alchemy.check(p, data, _selected)
	_status.text = reason
	var craft := UIStyle.button(VERBS.get(_prof_id, "Craft"), _craft)
	craft.name = "Craft"
	craft.disabled = reason != ""
	_actions.add_child(craft)
	var batch := UIStyle.button("%s x%d" % [VERBS.get(_prof_id, "Craft"), BATCH_SIZE], _craft.bind(BATCH_SIZE))
	batch.name = "CraftBatch"
	batch.disabled = reason != ""
	_actions.add_child(batch)


func _craft(times: int = 1) -> void:
	GameState.refine_batch(_selected, times)
	_focus_after_craft.call_deferred()


func _study(item_id: String) -> void:
	GameState.use_item(item_id)
	_focus_selected.call_deferred()


func _focus_after_craft() -> void:
	var craft := _actions.get_node_or_null("Craft") as Button
	if craft != null and not craft.disabled:
		craft.grab_focus()
	else:
		_focus_selected()


func _focus_selected() -> void:
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
