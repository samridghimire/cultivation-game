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
		assert_true(n.size() >= 2 and n.size() <= 3)
		seen[str(n)] = true
	assert_true(seen.size() > 1, "different days differ")
	assert_true(Foraging.nodes(d, "misty_forest", 5, 0, {}).is_empty())


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
