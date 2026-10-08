extends TestCase
## PROF-001: crafting commissions.


func _alchemist() -> CharacterData:
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	return c


func test_roll_needs_a_profession_and_respects_the_cap() -> void:
	var rng := seeded_rng()
	assert_eq(Commissions.roll(new_character(), data(), rng, 0).size(), 0)
	var c := _alchemist()
	assert_eq(Commissions.roll(c, data(), rng, 100).size(), 1)
	assert_eq(Commissions.roll(c, data(), rng, 100).size(), 0, "one open order per profession")
	assert_eq(c.commissions.size(), 1)
	assert_eq(int(c.commissions[0]["due_day"]), 100 + int(data().commissions["days"]))


func test_reward_and_xp() -> void:
	var c := _alchemist()
	var order := Commissions.roll(c, data(), seeded_rng(7), 0)[0]
	var recipe: Dictionary = data().recipes[order["recipe"]]
	var count := int(order["count"])
	assert_true(count >= 1 and count <= 3)
	assert_eq(int(order["reward"]), maxi(1, ceili(Items.material_value(data(), order["item"]) * count * 2.0)))
	assert_eq(float(order["xp"]), float(recipe["xp"]) * 0.5 * count)


func test_deliver() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var order: Dictionary = c.commissions[0]
	assert_true(Commissions.check_deliver(c, data(), 0).begins_with("You need"))
	assert_eq(Commissions.check_deliver(c, data(), 5), "No such order.")
	assert_false(Commissions.deliver(c, data(), 0)["ok"])
	c.add_item(order["item"], int(order["count"]) + 1)
	var stones := c.item_count("spirit_stone")
	var result := Commissions.deliver(c, data(), 0)
	assert_true(result["ok"])
	assert_eq(c.item_count("spirit_stone"), stones + int(order["reward"]))
	assert_eq(c.item_count(order["item"]), 1)
	assert_eq(c.commissions.size(), 0)
	assert_gt(Professions.xp_of(c, "alchemist") + Professions.rank_of(c, "alchemist"), 0.0)
	assert_eq(LifeStats.get_stat(c, "commissions_done"), 1)


func test_expire_only_past_due() -> void:
	var c := _alchemist()
	c.commissions.append({"profession": "alchemist", "recipe": "qi_gathering_pill", "item": "qi_gathering_pill", "count": 1, "reward": 5, "xp": 1.0, "due_day": 10})
	c.commissions.append({"profession": "alchemist", "recipe": "qi_gathering_pill", "item": "qi_gathering_pill", "count": 1, "reward": 5, "xp": 1.0, "due_day": 20})
	assert_eq(Commissions.expire(c, 10).size(), 0)
	assert_eq(Commissions.expire(c, 11).size(), 1)
	assert_eq(c.commissions.size(), 1)
	assert_eq(int(c.commissions[0]["due_day"]), 20)


func test_describe_and_journal() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var text := Commissions.describe(c, data(), c.commissions[0], 0)
	assert_true(text.contains("spirit stones") and text.contains("alchemist xp") and text.contains("60 days left"), text)
	var rows := Guidance.journal(c, data(), {}, 0, c.home_region)
	var found := false
	for row in rows:
		if row["section"] == "Commissions":
			found = true
			assert_eq(row["tone"], "normal")
	assert_true(found)
	assert_eq(Guidance.journal(c, data(), {}, 55, c.home_region).filter(func(r: Dictionary) -> bool: return r["section"] == "Commissions")[0]["tone"], "warning")


func test_save_round_trip() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.commissions, c.commissions)
	var d := c.to_dict()
	d.erase("commissions")
	assert_eq(CharacterData.from_dict(d).commissions.size(), 0)


func test_validation_rejects_bad_values() -> void:
	var g := GameData.load_from_dir()
	g.load_errors.clear()
	g.commissions["reward_mult"] = 0.5
	g._validate_commissions()
	assert_eq(g.load_errors.size(), 1)
