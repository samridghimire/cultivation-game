extends TestCase
## STAT-002: spirit stones earned and qi gathered in the life record.


func _earned(c: CharacterData) -> int:
	return LifeStats.get_stat(c, "stones_earned")


func test_record_stones_ignores_non_positive() -> void:
	var c := new_character()
	LifeStats.record_stones(c, 0)
	LifeStats.record_stones(c, -5)
	assert_eq(_earned(c), 0)
	LifeStats.record_stones(c, 7)
	assert_eq(_earned(c), 7)


func test_profession_work_counts() -> void:
	var c := new_character()
	c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	var result := Professions.work(c, data(), "blacksmith", Calendar.DAYS_PER_MONTH)
	assert_gt(int(result["income"]), 0)
	assert_eq(_earned(c), int(result["income"]))


func test_commission_delivery_counts() -> void:
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	Commissions.roll(c, data(), seeded_rng(), 0)
	var order: Dictionary = c.commissions[0]
	c.add_item(order["item"], int(order["count"]))
	assert_true(Commissions.deliver(c, data(), 0)["ok"])
	assert_eq(_earned(c), int(order["reward"]))


func test_selling_counts_each_time_and_buying_does_not() -> void:
	var c := new_character()
	c.add_item("cold_iron", 4)
	var first := Items.sell(c, data(), "cold_iron", 2)
	assert_true(first["ok"])
	assert_eq(_earned(c), int(first["stones"]))
	var second := Items.sell(c, data(), "cold_iron", 2)
	assert_eq(_earned(c), int(first["stones"]) + int(second["stones"]))
	var before := _earned(c)
	c.add_item("spirit_stone", 500)
	assert_true(Items.buy(c, data(), "cold_iron", 1)["ok"])
	assert_eq(_earned(c), before, "spending stones earns nothing")


func test_sect_stipend_counts() -> void:
	var d := GameData.load_from_dir()
	for sect: SectDef in d.sects.values():
		for rank: Dictionary in sect.ranks:
			rank.erase("trial")
	var c := CharacterFactory.create("Disciple", d, seeded_rng())
	c.alignment = -300
	assert_true(Sects.join(c, d, "blood_lotus_sect")["ok"])
	Sects.add_contribution(c, d, 400)
	Sects.month_end(c, d)
	var before := _earned(c)
	Sects.add_contribution(c, d, Sects.monthly_duty(c, d))
	var result := Sects.month_end(c, d)
	assert_true(result["paid"])
	assert_eq(_earned(c), before + int(result["stones"]))
	assert_gt(int(result["stones"]), 0)


func test_karma_repayment_counts() -> void:
	var c := new_character()
	var npc := new_character()
	npc.realm_index = 1
	var rules: Dictionary = data().karma["gratitude"]["repay"]
	Karma.add_gratitude(c, data(), "npc", 100)
	var stones := c.item_count("spirit_stone")
	Karma.repay_debts(c, {"npc": npc}, data(), 120, seeded_rng(), {})
	var gained := c.item_count("spirit_stone") - stones
	assert_gt(gained, 0)
	assert_true(_earned(c) > 0 and _earned(c) <= gained, "stones only (gifts are items)")
	assert_gt(int(rules["cost"]), 0)


func test_effect_stone_grants_count_but_other_items_do_not() -> void:
	var c := new_character()
	Effects.apply(c, data(), {"items": {"spirit_stone": 12, "cold_iron": 3}}, {})
	assert_eq(_earned(c), 12)
	Effects.apply(c, data(), {"items": {"spirit_stone": -5}}, {})
	assert_eq(_earned(c), 12, "paying stones is not income")


func test_qi_gathered_from_cultivation_and_effects() -> void:
	var c := new_character()
	var result := Cultivation.cultivate(c, data(), 10)
	assert_eq(LifeStats.get_stat(c, "qi_gathered"), int(result["qi_gained"]))
	var before := LifeStats.get_stat(c, "qi_gathered")
	Effects.apply(c, data(), {"qi": 5}, {})
	assert_gt(LifeStats.get_stat(c, "qi_gathered"), before)


func test_summary_and_epilogue_lines() -> void:
	var c := new_character()
	var lines := LifeStats.year_summary({}, {"stones_earned": 1}, "", "")
	assert_eq(lines[0], "You earned 1 spirit stone.")
	assert_eq(LifeStats.year_summary({}, {"stones_earned": 30}, "", "")[0], "You earned 30 spirit stones.")
	assert_eq(LifeStats.year_summary({"stones_earned": 5}, {"stones_earned": 5}, "", "")[0], "A quiet year of cultivation.")
	LifeStats.record_stones(c, 42)
	assert_true(Array(LifeStats.epilogue(c, data())).has("Spirit stones earned: 42"))
