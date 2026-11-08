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


## C-287: every wild region has roamers, 3-7 entries, a non-lethal beast, at least one seasonal entry.
func test_wild_regions_have_roamers() -> void:
	var d := _gdata()
	assert_true(Wildlife.validate(d).is_empty())
	for id: String in ["misty_forest", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]:
		var def: Dictionary = d.regions[id].get("roamers", {})
		var entries: Array = def.get("enemies", [])
		assert_true(entries.size() >= 3 and entries.size() <= 7, "%s entries" % id)
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

## WILD-014: the first beast, beaten, comes back as the `return` enemy.
func test_great_return_switches_after_first_win() -> void:
	var d := _gdata()
	var c := _player(1)
	assert_eq(Wildlife.active_great_enemy(c, d, "misty_forest"), "old_tusker_boar")
	var wd := Wildlife.great_day("misty_forest", d.regions["misty_forest"]["roamers"]["great"])
	var day := 7 * 40 + wd
	assert_eq(String(Wildlife.great_roamer(c, d, "misty_forest", day, {})["enemy"]), "old_tusker_boar")
	assert_eq(Wildlife.record_great(c, d, "old_tusker_boar", "misty_forest", day), "old_tuskers_broken_tusk")
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "", "C-317: the return is a Foundation fight")
	c.realm_index = d.realm_index_of("foundation_establishment")
	assert_eq(Wildlife.active_great_enemy(c, d, "misty_forest"), "scarred_old_tusker")
	assert_eq(String(Wildlife.great_roamer(c, d, "misty_forest", day + 7, {})["enemy"]), "scarred_old_tusker")
	assert_eq(Wildlife.next_great_day(d, "misty_forest", day + 1, c.realm_index, c), day + 7, "same weekday")
	assert_eq(Wildlife.record_great(c, d, "scarred_old_tusker", "misty_forest", day + 7), "scarred_tuskers_spear_head")
	assert_eq(Wildlife.record_great(c, d, "scarred_old_tusker", "misty_forest", day + 14), "", "once")
	assert_eq(Wildlife.record_great(c, d, "old_tusker_boar", "misty_forest", day + 14), "", "once")
	assert_eq(Wildlife.active_great_enemy(c, d, "qingshi_village"), "")
	assert_true(Wildlife.rumor_of(d, "misty_forest", c) != Wildlife.rumor_of(d, "misty_forest"))


func test_great_without_return_keeps_beast() -> void:
	var d := _gdata()
	var c := _player()
	c.great_beasts["cloud_crane"] = 1
	var g: Dictionary = d.regions["azure_peak"]["roamers"]["great"]
	var old: Variant = g["return"]
	g.erase("return")
	assert_eq(Wildlife.active_great_enemy(c, d, "azure_peak"), "cloud_crane")
	g["return"] = old


func test_validate_rejects_bad_return() -> void:
	var d := _gdata()
	var g: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	var old: Dictionary = g["return"]
	for bad in [{"enemy": "nope", "trophy": "old_tuskers_broken_tusk"}, {"enemy": "salt_road_captain", "trophy": "old_tuskers_broken_tusk"},
			{"enemy": "scarred_old_tusker", "trophy": "spirit_stone"}, {"enemy": "scarred_old_tusker"}]:
		g["return"] = bad
		assert_false(Wildlife.validate(d).is_empty(), str(bad))
	g["return"] = old
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


## WILD-007: a trophy once per great beast kind.
func test_record_great_trophy_once_and_round_trip() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"].duplicate(true)
	d.items["test_trophy"] = {"name": "Test Tusk", "tags": ["trophy"]}
	var g: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	g["trophy"] = "test_trophy"
	var c := CharacterData.new()
	var enemy := String(g["enemy"])
	assert_eq(Wildlife.record_great(c, d, enemy, "misty_forest", 12), "test_trophy", "first win gives it")
	assert_eq(Wildlife.record_great(c, d, enemy, "misty_forest", 30), "", "later wins do not")
	assert_eq(int(c.great_beasts[enemy]), 12, "first day kept")
	assert_eq(int(CharacterData.from_dict(c.to_dict()).great_beasts[enemy]), 12, "round trip")
	assert_true(CharacterData.from_dict({}).great_beasts.is_empty(), "old save loads")
	assert_eq(Wildlife.validate(d).size(), 0, str(Wildlife.validate(d)))
	d.items["test_trophy"]["tags"] = []
	assert_true(Wildlife.validate(d).size() > 0, "trophy needs the tag")
	d.items.erase("test_trophy")
	d.regions["misty_forest"]["roamers"] = old
	assert_eq(Wildlife.validate(d).size(), 0)


## C-294: every great beast leaves a real, trophy-tagged, unsold token.
func test_every_great_beast_has_a_trophy() -> void:
	var d := _gdata()
	var seen := 0
	for rid: String in d.regions:
		var rd: Variant = d.regions[rid]
		if not (rd is Dictionary) or not (rd as Dictionary).has("roamers"):
			continue
		var great: Dictionary = (rd as Dictionary)["roamers"].get("great", {})
		if great.is_empty():
			continue
		seen += 1
		var tid := String(great.get("trophy", ""))
		assert_true(d.items.has(tid), "%s trophy exists" % rid)
		var tags: Array = (d.items[tid] as Dictionary).get("tags", [])
		assert_true(tags.has("trophy") and tags.has("no_shop"), "%s trophy tags" % rid)
		var price := int((d.items[tid] as Dictionary).get("price", 0))
		assert_true(price >= 15 and price <= 40, "%s trophy price" % rid)
	assert_true(seen >= 4)


## C-301: every great beast comes back stronger, with its own trophy and rumour.
func test_every_great_return_is_stronger() -> void:
	var d := _gdata()
	var seen := 0
	for rid: String in d.regions:
		var rd: Variant = d.regions[rid]
		if not (rd is Dictionary) or not (rd as Dictionary).has("roamers"):
			continue
		var great: Dictionary = (rd as Dictionary)["roamers"].get("great", {})
		if great.is_empty():
			continue
		seen += 1
		assert_true(great.has("return"), "%s has a return" % rid)
		var ret: Dictionary = great.get("return", {})
		var a: Dictionary = d.enemies[String(great["enemy"])]
		var b: Dictionary = d.enemies[String(ret["enemy"])]
		assert_true(String(ret.get("rumor", "")) != "", "%s return rumour" % rid)
		assert_true(d.items.has(String(ret["trophy"])), "%s return trophy" % rid)
		assert_true(ret["trophy"] != great["trophy"], "%s trophies differ" % rid)
		assert_eq(a.get("tags"), b.get("tags"), "%s tags" % rid)
		assert_eq(a.get("lethal"), b.get("lethal"), "%s lethal" % rid)
		var ra := d.realm_index_of(String(a["realm"]))
		var rb := d.realm_index_of(String(b["realm"]))
		if int(a.get("hp", 0)) > 0 and ra == rb:
			assert_true(int(b["hp"]) + int(b["attack"]) > int(a["hp"]) + int(a["attack"]), "%s stronger" % rid)
		else:
			assert_true(rb > ra or (rb == ra and int(b["stage"]) > int(a["stage"])), "%s later stage" % rid)
	assert_true(seen >= 4)


## WILD-009: quarry notes appear after 3 hunts, deterministic, temper only without recorded spoils.
func test_quarry_notes() -> void:
	var d := _gdata()
	var c := _player()
	var id := "wild_boar"
	assert_eq(Wildlife.quarry_notes(c, d, id), "", "unknown below 3 hunts")
	c.hunt_log[id] = 2
	assert_eq(Wildlife.quarry_notes(c, d, id), "")
	c.hunt_log[id] = 3
	var bare := Wildlife.quarry_notes(c, d, id)
	assert_true(bare != "" and not bare.contains("Usually leaves"), "old save: temper only")
	var items: Array = d.items.keys()
	items.sort()
	Wildlife.record_spoils(c, id, {items[2]: 1, items[1]: 5, items[0]: 1, items[3]: 1})
	var note := Wildlife.quarry_notes(c, d, id)
	assert_true(note.begins_with("Usually leaves: %s, " % d.items[items[1]]["name"]), note)
	assert_eq(note.split(",").size(), 3 if not note.split(";")[0].contains("spirit") else 3, "at most 3 items")
	assert_eq(note, Wildlife.quarry_notes(c, d, id), "deterministic")


func test_tracks_the_day_before_a_walk_only() -> void:
	var d := _gdata()
	var def: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	var wd := Wildlife.great_day("misty_forest", def)
	var hits := 0
	for day in range(0, 14):
		var t := Wildlife.tracks_today(d, "misty_forest", day, 0)
		assert_eq(t, (day + 1) % 7 == wd and not Wildlife.great_roamer(_player(), d, "misty_forest", day + 1, {}).is_empty())
		if t:
			hits += 1
	assert_true(hits >= 1)
	assert_false(Wildlife.tracks_today(d, "qingshi_village", 0, 0), "no great beast there")
	var old: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	d.regions["misty_forest"]["roamers"]["great"] = {"enemy": "fog_antler_stag", "weekday": 0, "min_realm": "foundation_establishment"}
	assert_false(Wildlife.tracks_today(d, "misty_forest", 6, 0), "realm the beast ignores")
	assert_true(Wildlife.tracks_today(d, "misty_forest", 6, 3))
	d.regions["misty_forest"]["roamers"]["great"] = old


## WILD-013: in-season beasts.
func test_in_season_helpers_and_validation() -> void:
	var d := _gdata()
	var autumn_day := 7 * 30  # month 8 (autumn)
	var summer_day := 4 * 30  # month 5 (summer)
	assert_eq(Calendar.season_of(autumn_day), "Autumn")
	assert_eq(Calendar.season_of(summer_day), "Summer")
	assert_true(Wildlife.in_season_now(d, "misty_forest", "mist_fox", autumn_day))
	assert_false(Wildlife.in_season_now(d, "misty_forest", "mist_fox", summer_day))
	assert_false(Wildlife.in_season_now(d, "misty_forest", "wild_boar", autumn_day))
	assert_eq(Wildlife.season_clause(d, "misty_forest", autumn_day), "Fat Mist Foxes run in Misty Forest this autumn.")
	assert_eq(Wildlife.season_clause(d, "misty_forest", summer_day), "Fat Wild Boars run in Misty Forest this summer.")
	assert_eq(Wildlife.season_clause(d, "misty_forest", 9 * 30), "Fat Den Wolves run in Misty Forest this winter.")
	assert_true(Wildlife.season_clause(d, "withered_bone_marsh", summer_day).begins_with("Fat Mist Pythons"))
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	d.regions["misty_forest"]["roamers"] = {"count": [1, 1], "enemies": [{"enemy": "mist_fox", "weight": 1, "in_season": ["monsoon"]}]}
	assert_eq(Wildlife.validate(d).size(), 1)
	d.regions["misty_forest"]["roamers"] = {"count": [1, 1], "enemies": [{"enemy": "mist_fox", "weight": 1, "in_season": "autumn"}]}
	assert_eq(Wildlife.validate(d).size(), 1)
	d.regions["misty_forest"]["roamers"] = old
	assert_eq(Wildlife.validate(d).size(), 0)


## C-300: at most four in-season beasts per region, each in a season it can appear in.
func test_in_season_limits() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	d.regions["misty_forest"]["roamers"] = {"count": [1, 1], "enemies": [{"enemy": "den_wolf", "weight": 1, "seasons": ["winter"], "in_season": ["spring"]}]}
	assert_eq(Wildlife.validate(d).size(), 1, "in_season outside seasons")
	d.regions["misty_forest"]["roamers"] = {"count": [1, 1], "enemies": [
		{"enemy": "mist_fox", "weight": 1, "in_season": ["autumn"]},
		{"enemy": "wild_boar", "weight": 1, "in_season": ["spring"]},
		{"enemy": "den_wolf", "weight": 1, "in_season": ["winter"]},
		{"enemy": "mist_python", "weight": 1, "in_season": ["summer"]},
		{"enemy": "fog_antler_stag", "weight": 1, "in_season": ["summer"]}]}
	assert_eq(Wildlife.validate(d).size(), 1, "five in-season beasts")
	d.regions["misty_forest"]["roamers"] = old
	assert_eq(Wildlife.validate(d).size(), 0)
	for rid: String in ["misty_forest", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]:
		var n := 0
		for e: Dictionary in d.regions[rid]["roamers"]["enemies"]:
			if e.has("in_season"):
				n += 1
		assert_true(n >= 1 and n <= 4, rid)


func test_in_season_spoils_double_only_in_season() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var weak: Dictionary = gs.data.enemies["wild_boar"].duplicate(true)
	weak.merge({"id": "t_weakling", "hp": -1000, "attack": -1000, "defense": -1000, "speed": -1000}, true)
	weak["rewards"] = {"items": {"boar_meat": 2}}
	gs.data.enemies["t_weakling"] = weak
	var old: Dictionary = gs.data.regions["misty_forest"]["roamers"]
	var got: Array[int] = []
	for season_list: Array in [[], ["spring", "summer", "autumn", "winter"]]:
		var entry := {"enemy": "t_weakling", "weight": 1}
		if not season_list.is_empty():
			entry["in_season"] = season_list
		gs.data.regions["misty_forest"]["roamers"] = {"count": [1, 1], "enemies": [entry]}
		var c := CharacterFactory.create("Hunter", gs.data, seeded_rng(9))
		gs.start_session(c)
		gs.current_region = "misty_forest"
		GameClock.total_days = 5
		var before := c.item_count("boar_meat")
		assert_true(gs.engage_roamer(0))
		got.append(c.item_count("boar_meat") - before)
	gs.data.regions["misty_forest"]["roamers"] = old
	gs.data.enemies.erase("t_weakling")
	assert_eq(got[1], got[0] * 2, "in season doubles the spoils")
	assert_true(got[0] > 0)


## WILD-015: bait items, weaken, validation.
func test_bait_item_weaken_and_validation() -> void:
	var d := _gdata()
	var c := _player()
	assert_eq(Wildlife.bait_item(c, d, "misty_forest"), "", "holds none")
	c.add_item("village_mugwort", 1)
	assert_eq(Wildlife.bait_item(c, d, "misty_forest"), "village_mugwort")
	assert_eq(Wildlife.bait_item(c, d, "qingshi_village"), "", "no great beast")
	assert_eq(Wildlife.bait_weaken(d, "misty_forest"), 0.1)
	var e: Dictionary = d.enemies["old_tusker_boar"]
	var base := Combat.enemy_stats(e, d)
	var weak := Combat.enemy_stats(Wildlife.weakened(e, 0.1), d)
	assert_true(int(weak["max_hp"]) < int(base["max_hp"]))
	assert_true(int(weak["attack"]) < int(base["attack"]))
	assert_eq(int(weak["defense"]), int(base["defense"]))
	d.regions["misty_forest"]["roamers"]["great"]["bait"] = ["no_such_item"]
	assert_true(Wildlife.validate(d).size() > 0)
	d.regions["misty_forest"]["roamers"]["great"]["bait"] = ["village_mugwort"]
	d.regions["misty_forest"]["roamers"]["great"]["bait_weaken"] = 0.9
	assert_true(Wildlife.validate(d).size() > 0)
	d.regions["misty_forest"]["roamers"]["great"].erase("bait_weaken")
	assert_eq(Wildlife.validate(d).size(), 0)


## WILD-018: max_realm on roamers, own min_realm on return beasts.
func test_max_realm_filters_and_validates() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"]
	_with(d, {"count": [3, 3], "enemies": [{"enemy": "wild_boar", "weight": 1, "max_realm": "qi_refining"}, {"enemy": "mist_fox", "weight": 1, "min_realm": "foundation_establishment"}]})
	assert_eq(Wildlife.roamers(d, "misty_forest", 5, 1, {}).size(), 3)
	for r in Wildlife.roamers(d, "misty_forest", 5, 1, {}):
		assert_eq(r["enemy"], "wild_boar")
	for r in Wildlife.roamers(d, "misty_forest", 5, 3, {}):
		assert_eq(r["enemy"], "mist_fox", "boar is beneath a Foundation cultivator")
	_with(d, {"count": [3, 3], "enemies": [{"enemy": "wild_boar", "weight": 1, "max_realm": "mortal"}]})
	assert_true(Wildlife.roamers(d, "misty_forest", 5, 1, {}).is_empty(), "empty pool is fine")
	assert_true(Wildlife.validate(d).is_empty())
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "wild_boar", "weight": 1, "max_realm": "nope"}]})
	assert_false(Wildlife.validate(d).is_empty())
	_with(d, {"count": [1, 1], "enemies": [{"enemy": "wild_boar", "weight": 1, "min_realm": "foundation_establishment", "max_realm": "qi_refining"}]})
	assert_false(Wildlife.validate(d).is_empty(), "max below min")
	_with(d, old)
	assert_true(Wildlife.validate(d).is_empty())


func test_foundation_misty_forest_has_no_weak_beasts() -> void:
	var d := _gdata()
	for day in range(0, 14):
		for r in Wildlife.roamers(d, "misty_forest", day, 3, {}):
			assert_false(["wild_boar", "mist_fox"].has(String(r["enemy"])), "day %d" % day)


func test_return_beast_own_min_realm() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"].duplicate(true)
	var def: Dictionary = d.regions["misty_forest"]["roamers"]
	def["great"]["min_realm"] = "foundation_establishment"
	def["great"]["return"]["min_realm"] = "qi_refining"
	var c := CharacterData.new()
	c.realm_index = 1
	var day := Wildlife.next_great_day(d, "misty_forest", 0, 3)
	assert_eq(Wildlife.next_great_day(d, "misty_forest", 0, 1, c), -1, "parent gate before the first win")
	c.great_beasts[String(def["great"]["enemy"])] = true
	assert_true(Wildlife.next_great_day(d, "misty_forest", 0, 1, c) >= 0, "return beast walks at its own realm")
	assert_eq(Wildlife.next_great_day(d, "misty_forest", 0, 0, c), -1, "not below it")
	assert_true(day >= 0)
	d.regions["misty_forest"]["roamers"] = old


## WILD-019: great beasts you have outgrown step aside.
func test_great_max_realm_hands_slot_to_return_beast() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"].duplicate(true)
	var great: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	great["max_realm"] = "qi_refining"
	var wd := Wildlife.great_day("misty_forest", great)
	var day := 7 * 40 + wd
	var qr := _player(1)
	var fe := _player(1)
	fe.realm_index = d.realm_index_of("foundation_establishment")
	assert_eq(Wildlife.great_enemy_for(qr, d, "misty_forest"), "old_tusker_boar")
	assert_eq(Wildlife.great_enemy_for(fe, d, "misty_forest"), "scarred_old_tusker", "outgrown: the return beast walks")
	assert_eq(Wildlife.great_enemy_for(null, d, "misty_forest"), "old_tusker_boar", "no character: unchanged")
	assert_eq(String(Wildlife.great_roamer(fe, d, "misty_forest", day, {})["enemy"]), "scarred_old_tusker")
	assert_eq(Wildlife.next_great_day(d, "misty_forest", day, fe.realm_index, fe), day)
	assert_true(Wildlife.tracks_today(d, "misty_forest", day - 1, fe.realm_index, fe))
	assert_eq(Wildlife.rumor_of(d, "misty_forest", fe), String(great["return"]["rumor"]))
	assert_eq(Wildlife.rumor_of(d, "misty_forest", qr), String(great["rumor"]))
	# Beaten the first beast and above the return's max_realm: nothing walks.
	great["return"]["max_realm"] = "qi_refining"
	fe.great_beasts["old_tusker_boar"] = 1
	assert_eq(Wildlife.great_enemy_for(fe, d, "misty_forest"), "")
	assert_eq(Wildlife.next_great_day(d, "misty_forest", day, fe.realm_index, fe), -1)
	assert_true(Wildlife.great_roamer(fe, d, "misty_forest", day, {}).is_empty())
	var line := Guidance.arrival_line(fe, d, "misty_forest", day, {}, "")
	assert_false(line.contains("roams"), line)
	d.regions["misty_forest"]["roamers"] = old


func test_great_max_realm_validation() -> void:
	var d := _gdata()
	var old: Dictionary = d.regions["misty_forest"]["roamers"].duplicate(true)
	var great: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	great["max_realm"] = "nope"
	assert_false(Wildlife.validate(d).is_empty(), "unknown max_realm")
	great["min_realm"] = "foundation_establishment"
	great["max_realm"] = "qi_refining"
	assert_false(Wildlife.validate(d).is_empty(), "max below min")
	great.erase("min_realm")
	great["max_realm"] = "foundation_establishment"
	great["return"]["min_realm"] = "foundation_establishment"
	great["return"]["max_realm"] = "qi_refining"
	assert_false(Wildlife.validate(d).is_empty(), "return max below min")
	great["return"]["max_realm"] = "nope"
	assert_false(Wildlife.validate(d).is_empty(), "return unknown max_realm")
	d.regions["misty_forest"]["roamers"] = old
	assert_true(Wildlife.validate(d).is_empty())


## C-317: every region's great beast is a fight for each realm it serves, and the returns are Foundation fights.
func test_great_beasts_for_every_realm() -> void:
	var d := _gdata()
	var foundation_only := ["myriad_peaks_ridge"]  # its first great beast is built for Foundation
	var qr := _player(d.realm_index_of("qi_refining"))
	var fe := _player(d.realm_index_of("foundation_establishment"))
	for rid: String in d.regions:
		var g: Dictionary = d.regions[rid].get("roamers", {}).get("great", {})
		if g.is_empty():
			continue
		assert_true(Wildlife.next_great_day(d, rid, 100, fe.realm_index, fe) >= 0, "%s: a great beast walks for Foundation" % rid)
		if not foundation_only.has(rid):
			assert_true(Wildlife.next_great_day(d, rid, 100, qr.realm_index, qr) >= 0, "%s: a great beast walks for Qi Refining" % rid)
			assert_eq(String(g.get("max_realm", "")), "qi_refining", "%s: the first beast is Qi Refining only" % rid)
		var ret: Dictionary = g.get("return", {})
		assert_eq(String(d.enemies[String(ret["enemy"])]["realm"]), "foundation_establishment", "%s: the return beast is a Foundation foe" % rid)


## C-312: every region with roamers keeps a Foundation roster; the weakest beasts step aside for it.
func test_every_roaming_region_has_foundation_beasts() -> void:
	var d := _gdata()
	var fe := d.realm_index_of("foundation_establishment")
	for region_id: String in d.regions:
		var def: Dictionary = d.regions[region_id].get("roamers", {})
		if def.is_empty():
			continue
		var has_foundation := false
		for entry: Dictionary in def["enemies"]:
			if String(d.enemies[String(entry["enemy"])].get("realm", "")) != "foundation_establishment":
				continue
			if entry.has("min_realm") and d.realm_index_of(String(entry["min_realm"])) > fe:
				continue
			if entry.has("max_realm") and d.realm_index_of(String(entry["max_realm"])) < fe:
				continue
			has_foundation = true
		assert_true(has_foundation, "%s has a Foundation roamer entry" % region_id)
		var seen := {}  # season -> Foundation-realm roamers met
		for day in range(0, 360):
			for r in Wildlife.roamers(d, region_id, day, fe, {}):
				if String(d.enemies[String(r["enemy"])]["realm"]) == "foundation_establishment":
					var season := Calendar.season_of(day)
					seen[season] = int(seen.get(season, 0)) + 1
		assert_true(seen.size() >= 1, "%s: a Foundation Early player meets Foundation beasts" % region_id)


## WILD-020: a great-beast trail of three steps: first -> middle -> last.
func _chain_fixture(d: GameData) -> Dictionary:
	var old: Dictionary = d.regions["misty_forest"]["roamers"].duplicate(true)
	var great: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	great.erase("max_realm")
	great["return"]["min_realm"] = "foundation_establishment"
	great["return"]["max_realm"] = "foundation_establishment"
	great["return"]["return"] = {"enemy": "mist_fox", "trophy": "old_tuskers_broken_tusk", "min_realm": "foundation_establishment", "rumor": "A third beast walks the fog."}
	return old


func test_great_chain_walks_in_order() -> void:
	var d := _gdata()
	var old := _chain_fixture(d)
	var c := _player(2)
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "old_tusker_boar")
	c.great_beasts["old_tusker_boar"] = 1
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "scarred_old_tusker")
	assert_eq(Wildlife.rumor_of(d, "misty_forest", c), String(d.regions["misty_forest"]["roamers"]["great"]["return"]["rumor"]))
	c.great_beasts["scarred_old_tusker"] = 2
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "mist_fox")
	assert_eq(Wildlife.rumor_of(d, "misty_forest", c), "A third beast walks the fog.")
	assert_eq(Wildlife.record_great(c, d, "mist_fox", "misty_forest", 9), "old_tuskers_broken_tusk")
	assert_eq(Wildlife.great_trophy(d, "mist_fox"), "old_tuskers_broken_tusk")
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "mist_fox", "the last step keeps walking")
	assert_true(Wildlife.validate(d).is_empty())
	d.regions["misty_forest"]["roamers"] = old


func test_great_chain_skips_outgrown_and_stops_below() -> void:
	var d := _gdata()
	var old := _chain_fixture(d)
	var c := _player(3)  # Core Formation: above the middle's max_realm
	c.great_beasts["old_tusker_boar"] = 1
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "mist_fox", "middle skipped")
	var q := _player(1)  # Qi Refining, first beaten, below the middle
	q.great_beasts["old_tusker_boar"] = 1
	assert_eq(Wildlife.great_enemy_for(q, d, "misty_forest"), "", "below the middle: nothing walks")
	d.regions["misty_forest"]["roamers"]["great"]["return"]["return"]["max_realm"] = "qi_refining"
	assert_eq(Wildlife.great_enemy_for(c, d, "misty_forest"), "", "nothing fits")
	d.regions["misty_forest"]["roamers"] = old


func test_great_chain_validation_is_recursive() -> void:
	var d := _gdata()
	var old := _chain_fixture(d)
	var third: Dictionary = d.regions["misty_forest"]["roamers"]["great"]["return"]["return"]
	third["enemy"] = "salt_road_captain"
	assert_false(Wildlife.validate(d).is_empty(), "lethal nested return")
	third["enemy"] = "mist_fox"
	third["trophy"] = "spirit_stone"
	assert_false(Wildlife.validate(d).is_empty(), "trophy must be tagged")
	third["trophy"] = "old_tuskers_broken_tusk"
	third["rumor"] = "x".repeat(141)
	assert_false(Wildlife.validate(d).is_empty(), "long rumor")
	d.regions["misty_forest"]["roamers"] = old
