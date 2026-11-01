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
		assert_true(r.size() >= 2 and r.size() <= 4)
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


## C-287: every wild region has roamers, 3-5 entries, a non-lethal beast, at least one seasonal entry.
func test_wild_regions_have_roamers() -> void:
	var d := _gdata()
	assert_true(Wildlife.validate(d).is_empty())
	for id: String in ["misty_forest", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]:
		var def: Dictionary = d.regions[id].get("roamers", {})
		var entries: Array = def.get("enemies", [])
		assert_true(entries.size() >= 3 and entries.size() <= 5, "%s entries" % id)
		var seasonal := false
		for e: Dictionary in entries:
			assert_false(bool(d.enemies[e["enemy"]].get("lethal", false)))
			seasonal = seasonal or e.has("seasons")
		assert_true(seasonal, "%s has a seasonal entry" % id)
	assert_false(d.regions["fallen_star_market"].has("roamers"))


## WILD-002: tempers by threat, override, validation, carried by roamers().
func test_temper() -> void:
	var d := _gdata()
	var c := CharacterData.new()
	c.realm_index = 0
	var weak_id := ""
	var strong_id := ""
	for id: String in d.enemies:
		var e: Dictionary = d.enemies[id]
		if not (e.get("tags", []) as Array).has("beast"):
			continue
		var t := Wildlife.threat(c, d, id)
		if t == "Weak" and weak_id == "":
			weak_id = id
		elif (t == "Risky" or t == "Dangerous" or t == "Deadly") and strong_id == "":
			strong_id = id
	assert_true(weak_id != "" and strong_id != "")
	assert_eq(Wildlife.temper(c, d, weak_id), "flees")
	assert_eq(Wildlife.temper(c, d, strong_id), "bold")
	assert_eq(Wildlife.temper(c, d, weak_id, "bold"), "bold", "override wins")


func test_temper_validation_and_carry() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "wild_boar", "weight": 1, "temper": "angry"}]})
	assert_false(Wildlife.validate(d).is_empty())
	_with(d, {"count": [2, 2], "enemies": [{"enemy": "wild_boar", "weight": 1, "temper": "wary"}]})
	assert_true(Wildlife.validate(d).is_empty())
	for r in Wildlife.roamers(d, "misty_forest", 3, 0, {}):
		assert_eq(r["temper"], "wary")
	_with(d, old)
	for r in Wildlife.roamers(d, "misty_forest", 3, 0, {}):
		assert_eq(r["temper"], "")


func test_hunt_log_and_summary() -> void:
	var d := _gdata()
	var c := CharacterData.new()
	assert_eq(Wildlife.log_summary(c, d), "")
	Wildlife.record_hunt(c, "wild_boar")
	Wildlife.record_hunt(c, "wild_boar")
	assert_eq(int(c.hunt_log["wild_boar"]), 2)
	assert_eq(LifeStats.get_stat(c, "beasts_hunted"), 2)
	var all := Wildlife.huntable(d)
	assert_true(all.has("wild_boar") and all.has("mist_fox"), "misty roamers are huntable")
	assert_eq(Wildlife.log_summary(c, d), "Beasts hunted: 1 of %d kinds" % all.size())
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(int(back.hunt_log["wild_boar"]), 2)
	assert_true(CharacterData.from_dict({}).hunt_log.is_empty(), "old saves load empty")
