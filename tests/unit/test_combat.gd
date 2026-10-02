extends TestCase


func test_all_enemies_and_techniques_load() -> void:
	assert_eq(data().load_errors.size(), 0, ", ".join(data().load_errors))
	assert_gt(data().enemies.size(), 0)
	assert_gt(data().techniques.size(), 0)


func test_higher_realm_means_stronger_stats() -> void:
	var c := new_character()
	var mortal := Combat.stats(c, data())
	c.realm_index = 1
	var refining := Combat.stats(c, data())
	assert_gt(refining["attack"], mortal["attack"])
	assert_gt(refining["max_hp"], mortal["max_hp"])


func test_resolve_does_not_mutate_character() -> void:
	var c := new_character()
	var before := c.to_dict()
	Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng())
	assert_eq(c.to_dict(), before)


func test_resolve_is_deterministic_for_a_seed() -> void:
	var c := new_character()
	var a := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng(7))
	var b := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng(7))
	assert_eq(a["log"], b["log"])
	assert_eq(a["victory"], b["victory"])


func test_mortal_cannot_beat_foundation_beast() -> void:
	var c := new_character()
	for i in 20:
		assert_false(Combat.resolve(c, data(), data().enemies["cloud_eagle"], seeded_rng(i))["victory"])
	assert_eq(Combat.danger_label(c, data(), data().enemies["cloud_eagle"]), "Deadly")


func test_qi_refining_cultivator_beats_wild_boar() -> void:
	var c := new_character()
	c.realm_index = 1
	for i in 20:
		assert_true(Combat.resolve(c, data(), data().enemies["wild_boar"], seeded_rng(i))["victory"])
	assert_eq(Combat.danger_label(c, data(), data().enemies["wild_boar"]), "Weak")


func test_mortal_vs_boar_is_winnable() -> void:
	var c := new_character()
	var wins := 0
	for i in 50:
		if Combat.resolve(c, data(), data().enemies["wild_boar"], seeded_rng(i))["victory"]:
			wins += 1
	assert_gt(wins, 25, "an ordinary mortal should usually beat a boar")


func test_victory_grants_rewards() -> void:
	var c := new_character()
	var stones := c.item_count("spirit_stone")
	var enemy: Dictionary = data().enemies["wild_boar"]
	var outcome := Combat.apply_outcome(c, data(), enemy, {"victory": true, "draw": false}, {})
	assert_false(outcome["died"])
	assert_eq(c.item_count("spirit_stone"), stones + int(enemy["rewards"]["items"]["spirit_stone"]))


func test_nonlethal_defeat_costs_stones_and_time() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 100}
	var outcome := Combat.apply_outcome(c, data(), data().enemies["mountain_bandit"], {"victory": false, "draw": false}, {})
	assert_false(outcome["died"])
	assert_eq(c.item_count("spirit_stone"), 80)
	assert_eq(outcome["days"], 1 + data().recovery_days)


func test_lethal_defeat_kills() -> void:
	var c := new_character()
	var outcome := Combat.apply_outcome(c, data(), data().enemies["mist_wolf"], {"victory": false, "draw": false}, {})
	assert_true(outcome["died"])
	assert_true(outcome["cause"].contains("Mist Wolf"))


func test_combat_techniques_raise_attack() -> void:
	var c := new_character()
	var base: int = Combat.stats(c, data())["attack"]
	assert_true(Techniques.learn(c, data(), "iron_fist")["ok"])
	assert_gt(Combat.stats(c, data())["attack"], base)


func test_danger_label_matches_win_chance() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = 8
	# A fight the player cannot win must never be rated better than Deadly.
	assert_eq(Combat.win_chance(c, data(), data().enemies["rogue_cultivator"]), 0.0)
	assert_eq(Combat.danger_label(c, data(), data().enemies["rogue_cultivator"]), "Deadly")


func test_win_chance_does_not_use_game_rng_or_mutate() -> void:
	var c := new_character()
	var before := c.to_dict()
	var a := Combat.win_chance(c, data(), data().enemies["mountain_bandit"])
	assert_eq(Combat.win_chance(c, data(), data().enemies["mountain_bandit"]), a)
	assert_eq(c.to_dict(), before)
