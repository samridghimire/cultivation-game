class_name JournalScreen
extends PanelContainer
## Read-only journal (WU-007): "what can I do now?" Renders Guidance.journal
## grouped by section. Gamepad: right stick scrolls, B closes.

signal closed
## WU-414: the "Village book" button at the end of the Around the village card.
signal book_requested
signal calendar_requested

const SCROLL_SPEED := 900.0
const QUIET_DAY := "A quiet day. Meditate, gather, or walk the roads."
const DIM := Color(0.6, 0.6, 0.6)

var _scroll: ScrollContainer
var _cards: VBoxContainer
## WU-458: the Today page (first) and which page shows.
const BLOCK_CAP := 5  ## WU-517: rows per Today block
const PAGES: Array[String] = ["today", "journal"]
var _page := "today"
var _today: VBoxContainer
var _almanac := PackedStringArray()  ## WU-513: the almanac lines shown under the Today date
var _tabs: HBoxContainer
## Every card's text joined, for tests and search.
var _text: RichTextLabel
var _close_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Journal", 24, UIStyle.ACCENT))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	for page: String in PAGES:
		var tab := UIStyle.button(page.capitalize(), func() -> void: set_page(page))
		tab.name = "Tab_" + page
		_tabs.add_child(tab)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(736, 440)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.visible = false
	add_child(_text)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	_today = VBoxContainer.new()
	_today.add_theme_constant_override("separation", 8)
	pages.add_child(_today)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_cards)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_close_button = UIStyle.button("Close", close)
	footer.add_child(_close_button)
	footer.add_child(UIStyle.label("[PgUp/PgDn] or right stick: scroll", 14, DIM))


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
		(_tabs.get_node("Tab_" + _page) as Button).grab_focus()


## Shows "today" or "journal".
func set_page(page: String) -> void:
	_page = page
	_today.visible = page == "today"
	_cards.visible = page == "journal"
	for tab in _tabs.get_children():
		(tab as Button).modulate = Color.WHITE if tab.name == "Tab_" + page else DIM
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Input.get_axis("scroll_up", "scroll_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


func open() -> void:
	var list := entries()
	_text.clear()
	_text.append_text(format_entries(list))
	_build_cards(list)
	_build_today(GameState.today_lines(), GameState.season_tasks(), GameState.season_reward_line(), GameState.earning_lines_here(), GameState.people_today_lines(), GameState.almanac_lines())
	set_page("today")
	visible = true
	(_tabs.get_node("Tab_today") as Button).grab_focus.call_deferred()


## The journal for the current session.
static func entries() -> Array[Dictionary]:
	return GameState.journal_entries()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## BBCode for journal `entries`: a heading per section, a bullet per line.
static func format_entries(entries: Array) -> String:
	var out := PackedStringArray()
	var last := ""
	for e: Dictionary in entries:
		var section := String(e["section"])
		if section != last:
			if last != "":
				out.append("")
			out.append("[color=#%s]%s[/color]" % [UIStyle.ACCENT.to_html(false), section])
			last = section
		var line := "  - %s" % String(e["text"]).replace("[", "[lb]")
		match String(e.get("tone", "normal")):
			"warning":
				line = "[color=#%s]%s[/color]" % [(UIStyle.CATEGORY_COLORS["warning"] as Color).to_html(false), line]
			"dim":
				line = "[color=#%s]%s[/color]" % [DIM.to_html(false), line]
		out.append(line)
	return "\n".join(out)


## Entries grouped by section, in order: [{section, entries: [...]}].
static func group_sections(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		if out.is_empty() or out[-1]["section"] != String(e["section"]):
			out.append({"section": String(e["section"]), "entries": []})
		(out[-1]["entries"] as Array).append(e)
	return out


## A goal line is "[x] text" or "[ ] text": returns {done, text}, or {} for a plain line.
static func parse_goal(text: String) -> Dictionary:
	if text.begins_with("[x] "):
		return {"done": true, "text": text.substr(4)}
	if text.begins_with("[ ] "):
		return {"done": false, "text": text.substr(4)}
	return {}


## WU-458: the date, weather and one icon row per Today line (a quiet-day line when there are none).
func _build_today(lines: PackedStringArray, tasks: Array = [], reward_line: String = "", earning: PackedStringArray = PackedStringArray(), people: PackedStringArray = PackedStringArray(), almanac: PackedStringArray = PackedStringArray()) -> void:
	_almanac = almanac
	for c in _today.get_children():
		_today.remove_child(c)
		c.queue_free()
	var card := UIStyle.panel()
	card.name = "TodayCard"
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	var here := PackedStringArray()
	var village := PackedStringArray()
	for line in lines:
		if people.has(line):  # People lines are shown in the People card below
			continue
		if is_village_line(line):
			village.append(line)
		else:
			here.append(line)
	# WU-509: no empty main card; the date heading moves to the first card that has lines.
	var main_empty: bool = tasks.is_empty() and here.is_empty() and village.is_empty() and not lines.is_empty()
	if not main_empty:
		_add_head(inner)
	if lines.is_empty():
		var quiet := UIStyle.label(QUIET_DAY, 15, DIM)
		quiet.name = "TodayQuiet"
		inner.add_child(quiet)
	# WU-517: three small headed blocks, each capped (WU-462: a done season task gets a check).
	_block(inner, "HereBlock", "Here today", here, null, "today_row")
	if not tasks.is_empty():
		var sh := UIStyle.label(season_header(GameState.current_region), 15, UIStyle.ACCENT)
		sh.name = "SeasonHeader"
		inner.add_child(sh)
		var shown := 0
		for t: Dictionary in tasks:
			if shown >= BLOCK_CAP:
				break
			inner.add_child(_today_row(season_task_text(t), HudIcons.today_glyph("check" if bool(t["done"]) else "dot"), "season_row"))
			shown += 1
		if tasks.size() > BLOCK_CAP:
			inner.add_child(_more_label(tasks.size() - BLOCK_CAP))
		if reward_line != "":
			inner.add_child(_today_row(reward_line, HudIcons.today_glyph("leaf"), "season_reward"))
	_block(inner, "VillageBlock", "Around the village", village, null, "today_row")
	if not main_empty:
		_today.add_child(card)
	else:
		card.free()  # never added to the tree, so it would leak
	_today_card("EarningCard", "Earning here", earning, "coin", main_empty)
	_today_card("PeopleCard", "People today", people, "calendar", main_empty and earning.is_empty())


## WU-517: lines about the village's own upkeep (shrine, incense, project stages, coop) rather than today's happenings.
static func is_village_line(line: String) -> bool:
	for k in ["shrine", "incense", "stages repaired", "is whole", "coop", "hens"]:
		if line.to_lower().contains(k):
			return true
	return false


## WU-517: a headed block of at most BLOCK_CAP icon rows plus a dim "+N more" line; nothing when empty.
func _block(inner: VBoxContainer, block_name: String, title: String, lines: PackedStringArray, _unused: Texture2D, meta: String) -> void:
	if lines.is_empty():
		return
	var blk := UIStyle.block(title, PackedStringArray())  # WU-530: shared heading; rows carry icons
	blk.name = block_name
	blk.get_child(1).queue_free()
	blk.remove_child(blk.get_child(1))
	inner.add_child(blk)
	for i in mini(lines.size(), BLOCK_CAP):
		blk.add_child(_today_row(lines[i], HudIcons.today_glyph(HudIcons.today_icon(lines[i])), meta))
	if lines.size() > BLOCK_CAP:
		blk.add_child(_more_label(lines.size() - BLOCK_CAP))


func _more_label(n: int) -> Label:
	var l := UIStyle.label("+%d more" % n, 14, DIM)
	l.name = "MoreLine"
	return l


## WU-513: the date heading, then the almanac lines straight under it (today's with its omen glyph, tomorrow's dim).
func _add_head(inner: VBoxContainer) -> void:
	inner.add_child(_today_head())
	for i in _almanac.size():
		var plain := Almanac.is_plain(GameState.today_omen())
		var dim: bool = i > 0 or plain
		var row := _today_row(_almanac[i], HudIcons.omen_glyph(GameState.today_omen()) if i == 0 and not plain else null, "almanac_row")
		row.name = "AlmanacToday" if i == 0 else "AlmanacTomorrow"
		if dim:
			for c in row.get_children():
				if c is RichTextLabel:
					(c as RichTextLabel).add_theme_color_override("default_color", DIM)
		inner.add_child(row)


## The Today page's date and weather heading.
func _today_head() -> Label:
	var day: int = GameClock.total_days
	var weather := Weather.of(GameState.data, GameState.current_region, day)
	var head := UIStyle.label("%s · %s" % [Calendar.format_date_weekday(day), Weather.label(weather)], 18, UIStyle.ACCENT)
	head.name = "TodayHeader"
	return head


## WU-504: a titled card of icon rows under the main Today card; hidden (not built) when there are no lines.
func _today_card(card_name: String, title: String, lines: PackedStringArray, icon_kind: String, with_date: bool = false) -> void:
	if lines.is_empty():
		return
	var card := UIStyle.panel()
	card.name = card_name
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	if with_date:
		_add_head(inner)
	inner.add_child(UIStyle.label(title, 15, UIStyle.ACCENT))
	for line in lines:
		inner.add_child(_today_row(line, HudIcons.today_glyph(icon_kind), "today_row"))
	_today.add_child(card)


## The Today page's season section title; says where the tasks are done when the player is elsewhere (WU-466).
static func season_header(region_id: String) -> String:
	return "The season's tasks" if region_id == SeasonTasks.REGION else "The season's tasks (in Qingshi Village)"


## "<text> (n/count)" for a season task row (the count only when more than one is needed).
static func season_task_text(t: Dictionary) -> String:
	var text := String(t["text"])
	var where := String(t.get("where", ""))
	if where != "" and not bool(t.get("done", false)):
		text = "%s %s." % [text.trim_suffix("."), where]
	var note := String(t.get("note", ""))
	if note != "" and not bool(t.get("done", false)):
		text = "%s %s" % [text, note]
	if int(t.get("count", 1)) > 1:
		return "%s (%d/%d)" % [text, t["n"], t["count"]]
	return text


func _today_row(line: String, tex: Texture2D, meta: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta(meta, true)
	if meta != "today_row":
		row.set_meta("today_row", true)
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = line
	row.add_child(text)
	return row


func _build_cards(list: Array) -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for sec in group_sections(list):
		var card := UIStyle.panel()
		card.name = "card_" + String(sec["section"]).validate_node_name()
		card.set_meta("title", sec["section"])
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		card.add_child(inner)
		inner.add_child(UIStyle.label(sec["section"], 18, UIStyle.ACCENT))
		for e: Dictionary in sec["entries"]:
			inner.add_child(_row(e))
		if sec["section"] == "Around the village":
			var book := UIStyle.button("Village book", func() -> void: book_requested.emit())
			book.name = "VillageBookButton"
			book.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var cal := UIStyle.button("Calendar", func() -> void: calendar_requested.emit())
			cal.name = "CalendarButton"
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(book)
			row.add_child(cal)
			inner.add_child(row)
		_cards.add_child(card)


func _row(e: Dictionary) -> Control:
	var tone := String(e.get("tone", "normal"))
	var color := Color.WHITE
	if tone == "warning":
		color = UIStyle.CATEGORY_COLORS["warning"]
	elif tone == "dim":
		color = DIM
	var goal := parse_goal(String(e["text"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark: Control
	if goal.is_empty():
		mark = UIStyle.label("-", 15, color)
	else:
		mark = CheckBox_pixel.new(goal["done"])
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_color_override("default_color", color)
	text.text = String(goal["text"]) if not goal.is_empty() else String(e["text"])
	row.add_child(text)
	return row


## A 14 px pixel box, ticked when done.
class CheckBox_pixel extends Control:
	var done := false

	func _init(is_done: bool) -> void:
		done = is_done
		custom_minimum_size = Vector2(16, 20)

	func _draw() -> void:
		var r := Rect2(1, 3, 14, 14)
		draw_rect(r, Color(0.12, 0.12, 0.14))
		draw_rect(r, UIStyle.ACCENT.darkened(0.2), false, 2.0)
		if done:
			var ok := Color("7fd36b")
			draw_rect(Rect2(4, 9, 3, 3), ok)
			draw_rect(Rect2(7, 11, 3, 3), ok)
			draw_rect(Rect2(10, 6, 3, 5), ok)
