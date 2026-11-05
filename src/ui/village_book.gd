class_name VillageBook
extends PanelContainer
## WU-414/WU-417: the village book, two pages (Fish, Herbs), each a grid of everything the village yields. Found ones show
## in colour with a count, missing ones as dark silhouettes with a hint. Opened from the journal or the character sheet;
## Esc/B closes; Tab / Shift+Tab (ui_focus_next/prev) switch pages.

signal closed

const COLUMNS := 6
const PAGES: Array[String] = ["fish", "hunts", "herbs", "people"]
const PEOPLE_COLUMNS := 3
const CARD_SIZE := Vector2(320, 120)
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
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
	for page: String in PAGES:
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
		var step := 1 if event.is_action_pressed("ui_focus_next") else -1
		set_page(PAGES[posmod(PAGES.find(_page) + step, PAGES.size())])


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
	if _page == "hunts":
		return Wildlife.huntable(GameState.data)
	if _page == "people":
		var ids: PackedStringArray = []
		for e in GameState.people_entries():
			ids.append(String(e["id"]))
		return ids
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
	for tab in _tabs.get_children():
		(tab as Button).disabled = false
		(tab as Button).modulate = Color.WHITE if tab.name == "Tab_" + _page else DIM
	_detail.text = ""
	if _page == "people":
		_build_people()
		return
	if _page == "hunts":
		_build_hunts()
		return
	_grid.columns = COLUMNS
	var herbs := _page == "herbs"
	var summary := HerbLore.log_summary(c, data) if herbs else Fishing.log_summary(c, data)
	_header.text = summary if summary != "" else ("Herbs: none found yet" if herbs else "Fish: none caught yet")
	_build_grid(page_ids(), c.herb_log if herbs else c.catch_log, "found" if herbs else "caught")


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


## WU-420: one card per known villager (`GameState.people_entries()`).
func _build_people() -> void:
	var entries := GameState.people_entries()
	_grid.columns = PEOPLE_COLUMNS
	_header.text = "People you know here: %d" % entries.size() if not entries.is_empty() else "People"
	if entries.is_empty():
		_detail.text = "You have not got to know anyone here yet."
	for e in entries:
		_grid.add_child(_card(e))


func _birthday_line(e: Dictionary) -> String:
	if String(e["birthday_text"]) == "":
		return ""
	var d := int(e["birthday_in"])
	var when := "today" if d == 0 else ("tomorrow" if d == 1 else "in %d days" % d)
	return "Birthday: %s (%s)" % [e["birthday_text"], when]


## Tastes as small item icons: known likes, then "?" for the ones not yet learned.
static func taste_row(data: GameData, known: Array, total: int, tint: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in known:
		var tex := ItemIcon.for_id(data, id)
		if tex == null:
			continue
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(20, 20)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.modulate = tint
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	for i in maxi(total - known.size(), 0):
		var q := UIStyle.label("?", 16, DIM)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(q)
	return row


func _card(e: Dictionary) -> Button:
	var data: GameData = GameState.data
	var id := String(e["id"])
	var b := UIStyle.button("", Callable())
	b.name = id
	b.custom_minimum_size = CARD_SIZE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	b.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var face := TextureRect.new()
	face.texture = PixelFigure.frame(NPC_SCRIPT.look_of(id, Color("9a8f7a")), "down", 0)
	face.custom_minimum_size = Vector2(64, 96)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_label := UIStyle.label(String(e["name"]), 16, UIStyle.ACCENT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var hearts := maxi((data.family.get("folk_tiers", []) as Array).size(), 1)
	var h := TextureRect.new()
	h.texture = HudIcons.hearts(hearts, int(e["tier_index"]) + 1, 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.stretch_mode = TextureRect.STRETCH_KEEP
	col.add_child(h)
	var tier := UIStyle.label(String(e["tier_name"]), 14)
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tier)
	var bday := UIStyle.label(_birthday_line(e).replace("Birthday: ", "Birthday ").replace("Month ", "M").replace(", Day ", " D"), 13, DIM)
	bday.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bday)
	col.add_child(taste_row(data, e["likes_known"], int(e["likes_total"])))
	var show := func() -> void: _detail.text = people_detail(e, data)
	b.focus_entered.connect(show)
	b.mouse_entered.connect(show)
	return b


## The full text under the grid for one people entry.
static func people_detail(e: Dictionary, data: GameData) -> String:
	var parts: PackedStringArray = ["%s, %s." % [e["name"], String(e["tier_name"]).to_lower() if String(e["tier_name"]) != "" else "an acquaintance"]]
	var names := func(ids: Array) -> String:
		return ", ".join(PackedStringArray(ids.map(func(i: String) -> String: return String(data.items.get(i, {}).get("name", i)))))
	var likes: Array = e["likes_known"]
	parts.append("Likes: %s." % (names.call(likes) if not likes.is_empty() else "not yet learned"))
	var dislikes: Array = e["dislikes_known"]
	if not dislikes.is_empty():
		parts.append("Dislikes: %s." % names.call(dislikes))
	return " ".join(parts)


## WU-425: the regions whose roamer rosters can field `enemy_id`, by name.
static func roams_in(data: GameData, enemy_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for rid: String in data.regions:
		for e: Dictionary in data.regions[rid].get("roamers", {}).get("enemies", []):
			if String(e["enemy"]) == enemy_id:
				out.append(String(data.regions[rid].get("name", rid)))
				break
	out.sort()
	return out


## Slot text: the beast and its count when hunted, "???" with where it roams otherwise.
static func hunt_text(data: GameData, c: CharacterData, enemy_id: String) -> String:
	if c.hunt_log.has(enemy_id):
		return "%s\nhunted %d" % [String(data.enemies[enemy_id].get("name", enemy_id)), int(c.hunt_log[enemy_id])]
	return "???\n(roams %s)" % ", ".join(roams_in(data, enemy_id))


## Detail line: the spoils a hunted beast drops, or a hint for an unhunted one.
static func hunt_detail(data: GameData, c: CharacterData, enemy_id: String) -> String:
	if not c.hunt_log.has(enemy_id):
		return "Unhunted. It roams %s." % ", ".join(roams_in(data, enemy_id))
	var nm := String(data.enemies[enemy_id].get("name", enemy_id))
	if c.great_beasts.has(enemy_id):
		nm = Wildlife.display_name(data, enemy_id, true) + " (slain day %d)" % (int(c.great_beasts[enemy_id]) + 1)
	var spoils := Wildlife.spoils_of(c, enemy_id)
	if spoils.is_empty():
		return "%s: spoils unknown." % nm
	var names := PackedStringArray()
	for item_id: String in spoils:
		names.append("%s x%d" % [String(data.items.get(item_id, {}).get("name", item_id)), int(spoils[item_id])])
	var out := "%s. Spoils: %s." % [nm, ", ".join(names)]
	var trophy := Wildlife.great_trophy(data, enemy_id)
	if c.great_beasts.has(enemy_id) and trophy != "":
		out += " Trophy: %s." % String(data.items.get(trophy, {}).get("name", trophy))
	return out


## WU-437: one row per great beast in regions.json order: {enemy, region, name, won, day, trophy, text, detail}.
## Won -> the trophy's name and description; not yet -> "???" with where and which weekday it walks.
static func trophy_rows(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rid: String in data.regions:
		var g: Dictionary = data.regions[rid].get("roamers", {}).get("great", {})
		if g.is_empty():
			continue
		var blocks: Array[Dictionary] = [g]
		var ret: Variant = g.get("return")
		# WU-451: a region with a `return` beast always shows a second slot beside the first.
		if ret is Dictionary:
			blocks.append(ret)
		for block: Dictionary in blocks:
			_trophy_row(rows, c, data, rid, g, block)
	return rows


static func _trophy_row(rows: Array[Dictionary], c: CharacterData, data: GameData, rid: String, g: Dictionary, block: Dictionary) -> void:
	var enemy := String(block["enemy"])
	var won := c.great_beasts.has(enemy)
	var region := String(data.regions[rid].get("name", rid))
	var trophy := Wildlife.great_trophy(data, enemy)
	var item: Dictionary = data.items.get(trophy, {})
	var row := {"enemy": enemy, "region": region, "won": won, "trophy": trophy, "day": -1}
	if won:
		row["day"] = int(c.great_beasts[enemy]) + 1
		row["text"] = "%s\n%s" % [Wildlife.display_name(data, enemy, true), String(item.get("name", "no trophy"))]
		row["detail"] = "%s, slain day %d. %s" % [Wildlife.display_name(data, enemy, true), row["day"], String(item.get("description", ""))]
	elif block != g and not c.great_beasts.has(String(g["enemy"])):
		# WU-451: the return beast stays a mystery until the first has fallen (its rumour would spoil it).
		row["text"] = "???\n(%s)" % region
		row["detail"] = "Some say a great beast never walks alone."
	else:
		var walk := Calendar.weekday_label(Wildlife.great_day(rid, g))
		row["text"] = "???\n(%s, %s)" % [region, Calendar.weekday_label(Wildlife.great_day(rid, g))]
		row["detail"] = "A great beast walks %s on %s." % [region, walk]
		var rumor := String(block.get("rumor", ""))
		if rumor != "":
			row["rumor"] = rumor
			row["detail"] = "%s\nHunters say: %s" % [row["detail"], rumor]
	rows.append(row)


func _build_hunts() -> void:
	var data: GameData = GameState.data
	var c: CharacterData = GameState.player
	_grid.columns = 4
	var summary := Wildlife.log_summary(c, data)
	_header.text = summary if summary != "" else "Beasts hunted: none yet"
	for row in trophy_rows(c, data):  # WU-437: the trophy shelf comes first
		var tb := UIStyle.button(String(row["text"]), Callable())
		tb.name = "trophy_" + String(row["enemy"])
		tb.custom_minimum_size = Vector2(230, 80)
		tb.add_theme_font_size_override("font_size", 15)
		tb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not bool(row["won"]):
			tb.modulate = DIM
		else:
			tb.add_theme_color_override("font_color", Color("e8c35a"))
		var tshow := func() -> void: _detail.text = String(row["detail"])
		tb.focus_entered.connect(tshow)
		tb.mouse_entered.connect(tshow)
		_grid.add_child(tb)
	for id in Wildlife.huntable(data):
		var found := c.hunt_log.has(id)
		var b := UIStyle.button(hunt_text(data, c, id), Callable())
		b.name = id
		b.custom_minimum_size = Vector2(230, 80)
		b.add_theme_font_size_override("font_size", 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long "roams ..." list wraps instead of widening the grid
		b.set_meta("found", found)
		if not found:
			b.modulate = DIM
		var show := func() -> void: _detail.text = hunt_detail(data, c, id)
		b.focus_entered.connect(show)
		b.mouse_entered.connect(show)
		_grid.add_child(b)
