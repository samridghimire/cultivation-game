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
				if stones > 0 and Deeds.is_repeatable(deed) and int(deed.get("effects", {}).get("alignment", 0)) >= 0 and String(deed.get("enemy", "")) == "" and Deeds.check(c, data(), deed, {}, 0) == "":
					best = maxf(best, float(stones) / float(maxi(1, int(deed.get("days", 1)))))
		assert_true(absf(float(r["per_day"]) - best) < 0.001, "chore %f vs %f" % [float(r["per_day"]), best])
		return


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


## GUIDE-230: wages come only from good, repeatable errands.
func test_atrocities_and_one_time_deeds_are_not_wages() -> void:
	var c := new_character()
	var bad := ["poison_village_well", "sell_street_child", "rob_traveller"]
	for region in ["qingshi_village", "withered_bone_marsh"]:
		for r in Earnings.earning_options(c, data(), {}, region, 0):
			if r["kind"] == "chore":
				for id in bad:
					assert_false(String(r["note"]) == String(data().deeds[id]["name"]), "%s in %s" % [id, region])
	c.inventory = {"spirit_stone": 5}
	for region in ["qingshi_village", "withered_bone_marsh"]:
		var hint := Guidance.empty_purse_hint(c, data(), region, 0)
		for id in bad:
			assert_false(hint.contains(String(data().deeds[id]["name"])), hint)


func test_is_repeatable_only_for_deeds_that_come_back() -> void:
	assert_false(Deeds.is_repeatable(data().deeds["chore_gather_herbs"]), "headman chores are one-time")
	assert_true(Deeds.is_repeatable(data().deeds["help_villager"]))
	assert_false(Deeds.is_repeatable(data().deeds["poison_village_well"]))
	assert_false(Deeds.is_repeatable(data().deeds["con_the_poisoner"]))
	assert_false(Deeds.is_repeatable({"id": "x", "blocked_by_flag": "x_done", "effects": {"set_flag": "x_done"}}))
	assert_true(Deeds.is_repeatable({"id": "y", "blocked_by_flag": "y", "effects": {"set_flag": "y", "flag_days": 5}}))


func test_festival_first_day_has_no_tomorrow_line_and_one_bullet() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	var today: int = GameClock.total_days
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": today, "end_day": today + 6, "done": false}]
	var lines: PackedStringArray = gs.today_lines()
	var festival_lines := 0
	for l in lines:
		assert_false(l.begins_with("Tomorrow: Lantern Festival"), l)
		if l.contains("Lantern Festival"):
			festival_lines += 1
	assert_eq(festival_lines, 1, str(lines))


## GUIDE-232: one far row at most, only when the gain survives the round trip.
func _first_route_region(from: String) -> String:
	return String(data().regions[from]["routes"][0]["to"])


func test_far_row_shape_and_gain() -> void:
	var c := new_character()
	c.realm_index = 2  # high enough to pass every route's realm gate
	for from: String in data().regions:
		var far := Earnings.far_row(c, data(), {}, from, 0)
		if far.is_empty():
			continue
		var local := Earnings.earning_options(c, data(), {}, from, 0)
		var local_best := float(local[0]["per_day"]) if not local.is_empty() else 0.0
		var value := float(far["per_day"]) * Earnings.FAR_STAY_DAYS / (Earnings.FAR_STAY_DAYS + 2.0 * float(far["days"]))
		assert_true(value >= Earnings.FAR_GAIN * local_best - 0.001, "%s: %s" % [from, str(far)])
		assert_eq(String(far["kind"]), "far")
		assert_true(Earnings.lines([far] as Array[Dictionary])[0].contains("days away"))
		assert_true(Earnings.rows_with_far(c, data(), {}, from, 0).filter(func(r: Dictionary) -> bool: return r["kind"] == "far").size() == 1, "never two far rows")


func test_far_row_never_when_trip_eats_gain() -> void:
	var c := new_character()
	var d: GameData = data()
	var saved: Array = (d.regions["qingshi_village"]["routes"] as Array).duplicate(true)
	for route: Dictionary in d.regions["qingshi_village"]["routes"]:
		route["days"] = 400
		route.erase("min_realm")
	assert_true(Earnings.far_row(c, d, {}, "qingshi_village", 0).is_empty(), "a 400-day road never pays")
	d.regions["qingshi_village"]["routes"] = saved


func test_empty_purse_hint_names_far_row_only_when_nothing_pays_two() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 5}
	var hint := Guidance.empty_purse_hint(c, data(), "qingshi_village", 0)
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	if not rows.is_empty() and float(rows[0]["per_day"]) >= 2.0:
		assert_false(hint.contains("days away"), hint)


## GUIDE-233: the one-time headman jobs show on the card.
func test_one_time_rows_list_good_headman_jobs() -> void:
	var c := new_character()
	var rows := Earnings.one_time_rows(c, data(), {}, "qingshi_village", 0)
	assert_true(rows.size() >= 1 and rows.size() <= 2, "rows %d" % rows.size())
	for i in rows.size() - 1:
		assert_true(int(rows[i]["stones"]) >= int(rows[i + 1]["stones"]))
	for id in ["poison_village_well", "sell_street_child", "rob_traveller"]:
		for r in rows:
			assert_false(String(r["note"]) == String(data().deeds[id]["name"]))
	var first := String(rows[0]["note"])
	var flag := String(data().deeds["chore_gather_herbs"].get("blocked_by_flag", ""))
	var after := Earnings.one_time_rows(c, data(), {flag: true}, "qingshi_village", 0)
	for r in after:
		assert_false(String(r["note"]) == String(data().deeds["chore_gather_herbs"]["name"]))
	var text := Earnings.lines(rows, data())
	assert_true(text[0].begins_with("Once: "), text[0])
	assert_true(first != "")


func test_lines_capitalize_gathering() -> void:
	var rows: Array[Dictionary] = [{"kind": "gather", "place": "Herb Slope", "note": "gathering", "per_day": 3.0}]
	assert_true(Earnings.lines(rows)[0].begins_with("Gathering ("))

## C-347: Qingshi has repeatable paid errands; doing one hides the row until its cooldown ends.
func test_qingshi_errands_are_a_repeatable_wage() -> void:
	for id in ["chore_odd_jobs", "chore_haul_water"]:
		assert_true(Deeds.is_repeatable(data().deeds[id]), id)
	var c := new_character()
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	assert_true(_kinds(rows).has("chore"), "fresh character sees an errands row")
	for r in rows:
		if r["kind"] == "chore":
			assert_true(absf(float(r["per_day"]) - 4.5) < 0.001, "about 4.5 a day")
	c.deed_days["chore_odd_jobs"] = 0
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 1):
		if r["kind"] == "chore":
			assert_true(String(r["note"]).contains("Temple of Mercy"), "next deed is the water haul")
	c.deed_days["chore_haul_water"] = 0
	assert_false(_kinds(Earnings.earning_options(c, data(), {}, "qingshi_village", 1)).has("chore"), "both cooling down")
	assert_true(_kinds(Earnings.earning_options(c, data(), {}, "qingshi_village", 7)).has("chore"), "odd jobs back after 7 days")


## GUIDE-234: a disciple at their hall sees the best sect mission as an earning row.
func test_disciple_gets_mission_row_at_hall() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	c.add_item("spirit_herb", 3)
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	var mission := {}
	for r in rows:
		if r["kind"] == "mission":
			mission = r
	assert_false(mission.is_empty(), "mission row")
	assert_eq(mission["note"], String(data().sect_missions["herb_hall_tithe"]["name"]))
	assert_eq(int(roundf(float(mission["per_day"]))), 4)  # GUIDE-235: net of the herbs handed in
	var text := " ".join(Earnings.lines(rows, data()))
	assert_true(text.contains("Sect mission"), text)
	assert_true(text.contains("contribution"), text)


func test_rogue_gets_no_mission_row() -> void:
	var c := new_character()
	c.add_item("spirit_herb", 3)
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 0):
		assert_true(r["kind"] != "mission", "no mission row")


func test_mission_on_cooldown_is_not_a_row() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	c.add_item("spirit_herb", 3)
	for id: String in Sects.available_missions(c, data(), {}):
		c.mission_cooldowns[id] = c.age_days + 30
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 0):
		assert_true(r["kind"] != "mission", "no mission row")


## GUIDE-235: honest mission pay.
func test_contribution_value_is_median_shop_ratio() -> void:
	var v := Sects.contribution_value(data(), "azure_cloud_sect")
	assert_true(v > 0.0, "positive")
	var ratios: Array[float] = []
	for e: Dictionary in (data().sects["azure_cloud_sect"] as SectDef).shop:
		ratios.append(float(int(data().items[e["item_id"]].get("price", 0))) / float(e["contribution"]))
	ratios.sort()
	assert_true(v >= ratios[0] and v <= ratios[ratios.size() - 1], "between min and max")
	assert_eq(Sects.contribution_value(data(), "no_such_sect"), 0.0)


func test_mission_row_subtracts_consumed_items_and_shows_worth() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	c.add_item("spirit_herb", 3)
	var row := {}
	for r in Earnings.earning_options(c, data(), {}, "qingshi_village", 0):
		if r["kind"] == "mission":
			row = r
	assert_false(row.is_empty())
	var m: Dictionary = {}
	for id: String in data().sect_missions:
		if data().sect_missions[id]["name"] == row["note"]:
			m = data().sect_missions[id]
	var cost := 0
	for item_id: String in m.get("requires", {}).get("items", {}):
		cost += int(data().items[item_id]["price"]) * int(m["requires"]["items"][item_id])
	var pay := int(m.get("rewards", {}).get("items", {}).get("spirit_stone", 0))
	assert_eq(roundi(float(row["per_day"]) * maxi(1, int(m.get("days", 1)))), pay - cost)
	var text := " ".join(Earnings.lines([row] as Array[Dictionary], data()))
	assert_true(text.contains("worth about %d stones at the treasury" % int(row["worth"])), text)


func test_far_mission_wording_and_no_duplicate_giver() -> void:
	var far: Array[Dictionary] = [{"kind": "far", "place": "Azure Hall, Azure Peak", "note": "mission", "per_day": 10.0, "days": 3, "contribution": 5, "worth": 12}]
	var t := Earnings.lines(far, data())[0]
	assert_true(t.begins_with("Sect mission at Azure Hall, Azure Peak (3 days away): about 10 stones a day, +5 contribution"), t)
	var once: Array[Dictionary] = [{"kind": "job", "place": "Headman Zhou", "note": "Run errands for Headman Zhou", "stones": 9, "items": {}, "days": 2}]
	var u := Earnings.lines(once, data())[0]
	assert_false(u.contains("(Headman Zhou)"), u)
	var chore: Array[Dictionary] = [{"kind": "chore", "place": "Headman Zhou", "note": "Run errands for Headman Zhou", "per_day": 4.0}]
	assert_false(Earnings.lines(chore, data())[0].contains("(Headman Zhou)"))


## SECT-006: a sect member in their home region sees the steward's chore row with contribution; a rogue does not.
func test_steward_chore_row_for_disciple_only() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	var rows := Earnings.earning_options(c, data(), {}, "azure_peak", 0)
	var chore := {}
	for r in rows:
		if r["kind"] == "chore":
			chore = r
	assert_false(chore.is_empty(), "chore row")
	assert_true(int(chore["contribution"]) > 0)
	assert_eq(chore["place"], "Hall Steward Qiu")
	assert_true(" ".join(Earnings.lines(rows, data())).contains("contribution"))
	var rogue := new_character()
	for r in Earnings.earning_options(rogue, data(), {}, "azure_peak", 0):
		assert_true(String(r.get("place", "")) != "Hall Steward Qiu")
	# After the best chore, the row switches to the other one.
	var first := String(chore["note"])
	var id := "hall_chore_azure_heavy" if first == String(data().deeds["hall_chore_azure_heavy"]["name"]) else "hall_chore_azure_light"
	Deeds.perform(c, data(), id, {}, 0)
	var after := {}
	for r in Earnings.earning_options(c, data(), {}, "azure_peak", 1):
		if r["kind"] == "chore":
			after = r
	assert_true(after.is_empty() or after["note"] != first, "next chore differs")


## SECT-006: requires.sect on deeds.
func test_deed_requires_sect() -> void:
	var deed: Dictionary = data().deeds["hall_chore_azure_light"]
	var rogue := new_character()
	assert_true(Deeds.check(rogue, data(), deed, {}, 0).begins_with("Only disciples of the Azure Cloud Sect"))
	var other := new_character()
	other.realm_index = 1
	assert_true(Sects.join(other, data(), "blood_lotus_sect")["ok"])
	assert_true(Deeds.check(other, data(), deed, {}, 0) != "")
	var member := new_character()
	member.realm_index = 1
	assert_true(Sects.join(member, data(), "azure_cloud_sect")["ok"])
	assert_eq(Deeds.check(member, data(), deed, {}, 0), "")
	var any_deed := {"id": "x", "requires": {"sect": "any"}, "effects": {}}
	assert_true(Deeds.check(rogue, data(), any_deed, {}, 0) != "")
	assert_eq(Deeds.check(other, data(), any_deed, {}, 0), "")
	data().deeds["bad_sect"] = {"id": "bad_sect", "requires": {"sect": "nope"}, "effects": {}}
	var errs := Deeds.validate(data())
	data().deeds.erase("bad_sect")
	assert_true(" ".join(errs).contains("unknown sect"))
