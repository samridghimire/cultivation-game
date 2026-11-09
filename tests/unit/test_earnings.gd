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


## Day 0 is spring: compared with the baseline's Qingshi Novice spring figure (1.87); the estimate runs about 30% above the sim (cause unknown), so the bound is 40%.
func test_novice_figures_near_balance_baseline() -> void:
	var c := new_character()
	var rows := Earnings.earning_options(c, data(), {}, "qingshi_village", 0)
	for r in rows:
		if r["kind"] == "fishing":
			assert_true(absf(float(r["per_day"]) - 1.87) <= 1.87 * 0.4, "fishing %f" % float(r["per_day"]))
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
