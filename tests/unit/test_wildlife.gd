extends TestCase
## WILD-001: visible roaming beasts.


func _gdata() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func _with(data: GameData, def: Dictionary) -> void:
	data.regions["misty_forest"]["roamers"] = def


func test_deterministic_and_counted() -> void:
	var d := _gdata()
	var a := Wildlife.roamers(d, "misty_forest", 100, 0, {})
	assert_eq(a, Wildlife.roamers(d, "misty_forest", 100, 0, {}))
	var days_seen := {}
	for day in range(0, 60):
		var r := Wildlife.roamers(d, "misty_forest", day, 0, {})
		assert_true(r.size() >= 2 and r.size() <= 3)
		days_seen[str(r)] = true
	assert_true(days_seen.size() > 1, "different days differ")
	assert_true(Wildlife.roamers(d, "qingshi_village", 5, 0, {}).is_empty())


func test_season_and_realm_filters() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	_with(d, {"count": [3, 3], "enemies": [{"enemy": "wild_boar", "weight": 1, "seasons": ["spring"]}, {"enemy": "mist_fox", "weight": 1, "seasons": ["winter"], "min_realm": "foundation_establishment"}]})
	assert_eq(Wildlife.roamers(d, "misty_forest", 0, 0, {}).size(), 3)
	for r in Wildlife.roamers(d, "misty_forest", 0, 0, {}):
		assert_eq(r["enemy"], "wild_boar")
	assert_true(Wildlife.roamers(d, "misty_forest", 280, 0, {}).is_empty(), "winter fox needs the realm")
	assert_eq(Wildlife.roamers(d, "misty_forest", 280, 3, {}).size(), 3)
	_with(d, old)


func test_downed_slot_returns_next_day() -> void:
	var d := _gdata()
	var flags := {}
	var before := Wildlife.roamers(d, "misty_forest", 40, 0, flags)
	Wildlife.mark_down(flags, "misty_forest", int(before[0]["slot"]), 40)
	var after := Wildlife.roamers(d, "misty_forest", 40, 0, flags)
	assert_eq(after.size(), before.size() - 1)
	assert_eq(Wildlife.roamers(d, "misty_forest", 41, 0, flags).size(), Wildlife.roamers(d, "misty_forest", 41, 0, {}).size())


func test_validation() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	assert_true(Wildlife.validate(d).is_empty())
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "nope", "weight": 1}]})
	assert_false(Wildlife.validate(d).is_empty())
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "mist_wolf", "weight": 1}]})
	assert_false(Wildlife.validate(d).is_empty(), "lethal beast")
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "rogue_cultivator", "weight": 1}]})
	assert_false(Wildlife.validate(d).is_empty(), "non-beast")
	_with(d, old)
