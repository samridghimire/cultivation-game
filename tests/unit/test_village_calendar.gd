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
	assert_true(String(act[0]["text"]).contains("until " + Calendar.format_date(start + 5)))
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
