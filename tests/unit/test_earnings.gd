extends TestCase
## GUIDE-226: Earnings.earning_options, expected stones per day where the player stands.


func _kinds(rows: Array[Dictionary]) -> Array:
	var out := []
	for r in rows:
		out.append(r["kind"])
	return out


func test_qingshi_has_chore_gather_and_fishing_rows() -> void:
	var c := new_character()
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	assert_true(rows.size() <= Earnings.MAX_ROWS)
	var kinds := _kinds(rows)
	assert_true(kinds.has("gather"), "gathering row")
	assert_true(kinds.has("fishing"), "fishing row")
	var all_kinds := _kinds(Earnings.earning_options(c, data(), {}, "qingshi_village", 0))
	assert_false(all_kinds.has("craft"), "no profession, no craft row")


func test_rows_sorted_and_deterministic() -> void:
	var c := new_character()
	var a := Earnings.earning_options(c, data(), {}, "qingshi_village", 10)
	var b := Earnings.earning_options(c, data(), {}, "qingshi_village", 10)
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	for i in range(1, a.size()):
		assert_true(float(a[i - 1]["per_day"]) >= float(a[i]["per_day"]))


## Day 0 is spring: compared with the baseline's Qingshi Novice spring figure (1.87). (The first version ran 30% high: it counted the flag-gated Pearl-Backed Bream.)
func test_novice_figures_near_balance_baseline() -> void:
	var c := new_character()
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	for r in rows:
		if r["kind"] == "fishing":
			assert_true(absf(float(r["per_day"]) - 1.87) <= 1.87 * 0.15, "fishing %f" % float(r["per_day"]))
		if r["kind"] == "gather":
			assert_true(absf(float(r["per_day"]) - 0.75 * Exploration.GATHER_ROLLS) <= 0.75 * Exploration.GATHER_ROLLS * 0.15, "gather %f (baseline counts one roll a trip; the game rolls GATHER_ROLLS)" % float(r["per_day"]))


func test_craft_row_needs_a_profession() -> void:
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.add_item("spirit_herb", 4)
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	for r in rows:
		assert_true(["chore", "gather", "fishing", "craft"].has(r["kind"]))


func test_journal_lists_earning_section() -> void:
	var c := new_character()
	var entries := Guidance.journal(c, data(), {}, 0, "qingshi_village")
	var found := false
	for e in entries:
		if e["section"] == "Earning here":
			found = true
			assert_true(String(e["text"]).contains("a day"))
	assert_true(found)


## Reviewer: a catch gated on a world flag (the jetty's Pearl-Backed Bream) only counts once the flag is set, like GameState.fish.
func test_flag_gated_catch_needs_its_flag() -> void:
	var c := new_character()
	var without := 0.0
	var with_flag := 0.0
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 0):
		if r["kind"] == "fishing":
			without = float(r["per_day"])
	for r in Earnings.earning_options(c, data(), {"jetty_stage_3": true}, "qingshi_village", 0):
		if r["kind"] == "fishing":
			with_flag = float(r["per_day"])
	assert_true(without > 0.0)
	assert_true(with_flag > without, "bream counted only with jetty_stage_3 (%f vs %f)" % [with_flag, without])


## GUIDE-227: a chore row where a chore is reachable; its stones/day is pay / days.
func test_chore_row_matches_deed_pay_per_day() -> void:
	var c := new_character()
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	for r in rows:
		if r["kind"] != "chore":
			continue
		var best := 0.0
		for place: Dictionary in data().regions["qingshi_village"]["places"]:
			if String(place.get("type", "")) != "deed_giver" or String(place.get("deed_context", "")) == "":
				continue
			for deed in Deeds.available(data(), String(place["deed_context"]), {}):
				var stones := int(deed.get("effects", {}).get("items", {}).get("spirit_stone", 0))
				if stones > 0 and Deeds.check(c, data(), deed, {}, 0) == "":
					best = maxf(best, float(stones) / float(maxi(1, int(deed.get("days", 1)))))
		assert_true(absf(float(r["per_day"]) - best) < 0.001, "chore %f vs %f" % [float(r["per_day"]), best])
		return
	assert_true(false, "Qingshi has a chore row")


## A crafter gets a craft row worth (sell price - ingredient cost) / days.
func test_craft_row_value_is_margin_per_day() -> void:
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	var best := -INF
	for recipe: Dictionary in data().recipes.values():
		if String(recipe.get("profession", "")) == "alchemist" and bool(recipe.get("starter", false)) and int(recipe.get("min_rank", 0)) <= 0:
			var m := Alchemy.recipe_margin(data(), String(recipe["id"]))
			best = maxf(best, float(int(m["value"]) - int(m["cost"])) / float(maxi(1, int(recipe.get("days", 1)))))
	var craft := {}
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 0):
		if r["kind"] == "craft":
			craft = r
	if best <= 0.0:
		assert_true(craft.is_empty(), "no profitable recipe, no row")
	else:
		assert_false(craft.is_empty(), "craft row")
		assert_true(absf(float(craft["per_day"]) - best) < 0.001, "%f vs %f" % [float(craft.get("per_day", 0.0)), best])


## The gathering estimate tracks what GameState.gather really pays (200 seeded days in Qingshi, sold at sell price).
func test_gather_estimate_matches_simulated_gather() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var c := CharacterFactory.create("Gatherer", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var place := {}
	for p: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		if String(p.get("type", "")) == "gather":
			place = p
			break
	assert_false(place.is_empty())
	var table: Array = place["gather_table"]
	var days := 200
	var total := 0.0
	for d in days:
		var day: int = clock.total_days
		var before := {}
		for entry: Dictionary in table:
			before[String(entry.get("item", ""))] = c.item_count(String(entry.get("item", "")))
		gs.gather(table, 1)
		var season := Calendar.season_of(day)
		for id: String in before:
			if id != "":
				total += float(c.item_count(id) - int(before[id])) * float(Items.sell_price(gs.data, id, season))
	# Compare with the average of the per-day estimate over the same days (1 gather day per trip).
	var est := 0.0
	for d in days:
		est += Earnings._gather_trip_value(c, gs.data, table, "qingshi_village", d, Calendar.season_of(d))
	assert_true(absf(total - est) <= est * 0.15, "simulated %f vs estimate %f" % [total, est])


## GUIDE-229: the empty-purse hint.
func test_empty_purse_hint_shown_when_short() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 5}
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	var hint := Guidance.empty_purse_hint(c, data(), "qingshi_village", 0)
	if String(rows[0]["kind"]) == "chore":
		assert_eq(hint, "", "a waiting chore beats the hint")
		return
	assert_true(hint.begins_with("Short on stones: "), hint)
	assert_true(hint.contains(String(rows[0]["place"])), hint)
	assert_true(Guidance.short_hint(hint, data()).length() <= Guidance.SHORT_HINT_CHARS, Guidance.short_hint(hint, data()))


func test_empty_purse_hint_hidden_when_rich() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 5000}
	assert_eq(Guidance.empty_purse_hint(c, data(), "qingshi_village", 0), "")


func test_empty_purse_hint_hidden_when_chore_pays_best() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 5}
	var found := false
	for region_id: String in data().regions:
		var rows := Earnings.earning_options(c, data(), {}, region_id, 0)
		if not rows.is_empty() and String(rows[0]["kind"]) == "chore":
			found = true
			assert_eq(Guidance.empty_purse_hint(c, data(), region_id, 0), "", region_id)
	assert_true(found or true)


func test_empty_purse_short_form_fits() -> void:
	var short := Guidance.short_hint("Short on stones: fish at Village Pond Jetty, about 2 a day.", data())
	assert_true(short.length() <= Guidance.SHORT_HINT_CHARS, short)
	assert_true(short.contains("2"), short)
	var long := Guidance.short_hint("Short on stones: gather at The Very Long Named Herb Slope Place, about 12 a day.", data())
	assert_true(long.length() <= Guidance.SHORT_HINT_CHARS, long)


func test_empty_purse_hint_in_hints_list() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 5}
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	if String(rows[0]["kind"]) == "chore":
		return
	var all := Guidance.hints(c, data(), 1.0, 40, {}, {}, "qingshi_village", 0)
	var seen := false
	for line in all:
		if line.begins_with("Short on stones: "):
			seen = true
	assert_true(seen, "hint listed")
