class_name VillageBook
extends PanelContainer
## WU-414: the village book, a grid of every fish the village waters yield. Caught ones show in colour with a count,
## missing ones as dark silhouettes with a hint. Opened from the journal; Esc/B closes. (Herb tab: after GATHER-002.)

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


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(1000, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Village book", 24, UIStyle.ACCENT))
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
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_build()
	visible = true
	var first := _grid.get_child(0) if _grid.get_child_count() > 0 else _close_button
	(first as Control).grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Fish ids in book order: by region (data order), then price ascending.
static func fish_order(data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		var ids: Array[String] = []
		for place: Dictionary in region.get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			for entry: Dictionary in place.get("catch_table", []):
				var id := String(entry.get("item", ""))
				if id != "" and not out.has(id) and not ids.has(id) and data.items.get(id, {}).get("tags", []).has("fish"):
					ids.append(id)
		ids.sort_custom(func(a: String, b: String) -> bool: return int(data.items[a].get("price", 0)) < int(data.items[b].get("price", 0)))
		out.append_array(PackedStringArray(ids))
	return out


## Names of the fishing places (with region) that yield `item_id`.
static func spots_for(data: GameData, item_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for region_id: String in data.regions:
		for place: Dictionary in data.regions[region_id].get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			for entry: Dictionary in place.get("catch_table", []):
				if String(entry.get("item", "")) == item_id:
					out.append({"region": region_id, "place": String(place.get("display_name", "the water")), "seasons": entry.get("seasons", [])})
					break
	return out


## The detail line: where a caught fish bites, or a hint for a missing one.
static func hint_for(item_id: String, data: GameData, c: CharacterData) -> String:
	var item: Dictionary = data.items.get(item_id, {})
	var spots := spots_for(data, item_id)
	if c.catch_log.has(item_id):
		var where := ", ".join(PackedStringArray(spots.map(func(s: Dictionary) -> String: return s["place"])))
		return "%s Bites at %s." % [String(item.get("description", "")), where] if where != "" else String(item.get("description", ""))
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
	var summary := Fishing.log_summary(c, data)
	_header.text = summary if summary != "" else "Fish: none caught yet"
	_detail.text = ""
	for id in fish_order(data):
		_grid.add_child(_slot(id, data, c))


func _slot(id: String, data: GameData, c: CharacterData) -> Button:
	var found := c.catch_log.has(id)
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
		b.text = "%s\ncaught %d" % [String(data.items[id].get("name", id)), int(c.catch_log[id])]
	else:
		b.text = "???"
	b.set_meta("found", found)
	var show := func() -> void: _detail.text = hint_for(id, data, c) if not found else "%s: %s" % [String(data.items[id].get("name", id)), hint_for(id, data, c)]
	b.focus_entered.connect(show)
	b.mouse_entered.connect(show)
	return b
