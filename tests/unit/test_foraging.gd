extends TestCase
## FORAGE-001: pickups on the way.


func _gdata() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func test_deterministic_and_counted() -> void:
	var d := _gdata()
	assert_eq(Foraging.nodes(d, "qingshi_village", 100, 0, {}), Foraging.nodes(d, "qingshi_village", 100, 0, {}))
	var seen := {}
	for day in range(0, 40):
		var n := Foraging.nodes(d, "qingshi_village", day, 0, {})
		assert_true(n.size() >= 1 and n.size() <= 3)
		seen[str(n)] = true
	assert_true(seen.size() > 1, "different days differ")
	assert_true(Foraging.nodes(d, "misty_forest", 5, 0, {}).size() >= 1)


func test_season_and_realm_filters() -> void:
	var d := _gdata()
	var old: Variant = d.regions["qingshi_village"]["forage"]
	d.regions["qingshi_village"]["forage"] = {"count": [3, 3], "items": [
		{"item": "dew_grass", "weight": 1, "seasons": ["spring"]},
		{"item": "spirit_herb", "weight": 1, "seasons": ["winter"], "min_realm": "foundation_establishment", "min": 2, "max": 2}]}
	assert_eq(Foraging.nodes(d, "qingshi_village", 0, 0, {}).size(), 3)
	for n in Foraging.nodes(d, "qingshi_village", 0, 0, {}):
		assert_eq(n["item"], "dew_grass")
	assert_true(Foraging.nodes(d, "qingshi_village", 280, 0, {}).is_empty())
	for n in Foraging.nodes(d, "qingshi_village", 280, 3, {}):
		assert_eq(int(n["amount"]), 2)
	d.regions["qingshi_village"]["forage"] = old


## FORAGE-004: a weather-gated item only rolls on those days.
func test_weather_gated_item() -> void:
	var d := _gdata()
	var old: Variant = d.regions["misty_forest"]["forage"]
	d.regions["misty_forest"]["forage"] = {"count": [3, 3], "items": [
		{"item": "dew_grass", "weight": 1},
		{"item": "purple_cloud_mushroom", "weight": 50, "weather": ["rain"]}]}
	var rain_seen := false
	for day in range(0, 120):
		var wx := Weather.of(d, "misty_forest", day)
		for n in Foraging.nodes(d, "misty_forest", day, 0, {}):
			if n["item"] == "purple_cloud_mushroom":
				assert_eq(wx, "rain", "mushrooms only in rain")
				rain_seen = true
	assert_true(rain_seen, "a rain day offers the mushroom")
	d.regions["misty_forest"]["forage"] = old


func test_weather_validation() -> void:
	var d := _gdata()
	var old: Variant = d.regions["qingshi_village"]["forage"]
	for bad: Variant in [["monsoon"], []]:
		d.regions["qingshi_village"]["forage"] = {"count": [1, 2], "items": [{"item": "dew_grass", "weight": 1, "weather": bad}]}
		assert_false(Foraging.validate(d).is_empty())
	d.regions["qingshi_village"]["forage"] = old
	assert_true(Foraging.validate(d).is_empty())


func test_picked_slot_returns_next_day() -> void:
	var d := _gdata()
	var flags := {}
	var before := Foraging.nodes(d, "qingshi_village", 40, 0, flags)
	Foraging.mark_picked(flags, "qingshi_village", int(before[0]["slot"]), 40)
	assert_eq(Foraging.nodes(d, "qingshi_village", 40, 0, flags).size(), before.size() - 1)
	assert_eq(Foraging.nodes(d, "qingshi_village", 41, 0, flags), Foraging.nodes(d, "qingshi_village", 41, 0, {}))


func test_validation() -> void:
	var d := _gdata()
	var old: Variant = d.regions["qingshi_village"]["forage"]
	assert_true(Foraging.validate(d).is_empty())
	for bad: Dictionary in [
			{"count": [2, 3], "items": [{"item": "nope", "weight": 1}]},
			{"count": [2, 3], "items": [{"item": "dew_grass", "weight": 0}]},
			{"count": [3, 1], "items": [{"item": "dew_grass", "weight": 1}]},
			{"count": [1, 2], "items": [{"item": "dew_grass", "weight": 1, "seasons": ["monsoon"]}]}]:
		d.regions["qingshi_village"]["forage"] = bad
		assert_false(Foraging.validate(d).is_empty())
	d.regions["qingshi_village"]["forage"] = old


## C-288: every region forages cheaply; no pickup sells above 12; wild regions gate a rare entry by realm.
func test_every_region_forages_cheaply() -> void:
	var d := _gdata()
	for id: String in d.regions:
		var def: Dictionary = d.regions[id].get("forage", {})
		assert_false(def.is_empty(), "%s has forage" % id)
		assert_true((def["items"] as Array).size() >= 3, "%s has 3+ entries" % id)
		for e: Dictionary in def["items"]:
			assert_true(Items.sell_price(d, String(e["item"])) <= 12, "%s %s sells <= 12" % [id, e["item"]])
	assert_true((d.regions["fallen_star_market"]["forage"]["count"] as Array)[0] == 0)
	for id in ["azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]:
		var gated := false
		for e: Dictionary in d.regions[id]["forage"]["items"]:
			gated = gated or e.has("min_realm")
		assert_true(gated, "%s has a realm-gated entry" % id)
	assert_true(Foraging.validate(d).is_empty())


func test_unpicked_and_summary() -> void:
	var d := _gdata()
	var flags := {}
	assert_eq(Foraging.unpicked(d, "qingshi_village", 40, 0, flags), Foraging.nodes(d, "qingshi_village", 40, 0, {}))
	var before := Foraging.unpicked(d, "qingshi_village", 40, 0, flags)
	Foraging.mark_picked(flags, "qingshi_village", int(before[0]["slot"]), 40)
	assert_eq(Foraging.unpicked(d, "qingshi_village", 40, 0, flags).size(), before.size() - 1)
	assert_eq(Foraging.unpicked(d, "qingshi_village", 40, 0, flags), Foraging.unpicked(d, "qingshi_village", 40, 0, flags))
	var nm: String = d.items["dew_grass"]["name"]
	var other: String = d.items["spirit_herb"]["name"]
	assert_eq(Foraging.summary(d, [{"item": "dew_grass", "amount": 1}, {"item": "spirit_herb", "amount": 1}, {"item": "dew_grass", "amount": 1}]), "%s x2, %s" % [nm, other])
	assert_eq(Foraging.summary(d, []), "")


func test_game_state_forage_today() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	assert_eq(gs.forage_today("qingshi_village"), gs.forage_here())
	var n: int = gs.forage_here().size()
	assert_true(gs.pick_forage(int(gs.forage_here()[0]["slot"])))
	assert_eq(gs.forage_today("qingshi_village").size(), n - 1)
	assert_eq(gs.forage_today("qingshi_village"), gs.forage_here())
	gs.end_session()


## FORAGE-003: picking a herb forage adds it to the herb log.
func test_pick_herb_forage_records_herb_log() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	for day in range(0, 40):
		GameClock.total_days = day
		for n: Dictionary in gs.forage_here():
			if gs.data.items[String(n["item"])].get("tags", []).has("herb"):
				assert_false(gs.player.herb_log.has(String(n["item"])))
				assert_true(gs.pick_forage(int(n["slot"])))
				assert_eq(int(gs.player.herb_log[String(n["item"])]), int(n["amount"]))
				gs.end_session()
				return
	gs.end_session()
	assert_true(false, "no herb forage found in 40 days")


## C-293: forage is a snack, not a living. Worst-case (season x realm) expected sell value per day stays small.
func test_expected_forage_value_per_day() -> void:
	var d := _gdata()
	for id: String in d.regions:
		var def: Dictionary = d.regions[id].get("forage", {})
		var cap := 1.7 if id == "qingshi_village" else 2.9
		for season: String in ["spring", "summer", "autumn", "winter"]:
			for gated in [false, true]:
				var weight := 0.0
				var value := 0.0
				for e: Dictionary in def["items"]:
					if not Exploration.in_season(e, season):
						continue
					if e.has("min_realm") and not gated:
						continue
					var lo := int(e.get("min", 1))
					var avg := (lo + int(e.get("max", lo))) / 2.0
					weight += float(e["weight"])
					value += float(e["weight"]) * Items.sell_price(d, String(e["item"])) * avg
				var counts: Array = def["count"]
				var per_day := (int(counts[0]) + int(counts[1])) / 2.0 * value / weight
				assert_true(per_day <= cap, "%s %s: %.2f stones/day > %.1f" % [id, season, per_day, cap])
	assert_eq(String(d.items["village_mugwort"]["name"]), "Mugwort")


## FORAGE-005: a forager's eye.
func test_forager_tiers() -> void:
	assert_eq(Foraging.tier_for(0), 0)
	assert_eq(Foraging.tier_for(24), 0)
	assert_eq(Foraging.tier_for(25), 1)
	assert_eq(Foraging.tier_for(75), 2)
	assert_eq(Foraging.tier_for(150), 3)
	assert_eq(Foraging.tier_line(0), "")
	assert_true(Foraging.tier_line(3) != "")


func test_tier_two_adds_pickups_and_tier_three_adds_copies() -> void:
	var d := _gdata()
	var base_n := 0
	var t2_n := 0
	var base_amt := 0
	var t3_amt := 0
	for day in range(0, 120):
		var b := Foraging.nodes(d, "qingshi_village", day, 0, {}, 0)
		var t1 := Foraging.nodes(d, "qingshi_village", day, 0, {}, 1)
		assert_eq(b, t1)  # tier 1 changes no pickups
		var t2 := Foraging.nodes(d, "qingshi_village", day, 0, {}, 2)
		var t3 := Foraging.nodes(d, "qingshi_village", day, 0, {}, 3)
		assert_eq(t3, Foraging.nodes(d, "qingshi_village", day, 0, {}, 3))
		base_n += b.size()
		t2_n += t2.size()
		assert_true(t2.size() <= 4)
		for n in b:
			base_amt += int(n["amount"])
		for n in t3:
			t3_amt += int(n["amount"])
	assert_true(t2_n > base_n)
	assert_true(t3_amt > base_amt)


## REVIEW: reaching a tier mid-day must not change which item lies in a slot already shown on the map.
func test_tier_keeps_shown_slots() -> void:
	var d := _gdata()
	for region_id: String in ["qingshi_village", "withered_bone_marsh"]:
		for day in range(0, 120):
			var b := Foraging.nodes(d, region_id, day, 0, {}, 0)
			for tier in [2, 3]:
				var t := Foraging.nodes(d, region_id, day, 0, {}, tier)
				assert_true(t.size() >= b.size())
				for i in b.size():
					assert_eq(t[i]["item"], b[i]["item"], "%s day %d tier %d slot %d" % [region_id, day, tier, i])
					assert_true(int(t[i]["amount"]) - int(b[i]["amount"]) in [0, 1])


func test_tier_three_value_stays_within_cap() -> void:
	var d := _gdata()
	var total := 0.0
	var days := 360
	for day in days:
		for n in Foraging.nodes(d, "qingshi_village", day, 0, {}, 3):
			total += Items.sell_price(d, String(n["item"])) * int(n["amount"])
	var base := 0.0
	for day in days:
		for n in Foraging.nodes(d, "qingshi_village", day, 0, {}, 0):
			base += Items.sell_price(d, String(n["item"])) * int(n["amount"])
	assert_true(total / days <= 2.0, "%.2f stones/day (base %.2f)" % [total / days, base / days])


func test_picking_counts_and_posts_tier_line() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.player.forage_picks = 24
	assert_true(gs.pick_forage(int(gs.forage_here()[0]["slot"])))
	assert_eq(gs.player.forage_picks, 25)
	assert_eq(CharacterData.from_dict(gs.player.to_dict()).forage_picks, 25)
	gs.end_session()


## FORAGE-006: a region's signature item takes slot 0 on days it is available; other slots stay put.
func test_signature_item() -> void:
	var d := _gdata()
	var old: Variant = d.regions["misty_forest"]["forage"]
	var items: Array = [
		{"item": "dew_grass", "weight": 5},
		{"item": "village_mugwort", "weight": 5},
		{"item": "peach_blossom_petal", "weight": 1, "seasons": ["spring"]}]
	d.regions["misty_forest"]["forage"] = {"count": [3, 3], "items": items}
	var plain: Array = []
	for day in [0, 1, 2]:
		plain.append(Foraging.nodes(d, "misty_forest", day, 0, {}))
	d.regions["misty_forest"]["forage"] = {"count": [3, 3], "items": items, "signature": "peach_blossom_petal"}
	for day in [0, 1, 2]:  # spring
		var n := Foraging.nodes(d, "misty_forest", day, 0, {})
		assert_eq(String(n[0]["item"]), "peach_blossom_petal")
		assert_eq(n.size(), 3)
		assert_eq(n[1], plain[day][1])
		assert_eq(n[2], plain[day][2])
	for n in Foraging.nodes(d, "misty_forest", 150, 0, {}):  # summer: out of season, slot 0 rolls normally
		assert_true(String(n["item"]) != "peach_blossom_petal")
	d.regions["misty_forest"]["forage"] = {"count": [3, 3], "items": items, "signature": "spirit_herb"}
	assert_false(Foraging.validate(d).is_empty())
	d.regions["misty_forest"]["forage"] = old
	assert_true(Foraging.validate(d).is_empty())
