class_name CraftingScreen
extends PanelContainer
## Modal crafting overview for the workshop (alchemy, forging, talisman inscription):
## known recipes on the left; ingredients (have/need), output, odds and a Craft
## button on the right. All rules live in Alchemy / GameState.refine.

signal closed

const TITLES := {"alchemist": "Alchemy", "blacksmith": "Forge", "talisman_master": "Talisman Inscription", "array_master": "Array Refining", "beast_tamer": "Beast Feed Mixing"}
const BATCH_SIZE := 5
const VERBS := {"alchemist": "Refine", "blacksmith": "Forge", "talisman_master": "Inscribe", "array_master": "Refine", "beast_tamer": "Mix"}

var _title: Label
var _list: VBoxContainer
var _name: Label
var _info: Label
var _ingredients: Label
var _where: Label
var _all_toggle: Button
var _all_sources: Label
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

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size = Vector2(440, 330)
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	details.add_child(_info)
	_ingredients = _wrapped(UIStyle.label("", 16))
	details.add_child(_ingredients)
	_where = _wrapped(UIStyle.label("", 14, Color(0.7, 0.7, 0.7)))
	details.add_child(_where)
	_all_toggle = UIStyle.button("All sources", _toggle_all_sources)
	_all_toggle.name = "AllSources"
	details.add_child(_all_toggle)
	_all_sources = _wrapped(UIStyle.label("", 13, Color(0.7, 0.7, 0.7)))
	_all_sources.visible = false
	details.add_child(_all_sources)
	_output = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_output)
	_odds = _wrapped(UIStyle.label("", 16))
	details.add_child(_odds)
	_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_status)
	_actions = HBoxContainer.new()
	right.add_child(_actions)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(_on_player_changed_rebuild)


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
## A missing ingredient that grows somewhere gets " - grows at <place>" (WU-206; "found at"
## for non-herbs such as ores, WU-201);
## `region_id` makes the current region's place win; `today` (>= 0) respects seasons (GUIDE-048).
static func ingredient_lines(c: CharacterData, data: GameData, recipe_id: String, region_id: String = "", today: int = -1) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		var line := "%d / %d %s" % [c.item_count(item_id), int(ingredients[item_id]), data.items[item_id].get("name", item_id)]
		if c.item_count(item_id) < int(ingredients[item_id]):
			var source := Guidance.source_phrase(c, data, item_id, region_id, today)
			if source != "" and source != "sold by merchants":
				line += " - " + source
		lines.append(line)
	return lines


## True when `source` ("Gathered at <place> (<region>)") is the place the ingredient line
## already names (`place` may read "<place> in <Region>" or "<place> (in <Season>)").
static func _names_gather_place(source: String, place: String) -> bool:
	if not source.begins_with("Gathered at "):
		return false
	var name := source.trim_prefix("Gathered at ").split(" (")[0]
	return place == name or place.begins_with(name + " in ") or place.begins_with(name + " (in ")


const GENERIC_SOURCE_NOTE := "dropped by creatures, found exploring"


## The shop/gather/fishing lines of `Items.sources` for `item_id`, nearest first: this region,
## then by road days from `region_id`, then name; the generic kinds (drops, rewards) are dropped.
## Each entry is the place phrase without its verb ("Village Herb Seller (here)"); returns at most `limit`
## (-1 = all). WU-492.
static func nearest_sources(c: CharacterData, data: GameData, item_id: String, region_id: String = "", limit: int = 2, skip_place: String = "") -> Array[String]:
	var days_to := {}
	for route: Dictionary in Exploration.routes(c, data, region_id):
		if route["ok"]:
			days_to[String(route["to"])] = int(route["days"])
	var ranked: Array = []
	for source in Items.sources(data, item_id):
		var phrase := ""
		for verb in ["Sold at ", "Gathered at ", "Caught at "]:
			if source.begins_with(verb):
				phrase = source.trim_prefix(verb)
		if phrase == "" or (skip_place != "" and _names_gather_place(source, skip_place)):
			continue
		var rank := 9999
		var tag := ""
		for rid: String in data.regions:
			var rname := String(data.regions[rid].get("name", rid))
			if phrase.contains("(" + rname + ")") or phrase.ends_with(", " + rname) or phrase.contains(", " + rname + " "):
				if rid == region_id:
					rank = 0
					tag = " (here)"
				elif days_to.has(rid):
					rank = 1 + int(days_to[rid])
				phrase = phrase.replace(" (" + rname + ")", "").replace(", " + rname, "")
				if tag == "" and rank > 0 and rank < 9999:
					tag = " (%s)" % rname
				elif tag == "":
					tag = " (%s)" % rname
				break
		ranked.append({"rank": rank, "text": phrase + tag})
	ranked.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["rank"] != y["rank"]:
			return x["rank"] < y["rank"]
		return String(x["text"]) < String(y["text"]))
	var out: Array[String] = []
	for r: Dictionary in ranked:
		out.append(String(r["text"]))
	if limit >= 0 and out.size() > limit:
		out = out.slice(0, limit)
	return out


## One short line per ingredient the player lacks: the nearest two places and "+N more"
## (the generic note when only drops/rewards remain). "" when none is missing.
## Gather sources the ingredient line already names are left out (WU-201).
## `today` must match the one given to ingredient_lines so both name the same place.
static func missing_sources_text(c: CharacterData, data: GameData, recipe_id: String, region_id: String = "", today: int = -1) -> String:
	var lines: PackedStringArray = []
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		if c.item_count(item_id) >= int(ingredients[item_id]):
			continue
		var place := Guidance.herb_place(c, data, item_id, region_id, today)
		var all := nearest_sources(c, data, item_id, region_id, -1, place)
		var name: String = data.items[item_id].get("name", item_id)
		if all.is_empty():
			lines.append("%s: %s" % [name, GENERIC_SOURCE_NOTE])
			continue
		var line := "%s: %s" % [name, ", ".join(all.slice(0, 2))]
		if all.size() > 2:
			line += " +%d more" % (all.size() - 2)
		lines.append(line)
	return "\n".join(lines)


## Every source of every missing ingredient, one per line (the "All sources" toggle and tooltip).
static func all_sources_text(c: CharacterData, data: GameData, recipe_id: String) -> String:
	var lines: PackedStringArray = []
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		if c.item_count(item_id) < int(ingredients[item_id]):
			lines.append("%s: %s" % [data.items[item_id].get("name", item_id), "; ".join(Items.sources(data, item_id))])
	return "\n".join(lines)


func _toggle_all_sources() -> void:
	_all_sources.visible = not _all_sources.visible
	_all_toggle.text = "Hide sources" if _all_sources.visible else "All sources"


## "2x Qi Gathering Pill" for a recipe output block ({item, count}).
static func output_text(data: GameData, output: Dictionary) -> String:
	return "%dx %s" % [int(output.get("count", 1)), data.items[output["item"]].get("name", output["item"])]


const READY_SUFFIX := " (ready)"


## Recipes you can make now come first, each group keeping its given order (WU-083).
static func order_recipes(c: CharacterData, data: GameData, ids: PackedStringArray) -> PackedStringArray:
	var ready := PackedStringArray()
	var rest := PackedStringArray()
	for id in ids:
		if Alchemy.check(c, data, id) == "":
			ready.append(id)
		else:
			rest.append(id)
	ready.append_array(rest)
	return ready


func _rebuild() -> void:
	var data := GameState.data
	_title.text = TITLES.get(_prof_id, "Crafting")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := order_recipes(GameState.player, data, Alchemy.known_recipes(GameState.player, data, _prof_id))
	var scrolls := Alchemy.scroll_recipes(GameState.player, data, _prof_id)
	var all_ids := ids.duplicate()
	for recipe_id in scrolls:
		all_ids.append(recipe_id)
	if not all_ids.has(_selected):
		_selected = all_ids[0] if not all_ids.is_empty() else ""
		if not ids.is_empty() and Alchemy.check(GameState.player, data, ids[0]) == "":
			_selected = ids[0]
	if all_ids.is_empty():
		var hint := _wrapped(UIStyle.label("You know no recipes. Recipe scrolls can be bought or found while exploring.", 16, Color(0.7, 0.7, 0.7)))
		hint.custom_minimum_size = Vector2(300, 0)
		_list.add_child(hint)
	for recipe_id in all_ids:
		var label: String = data.recipes[recipe_id]["name"]
		if scrolls.has(recipe_id):
			label += " (scroll)"
		var ready := not scrolls.has(recipe_id) and Alchemy.check(GameState.player, data, recipe_id) == ""
		if ready:
			label += READY_SUFFIX
		var b := UIStyle.button(label, _select.bind(recipe_id))
		b.name = recipe_id
		ItemIcon.apply(b, ItemIcon.for_id(data, str((data.recipes[recipe_id].get("output", {}) as Dictionary).get("item", ""))))
		if ready:
			b.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS.get("good", UIStyle.ACCENT))
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
	for c in [_name, _info, _ingredients, _where, _all_toggle, _all_sources, _output, _odds, _status]:
		c.visible = not recipe.is_empty()
	if recipe.is_empty():
		return
	_name.text = recipe["name"]
	var scroll_item: String = Alchemy.scroll_recipes(p, data, _prof_id).get(_selected, "")
	var min_rank := int(recipe.get("min_rank", 0))
	var prof: ProfessionDef = data.professions[recipe["profession"]]
	_info.text = "Requires %s %s  |  takes %s" % [data.profession_rank_names[min_rank], prof.name, Calendar.format_duration(int(recipe["days"]))]
	_ingredients.text = "Ingredients:\n  " + "\n  ".join(ingredient_lines(p, data, _selected, GameState.current_region, GameClock.total_days)) + "\n" + Alchemy.margin_line(data, _selected)
	_where.text = missing_sources_text(p, data, _selected, GameState.current_region, GameClock.total_days)
	_where.visible = _where.text != ""
	_all_sources.text = all_sources_text(p, data, _selected)
	_all_toggle.visible = _where.visible
	_all_sources.visible = _all_sources.visible and _where.visible
	_ingredients.tooltip_text = _all_sources.text
	_ingredients.mouse_filter = Control.MOUSE_FILTER_STOP if _all_sources.text != "" else Control.MOUSE_FILTER_IGNORE
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


func _on_player_changed_rebuild() -> void:
	if visible:
		_rebuild()
