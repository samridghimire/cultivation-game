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


func test_hunt_spoils_record_and_round_trip() -> void:
	var c := CharacterData.new()
	assert_true(Wildlife.spoils_of(c, "wild_boar").is_empty())
	var gain := Wildlife.inventory_gain({"a": 1, "b": 2}, {"a": 1, "b": 1, "c": 3})
	assert_eq(gain, {"c": 3}, "only gains count")
	Wildlife.record_spoils(c, "wild_boar", gain)
	Wildlife.record_spoils(c, "wild_boar", {"c": 1, "d": 2})
	assert_eq(Wildlife.spoils_of(c, "wild_boar"), {"c": 4, "d": 2})
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(Wildlife.spoils_of(back, "wild_boar"), {"c": 4, "d": 2})
	assert_true(CharacterData.from_dict({"hunt_log": {"wild_boar": 1}}).hunt_spoils.is_empty(), "old save")


## C-289: every roamer beast drops an item; kitchen meats and meals validate; each meal is liked by an NPC.
func test_roamer_spoils_and_meals() -> void:
	var d := _gdata()
	for rid: String in d.regions:
		for e: Dictionary in d.regions[rid].get("roamers", {}).get("enemies", []):
			var items: Dictionary = d.enemies[e["enemy"]].get("rewards", {}).get("items", {})
			var got := false
			for it: String in items:
				if it != "spirit_stone":
					got = true
			assert_true(got, "%s drops a part" % e["enemy"])
	for meat: String in ["boar_meat", "venison", "python_meat"]:
		assert_true(d.items[meat].tags.has("meat"))
		assert_true(d.items[meat].price >= 2 and d.items[meat].price <= 12)
	var liked := {}
	for n: Variant in d.npcs.values():
		for l: Variant in n.likes:
			liked[l] = true
	for meal: String in ["boar_roast", "venison_broth"]:
		assert_true(d.items.has(meal))
		assert_true(liked.has(meal), "%s liked" % meal)


## WILD-006: the great beast.
func _player(realm: int = 0) -> CharacterData:
	var c := CharacterData.new()
	c.realm_index = realm
	return c


func test_great_day_stable_and_in_range() -> void:
	for id in ["misty_forest", "azure_peak", "x"]:
		var g := Wildlife.great_day(id, {})
		assert_true(g >= 0 and g <= 6)
		assert_eq(g, Wildlife.great_day(id, {}))
	assert_eq(Wildlife.great_day("misty_forest", {"weekday": 5}), 5)


func test_great_roamer_only_on_its_weekday() -> void:
	var d := _gdata()
	var c := _player()
	var def: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	var wd := Wildlife.great_day("misty_forest", def)
	var seen := 0
	for day in range(0, 14):
		var g := Wildlife.great_roamer(c, d, "misty_forest", day, {})
		assert_eq(not g.is_empty(), day % 7 == wd)
		if not g.is_empty():
			seen += 1
			assert_eq(int(g["slot"]), Wildlife.GREAT_SLOT)
			assert_eq(g["enemy"], def["enemy"])
	assert_eq(seen, 2)
	var flags := {}
	Wildlife.mark_down(flags, "misty_forest", Wildlife.GREAT_SLOT, wd)
	assert_true(Wildlife.great_roamer(c, d, "misty_forest", wd, flags).is_empty(), "down today")
	assert_false(Wildlife.great_roamer(c, d, "misty_forest", wd + 7, flags).is_empty(), "back next week")
	assert_true(Wildlife.great_roamer(c, d, "qingshi_village", wd, {}).is_empty())


func test_great_season_and_realm_gates() -> void:
	var d := _gdata()
	var roamers: Dictionary = d.regions["misty_forest"]["roamers"]
	var old: Dictionary = roamers["great"]
	roamers["great"] = {"enemy": "fog_antler_stag", "weekday": 0, "seasons": ["winter"], "min_realm": "foundation_establishment"}
	assert_true(Wildlife.great_roamer(_player(0), d, "misty_forest", 280, {}).is_empty(), "below realm")
	assert_false(Wildlife.great_roamer(_player(3), d, "misty_forest", 280, {}).is_empty())
	assert_true(Wildlife.great_roamer(_player(3), d, "misty_forest", 0, {}).is_empty(), "out of season")
	var nxt := Wildlife.next_great_day(d, "misty_forest", 0, 3)
	assert_true(nxt >= 0 and nxt % 7 == 0 and Calendar.season_of(nxt) == "Winter" or Calendar.season_of(nxt) == "winter")
	roamers["great"] = old


func test_next_great_day() -> void:
	var d := _gdata()
	var nxt := Wildlife.next_great_day(d, "misty_forest", 10, 0)
	assert_true(nxt >= 10 and nxt < 17)
	assert_false(Wildlife.great_roamer(_player(), d, "misty_forest", nxt, {}).is_empty())
	assert_eq(Wildlife.next_great_day(d, "qingshi_village", 0, 0), -1)


func test_validate_rejects_bad_great() -> void:
	var d := _gdata()
	var roamers: Dictionary = d.regions["misty_forest"]["roamers"]
	var old: Dictionary = roamers["great"]
	for bad in [{"enemy": "stone_ape"}, {"enemy": "salt_road_captain"}, {"enemy": "nope"}, {"enemy": "fog_antler_stag", "weekday": 7}]:
		roamers["great"] = bad
		assert_false(Wildlife.validate(d).is_empty(), str(bad))
	roamers["great"] = old
	assert_true(Wildlife.validate(d).is_empty())

## C-290: the gentle ape leaves a token, not a skin.
func test_gentle_ape_drop() -> void:
	var d := _gdata()
	var items: Dictionary = d.enemies["grave_guardian_ape"].rewards["items"]
	assert_false(items.has("stone_ape_hide"))
	assert_true(items.has("guardian_river_stone"))
	var t: Variant = d.items["guardian_river_stone"]
	assert_true(t.price >= 6 and t.price <= 10)
	assert_false(t.tags.has("meat") or t.tags.has("hide") or t.tags.has("beast_material"))


## C-291: every region with roamers has a valid great beast, and linked regions never share its day.
func test_every_roamer_region_has_a_great_beast() -> void:
	var d := _gdata()
	var days := {}
	for id in d.regions:
		var rd: Dictionary = d.regions[id]
		if not rd.has("roamers"):
			continue
		assert_true(rd["roamers"].has("great"), "%s has a great beast" % id)
		var g: Dictionary = rd["roamers"]["great"]
		assert_true(d.enemies.has(g["enemy"]), "%s great enemy exists" % id)
		assert_false(d.enemies[g["enemy"]].lethal, "%s great is not lethal" % id)
		assert_true(d.enemies[g["enemy"]].tags.has("beast"), "%s great is a beast" % id)
		days[id] = Wildlife.great_day(id, g)
	for id in days:
		for route in d.regions[id].get("routes", []):
			if days.has(route["to"]):
				assert_true(days[id] != days[route["to"]], "%s and %s share a great day" % [id, route["to"]])
