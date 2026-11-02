extends TestCase
## GOAL-001: milestones.


func _milestone(id: String, check: Dictionary) -> Dictionary:
	return {"id": id, "name": id, "description": "", "check": check}


func test_data_loads_clean() -> void:
	assert_true(data().milestones.size() >= 15)
	assert_eq(data().load_errors.size(), 0, str(data().load_errors))


func test_life_stat_and_realm_checks() -> void:
	var c := new_character()
	var flags := {}
	assert_false(Milestones.is_met(c, data(), flags, null, {"type": "life_stat", "stat": "fights_won", "min": 2}))
	LifeStats.add(c, "fights_won", 2)
	assert_true(Milestones.is_met(c, data(), flags, null, {"type": "life_stat", "stat": "fights_won", "min": 2}))
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.stage = 0
	assert_true(Milestones.is_met(c, data(), flags, null, {"type": "realm", "realm": "foundation_establishment", "stage": 0}))
	assert_true(Milestones.is_met(c, data(), flags, null, {"type": "realm", "realm": "qi_refining", "stage": 5}))
	assert_false(Milestones.is_met(c, data(), flags, null, {"type": "realm", "realm": "foundation_establishment", "stage": 1}))
	assert_false(Milestones.is_met(c, data(), flags, null, {"type": "realm", "realm": "core_formation", "stage": 0}))


func test_flag_sect_married_clan_crafted() -> void:
	var c := new_character()
	assert_false(Milestones.is_met(c, data(), {}, null, {"type": "flag", "flag": "f"}))
	assert_true(Milestones.is_met(c, data(), {"f": true}, null, {"type": "flag", "flag": "f"}))
	assert_false(Milestones.is_met(c, data(), {}, null, {"type": "sect_joined"}))
	c.sect = {"id": "x"}
	assert_true(Milestones.is_met(c, data(), {}, null, {"type": "sect_joined"}))
	assert_false(Milestones.is_met(c, data(), {}, null, {"type": "married"}))
	c.spouses.append("npc_1")
	assert_true(Milestones.is_met(c, data(), {}, null, {"type": "married"}))
	assert_false(Milestones.is_met(c, data(), {}, null, {"type": "clan_founded"}))
	assert_true(Milestones.is_met(c, data(), {}, ClanData.new(), {"type": "clan_founded"}))
	assert_false(Milestones.is_met(c, data(), {}, null, {"type": "item_crafted", "min": 1}))
	LifeStats.add(c, "items_crafted")
	assert_true(Milestones.is_met(c, data(), {}, null, {"type": "item_crafted", "min": 1}))


func test_milestone_fires_once_and_saves() -> void:
	var c := new_character()
	LifeStats.add(c, "fights_won")
	var first := Milestones.award(c, data(), {})
	assert_true(first.any(func(d): return d["id"] == "first_fight"))
	assert_eq(Milestones.award(c, data(), {}).size(), 0)
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_true(loaded.milestones.has("first_fight"))
	assert_eq(Milestones.newly_reached(loaded, data(), {}).size(), 0)


func test_old_save_without_milestones_loads() -> void:
	var d := new_character().to_dict()
	d.erase("milestones")
	assert_eq(CharacterData.from_dict(d).milestones.size(), 0)


# --- MS-002: progress ---------------------------------------------------------

func test_progress_counts_stats_and_stages() -> void:
	var c := new_character()
	var crafted := Milestones.progress(c, data(), {}, null, "alchemist")
	for def in data().milestones:
		var p := Milestones.progress(c, data(), {}, null, String(def["id"]))
		assert_true(int(p["target"]) >= 1 and int(p["current"]) <= int(p["target"]), String(def["id"]))
	assert_eq(Milestones.progress(c, data(), {}, null, "no_such")["target"], 1)
	assert_true(crafted.has("current"))
	var check := {"type": "life_stat", "stat": "fights_won", "min": 25}
	var d := GameData.load_from_dir()
	d.milestones = [_milestone("a", check), _milestone("b", {"type": "item_crafted", "min": 5}), _milestone("c", {"type": "realm", "realm": "foundation_establishment", "stage": 2}), _milestone("d", {"type": "flag", "flag": "f"}), _milestone("e", {"type": "married"}), _milestone("f", {"type": "sect_joined"}), _milestone("g", {"type": "clan_founded"})]
	LifeStats.add(c, "fights_won", 4)
	LifeStats.add(c, "items_crafted", 7)
	assert_eq(Milestones.progress(c, d, {}, null, "a"), {"current": 4, "target": 25})
	assert_eq(Milestones.progress(c, d, {}, null, "b"), {"current": 5, "target": 5}, "capped at the target")
	assert_eq(Milestones.progress_text(c, d, {}, null, "a"), "4/25")
	assert_eq(Milestones.progress_text(c, d, {}, null, "d"), "", "yes/no checks have no count")
	var qr := data().realm_index_of("qi_refining")
	var fe := data().realm_index_of("foundation_establishment")
	c.realm_index = qr
	c.stage = 3
	var before: int = Milestones.progress(c, d, {}, null, "c")["current"]
	var target: int = Milestones.progress(c, d, {}, null, "c")["target"]
	assert_eq(before, Milestones.stage_total(data(), qr) + 3)
	assert_eq(target, Milestones.stage_total(data(), fe) + 2)
	c.realm_index = fe
	c.stage = 1
	assert_eq(Milestones.progress(c, d, {}, null, "c")["current"], target - 1)
	assert_eq(Milestones.progress(c, d, {"f": true}, null, "d"), {"current": 1, "target": 1})
	assert_eq(Milestones.progress(c, d, {}, null, "e"), {"current": 0, "target": 1})
	c.spouses.append("x")
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_eq(Milestones.progress(c, d, {}, ClanData.new(), "e")["current"], 1)
	assert_eq(Milestones.progress(c, d, {}, ClanData.new(), "f")["current"], 1)
	assert_eq(Milestones.progress(c, d, {}, ClanData.new(), "g")["current"], 1)
	c.milestones.append("a")
	assert_eq(Milestones.progress(c, d, {}, null, "a"), {"current": 25, "target": 25}, "earned shows full")


func test_flag_count_check_counts_matching_set_flags() -> void:
	var c := new_character()
	var check := {"type": "flag_count", "prefix": "errand_", "suffix": "_done", "min": 2}
	var flags := {"errand_lan_done": true, "errand_lan_asked": true, "errand_hei_done": false}
	assert_false(Milestones.is_met(c, data(), flags, null, check))
	flags["errand_hei_done"] = true
	assert_true(Milestones.is_met(c, data(), flags, null, check))


func test_ms003_milestones_are_earned_from_their_counters() -> void:
	var c := new_character()
	assert_eq(Milestones.newly_reached(c, data(), {}).size(), 0)
	LifeStats.add(c, "commissions_done")
	LifeStats.add(c, "realm_floors_cleared")
	LifeStats.add(c, "inheritances_claimed")
	var got := Milestones.newly_reached(c, data(), {"errand_mo_done": true})
	for id in ["trusted_artisan", "favor_repaid", "into_secret_realm", "heir_to_ancients"]:
		assert_true(got.has(id), "%s in %s" % [id, got])
	var p := Milestones.progress(c, data(), {}, null, "favor_repaid")
	assert_eq(int(p["current"]), 0)


func test_flag_count_needs_prefix_or_suffix() -> void:
	var d := GameData.load_from_dir()
	d.milestones.append(_milestone("bad_fc", {"type": "flag_count"}))
	d._validate_milestones()
	assert_true(", ".join(d.load_errors).contains("flag_count check needs"))


func test_log_complete_rejects_hunt_log() -> void:
	var d := GameData.load_from_dir()
	d.milestones.append(_milestone("bad_hunt", {"type": "log_complete", "log": "hunt_log"}))
	d._validate_milestones()
	assert_true(", ".join(d.load_errors).contains("log_complete cannot use hunt_log"))


func test_far_traveller_milestone_fires_at_five_regions() -> void:
	var c := CharacterData.new()
	var ids: Array = data().regions.keys()
	for i in 4:
		Exploration.visit(c, String(ids[i]))
	var before: Array = Milestones.newly_reached(c, data(), {})
	assert_false(before.has("far_traveller"))
	Exploration.visit(c, String(ids[4]))
	var after: Array = Milestones.newly_reached(c, data(), {})
	assert_true(after.has("far_traveller"))
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_eq(loaded.visited_regions, c.visited_regions)


func test_flag_count_ignores_text_flags() -> void:
	var flags := {"errand_a_done": true, "errand_b_done": "Old Wu", "errand_c_done": 0}
	assert_eq(Milestones.flag_count(flags, {"prefix": "errand_", "suffix": "_done"}), 1)


func test_c110_rival_bout_milestones() -> void:
	var c := new_character()
	LifeStats.add(c, "rival_bouts_won")
	var got := Milestones.newly_reached(c, data(), {})
	assert_true(got.has("crossed_hands"), str(got))
	assert_false(got.has("worthy_rival"), str(got))


func test_c130_renown_title_milestones() -> void:
	var c := new_character()
	LifeStats.add(c, "renown_titles")
	var got := Milestones.newly_reached(c, data(), {})
	assert_true(got.has("name_spoken"), str(got))
	assert_false(got.has("known_across_the_land"), str(got))
	LifeStats.add(c, "renown_titles", 3)
	assert_true(Milestones.newly_reached(c, data(), {}).has("known_across_the_land"))


func test_goal005_log_checks() -> void:
	var c := new_character()
	var fish := Fishing.catchable(data())
	var herbs := HerbLore.findable(data())
	assert_false(Milestones.newly_reached(c, data(), {}).has("first_catch"))
	c.catch_log[fish[0]] = 1
	assert_true(Milestones.newly_reached(c, data(), {}).has("first_catch"))
	assert_false(Milestones.newly_reached(c, data(), {}).has("angler"))
	for id in fish:
		c.catch_log[id] = 1
	assert_true(Milestones.newly_reached(c, data(), {}).has("angler"))
	for i in 4:
		c.herb_log[herbs[i]] = 3
	assert_false(Milestones.newly_reached(c, data(), {}).has("herb_gatherer"))
	c.herb_log[herbs[4]] = 1
	assert_true(Milestones.newly_reached(c, data(), {}).has("herb_gatherer"))
	assert_false(Milestones.newly_reached(c, data(), {}).has("herbalist"))
	for id in herbs:
		c.herb_log[id] = 1
	assert_true(Milestones.newly_reached(c, data(), {}).has("herbalist"))
	assert_eq(Milestones.progress(c, data(), {}, null, "angler")["target"], fish.size())


func test_goal005_trophy_and_green_thumb() -> void:
	var c := new_character()
	var d := data()
	var trophies := Fishing.trophy_items(d)
	assert_eq(trophies.size(), 5, "one trophy per fishing water: carp, eel, marsh, Azure, Myriad")
	assert_false(Milestones.newly_reached(c, d, {}).has("pond_legend"))
	c.catch_log[trophies[0]] = 1
	assert_true(Milestones.newly_reached(c, d, {}).has("pond_legend"))
	# A fresh copy: stripping the trophies from the shared data() would leak into later tests.
	var bare := GameData.load_from_dir()
	for rid: String in bare.regions.keys():
		var places: Array = bare.regions[rid].get("places", [])
		for pl: Dictionary in places:
			for e: Dictionary in pl.get("catch_table", []):
				e.erase("trophy")
	assert_false(Milestones.newly_reached(c, bare, {}).has("pond_legend"), "no trophy kinds, no milestone")
	LifeStats.add(c, "harvests", 9)
	assert_false(Milestones.newly_reached(c, data(), {}).has("green_thumb"))
	LifeStats.add(c, "harvests")
	assert_true(Milestones.newly_reached(c, data(), {}).has("green_thumb"))


func test_goal006_village_milestones() -> void:
	var c := new_character()
	var d := data()
	var got := func() -> Array[String]: return Milestones.newly_reached(c, d, {})
	assert_false(got.call().has("first_find"))
	LifeStats.add(c, "foraged")
	assert_true(got.call().has("first_find"))
	assert_false(got.call().has("forager"))
	LifeStats.add(c, "foraged", 48)
	assert_false(got.call().has("forager"), "49 is not 50")
	LifeStats.add(c, "foraged")
	assert_true(got.call().has("forager"))
	# Home Cook: every home meal once.
	for i in d.home_meals.size() - 1:
		c.cooked_meals[String(d.home_meals[i]["id"])] = 1
	assert_false(got.call().has("home_cook"))
	c.cooked_meals[String(d.home_meals[d.home_meals.size() - 1]["id"])] = 2
	assert_true(got.call().has("home_cook"))
	# Rain Angler: a fish that needs rain; an ordinary fish does not count.
	c.catch_log["silver_carp"] = 3
	assert_false(got.call().has("rain_angler"))
	c.catch_log["rain_loach"] = 1
	assert_true(got.call().has("rain_angler"))
	# Beast Hunter II: five different kinds.
	for id in ["wild_boar", "mist_fox", "den_wolf", "moss_back_ape"]:
		c.hunt_log[id] = 9
	assert_false(got.call().has("beast_hunter_ii"))
	c.hunt_log["mist_python"] = 1
	assert_true(got.call().has("beast_hunter_ii"))


func test_goal006_cooked_meals_recorded_and_saved() -> void:
	var c := new_character()
	var d := data()
	var m: Dictionary = d.home_meals[0]
	for item_id: String in m["ingredients"]:
		c.add_item(item_id, int(m["ingredients"][item_id]) * 2)
	assert_true(Cooking.cook(c, d, String(m["id"]))["ok"])
	assert_true(Cooking.cook(c, d, String(m["id"]))["ok"])
	assert_eq(int(c.cooked_meals[String(m["id"])]), 2)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.cooked_meals, c.cooked_meals)
	var old := c.to_dict()
	old.erase("cooked_meals")
	assert_eq(CharacterData.from_dict(old).cooked_meals.size(), 0, "old saves load")
