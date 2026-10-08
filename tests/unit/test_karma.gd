extends TestCase
## RIV-001: grudges, gratitude and hostile acts (data/karma.json, Karma).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(id: String, age: int = 25) -> CharacterData:
	var c := new_character()
	c.id = id
	c.name = id
	c.age_days = age * Calendar.DAYS_PER_YEAR
	return c


## A victim with a living father and a dead mother, in a people dictionary.
func _family() -> Dictionary:
	var victim := _person("victim")
	var father := _person("father", 50)
	var mother := _person("mother", 48)
	mother.alive = false
	victim.parents.assign(["father", "mother"])
	father.children.append("victim")
	return {"victim": victim, "father": father, "mother": mother}


func test_ledgers_cap_and_drop_zero() -> void:
	var c := _person("player")
	assert_eq(Karma.add_grudge(c, data(), "a", 70), 70)
	assert_eq(Karma.add_grudge(c, data(), "a", 70), int(data().karma["max_grudge"]))
	assert_eq(Karma.add_grudge(c, data(), "a", -500), 0)
	assert_false(c.grudges.has("a"), "a forgotten grudge leaves the ledger")
	assert_eq(Karma.add_gratitude(c, data(), "b", 20), 20)
	assert_eq(Karma.gratitude(c, "b"), 20)


func test_act_checks() -> void:
	var c := _person("player")
	var npc := _person("npc")
	assert_eq(Karma.check_act(c, npc, "rob", data()), "")
	assert_true(Karma.check_act(c, npc, "dance", data()) != "", "unknown act")
	assert_true(Karma.check_act(c, null, "rob", data()) != "", "missing npc")
	assert_true(Karma.check_act(c, _person("kid", 10), "rob", data()) != "", "children are off limits")
	assert_true(Karma.check_act(c, npc, "humiliate", data()) != "", "humiliating needs a higher realm")
	c.realm_index = 1
	assert_eq(Karma.check_act(c, npc, "humiliate", data()), "")
	c.spouses.append("npc")
	assert_true(Karma.check_act(c, npc, "kill", data()) != "", "not your own family")
	npc.alive = false
	c.spouses.clear()
	assert_true(Karma.check_act(c, npc, "kill", data()) != "", "already dead")


func test_rob_loots_and_spreads_grudge_to_living_kin() -> void:
	var c := _person("player")
	var people := _family()
	var victim: CharacterData = people["victim"]
	victim.realm_index = 1
	victim.add_item("spirit_stone", 4)
	var align_before := c.alignment
	var result := Karma.commit(c, victim, "rob", true, people, data(), seeded_rng())
	var rob := Karma.act(data(), "rob")
	assert_eq(Karma.grudge(c, "victim"), int(rob["grudge"]))
	assert_eq(Karma.grudge(c, "father"), int(rob["kin_grudge"]))
	assert_eq(Karma.grudge(c, "mother"), 0, "the dead hold no grudges")
	assert_eq(result["kin"], ["father"])
	assert_eq(c.alignment, align_before + int(rob["alignment"]))
	assert_gt(c.item_count("spirit_stone"), int(rob["loot_stones"][0]) * 2 + 3, "realm-scaled stones plus their purse")
	assert_eq(victim.item_count("spirit_stone"), 0)
	assert_true(victim.alive)
	assert_eq(result["favor"], int(rob["favor"]))


func test_kill_and_failed_attack() -> void:
	var c := _person("player")
	var people := _family()
	var victim: CharacterData = people["victim"]
	Karma.add_grudge(c, data(), "victim", 10)
	Karma.commit(c, victim, "kill", true, people, data(), seeded_rng())
	assert_false(victim.alive)
	assert_false(c.grudges.has("victim"), "the dead are dropped from the ledger")
	assert_eq(Karma.grudge(c, "father"), int(Karma.act(data(), "kill")["kin_grudge"]))

	var other := _person("other")
	var result := Karma.commit(c, other, "kill", false, {"other": other}, data(), seeded_rng())
	assert_true(other.alive)
	assert_eq(Karma.grudge(c, "other"), int(Karma.act(data(), "kill")["failed_grudge"]))
	assert_eq(result["days"], 0)


func test_kin_who_are_your_family_hold_no_grudge() -> void:
	var c := _person("player")
	var people := _family()
	c.spouses.append("father")
	(people["father"] as CharacterData).spouses.append("player")
	var result := Karma.commit(c, people["victim"], "rob", true, people, data(), seeded_rng())
	assert_eq(Karma.grudge(c, "father"), 0)
	assert_true((result["kin"] as Array).is_empty())


func test_amends_and_decay() -> void:
	var c := _person("player")
	var npc := _person("npc")
	c.inventory.clear()
	assert_true(Karma.check_amends(c, npc, data()) != "", "no grudge")
	Karma.add_grudge(c, data(), "npc", 40)
	var cost := Karma.amends_cost(c, "npc", data())
	assert_eq(cost, maxi(int(data().karma["amends"]["min_cost"]), 40 * int(data().karma["amends"]["stones_per_point"])))
	assert_false(Karma.make_amends(c, npc, data())["ok"], "too poor")
	c.add_item("spirit_stone", cost)
	assert_true(Karma.make_amends(c, npc, data())["ok"])
	assert_eq(c.item_count("spirit_stone"), 0)
	assert_eq(Karma.grudge(c, "npc"), 0)

	Karma.add_grudge(c, data(), "npc", 12)
	var per_year := int(data().karma["decay_per_year"])
	assert_eq(Karma.decay_amount(data(), 10, 20), 0)
	assert_eq(Karma.decay_amount(data(), 0, Calendar.DAYS_PER_YEAR * 2), per_year * 2)
	Karma.decay(c, data(), per_year)
	assert_eq(Karma.grudge(c, "npc"), 12 - per_year)


func test_npc_enemy_and_describe() -> void:
	var npc := _person("npc")
	npc.realm_index = 1
	npc.stage = 2
	var enemy := Karma.npc_enemy(npc, data())
	assert_eq(enemy["realm"], data().realms[1].id)
	assert_eq(enemy["stage"], 2)
	assert_false(enemy["lethal"])
	var c := _person("player")
	Karma.add_grudge(c, data(), "npc", 30)
	Karma.add_gratitude(c, data(), "npc", 5)
	var lines := Karma.describe(c, {"npc": npc})
	assert_eq(lines.size(), 2)
	assert_true(lines[0].contains("npc") and lines[0].contains("30"))


# --- GameState integration ----------------------------------------------------

func _gs() -> Node:
	return _root().get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Karma", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


func _victim(gs: Node) -> CharacterData:
	var victim := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "realm": "mortal"})
	var father := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 55, "realm": "mortal"})
	victim.parents.append(father.id)
	father.children.append(victim.id)
	return victim


func test_game_state_humiliate_rob_kill_and_amends() -> void:
	var c := _start()
	var gs := _gs()
	var victim := _victim(gs)
	var father_id: String = victim.parents[0]
	gs.hostile_act(victim.id, "humiliate")
	assert_eq(Karma.grudge(c, victim.id), 0, "a mortal cannot humiliate a mortal")
	c.realm_index = 2  # far stronger, so the fights are certain
	gs.hostile_act(victim.id, "humiliate")
	assert_eq(Karma.grudge(c, victim.id), int(Karma.act(gs.data, "humiliate")["grudge"]))
	assert_eq(int(gs.npc_favor[victim.id]), int(Karma.act(gs.data, "humiliate")["favor"]))
	var stones := c.item_count("spirit_stone")
	gs.hostile_act(victim.id, "rob")
	assert_gt(c.item_count("spirit_stone"), stones)
	assert_gt(Karma.grudge(c, father_id), 0)
	c.add_item("spirit_stone", 1000)
	gs.make_amends(father_id)
	assert_eq(Karma.grudge(c, father_id), 0)
	gs.hostile_act(victim.id, "kill")
	assert_false(victim.alive)
	assert_gt(Karma.grudge(c, father_id), 0, "the father swears vengeance")

	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(Karma.grudge(restored, father_id), Karma.grudge(c, father_id), "grudges survive a save")


func test_game_state_losing_an_attack() -> void:
	var c := _start()
	var gs := _gs()
	var victim := _victim(gs)
	victim.realm_index = 3  # hopeless
	gs.hostile_act(victim.id, "rob")
	assert_true(c.alive, "losing to an NPC is not lethal")
	assert_true(victim.alive)
	assert_eq(Karma.grudge(c, victim.id), int(Karma.act(gs.data, "rob")["failed_grudge"]))


func test_grudges_fade_with_years() -> void:
	var c := _start()
	var gs := _gs()
	Karma.add_grudge(c, gs.data, "someone", 50)
	gs.work_profession("doctor", Calendar.DAYS_PER_YEAR)
	assert_eq(Karma.grudge(c, "someone"), 50 - int(gs.data.karma["decay_per_year"]))


# --- RIV-001e: gratitude sources and repayment --------------------------------

func test_kindness_earns_gratitude_and_favor_bonus() -> void:
	var c := _person("player")
	var rules: Dictionary = data().karma["gratitude"]
	assert_eq(Karma.on_kindness(c, data(), "npc", "treat_npc"), int(rules["sources"]["treat_npc"]))
	assert_eq(Karma.on_kindness(c, data(), "npc", "nonsense"), 0, "unknown sources give nothing")
	assert_eq(Karma.favor_bonus(c, data(), "stranger", 10, 99), 0, "no debt, no bonus")
	Karma.add_gratitude(c, data(), "npc", 100)
	var expected := int(10 * 100 * float(rules["favor_bonus_per_point"]))
	assert_gt(expected, 0)
	assert_eq(Karma.favor_bonus(c, data(), "npc", 10, 99), expected)
	assert_eq(Karma.favor_bonus(c, data(), "npc", 10, 1), 1, "capped by the room left")
	assert_eq(Karma.favor_bonus(c, data(), "npc", 10, -5), 0)
	assert_eq(Karma.on_kindness(c, data(), "npc", "treat_npc"), 0, "the ledger is capped")


func test_grateful_npcs_repay_their_debt() -> void:
	var c := _person("player")
	var npc := _person("npc")
	npc.realm_index = 1
	var dead := _person("dead")
	dead.alive = false
	var people := {"npc": npc, "dead": dead}
	var rules: Dictionary = data().karma["gratitude"]["repay"]
	Karma.add_gratitude(c, data(), "npc", int(rules["min_gratitude"]) - 1)
	Karma.add_gratitude(c, data(), "dead", 100)
	assert_eq(Karma.repay_debts(c, people, data(), 120, seeded_rng(), {}).size(), 0, "too small a debt, or dead")
	Karma.add_gratitude(c, data(), "npc", 1 + int(rules["cost"]))
	var owed := Karma.gratitude(c, "npc")
	var repaid := Karma.repay_debts(c, people, data(), 120, seeded_rng(), {})
	assert_eq(repaid.size(), 2, "repaid until the debt falls below the threshold")
	assert_eq(repaid[0]["npc_id"], "npc")
	assert_eq(Karma.gratitude(c, "npc"), owed - 2 * int(rules["cost"]))
	assert_true(c.item_count("spirit_stone") >= 2 * 2 * int(rules["stones_per_realm"][0]), "two repayments, stones x (realm index + 1)")


func test_gratitude_validation() -> void:
	var data := data()
	assert_eq(Karma.validate(data).size(), 0)
	var saved: Dictionary = data.karma["gratitude"]
	data.karma["gratitude"] = {"sources": {"x": -1}, "repay": {"cost": 0, "stones_per_realm": [5, 1], "gifts": [{"effects": {"items": {"nope": 1}}}]}}
	var errors := Karma.validate(data)
	data.karma["gratitude"] = saved
	assert_eq(errors.size(), 4, str(errors))


func test_game_state_treat_and_gift_earn_gratitude_that_is_repaid() -> void:
	var c := _start()
	var gs := _gs()
	var patient := _victim(gs)
	Injuries.inflict(patient, gs.data, "internal_injury")
	gs.treat_npc(patient.id)
	var rules: Dictionary = gs.data.karma["gratitude"]
	assert_eq(Karma.gratitude(c, patient.id), int(rules["sources"]["treat_npc"]))
	c.add_item("qi_gathering_pill", 1)
	gs.give_gift(patient.id, "qi_gathering_pill")
	assert_eq(Karma.gratitude(c, patient.id), int(rules["sources"]["treat_npc"]) + int(rules["sources"]["gift"]))
	Karma.add_gratitude(c, gs.data, patient.id, 100)
	var owed := Karma.gratitude(c, patient.id)
	gs.work_profession("doctor", 2 * Calendar.DAYS_PER_YEAR)
	assert_true(Karma.gratitude(c, patient.id) < owed, "a grateful NPC repays within two years")


func test_attitude_words_follow_ledger_tiers() -> void:
	var c := _person("player")
	var npc := _person("Lin")
	assert_eq(Karma.attitude(c, npc, data()).size(), 0, "no ledger, no words")
	Karma.add_grudge(c, data(), "Lin", 10)
	var words := Karma.attitude(c, npc, data())
	assert_eq(words.size(), 1)
	assert_true(words[0].contains("resentment"), words[0])
	assert_true(words[0].begins_with("Lin"), "name filled in: %s" % words[0])
	Karma.add_grudge(c, data(), "Lin", 80)
	assert_true(Karma.attitude(c, npc, data())[0].contains("sworn"), "top tier at 90")
	Karma.add_gratitude(c, data(), "Lin", 45)
	words = Karma.attitude(c, npc, data())
	assert_eq(words.size(), 2, "grudge and gratitude both shown")
	assert_true(words[1].contains("indebted"), words[1])


func test_attitude_tiers_validated() -> void:
	var d := GameData.new()
	d.karma = {"acts": {}, "attitudes": {"grudge": [[40, "a"], [10, "b"]]}}
	assert_eq(Karma.validate(d).size(), 1, "descending tiers rejected")
	d.karma["attitudes"] = {"grudge": [[1, "a"], [40, "b"]], "gratitude": [[5, ""]]}
	assert_eq(Karma.validate(d).size(), 1, "empty sentence rejected")
	assert_eq(Karma.validate(data()).size(), 0, "shipped data is valid")


func test_killing_a_pregnant_npc_ends_the_pregnancy() -> void:
	# QA-20261004-3: only old-age deaths used to clear an NPC's pregnancy.
	var c := _person("player")
	var people := _family()
	var victim: CharacterData = people["victim"]
	victim.pregnancy = {"partner": "father", "days_left": 120}
	var result := Karma.commit(c, victim, "kill", true, people, data(), seeded_rng())
	assert_false(victim.alive)
	assert_false(Children.is_pregnant(victim), "the dead do not stay pregnant")
	assert_true(", ".join(result["notes"]).contains("unborn child"), "the note mentions the lost child")


func test_grudge_words_and_ledger_wording() -> void:
	assert_eq(Karma.grudge_word(5, data()), "a slight")
	assert_eq(Karma.grudge_word(20, data()), "a bitter grudge")
	assert_eq(Karma.grudge_word(99, data()), "a blood feud")
	var c := _person("hero")
	c.grudges["gone_npc"] = 70
	var people := {"hero": c}
	var lines := Karma.describe(c, people, data())
	assert_true(lines[0].contains("someone long gone") and not lines[0].contains("gone_npc"), "never a raw id")
	assert_true(lines[0].contains("a blood feud"))
	var foe := _person("foe")
	people["foe"] = foe
	c.grudges["foe"] = 30
	lines = Karma.describe(c, people, data())
	assert_true(lines[1].contains("foe (a bitter grudge, 30)"), lines[1])


func test_act_sentences() -> void:
	var npc := _person("Li Wei")
	assert_eq(Karma.act_sentence(npc, "rob", {"stones": 5}), "You rob Li Wei of 5 spirit stones.")
	assert_eq(Karma.act_sentence(npc, "humiliate", {}), "You humiliate Li Wei before onlookers.")
	assert_eq(Karma.act_sentence(npc, "kill", {}), "You kill Li Wei.")
