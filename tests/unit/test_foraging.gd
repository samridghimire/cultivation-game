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
	assert_true(Foraging.nodes(d, "misty_forest", 5, 0, {}).size() >= 2)


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
