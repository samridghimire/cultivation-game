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
const MET_GREEN := Color(0.55, 0.9, 0.55)  # WU-622: a met duty

var _scroll: ScrollContainer
var _cards: VBoxContainer
## WU-458: the Today page (first) and which page shows.
const BLOCK_CAP := 5  ## WU-517: rows per Today block
const PAGES: Array[String] = ["today", "sect", "journal"]  # WU-605: "sect" only shows for members
var _page := "today"
var _today: VBoxContainer
const TREASURY_SHOWN := 8  ## WU-613: rows shown before "+N more", so This month fits the first screen
var _sect: VBoxContainer  ## WU-605: the Sect page
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
		tab.visible = page != "sect"
		_tabs.add_child(tab)
	# WU-576: the calendar has no pad button, so it sits in the header row, one d-pad step from the tabs.
	var cal_tab := UIStyle.button("Calendar", func() -> void: calendar_requested.emit())
	cal_tab.name = "CalendarTab"
	_tabs.add_child(cal_tab)
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
	_sect = VBoxContainer.new()
	_sect.add_theme_constant_override("separation", 8)
	pages.add_child(_sect)
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
		var i := PAGES.find(_page)
		for _n in PAGES.size():
			i = posmod(i + step, PAGES.size())
			if (_tabs.get_node("Tab_" + PAGES[i]) as Button).visible:
				break
		set_page(PAGES[i])
		(_tabs.get_node("Tab_" + _page) as Button).grab_focus()


## Shows "today" or "journal".
func set_page(page: String) -> void:
	_page = page
	_today.visible = page == "today"
	_sect.visible = page == "sect"
	_cards.visible = page == "journal"
	for tab in _tabs.get_children():
		if tab.name == "CalendarTab":
			continue
		(tab as Button).modulate = Color.WHITE if tab.name == "Tab_" + page else DIM
	_scroll.scroll_vertical = 0
	# WU-613: a tab that holds the focus ring follows the page (open() then set_page("sect") used to leave it on Today).
	if is_inside_tree() and get_viewport().gui_get_focus_owner() in _tabs.get_children():
		(_tabs.get_node("Tab_" + page) as Button).grab_focus()


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
	_build_sect()
	set_page("today")
	visible = true
	focus_page()


## WU-608: focus the first control of the current page (the tab button).
func focus_page() -> void:
	_focus_current_tab.call_deferred()


func _focus_current_tab() -> void:  ## resolves the page when it runs, so open() then set_page("sect") lands on the Sect tab
	(_tabs.get_node("Tab_" + _page) as Button).grab_focus()


## WU-605: the Sect page: banner header, this month, the rank ladder. Members only; the tab hides for rogues.
func _build_sect() -> void:
	for c in _sect.get_children():
		_sect.remove_child(c)
		c.queue_free()
	var p := GameState.player
	var member := not p.is_rogue() and GameState.data.sects.has(p.sect["id"])
	(_tabs.get_node("Tab_sect") as Button).visible = member
	if not member:
		return
	var def: SectDef = GameState.data.sects[p.sect["id"]]
	var color := Color(String(def.robe_color)) if String(def.robe_color) != "" else UIStyle.ACCENT
	var status := Sects.month_status(p, GameState.data, GameClock.total_days, GameState.world_flags)
	var head := UIStyle.panel()
	head.name = "SectHeader"
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	head.add_child(hrow)
	var banner := SectCard.SectBanner.new()
	banner.custom_minimum_size = Vector2(26, 34)
	banner.color = color
	hrow.add_child(banner)
	var htext := VBoxContainer.new()
	hrow.add_child(htext)
	htext.add_child(UIStyle.label(def.name, 22, color))
	htext.add_child(UIStyle.label("%s · %d contribution to spend" % [def.rank_name(int(p.sect["rank"])), int(status["balance"])], 16))
	var prog := Sects.rank_progress(p, GameState.data)
	if not prog.is_empty():
		var pbar := UIStyle.bar(Vector2(300, 14), color)
		pbar.name = "RankBar"
		pbar.max_value = maxi(1, int(prog["need"]))
		pbar.value = mini(int(prog["have"]), int(pbar.max_value))
		pbar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		htext.add_child(pbar)
		var ptxt := "%s: %s" % [String(prog["next_name"]), rank_progress_text(prog)]
		htext.add_child(UIStyle.label(ptxt, 14, DIM))
		if String(prog["trial_foe"]) != "":
			htext.add_child(UIStyle.label("Trial: %s" % String(prog["trial_foe"]), 14, DIM))
	_sect.add_child(head)
	var goal_rows := sect_goal_rows(p, GameState.data, GameState.world_flags)
	if not goal_rows.is_empty():  # WU-618: the next rank's goals, done/undone like the first-days rows
		var gpanel := UIStyle.panel()
		gpanel.name = "SectGoals"
		var gbox := VBoxContainer.new()
		gbox.add_theme_constant_override("separation", 4)
		gpanel.add_child(gbox)
		gbox.add_child(UIStyle.label(sect_goals_heading(p, GameState.data), 18, UIStyle.ACCENT))
		for g: Dictionary in goal_rows:
			var gl := UIStyle.label("%s %s" % ["[x]" if bool(g["done"]) else "[ ]", String(g["text"])], 15, DIM if bool(g["done"]) else Color.WHITE)
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gl.custom_minimum_size = Vector2(700, 0)
			gbox.add_child(gl)
		_sect.add_child(gpanel)
	var month := UIStyle.panel()
	month.name = "SectMonth"
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 6)
	month.add_child(mbox)
	mbox.add_child(UIStyle.label("This month", 18, UIStyle.ACCENT))
	var names := Sects.ready_mission_names(p, GameState.data, GameState.world_flags)
	for line in month_lines(status):
		var met := line.begins_with("Duty:") and int(status["progress"]) >= int(status["duty"])
		mbox.add_child(UIStyle.label(line, 15, MET_GREEN if met else Color.WHITE))
		if line.begins_with("Missions:") and blockers_text(status) != "":
			var bl := UIStyle.label("    " + blockers_text(status), 14, DIM)
			bl.name = "MissionBlockers"
			mbox.add_child(bl)
		if line.begins_with("Missions:") and not names.is_empty():  # WU-613: the names sit right under the count
			mbox.add_child(UIStyle.label("    Ready: %s" % ", ".join(names), 14, DIM))
	var rows := treasury_order(Sects.treasury_rows(p, GameState.data))
	if not rows.is_empty():
		mbox.add_child(UIStyle.label("Treasury", 15, UIStyle.ACCENT))
		var trow := HFlowContainer.new()
		trow.name = "SectTreasury"
		trow.custom_minimum_size = Vector2(700, 0)
		trow.add_theme_constant_override("h_separation", 20)
		for i in mini(rows.size(), TREASURY_SHOWN):
			trow.add_child(UIStyle.label(String(rows[i]["text"]), 14, Color.WHITE if bool(rows[i]["affordable"]) else DIM))
		if rows.size() > TREASURY_SHOWN:
			trow.add_child(UIStyle.label("+%d more at the hall" % (rows.size() - TREASURY_SHOWN), 14, DIM))
		mbox.add_child(trow)
	var duty := int(status["duty"])
	if duty > 0:
		var bar := ProgressBar.new()
		bar.name = "DutyBar"
		bar.max_value = duty
		bar.value = mini(int(status["progress"]), duty)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 14)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mbox.add_child(bar)
	_sect.add_child(month)
	var lad := UIStyle.panel()
	lad.name = "SectLadder"
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 4)
	lad.add_child(lbox)
	lbox.add_child(UIStyle.label("Ranks", 18, UIStyle.ACCENT))
	var seen_next := false
	for r: Dictionary in Sects.ladder(p, GameState.data):
		var needs := ", ".join(r["needs"] as PackedStringArray)
		var text := String(r["name"])
		var col := Color.WHITE
		if bool(r["current"]):
			text += "  (you)"
			col = color
		elif bool(r["reached"]):
			text = "[x] " + text
			col = DIM
		else:
			if needs != "":
				text += ": " + needs
			if not seen_next:
				seen_next = true
				text = "Next: " + text
		var l := UIStyle.label(text, 15, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		lbox.add_child(l)
		if bool(r["current"]) or seen_next and text.begins_with("Next: "):
			var perks := ", ".join(r["perks"] as PackedStringArray)
			if perks != "":
				var pl := UIStyle.label("    " + perks, 14, DIM)
				pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				pl.custom_minimum_size = Vector2(700, 0)
				lbox.add_child(pl)
	_sect.add_child(lad)


## WU-618: the rank goals (SECT-042) a member past the first rank is working on. [] for rogues and at rank 0
## (the first-days rows show those on the Today page) and at the top rank with nothing left to do.
static func sect_goal_rows(c: CharacterData, data: GameData, flags: Dictionary) -> Array[Dictionary]:
	if c.is_rogue() or not data.sects.has(c.sect["id"]) or int(c.sect["rank"]) < 1:
		return []
	return Guidance.sect_goals(c, data, flags)


## WU-618: "Rise to Inner Disciple" for the heading over sect_goal_rows.
static func sect_goals_heading(c: CharacterData, data: GameData) -> String:
	var sect: SectDef = data.sects[c.sect["id"]]
	var rank := int(c.sect["rank"])
	if rank + 1 < sect.ranks.size():
		return "Rise to %s" % sect.rank_name(rank + 1)
	return "Goals"


## WU-610: "212 / 500 contribution" for a Sects.rank_progress. Pure.
static func rank_progress_text(prog: Dictionary) -> String:
	return "%d / %d contribution" % [int(prog["have"]), int(prog["need"])]


## WU-605: the This month text lines for a Sects.month_status. Pure.
static func month_lines(status: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var duty := int(status.get("duty", 0))
	if duty > 0:
		out.append("Duty: %d / %d contribution, %d days left" % [int(status["progress"]), duty, int(status["days_left"])])
	else:
		out.append("No duty this month")
	var pay: Dictionary = status.get("stipend", {})
	var parts := PackedStringArray()
	if int(pay.get("spirit_stones", 0)) > 0:
		parts.append("%d spirit stones" % int(pay["spirit_stones"]))
	for id: String in pay.get("items", {}):
		parts.append("%d %s" % [int(pay["items"][id]), String(GameState.data.items.get(id, {}).get("name", id))])
	if not parts.is_empty():
		out.append("Stipend: %s" % ", ".join(parts))
	if String(status.get("lecture", "")) != "":
		out.append("Lecture: %s" % String(status["lecture"]))
	if String(status.get("contest", "")) != "":
		out.append(String(status["contest"]))
	if int(status.get("missions_total", 0)) > 0:
		out.append("Missions: %d of %d ready" % [int(status["missions_ready"]), int(status["missions_total"])])
	return out


## WU-622: "9 need a higher rank, 5 need items" for a month_status' `blockers`. "" with none. Pure.
static func blockers_text(status: Dictionary) -> String:
	var b: Dictionary = status.get("blockers", {})
	var parts := PackedStringArray()
	var labels := {"rank": "need a higher rank", "realm": "need a higher realm", "items": "need items", "wait": "are resting", "other": "are not open to you"}
	for k: String in ["rank", "realm", "items", "wait", "other"]:
		if int(b.get(k, 0)) > 0:
			parts.append("%d %s" % [int(b[k]), labels[k]])
	return ", ".join(parts)


## WU-613: treasury rows with the affordable ones first (stable order inside each group). Pure.
static func treasury_order(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		if bool(r["affordable"]):
			out.append(r)
	for r in rows:
		if not bool(r["affordable"]):
			out.append(r)
	return out


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
		text = SeasonTasks.with_where(text, where)
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
