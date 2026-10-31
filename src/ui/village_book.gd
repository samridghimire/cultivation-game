class_name VillageBook
extends PanelContainer
## WU-414/WU-417: the village book, two pages (Fish, Herbs), each a grid of everything the village yields. Found ones show
## in colour with a count, missing ones as dark silhouettes with a hint. Opened from the journal or the character sheet;
## Esc/B closes; Tab / Shift+Tab (ui_focus_next/prev) switch pages.

signal closed

const COLUMNS := 6
const SLOT_SIZE := Vector2(150, 104)
const SILHOUETTE := Color(0.1, 0.1, 0.12)
const DIM := Color(0.6, 0.6, 0.6)

var _header: Label
var _grid: GridContainer
var _detail: Label
var _close_button: Button
var _silhouettes: Dictionary = {}
var _tabs: HBoxContainer
var _page: String = "fish"


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(1000, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Village book", 24, UIStyle.ACCENT))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	for page: String in ["fish", "herbs"]:
		var tab := UIStyle.button(page.capitalize(), func() -> void: set_page(page))
		tab.name = "Tab_" + page
		_tabs.add_child(tab)
	_header = UIStyle.label("", 16, DIM)
	box.add_child(_header)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_detail = UIStyle.label("", 16)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(960, 48)
	box.add_child(_detail)
	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		set_page("herbs" if _page == "fish" else "fish")


func open() -> void:
	_page = "fish"
	_build()
	visible = true
	_focus_first()


func _focus_first() -> void:
	_grab_first.call_deferred()


func _grab_first() -> void:
	if not visible or not is_inside_tree():
		return
	var first := _grid.get_child(0) if _grid.get_child_count() > 0 else _close_button
	(first as Control).grab_focus()


## Switches to "fish" or "herbs" and keeps a control focused.
func set_page(page: String) -> void:
	_page = page
	_build()
	_focus_first()


## The id list of the current page.
func page_ids() -> PackedStringArray:
	return herb_order(GameState.data) if _page == "herbs" else fish_order(GameState.data)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Fish ids in book order: `Fishing.catchable` (the one source of truth), by region then price.
static func fish_order(data: GameData) -> PackedStringArray:
	return _by_region_then_price(data, Fishing.catchable(data), "fishing")


## Herb ids in book order (`HerbLore.findable` already sorts by region then price).
static func herb_order(data: GameData) -> PackedStringArray:
	return HerbLore.findable(data)


static func _by_region_then_price(data: GameData, ids: PackedStringArray, place_type: String) -> PackedStringArray:
	var rows: Array = []
	for id in ids:
		var region := 0
		var i := 0
		for region_data: Dictionary in data.regions.values():
			if not _region_yields(region_data, id, place_type):
				i += 1
				continue
			region = i
			break
		rows.append({"id": id, "region": region, "price": int(data.items[id].get("price", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["region"] != b["region"]:
			return a["region"] < b["region"]
		return a["price"] < b["price"])
	var out: PackedStringArray = []
	for row: Dictionary in rows:
		out.append(String(row["id"]))
	return out


static func _region_yields(region: Dictionary, id: String, place_type: String) -> bool:
	var key := "catch_table" if place_type == "fishing" else "gather_table"
	for place: Dictionary in region.get("places", []):
		if String(place.get("type", "")) != place_type:
			continue
		for entry: Dictionary in place.get(key, []):
			if String(entry.get("item", "")) == id:
				return true
	return false


## Names of the fishing places (with region) that yield `item_id`.
static func spots_for(data: GameData, item_id: String, place_type: String = "fishing") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key := "catch_table" if place_type == "fishing" else "gather_table"
	for region_id: String in data.regions:
		for place: Dictionary in data.regions[region_id].get("places", []):
			if String(place.get("type", "")) != place_type:
				continue
			for entry: Dictionary in place.get(key, []):
				if String(entry.get("item", "")) == item_id:
					out.append({"region": region_id, "place": String(place.get("display_name", "the water")), "seasons": entry.get("seasons", [])})
					break
	return out


## The detail line: where a found fish/herb turns up, or a hint for a missing one.
static func hint_for(item_id: String, data: GameData, c: CharacterData) -> String:
	var item: Dictionary = data.items.get(item_id, {})
	var herb: bool = item.get("tags", []).has("herb")
	var log: Dictionary = c.herb_log if herb else c.catch_log
	var spots := spots_for(data, item_id, "gather" if herb else "fishing")
	if log.has(item_id):
		var where := ", ".join(PackedStringArray(spots.map(func(s: Dictionary) -> String: return s["place"])))
		var verb := "Grows at" if herb else "Bites at"
		return "%s %s %s." % [String(item.get("description", "")), verb, where] if where != "" else String(item.get("description", ""))
	for s in spots:
		if c.visited_regions.has(s["region"]) or String(s["region"]) == data.start_region:
			var seasons: Array = s["seasons"]
			var when := " in %s" % " or ".join(PackedStringArray(seasons.map(func(x) -> String: return String(x).to_lower()))) if not seasons.is_empty() else ""
			return "Try %s%s." % [s["place"], when]
	return "Somewhere you have not been."


func _silhouette(tex: Texture2D) -> Texture2D:
	if _silhouettes.has(tex):
		return _silhouettes[tex]
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, SILHOUETTE)
	var out := ItemRow.framed(ImageTexture.create_from_image(img))
	_silhouettes[tex] = out
	return out


func _build() -> void:
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	var data: GameData = GameState.data
	var c: CharacterData = GameState.player
	var herbs := _page == "herbs"
	var summary := HerbLore.log_summary(c, data) if herbs else Fishing.log_summary(c, data)
	_header.text = summary if summary != "" else ("Herbs: none found yet" if herbs else "Fish: none caught yet")
	_detail.text = ""
	_build_grid(page_ids(), c.herb_log if herbs else c.catch_log, "found" if herbs else "caught")
	for tab in _tabs.get_children():
		(tab as Button).disabled = false
		(tab as Button).modulate = Color.WHITE if tab.name == "Tab_" + _page else DIM


## One grid for both pages: `log` maps id -> count, `verb` words the count line.
func _build_grid(ids: PackedStringArray, log: Dictionary, verb: String) -> void:
	var data: GameData = GameState.data
	var c: CharacterData = GameState.player
	for id in ids:
		_grid.add_child(_slot(id, data, c, log, verb))


func _slot(id: String, data: GameData, c: CharacterData, log: Dictionary, verb: String) -> Button:
	var found := log.has(id)
	var tex := ItemIcon.for_id(data, id)
	var b := UIStyle.button("", Callable())
	b.name = id
	b.custom_minimum_size = SLOT_SIZE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.expand_icon = false
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 15)
	if tex != null:
		b.icon = ItemRow.framed(tex) if found else _silhouette(tex)
		b.add_theme_constant_override("icon_max_width", ItemRow.SLOT)
	if found:
		b.text = "%s\n%s %d" % [String(data.items[id].get("name", id)), verb, int(log[id])]
	else:
		b.text = "???"
	b.set_meta("found", found)
	var show := func() -> void: _detail.text = hint_for(id, data, c) if not found else "%s: %s" % [String(data.items[id].get("name", id)), hint_for(id, data, c)]
	b.focus_entered.connect(show)
	b.mouse_entered.connect(show)
	return b
