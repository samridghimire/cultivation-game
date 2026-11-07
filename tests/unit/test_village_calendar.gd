extends TestCase
## CAL-001: VillageCalendar.upcoming / month_grid / month_start.


func _village(npcs: Dictionary, count: int) -> void:
	for i in count:
		Npcs.spawn(npcs, data(), seeded_rng(10 + i), {"age_years": 20 + i * 10, "region": "qingshi_village", "realm": "mortal"})


func _kinds(entries: Array, kind: String) -> Array:
	return entries.filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


func test_market_days_listed_for_region_with_stall() -> void:
	var e := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30)
	var days: Array = _kinds(e, "market").map(func(x: Dictionary) -> int: return Calendar.day_of(int(x["day"])))
	assert_eq(days, [10, 25])
	assert_true(String(_kinds(e, "market")[0]["text"]).begins_with("Market: "))
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", 0, 30), "market").size(), 0)


func test_birthday_needs_favor() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs[npcs.keys()[0]]
	var b := Folk.birthday_day(npc, data())
	var start := b + Calendar.DAYS_PER_YEAR - 3
	assert_eq(_kinds(VillageCalendar.upcoming(data(), npcs, {npc.id: 9}, [], "qingshi_village", start), "birthday").size(), 0)
	var e := _kinds(VillageCalendar.upcoming(data(), npcs, {npc.id: 10}, [], "qingshi_village", start), "birthday")
	assert_eq(e.size(), 1)
	assert_eq(int(e[0]["day"]), start + Folk.days_to_birthday(npc, data(), start))
	assert_true(String(e[0]["text"]).contains("birthday"))


func test_active_festival_once_with_end_date() -> void:
	var start := 9 * Calendar.DAYS_PER_MONTH  # month 10
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": start - 2, "end_day": start + 5}
	var e := VillageCalendar.upcoming(data(), {}, {}, [inst], "qingshi_village", start)
	var act := _kinds(e, "festival_active")
	assert_eq(act.size(), 1)
	assert_eq(int(act[0]["day"]), start)
	assert_true(String(act[0]["text"]).contains("to " + Calendar.format_date(start + 4)))
	assert_eq(_kinds(e, "festival_month").size(), 0)


func test_festival_month_on_day_one_when_not_active() -> void:
	var start := 8 * Calendar.DAYS_PER_MONTH + 20  # month 9, day 21
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start), "festival_month")
	assert_eq(e.size(), 1)
	assert_eq(int(e[0]["day"]), 9 * Calendar.DAYS_PER_MONTH)
	assert_true(String(e[0]["text"]).contains("Lantern Festival this month"))


func test_season_entry_and_ordering_and_grid() -> void:
	var start := 9 * Calendar.DAYS_PER_MONTH - 5  # late month 9
	var e := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start)
	var s := _kinds(e, "season")
	assert_eq(s.size(), 1)
	assert_eq(int(s[0]["day"]), 9 * Calendar.DAYS_PER_MONTH)
	assert_eq(s[0]["text"], "Winter begins")
	# festival_month and season share that day: festival_month sorts first.
	var same: Array = e.filter(func(x: Dictionary) -> bool: return int(x["day"]) == 9 * Calendar.DAYS_PER_MONTH)
	assert_eq(same[0]["kind"], "festival_month")
	assert_eq(same[1]["kind"], "season")
	var ms := VillageCalendar.month_start(start + 10)
	assert_eq(ms, 9 * Calendar.DAYS_PER_MONTH)
	var grid := VillageCalendar.month_grid(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", ms), ms)
	assert_eq((grid[1] as Array).size(), 2)
	assert_true(grid.has(10) and grid.has(25))


## Review: a window starting mid-month reaches into the next month; month_grid keeps only the asked month.
func test_month_grid_leaves_out_other_months() -> void:
	var start := 9 * Calendar.DAYS_PER_MONTH + 14  # day 15 of month 10: the window runs into month 11
	var e := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start)
	var next_month := start + 16  # day 1 of month 11
	assert_true(e.any(func(x: Dictionary) -> bool: return int(x["day"]) == next_month + 9), "next month's day-10 market is in the window")
	var grid := VillageCalendar.month_grid(e, VillageCalendar.month_start(start))
	assert_false(grid.has(10), "day 10 of the next month does not land in this month's cell")
	assert_true(grid.has(25))
	var later := VillageCalendar.month_grid(e, next_month)
	assert_true(later.has(10))
	assert_false(later.has(25))


## CAL-002: the player's own dates.
func _calendar_player() -> CharacterData:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	return c


func test_own_dates_null_matches_old_output() -> void:
	var a := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30)
	var b := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30, null)
	assert_eq(a, b)
	assert_eq(_kinds(a, "field").size(), 0)


func test_planted_crop_shows_on_ready_day() -> void:
	var c := _calendar_player()
	c.field_plots["qingshi_village:Test"] = {"paid_until": 200, "crops": [{"item": "spirit_herb", "days_left": 5}]}
	var place := FieldPlots.place_def(data(), "qingshi_village")
	var start := 10  # spring: not frozen
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start, 30, c), "field")
	if place.is_empty():
		return
	assert_eq(e.size(), 1)
	assert_eq(int(e[0]["day"]), start + 5)
	assert_true(String(e[0]["text"]).begins_with("Your "))


func test_crop_not_ready_when_rent_lapses_first() -> void:
	# FieldPlots.advance grows a crop on reaching each paid day, so 5 days left with rent paid until start + 5
	# only grows 4 days: the crop never ripens and the calendar must not promise it.
	var c := _calendar_player()
	var start := 10
	c.field_plots["qingshi_village:Test"] = {"paid_until": start + 5, "crops": [{"item": "spirit_herb", "days_left": 5}]}
	if FieldPlots.place_def(data(), "qingshi_village").is_empty():
		return
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start, 30, c), "field").size(), 0)
	c.field_plots["qingshi_village:Test"]["paid_until"] = start + 6
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start, 30, c), "field").size(), 1)


func test_rent_end_listed() -> void:
	var c := _calendar_player()
	c.field_plots["qingshi_village:Test"] = {"paid_until": 20, "crops": []}
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30, c), "rent")
	assert_eq(e.size(), 1)
	assert_eq(int(e[0]["day"]), 20)


func test_request_shows_on_until_day() -> void:
	var c := _calendar_player()
	c.letter_requests.append({"npc_id": "nobody", "item": "spirit_herb", "count": 2, "until": 12, "favor": 1, "effects": {}})
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30, c), "request")
	assert_eq(e.size(), 1)
	assert_eq(int(e[0]["day"]), 12)
	assert_true(String(e[0]["text"]).contains("ask is due: 2"))


func test_secret_realm_opening_once_and_barrier() -> void:
	var def: Dictionary = data().secret_realms["peach_blossom_grotto"]
	var opens := int(def["offset_years"]) * Calendar.DAYS_PER_YEAR
	var c := _calendar_player()
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", opens - 5, 30, c), "secret_realm")
	var opening := e.filter(func(x: Dictionary) -> bool: return String(x["text"]) == "Peach Blossom Grotto opens")
	assert_eq(opening.size(), 1)
	assert_eq(int(opening[0]["day"]), opens)
	assert_eq(String(opening[0]["region"]), "qingshi_village")
	c.realm_index = data().realm_index_of("core_formation")
	var closed := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", opens - 5, 30, c), "secret_realm")
	assert_eq(closed.filter(func(x: Dictionary) -> bool: return String(x["text"]).begins_with("Peach")).size(), 0)


func test_one_region_festival_month_has_region() -> void:
	var start := 8 * Calendar.DAYS_PER_MONTH + 20
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", start), "festival_month")
	assert_eq(e.size(), 1)
	assert_true(e[0].has("region"))


## CAL-003: tomorrow's reminders.
func test_reminder_market_tomorrow() -> void:
	var r := VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 8, null)
	assert_eq(r.size(), 2, "market day and the spring hunt (C-309)")
	assert_true(r[0].begins_with("Tomorrow: market day at "), r[0])
	assert_eq(VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 10, null).size(), 0)


func test_reminder_birthday_with_and_without_known_like() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs[npcs.keys()[0]]
	npc.gender = "female"
	var today := Folk.birthday_day(npc, data()) + Calendar.DAYS_PER_YEAR - 1
	var r := VillageCalendar.reminders(data(), npcs, {npc.id: 10}, [], "qingshi_village", today, null)
	assert_eq(r.size(), 1)
	assert_true(r[0].begins_with("Tomorrow: ") and r[0].contains("birthday") and not r[0].contains("likes"), r[0])
	var item_id: String = data().items.keys()[0]
	var flags := {"taste_%s_%s" % [npc.id, item_id]: 1}
	r = VillageCalendar.reminders(data(), npcs, {npc.id: 10}, [], "qingshi_village", today, null, flags)
	assert_true(r[0].contains("she likes"), r[0])
	assert_eq(VillageCalendar.reminders(data(), npcs, {npc.id: 9}, [], "qingshi_village", today, null).size(), 0, "unknown villager")


func test_reminders_capped_at_three() -> void:
	var c := _calendar_player()
	for i in 5:
		c.letter_requests.append({"npc_id": "nobody", "item": "spirit_herb", "count": 1, "until": 9, "favor": 1, "effects": {}})
	var r := VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 8, c)
	assert_eq(r.size(), VillageCalendar.MAX_REMINDERS)


## CAL-004: the day before rent lapses gets a reminder; the lapse day is a calendar entry.
func test_rent_reminder_fires_day_before() -> void:
	var c := _calendar_player()
	c.field_plots["qingshi_village:Test"] = {"paid_until": 20, "crops": []}
	var r := VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 19, c)
	assert_true(r.has("Tomorrow: field rent is due."))
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 20, 30, c), "rent").size(), 1)


func test_request_reminder_wording() -> void:
	var c := _calendar_player()
	c.letter_requests.append({"npc_id": "nobody", "item": "spirit_herb", "count": 2, "until": 12, "favor": 1, "effects": {}})
	var r := VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 11, c)
	assert_eq(r.size(), 1)
	assert_true(r[0].begins_with("Tomorrow: a neighbour's request is due (2 "), r[0])
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30, c), "request")
	assert_true(String(e[0]["text"]).begins_with("A neighbour's ask is due"))


## FORAGE-003: a visited region's seasonal forage shows the day before its season starts.
func test_forage_season_line_only_for_visited() -> void:
	var c := CharacterFactory.create("Lin Feng", data(), seeded_rng(), "male")
	c.visited_regions = ["qingshi_village"]
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 359, 3, c), "forage")
	assert_eq(e.size(), 1)
	assert_eq(e[0]["day"], 360)
	assert_eq(e[0]["region"], "qingshi_village")
	assert_true(String(e[0]["text"]).contains(String(data().items["peach_blossom_petal"]["name"])), e[0]["text"])
	assert_true(VillageCalendar.reminders(data(), {}, {}, [], "qingshi_village", 359, c).size() >= 1)
	c.visited_regions = []
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 359, 3, c), "forage").size(), 0)
	c.visited_regions = ["qingshi_village"]
	assert_eq(_kinds(VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 100, 5, c), "forage").size(), 0)


## CAL-006: marked days.
func _market_label() -> String:
	var e := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30)
	return String(_kinds(e, "market")[0]["text"])


func test_mark_checks_cap_and_label() -> void:
	var c := new_character()
	var entries := VillageCalendar.upcoming(data(), {}, {}, [], "qingshi_village", 0, 30)
	var m: Dictionary = _kinds(entries, "market")[0]
	var day := int(m["day"])
	assert_eq(VillageCalendar.check_mark(c, entries, 0, day, String(m["text"])), "")
	assert_true(VillageCalendar.check_mark(c, entries, 0, day, "nonsense") != "")
	assert_true(VillageCalendar.check_mark(c, entries, day, day, String(m["text"])) != "", "not a future day")
	for i in VillageCalendar.MAX_MARKS:
		c.marked_days[100 + i] = "x"
	assert_true(VillageCalendar.check_mark(c, entries, 0, day, String(m["text"])).contains("at most"))


func test_prune_and_lines() -> void:
	var c := new_character()
	c.marked_days = {3: "old", 5: "Market: Qingshi", 6: "Festival"}
	VillageCalendar.prune_marks(c, 5)
	assert_false(c.marked_days.has(3))
	assert_eq(Array(VillageCalendar.mark_lines(c, 5)), ["Today: Market: Qingshi (you marked it).", "Tomorrow: Festival."])
	assert_eq(VillageCalendar.mark_lines(c, 20).size(), 0)


func test_marks_save_round_trip_and_old_saves_load() -> void:
	var c := new_character()
	c.marked_days = {12: "Market: x"}
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.marked_days, {12: "Market: x"})
	var d := c.to_dict()
	d.erase("marked_days")
	assert_eq(CharacterData.from_dict(d).marked_days, {})


func test_game_state_mark_day() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var clock: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	clock.total_days = 0
	var label := _market_label()
	var day := 9
	assert_false(gs.mark_day(day, "made up"))
	assert_true(gs.mark_day(day, label))
	assert_eq(gs.player.marked_days[day], label)
	assert_false(gs.mark_day(day, label), "already marked")
	gs.unmark_day(day)
	assert_false(gs.player.marked_days.has(day))
	gs.mark_day(day, label)
	clock.total_days = day - 1
	gs.player.marked_days[day] = "Market: Qingshi"
	assert_eq(Array(VillageCalendar.mark_lines(gs.player, day - 1)), ["Tomorrow: Market: Qingshi."])
	gs.end_session()


func test_festival_fills_every_day_cell() -> void:
	var ms := 9 * Calendar.DAYS_PER_MONTH
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": ms, "end_day": ms + 8}
	var g := VillageCalendar.month_grid(VillageCalendar.upcoming(data(), {}, {}, [inst], "qingshi_village", ms), ms)
	for d in range(1, 9):
		var kinds: Array = (g[d] as Array).map(func(x: Dictionary) -> String: return String(x["kind"]))
		assert_true(kinds.has("festival_active" if d == 1 else "festival_day"), "day %d" % d)
	assert_false(g.has(9) and ((g[9] as Array).any(func(x: Dictionary) -> bool: return String(x["kind"]) == "festival_day")))
	var full := 0
	for d in g:
		for x: Dictionary in g[d]:
			if x["kind"] == "festival_active":
				full += 1
	assert_eq(full, 1)


func test_festival_from_last_month_fills_from_day_one() -> void:
	var ms := 9 * Calendar.DAYS_PER_MONTH
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": ms - 3, "end_day": ms + 4}
	var g := VillageCalendar.month_grid(VillageCalendar.upcoming(data(), {}, {}, [inst], "qingshi_village", ms - 3), ms)
	for d in range(1, 5):
		assert_true((g[d] as Array).any(func(x: Dictionary) -> bool: return x["kind"] == "festival_day"), "day %d" % d)
	assert_false(g.has(5) and ((g[5] as Array).any(func(x: Dictionary) -> bool: return String(x["kind"]) == "festival_day")))


func test_today_line_names_festival_day() -> void:
	var ms := 9 * Calendar.DAYS_PER_MONTH
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": ms, "end_day": ms + 8}
	var c := CharacterData.new()
	var l3 := Guidance.today_lines(c, data(), {}, [inst], ms + 2, "qingshi_village")
	assert_true(l3[0].contains("(day 3 of 8)"), l3[0])
	var l1 := Guidance.today_lines(c, data(), {}, [inst], ms, "qingshi_village")
	assert_false(l1[0].contains("(day"), l1[0])


## WILD-020: a wild region still has something to plan in a 40-day window.
func test_wild_region_has_great_beast_and_season_entries() -> void:
	var c := CharacterFactory.create("Lin Feng", data(), seeded_rng(), "male")
	c.visited_regions = ["misty_forest"]
	var start := 0  # spring, no season change inside 40 days
	var e := VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", start, 40, c)
	assert_eq(_kinds(e, "great_beast").size() > 0, true, "great beast")
	assert_true(_kinds(e, "forage").size() >= 1, "forage/season entry")
	assert_true(String(_kinds(e, "forage")[0]["text"]).contains("in season now"))


func test_foundation_sees_the_return_beast() -> void:
	var c := CharacterFactory.create("Lin Feng", data(), seeded_rng(), "male")
	c.visited_regions = ["misty_forest"]
	var e := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", 0, 40, c), "great_beast")
	assert_true(e.size() > 0)
	assert_eq(e[0]["enemy"], "old_tusker_boar")
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.great_beasts["old_tusker_boar"] = 1
	var f := _kinds(VillageCalendar.upcoming(data(), {}, {}, [], "misty_forest", 0, 40, c), "great_beast")
	assert_true(f.size() > 0)
	assert_eq(f[0]["enemy"], "scarred_old_tusker")
