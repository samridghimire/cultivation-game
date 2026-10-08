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
	assert_eq(int(order["reward"]), maxi(1, ceili(Commissions.unit_reward(data(), order["item"]) * count)))
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


## Review of PROF-001: an order for an item shops sell must not pay more than
## buying it costs (e.g. Jade Marrow Pills sold for 600 paid 1100 each).
func test_shop_bought_items_never_profit() -> void:
	for recipe: Dictionary in data().recipes.values():
		var item_id := String(recipe["output"]["item"])
		var price := int(data().items.get(item_id, {}).get("price", 0))
		var reward := Commissions.unit_reward(data(), item_id)
		if price > 0:
			assert_true(reward < price, "%s: reward %.0f vs shop price %d" % [item_id, reward, price])


func test_validation_rejects_bad_price_fraction() -> void:
	var g := GameData.load_from_dir()
	g.load_errors.clear()
	g.commissions["max_price_fraction"] = 1.5
	g._validate_commissions()
	assert_eq(g.load_errors.size(), 1)


func test_short_label_fits_and_has_no_doubled_count() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var order: Dictionary = c.commissions[0]
	var label := Commissions.short_label(c, data(), order, 0)
	assert_true(label.begins_with("Deliver %d " % int(order["count"])), label)
	assert_true(label.contains("(have 0/%d)" % int(order["count"])), label)
	assert_false(label.contains("you have"), label)
	var longest_id := ""
	for recipe: Dictionary in data().recipes.values():
		var item_id := String(recipe["output"]["item"])
		if longest_id == "" or String(data().items[item_id]["name"]).length() > String(data().items[longest_id]["name"]).length():
			longest_id = item_id
	var worst := {"item": longest_id, "count": 3, "reward": 99, "xp": 99, "due_day": 60}
	var worst_label := Commissions.short_label(c, data(), worst, 0)
	assert_true(worst_label.length() <= 60, "%d: %s" % [worst_label.length(), worst_label])
