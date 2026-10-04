extends TestCase
## FAM-006: clan estate buildings (data/clan_buildings.json, ClanEstate).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _head() -> CharacterData:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	return c


func _clan(treasury: int = 10000) -> ClanData:
	var clan := ClanData.new()
	clan.name = "Lin Clan"
	clan.head = "player"
	clan.treasury = treasury
	return clan


func test_data_is_valid() -> void:
	assert_eq(ClanEstate.validate(data()).size(), 0, str(ClanEstate.validate(data())))
	for id in ["ancestral_hall", "spirit_field", "alchemy_room", "protective_array", "library"]:
		assert_true(ClanEstate.building_ids(data()).has(id), id)
		assert_gt(ClanEstate.max_level(data(), id), 0)


func test_build_rules() -> void:
	var c := _head()
	assert_true(ClanEstate.check_build(c, null, "library", data()).contains("no clan"))
	var clan := _clan(0)
	assert_true(ClanEstate.check_build(c, clan, "moon_palace", data()).contains("no such"))
	assert_true(ClanEstate.check_build(c, clan, "library", data()).contains("treasury"))
	clan.treasury = 10000
	assert_eq(ClanEstate.check_build(c, clan, "library", data()), "")
	clan.buildings["library"] = 2
	assert_true(ClanEstate.check_build(c, clan, "library", data()).contains("Core Formation"), "level 3 needs a Core Formation head")
	c.realm_index = data().realm_index_of("core_formation")
	assert_eq(ClanEstate.check_build(c, clan, "library", data()), "")
	clan.buildings["library"] = ClanEstate.max_level(data(), "library")
	assert_true(ClanEstate.check_build(c, clan, "library", data()).contains("further"))


func test_construction_takes_time_and_one_project_at_a_time() -> void:
	var c := _head()
	var clan := _clan(2000)
	var def := ClanEstate.level_def(data(), "alchemy_room", 1)
	var result := ClanEstate.start_build(c, clan, "alchemy_room", data())
	assert_true(result["ok"], str(result["reason"]))
	assert_eq(clan.treasury, 2000 - int(def["cost"]), "paid from the treasury")
	assert_eq(ClanEstate.level(clan, "alchemy_room"), 0, "not built yet")
	assert_true(ClanEstate.check_build(c, clan, "library", data()).contains("still at work"))
	assert_eq(ClanEstate.advance_construction(clan, int(def["build_days"]) - 1), {})
	var done := ClanEstate.advance_construction(clan, 1)
	assert_eq(done, {"building": "alchemy_room", "level": 1})
	assert_eq(ClanEstate.level(clan, "alchemy_room"), 1)
	assert_true(clan.construction.is_empty())
	assert_eq(ClanEstate.check_build(c, clan, "alchemy_room", data()), "", "can upgrade next")


func test_monthly_effects() -> void:
	var c := _head()
	var clan := _clan(0)
	assert_eq(ClanEstate.qi_multiplier(clan, data()), 1.0)
	assert_eq(ClanEstate.training_multiplier(null, data()), 1.0)
	clan.buildings = {"alchemy_room": 1, "ancestral_hall": 2, "spirit_field": 2, "protective_array": 1, "library": 1}
	var income := int(ClanEstate.level_def(data(), "alchemy_room", 1)["effects"]["income"])
	var reputation := int(ClanEstate.level_def(data(), "ancestral_hall", 2)["effects"]["reputation"])
	var result := ClanEstate.apply_months(clan, c, data(), 3)
	assert_eq(clan.treasury, income * 3)
	assert_eq(clan.reputation, reputation * 3)
	assert_eq(result["income"], income * 3)
	assert_eq(c.item_count("dew_grass"), 12, "spirit field level 2 harvests 4 a month")
	assert_eq(c.item_count("qi_condensing_grass"), 6)
	assert_almost_eq(ClanEstate.qi_multiplier(clan, data()), 1.1)
	assert_almost_eq(ClanEstate.training_multiplier(clan, data()), 1.2, 0.0001, "library 0.15 + ancestral hall 0.05")
	assert_eq(ClanEstate.apply_months(clan, c, data(), 0)["income"], 0)
	assert_gt(ClanEstate.describe_effects(data(), "spirit_field", 2).size(), 1)


func test_library_speeds_up_training() -> void:
	var c := _head()
	c.inventory = {"spirit_stone": 1000}
	var xp := []
	for speed in [1.0, 2.0]:
		var child := new_character(7)
		child.id = "gen_child"
		child.age_days = 12 * Calendar.DAYS_PER_YEAR
		child.training = {"assignment": "profession", "profession": "alchemist"}
		c.children.clear()
		c.children.append(child.id)
		Training.advance(c, {child.id: child}, data(), 1, speed)
		xp.append(float(child.professions.get("alchemist", {}).get("xp", 0.0)))
	assert_gt(xp[0], 0.0)
	assert_almost_eq(xp[1], xp[0] * 2.0, 0.01, "double speed trains twice the days")


func test_save_round_trip() -> void:
	var clan := _clan(5)
	clan.buildings = {"library": 2}
	clan.construction = {"building": "spirit_field", "level": 1, "days_left": 12}
	var copy := ClanData.from_dict(JSON.parse_string(JSON.stringify(clan.to_dict())))
	assert_eq(copy.buildings, {"library": 2})
	assert_eq(copy.construction, {"building": "spirit_field", "level": 1, "days_left": 12})
	var old := ClanData.from_dict({"name": "Old Clan", "head": "player"})
	assert_true(old.buildings.is_empty(), "old saves have no buildings")
	assert_true(old.construction.is_empty())


func test_game_state_estate() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	gs.build_clan_building("alchemy_room")  # no clan: just a warning
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.inventory["spirit_stone"] = 5000
	c.abode = "waterfall_cave"  # a clan needs a seat (FAM-005c)
	gs.found_clan()
	gs.deposit_to_clan(1000)
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.build_clan_building("alchemy_room")
	assert_eq(clock.total_days, days, "giving the order takes no time")
	assert_eq(gs.clan.construction.get("building", ""), "alchemy_room")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.clan.construction.get("building", ""), "alchemy_room", "construction survives a save")
	var treasury: int = gs.clan.treasury
	clock.advance(120)
	assert_eq(ClanEstate.level(gs.clan, "alchemy_room"), 1, "built after its build days")
	assert_gt(gs.clan.treasury, treasury, "the alchemy room earns income")
	gs.end_session()


## FAM-006c: the protective array's qi bonus applies only at the clan seat,
## and its ward thins hostile encounters and ambushes in the seat's region.
func test_seat_bound_qi_and_ward() -> void:
	var d := data()
	var clan := ClanData.new()
	clan.seat = "waterfall_cave"
	clan.seat_region = String(d.abodes["waterfall_cave"]["region"])
	clan.buildings["protective_array"] = 2
	assert_gt(ClanEstate.seat_qi_multiplier(clan, d, "waterfall_cave"), 1.0)
	assert_eq(ClanEstate.seat_qi_multiplier(clan, d, "cloud_grotto"), 1.0, "only at the seat")
	assert_almost_eq(ClanEstate.ward(clan, d, clan.seat_region), 0.45)
	assert_eq(ClanEstate.ward(clan, d, "azure_peak"), 0.0, "only around the seat")
	assert_true(Array(ClanEstate.describe_effects(d, "protective_array", 2)).any(func(l: String) -> bool: return l.contains("hostile encounters")))
	var c := new_character()
	c.realm_index = 1
	var plain := Exploration.eligible_encounters(c, d, ["forest", "wild"], {})
	var warded := Exploration.eligible_encounters(c, d, ["forest", "wild"], {}, null, 1.0 - ClanEstate.ward(clan, d, clan.seat_region))
	var misfortune := func(pool: Array) -> float:
		var sum := 0.0
		for entry: Dictionary in pool:
			if entry["encounter"].get("kind", "") == "misfortune":
				sum += float(entry["weight"])
		return sum
	assert_almost_eq(misfortune.call(warded), misfortune.call(plain) * 0.55, 0.01)
	clan.buildings["protective_array"] = 99
	assert_true(ClanEstate.ward(clan, d, clan.seat_region) <= ClanEstate.MAX_WARD)
