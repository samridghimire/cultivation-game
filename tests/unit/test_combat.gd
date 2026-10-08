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
	var hides := c.item_count("boar_hide")
	var enemy: Dictionary = data().enemies["wild_boar"]
	var outcome := Combat.apply_outcome(c, data(), enemy, {"victory": true, "draw": false}, {}, seeded_rng())
	assert_false(outcome["died"])
	assert_eq(c.item_count("boar_hide"), hides + int(enemy["rewards"]["items"]["boar_hide"]))


func test_nonlethal_defeat_costs_stones_and_injures() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 100}
	c.attributes["fortune"] = 10
	var outcome := Combat.apply_outcome(c, data(), data().enemies["mountain_bandit"], {"victory": false, "draw": false}, {}, seeded_rng())
	assert_false(outcome["died"])
	assert_eq(c.item_count("spirit_stone"), 80)
	assert_eq(outcome["days"], 1)
	assert_true(c.injuries.has(outcome["injury"]), "a non-lethal defeat at average fortune always injures")


func test_lethal_defeat_kills() -> void:
	var c := new_character()
	var outcome := Combat.apply_outcome(c, data(), data().enemies["mist_wolf"], {"victory": false, "draw": false}, {}, seeded_rng())
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


func test_realm_training_strengthens_enemies_and_repeats_last_entry() -> void:
	var d := data()
	assert_false(d.enemy_realm_training.is_empty())
	var last: Dictionary = d.enemy_realm_training[-1]
	assert_eq(Combat.realm_training(d, d.realms.size() - 1), last, "higher realms use the last entry")
	var enemy := {"name": "x", "realm": "foundation_establishment", "stage": 0, "techniques": []}
	var saved := d.enemy_realm_training
	d.enemy_realm_training = []
	var untrained := Combat.enemy_stats(enemy, d)
	d.enemy_realm_training = saved
	var trained := Combat.enemy_stats(enemy, d)
	assert_gt(trained["attack"], untrained["attack"])
	assert_gt(trained["max_hp"], untrained["max_hp"])


func test_form_roll_stays_in_spread() -> void:
	var d := data()
	var rng := seeded_rng()
	for i in 50:
		var form := Combat.roll_form(d, rng)
		assert_true(form >= 1.0 - d.combat_form_spread and form <= 1.0 + d.combat_form_spread)
	var saved := d.combat_form_spread
	d.combat_form_spread = 0.0
	assert_eq(Combat.roll_form(d, rng), 1.0)
	d.combat_form_spread = saved


func test_combat_tuning_is_validated() -> void:
	var d := data()
	var saved_spread := d.combat_form_spread
	var saved_training := d.enemy_realm_training
	d.load_errors = []
	d.combat_form_spread = 1.5
	d.enemy_realm_training = [{"luck": 3}, 4]
	d._validate_combat()
	var errors := d.load_errors.duplicate()
	d.combat_form_spread = saved_spread
	d.enemy_realm_training = saved_training
	d.load_errors = []
	d._validate_combat()
	assert_eq(errors.size() - d.load_errors.size(), 3, ", ".join(errors))


func test_fight_log_names_people_without_an_article() -> void:
	var c := new_character()
	var boar: Dictionary = data().enemies["wild_boar"]
	assert_eq(Combat.foe_name(boar), "the Wild Boar")
	var person := {"name": "Lin Feng", "proper_name": true, "realm": "mortal", "stage": 0}
	assert_eq(Combat.foe_name(person), "Lin Feng")
	var log: PackedStringArray = Combat.resolve(c, data(), person, seeded_rng())["log"]
	assert_true(log[0].begins_with("You face Lin Feng."), log[0])
	for line in log:
		assert_false(line.contains("the Lin Feng"), line)
	var npc := new_character(99)
	npc.name = "Xue Yao"
	assert_eq(Combat.foe_name(Karma.npc_enemy(npc, data())), "Xue Yao", "NPC foes are people")


func test_resolve_starts_at_given_hp() -> void:
	var c := new_character()
	var full := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng(3))
	var low := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng(3), [], 2)
	assert_true(String(low["log"][0]).contains("You: 2 hp"))
	assert_true(int(low["player_hp"]) <= 2)
	assert_eq(low["player_max_hp"], full["player_max_hp"])
	var over := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng(3), [], 99999)
	assert_true(String(over["log"][0]).contains("You: %d hp" % full["player_max_hp"]))


func _foe(realm: String, stage: int, hp: int, attack: int, defense: int) -> Dictionary:
	return {"id": "t", "name": "Test Foe", "realm": realm, "stage": stage, "hp": hp, "attack": attack, "defense": defense, "speed": 0, "techniques": [], "rewards": {}}


func test_loss_advice_branches() -> void:
	var c := new_character()
	var lost := {"victory": false, "draw": false, "escaped": false}
	var d := data()
	assert_true(Combat.loss_advice(c, d, _foe("foundation_establishment", 0, 0, 0, 0), lost).contains("far above you"), Combat.loss_advice(c, d, _foe("foundation", 0, 0, 0, 0), lost))
	var p := Combat.stats(c, d)
	var hard := _foe("mortal", 0, 0, p["max_hp"] * 4, 0)
	assert_true(Combat.loss_advice(c, d, hard, lost).contains("hits too hard"), Combat.loss_advice(c, d, hard, lost))
	var tank := _foe("mortal", 0, 100000, 0, 100000)
	assert_true(Combat.loss_advice(c, d, tank, lost).contains("barely scratch"), Combat.loss_advice(c, d, tank, lost))
	var even := _foe("mortal", 0, 0, 0, 0)
	assert_true(Combat.loss_advice(c, d, even, lost).contains("stronger fighter today"), Combat.loss_advice(c, d, even, lost))
	for r in [{"victory": true, "draw": false}, {"victory": false, "draw": true}, {"victory": false, "draw": false, "escaped": true}]:
		assert_eq(Combat.loss_advice(c, d, even, r), "")


func test_loss_advice_nudges_unreadied_talismans() -> void:
	var c := new_character()
	var lost := {"victory": false, "draw": false, "escaped": false}
	var even := _foe("mortal", 0, 0, 0, 0)
	c.inventory["fire_strike_talisman"] = 1
	assert_true(Combat.loss_advice(c, data(), even, lost).ends_with("Readied talismans can turn a fight."))
	CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman")
	assert_false(Combat.loss_advice(c, data(), even, lost).contains("talisman"))


func test_log_names_attack_techniques() -> void:
	var plain := new_character()
	var log_plain := "\n".join(Combat.resolve(plain, data(), data().enemies["mountain_bandit"], seeded_rng())["log"])
	assert_false(log_plain.contains(" with "))
	var c := new_character()
	assert_true(Techniques.learn(c, data(), "iron_fist")["ok"])
	var log_known := "\n".join(Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng())["log"])
	assert_true(log_known.contains("You strike with Iron Fist") or log_known.contains("You strike critically with Iron Fist"))


func test_enemy_techniques_named_in_log() -> void:
	var c := new_character()
	var lines: Array = Combat.resolve(c, data(), data().enemies["rogue_cultivator"], seeded_rng())["log"]
	assert_true("\n".join(lines).contains("attacks with Metal Edge Sword"))
	var plain: Array = Combat.resolve(c, data(), data().enemies["wild_boar"], seeded_rng())["log"]
	assert_true("\n".join(plain).contains("hits you"))


func test_trace_matches_log_and_final_hp() -> void:
	var c := new_character()
	var r := Combat.resolve(c, data(), data().enemies["mountain_bandit"], seeded_rng())
	assert_eq(r["trace"].size(), r["log"].size())
	var last: Array = r["trace"][r["trace"].size() - 1]
	assert_eq(last[0], r["player_hp"])
	assert_eq(last[1], r["enemy_hp"])

