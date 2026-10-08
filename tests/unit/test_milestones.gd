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
