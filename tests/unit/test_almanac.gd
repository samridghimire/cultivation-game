extends TestCase
## CAL-010: the village almanac (omens by day, validation, hooks, Earnings).


func _find_day(d: GameData, salt: int, omen_id: String) -> int:
	for day in range(1, 400):
		if String(Almanac.omen_for(d, day, salt).get("id", "")) == omen_id:
			return day
	return -1


func test_deterministic_and_salted() -> void:
	var d := data()
	var differs := false
	for day in 30:
		assert_eq(Almanac.omen_for(d, day, 7)["id"], Almanac.omen_for(d, day, 7)["id"])
		if Almanac.omen_for(d, day, 7)["id"] != Almanac.omen_for(d, day, 8)["id"]:
			differs = true
	assert_true(differs, "another life has another calendar")


func test_shares_follow_weights() -> void:
	var d := data()
	var total := 0
	for o: Dictionary in d.almanac["omens"]:
		total += int(o["weight"])
	var counts := {}
	for day in 1000:
		var id := String(Almanac.omen_for(d, day, 3)["id"])
		counts[id] = int(counts.get(id, 0)) + 1
	for o: Dictionary in d.almanac["omens"]:
		var share := float(counts.get(o["id"], 0)) / 10.0
		var want := float(o["weight"]) * 100.0 / float(total)
		assert_true(absf(share - want) <= 5.0, "%s share %.1f vs %.1f" % [o["id"], share, want])


func test_validation_rejects_bad_effects() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Almanac.validate(d).size(), 0)
	d.almanac["omens"].append({"id": "x", "name": "X", "text": "t", "weight": 1, "boost": {"qi_mult": 2.0}})
	assert_gt(Almanac.validate(d).size(), 0)
	d.almanac["omens"].pop_back()
	d.almanac["omens"].append({"id": "y", "name": "Y", "text": "t", "weight": 1, "boost": {"fishing_mult": 2.0}})
	assert_gt(Almanac.validate(d).size(), 0)


func test_accessors_and_line() -> void:
	assert_eq(Almanac.fishing_mult({}), 1.0)
	assert_eq(Almanac.gather_bonus({}), 0.0)
	assert_eq(Almanac.gift_favor({}), 0)
	assert_eq(Almanac.sell_mult({}), 1.0)
	assert_eq(Almanac.practice_mult({}), 1.0)
	var d := data()
	var day := _find_day(d, 5, "good_fishing")
	assert_gt(day, 0)
	var omen := Almanac.omen_for(d, day, 5)
	assert_eq(Almanac.fishing_mult(omen), 1.2)
	assert_true(Almanac.line(omen).begins_with("Almanac: Good for fishing."))
	assert_eq(Almanac.tomorrow_line(omen), "Tomorrow is good for fishing.")
	var plain := Almanac.omen_for(d, _find_day(d, 5, "plain_ordinary"), 5)
	assert_true(Almanac.line(plain) != "")
	assert_eq(Almanac.tomorrow_line(plain), "")


func test_earnings_fishing_row_is_boosted_on_fishing_day() -> void:
	var d := data()
	var c := CharacterFactory.create("Angler", d, seeded_rng(1))
	var fishing := {"id": "f", "name": "F", "text": "t", "weight": 1, "boost": {"fishing_mult": 1.2}}
	var plain := {"id": "p", "name": "P", "text": "t", "weight": 1, "boost": {}}
	d.almanac["omens"] = [plain]
	var base := _fish_per_day(Earnings.earning_options(c, d, {}, "qingshi_village", 10))
	d.almanac["omens"] = [fishing]
	var lucky := _fish_per_day(Earnings.earning_options(c, d, {}, "qingshi_village", 10))
	assert_gt(base, 0.0)
	assert_true(absf(lucky / base - 1.2) < 0.001, "%f vs %f" % [lucky, base])


func _fish_per_day(rows: Array[Dictionary]) -> float:
	for r in rows:
		if String(r.get("kind", "")) == "fishing":
			return float(r["per_day"])
	return 0.0
