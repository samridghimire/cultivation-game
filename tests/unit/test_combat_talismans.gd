extends TestCase
## G-005b: combat talismans readied for fights (CombatTalismans, Combat.resolve).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _enemy(realm: String = "qi_refining", stage: int = 0, lethal: bool = false) -> Dictionary:
	return {"id": "test_foe", "name": "Test Foe", "realm": realm, "stage": stage, "lethal": lethal, "rewards": {}}


func test_readying_rules() -> void:
	var c := new_character()
	assert_true(CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman") != "", "none carried")
	assert_true(CombatTalismans.ready_talisman(c, data(), "golden_bell_talisman") != "", "a buff talisman is not a combat talisman")
	for item_id in ["fire_strike_talisman", "earth_wall_talisman", "thousand_li_escape_talisman", "golden_bell_talisman"]:
		c.add_item(item_id, 2)
	assert_eq(CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman"), "")
	assert_true(CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman") != "", "already readied")
	assert_eq(CombatTalismans.ready_talisman(c, data(), "earth_wall_talisman"), "")
	assert_eq(CombatTalismans.ready_talisman(c, data(), "thousand_li_escape_talisman"), "")
	assert_eq(c.readied_talismans.size(), CombatTalismans.MAX_READIED)
	assert_true(CombatTalismans.unready_talisman(c, "earth_wall_talisman"))
	assert_false(CombatTalismans.unready_talisman(c, "earth_wall_talisman"))
	assert_eq(CombatTalismans.available(c, data(), "strike"), ["fire_strike_talisman"] as Array[String])
	c.add_item("fire_strike_talisman", -2)
	assert_true(CombatTalismans.available(c, data(), "strike").is_empty(), "readied but none left")


func test_grade_scales_power() -> void:
	var power := float(CombatTalismans.combat_def(data(), "fire_strike_talisman")["power"])
	var grade := int(CombatTalismans.combat_def(data(), "fire_strike_talisman")["grade"])
	assert_eq(CombatTalismans.amount(data(), "fire_strike_talisman"), roundi(power * Combat.realm_power(grade - 1, 0)))


func test_strike_opens_the_fight_and_is_consumed() -> void:
	var c := new_character()
	c.realm_index = 1
	c.add_item("fire_strike_talisman", 2)
	CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman")
	var result := Combat.resolve(c, data(), _enemy(), seeded_rng())
	assert_eq(result["talismans_used"], ["fire_strike_talisman"] as Array[String])
	assert_true(String(result["log"][1]).contains("Fire Strike"), "the strike comes before the first exchange")
	assert_eq(c.item_count("fire_strike_talisman"), 2, "resolve is pure")
	var outcome := Combat.apply_outcome(c, data(), _enemy(), result, {}, seeded_rng())
	assert_eq(c.item_count("fire_strike_talisman"), 1)
	assert_true(String(outcome["notes"][0]).contains("Fire Strike"))


func test_strike_and_shield_raise_win_chance() -> void:
	var c := new_character()
	c.realm_index = 1
	var enemy := _enemy("qi_refining", 0)
	var without := Combat.win_chance(c, data(), enemy)
	c.add_item("fire_strike_talisman", 1)
	c.add_item("earth_wall_talisman", 1)
	CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman")
	CombatTalismans.ready_talisman(c, data(), "earth_wall_talisman")
	assert_gt(Combat.win_chance(c, data(), enemy), without)


func test_shield_absorbs_damage() -> void:
	var c := new_character()
	c.add_item("earth_wall_talisman", 1)
	CombatTalismans.ready_talisman(c, data(), "earth_wall_talisman")
	var result := Combat.resolve(c, data(), _enemy("mortal"), seeded_rng())
	var absorbed := false
	for line in result["log"]:
		if String(line).contains("barrier absorbs"):
			absorbed = true
	assert_true(absorbed)


func test_escape_turns_a_lethal_defeat_into_flight() -> void:
	var c := new_character()
	c.add_item("spirit_stone", 100)
	var stones := c.item_count("spirit_stone")
	var enemy := _enemy("foundation_establishment", 5, true)
	var plain := Combat.resolve(c, data(), enemy, seeded_rng())
	assert_false(plain["escaped"])
	assert_true(Combat.apply_outcome(c, data(), enemy, plain, {}, seeded_rng())["died"])
	c.add_item("thousand_li_escape_talisman", 1)
	CombatTalismans.ready_talisman(c, data(), "thousand_li_escape_talisman")
	var result := Combat.resolve(c, data(), enemy, seeded_rng())
	assert_true(result["escaped"])
	assert_false(result["victory"])
	var outcome := Combat.apply_outcome(c, data(), enemy, result, {}, seeded_rng())
	assert_false(outcome["died"])
	assert_eq(outcome["injury"], "")
	assert_eq(c.item_count("spirit_stone"), stones, "no stones lost while fleeing")
	assert_eq(c.item_count("thousand_li_escape_talisman"), 0)


func test_escape_is_kept_after_a_victory() -> void:
	var c := new_character()
	c.realm_index = 2
	c.add_item("thousand_li_escape_talisman", 1)
	CombatTalismans.ready_talisman(c, data(), "thousand_li_escape_talisman")
	var result := Combat.resolve(c, data(), _enemy("mortal"), seeded_rng())
	assert_true(result["victory"])
	Combat.apply_outcome(c, data(), _enemy("mortal"), result, {}, seeded_rng())
	assert_eq(c.item_count("thousand_li_escape_talisman"), 1)


func test_readied_talismans_round_trip_in_saves() -> void:
	var c := new_character()
	c.readied_talismans = ["fire_strike_talisman"] as Array[String]
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.readied_talismans, ["fire_strike_talisman"] as Array[String])
	assert_true(CharacterData.from_dict({}).readied_talismans.is_empty(), "old saves")


func test_game_state_ready_and_fight() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Inscriber", gs.data, seeded_rng())
	gs.start_session(c)
	gs.ready_talisman("fire_strike_talisman")
	assert_true(c.readied_talismans.is_empty(), "none carried: refused")
	c.add_item("fire_strike_talisman", 1)
	gs.ready_talisman("fire_strike_talisman")
	assert_eq(c.readied_talismans, ["fire_strike_talisman"] as Array[String])
	gs.fight_enemy(_enemy("mortal"))
	assert_eq(c.item_count("fire_strike_talisman"), 0, "burned in the fight")
	gs.unready_talisman("fire_strike_talisman")
	assert_true(c.readied_talismans.is_empty())
	gs.end_session()
