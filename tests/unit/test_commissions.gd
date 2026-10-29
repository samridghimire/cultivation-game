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


func test_roll_only_prof_skips_the_other_crafts() -> void:
	var c := _alchemist()
	c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	var added := Commissions.roll(c, data(), seeded_rng(), 0, "alchemist")
	assert_eq(added.size(), 1)
	assert_eq(String(added[0]["profession"]), "alchemist")


## PROF-009: with a region, orders prefer recipes whose ingredients are at hand.
func test_roll_prefers_recipes_with_nearby_ingredients() -> void:
	var d := GameData.load_from_dir()  # fresh: the test edits recipes
	d.items["far_herb"] = {"id": "far_herb", "name": "Far Herb", "tags": ["far_curio"], "price": 0}
	for rid: String in d.recipes.keys():
		if d.recipes[rid]["profession"] == "alchemist" and rid != "qi_gathering_pill":
			d.recipes.erase(rid)
	d.recipes["far_pill"] = {"id": "far_pill", "name": "Far Pill", "profession": "alchemist", "ingredients": {"far_herb": 2},
		"output": {"item": "qi_gathering_pill", "count": 1}, "min_rank": 0, "days": 3, "difficulty": 0.0, "xp": 10, "starter": true}
	var seen := {}
	for i in 20:
		var c := _alchemist()
		for order in Commissions.roll(c, d, seeded_rng(i + 1), 0, "", "qingshi_village"):
			assert_eq(String(order["recipe"]), "qi_gathering_pill")
	for i in 20:
		var c := _alchemist()
		for order in Commissions.roll(c, d, seeded_rng(i + 1), 0):
			seen[String(order["recipe"])] = true
	assert_true(seen.has("far_pill") and seen.has("qi_gathering_pill"), "no region: both appear")
	d.recipes.erase("qi_gathering_pill")
	var c2 := _alchemist()
	var added := Commissions.roll(c2, d, seeded_rng(), 0, "", "qingshi_village")
	assert_eq(added.size(), 1, "no recipe is near: an order is still rolled")
	assert_eq(String(added[0]["recipe"]), "far_pill")


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
	assert_eq(LifeStats.get_stat(c, "profession_stones"), int(order["reward"]))


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
	assert_true(worst_label.length() <= 64, "%d: %s" % [worst_label.length(), worst_label])
	for item: Dictionary in data().items.values():
		var item_name := String(item["name"])
		var cut := Commissions.short_label(c, data(), {"item": item["id"], "count": 1, "reward": 1, "xp": 1, "due_day": 1}, 0)
		if item_name.length() > Commissions.LABEL_NAME_MAX and cut.contains("…"):
			var prefix := cut.get_slice("…", 0).trim_prefix("Deliver 1 ")
			assert_true(item_name == prefix or item_name.begins_with(prefix + " "), "%s -> %s" % [item_name, cut])


## GUIDE-059: a two-unit order's label is pluralised before the word cut, so it still ends on a word.
func test_short_label_pluralises_before_the_cut() -> void:
	var c := _alchemist()
	var qgp := {"item": "qi_gathering_pill", "count": 2, "reward": 9, "xp": 9, "due_day": 9}
	var label := Commissions.short_label(c, data(), qgp, 0)
	assert_true(label.begins_with("Deliver 2 Qi Gathering…") or label.begins_with("Deliver 2 Qi Gathering Pills:"), label)
	for item: Dictionary in data().items.values():
		var cut := Commissions.short_label(c, data(), {"item": item["id"], "count": 2, "reward": 1, "xp": 1, "due_day": 1}, 0)
		if cut.contains("…"):
			var prefix := cut.get_slice("…", 0).trim_prefix("Deliver 2 ")
			var full := Items.item_plural(data(), String(item["id"]), 2)
			assert_true(full == prefix or full.begins_with(prefix + " "), "%s -> %s" % [full, cut])


func test_delivery_hint_needs_the_items() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var order: Dictionary = c.commissions[0]
	assert_eq(Commissions.delivery_hint(c, data(), 0), "")
	assert_eq(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 0).size(), Guidance.hints(c, data(), 1.0, 99).size())
	c.add_item(order["item"], int(order["count"]))
	var hint := Commissions.delivery_hint(c, data(), 0)
	assert_true(hint.begins_with("Deliver your"), hint)
	assert_true(hint.contains("%d days left" % int(data().commissions["days"])))
	assert_true(Array(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 0)).has(hint))


func test_lapse_warning_posts_once_across_the_seventh_day() -> void:
	var c := _alchemist()
	Commissions.roll(c, data(), seeded_rng(), 0)
	var due := int(c.commissions[0]["due_day"])
	var posted := 0
	for day in range(due - 9, due - 4):
		posted += Commissions.lapse_warnings(c, data(), day, day + 1).size()
	assert_eq(posted, 1)
	assert_eq(Commissions.lapse_warnings(c, data(), due - 8, due - 7).size(), 1)
	assert_eq(Commissions.lapse_warnings(c, data(), due - 7, due - 6).size(), 0)
	assert_eq(Commissions.lapse_warnings(c, data(), due - 20, due + 5).size(), 0, "already lapsed")


func _pill_order(count: int, due: int, with_recipe: bool = true) -> Dictionary:
	var order := {"profession": "alchemist", "item": "qi_gathering_pill", "count": count, "reward": 10, "xp": 5.0, "due_day": due}
	if with_recipe:
		order["recipe"] = "qi_gathering_pill"
	return order


func test_missing_line_names_the_first_short_ingredient_and_where() -> void:
	var c := _alchemist()
	var order := _pill_order(2, 100)
	var line := Commissions.missing_line(c, data(), order, "qingshi_village", 10)
	assert_true(line.begins_with("Needs Spirit Herb: "), line)
	assert_true(line.contains("grows at"), line)
	var old := Commissions.missing_line(c, data(), _pill_order(2, 100, false), "qingshi_village", 10)
	assert_eq(old, line, "an old entry without a recipe key still works")


func test_missing_line_ingredients_in_pack_and_fulfilled() -> void:
	var c := _alchemist()
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	assert_eq(Commissions.missing_line(c, data(), _pill_order(2, 100), "qingshi_village", 10), "You have the ingredients: craft it at a workshop.")
	var d := _alchemist()
	d.add_item("qi_gathering_pill", 2)
	assert_eq(Commissions.missing_line(d, data(), _pill_order(2, 100), "qingshi_village", 10), "")


func test_due_soon_hint_skips_an_order_the_pack_already_fills() -> void:
	var c := _alchemist()
	c.add_item("qi_gathering_pill", 2)
	var filled := _pill_order(2, 15)
	var short := {"profession": "alchemist", "recipe": "bone_setting_salve", "item": "bone_setting_salve", "count": 2, "reward": 10, "xp": 5.0, "due_day": 25}
	c.commissions = [filled, short]
	var hint := Commissions.due_soon_hint(c, data(), "qingshi_village", 12)
	assert_true(hint.begins_with("Order due in "), hint)
	assert_true(hint.contains("Needs Morning Dew Grass"), hint)


## WU-218: the journal row ends the order's "(you have N)" with a full stop before the missing line.
func test_journal_row_separates_the_missing_line() -> void:
	var c := _alchemist()
	c.commissions.append(_pill_order(2, 100))
	var rows := Guidance.journal(c, data(), {}, 20, "qingshi_village").filter(func(r: Dictionary) -> bool: return r["section"] == "Commissions")
	assert_true(String(rows[0]["text"]).contains("(you have 0). Needs "), rows[0]["text"])


func test_due_soon_hint_only_within_two_weeks() -> void:
	var c := _alchemist()
	c.commissions = [_pill_order(2, 30)]
	assert_eq(Commissions.due_soon_hint(c, data(), "qingshi_village", 10), "", "20 days left")
	var hint := Commissions.due_soon_hint(c, data(), "qingshi_village", 20)
	assert_true(hint.begins_with("Order due in "), hint)
	assert_true(hint.contains("Needs Spirit Herb"), hint)
	assert_true(Guidance.hints(c, data(), 1.0, 8, {}, {}, "qingshi_village", 20).has(hint))
	var journal := Guidance.journal(c, data(), {}, 20, "qingshi_village")
	var found := false
	for r in journal:
		if r["section"] == "Commissions" and String(r["text"]).contains("Needs Spirit Herb"):
			found = true
	assert_true(found)


func test_available_nearby_counts_only_merchants_one_route_away() -> void:
	var d := GameData.load_from_dir()
	d.items["rare_curio"] = {"id": "rare_curio", "name": "Rare Curio", "tags": ["rare_curio"], "price": 1}
	d.regions["home"] = {"routes": [{"to": "next", "days": 1}], "places": []}
	d.regions["next"] = {"routes": [], "places": []}
	d.regions["far"] = {"routes": [], "places": [{"type": "merchant", "stock_tags": ["rare_curio"], "max_price": 10}]}
	var c := _alchemist()
	assert_false(Guidance.available_nearby(c, d, "rare_curio", "home"), "sold only in a far region")
	assert_true(Guidance.available_nearby(c, d, "rare_curio", "far"), "from the merchant's own region")
	assert_true(Guidance.available_nearby(c, d, "rare_curio", ""), "no region: any region counts")
	d.regions["next"]["places"] = d.regions["far"]["places"]
	assert_true(Guidance.available_nearby(c, d, "rare_curio", "home"), "a merchant one route away counts")


## PROF-012: an order's count fits the time it takes to gather it.
func test_gather_rate_follows_the_table_and_season() -> void:
	var c := new_character()
	var d := data()
	assert_true(Exploration.gather_rate(c, d, "spirit_herb", "qingshi_village", "spring") > Exploration.gather_rate(c, d, "spirit_herb", "qingshi_village", "winter"))
	var expected := 0.0
	for p: Dictionary in d.regions["qingshi_village"]["places"]:
		if String(p.get("type", "")) != "gather":
			continue
		var total := 0.0
		var iron := 0.0
		for e: Dictionary in p["gather_table"]:
			if not e.has("seasons"):
				total += float(e["weight"])
				if String(e["item"]) == "iron_essence":
					iron += float(e["weight"]) * (float(e["min"]) + float(e["max"])) / 2.0
		if iron > 0.0:
			expected = maxf(expected, float(Exploration.GATHER_ROLLS) * iron / total / float(p["gather_days"]))
	assert_true(expected > 0.0)
	assert_true(absf(Exploration.gather_rate(c, d, "iron_essence", "qingshi_village", "winter") - expected) < 0.0001)
	assert_eq(Exploration.gather_rate(c, d, "iron_sword", "qingshi_village"), 0.0)


func test_roll_caps_the_count_to_what_can_be_gathered() -> void:
	var d := GameData.load_from_dir()
	for rid: String in d.recipes.keys():
		if d.recipes[rid]["profession"] == "blacksmith" and rid != "iron_sword":
			d.recipes.erase(rid)
	var recipe: Dictionary = d.recipes["iron_sword"]
	var cap_c := new_character()
	cap_c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	var cap := Commissions.max_count(cap_c, d, recipe, "qingshi_village", 0, int(d.commissions["days"]))
	assert_true(cap >= 1, "cap %d" % cap)
	var hungry: Dictionary = recipe.duplicate(true)
	hungry["ingredients"] = {"iron_essence": 20}
	assert_true(Commissions.max_count(cap_c, d, hungry, "qingshi_village", 0, 60) < 3, "20 iron essence per sword cannot be gathered 3 times")
	assert_eq(Commissions.max_count(cap_c, d, recipe, "", 0, 60), 999)
	for i in 10:
		var c := new_character()
		c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
		var added := Commissions.roll(c, d, seeded_rng(i), 0, "blacksmith", "qingshi_village")
		var n := int(added[0]["count"])
		assert_true(n >= 1 and n <= cap, "count %d within cap %d" % [n, cap])
		assert_eq(int(added[0]["reward"]), maxi(1, ceili(Commissions.unit_reward(d, "iron_sword") * n)))


func test_pills_are_not_capped() -> void:
	var c := _alchemist()
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	assert_true(Commissions.max_count(c, data(), recipe, "qingshi_village", 0, int(data().commissions["days"])) >= 3)


## PROF-013: a lapsed order says what you were short of.
func test_lapse_text_names_the_short_ingredient() -> void:
	var c := _alchemist()
	var text := Commissions.lapse_text(c, data(), _pill_order(2, 100))
	assert_true(text.begins_with("The order for 2 "), text)
	assert_true(text.ends_with(" lapsed. You were short of %s." % Items.item_plural(data(), Commissions.short_ingredient(c, data(), _pill_order(2, 100)), 2)), text)
	assert_eq(Commissions.short_ingredient(c, data(), _pill_order(2, 100)), "spirit_herb")


func test_lapse_text_ingredients_held_but_not_crafted() -> void:
	var c := _alchemist()
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	assert_eq(Commissions.short_ingredient(c, data(), _pill_order(2, 100)), "")
	assert_true(Commissions.lapse_text(c, data(), _pill_order(2, 100)).ends_with(" lapsed. You had the ingredients but never crafted them."))


func test_lapse_text_plain_when_output_held() -> void:
	var c := _alchemist()
	c.add_item("qi_gathering_pill", 2)
	assert_true(Commissions.lapse_text(c, data(), _pill_order(2, 100)).ends_with(" lapsed."))


## PROF-014: the missing line estimates the gathering time when the ingredient can be gathered here.
func test_missing_line_estimates_gathering_time() -> void:
	var c := _alchemist()
	var line := Commissions.missing_line(c, data(), _pill_order(2, 100), "qingshi_village", 10)
	assert_true(line.contains(" of gathering)."), line)
	assert_true(line.contains("(about "), line)
	assert_false(line.contains("longer than the order has"), line)


func test_missing_line_flags_an_estimate_past_the_deadline() -> void:
	var c := _alchemist()
	var line := Commissions.missing_line(c, data(), _pill_order(2, 11), "qingshi_village", 10)
	assert_true(line.ends_with(" of gathering, longer than the order has)."), line)


func test_missing_line_has_no_estimate_for_bought_ingredients() -> void:
	var c := _alchemist()
	var line := Commissions.missing_line(c, data(), _pill_order(2, 100), "far_nowhere", 10)
	assert_false(line.contains("of gathering"), line)


func test_missing_line_stays_short_for_every_gatherable_ingredient() -> void:
	var d := data()
	var c := _alchemist()
	var longest := 0
	for rid: String in d.recipes:
		var recipe: Dictionary = d.recipes[rid]
		for id: String in recipe["ingredients"]:
			var order := {"profession": "x", "recipe": rid, "item": String(recipe["output"]["item"]), "count": 1, "reward": 1, "xp": 1.0, "due_day": 500}
			for region: String in d.regions:
				var line := Commissions.missing_line(c, d, order, region, 10)
				if line.contains("of gathering") and not line.contains("longer than"):
					longest = maxi(longest, line.length())
	assert_true(longest > 0 and longest <= 110, "longest gathering line is %d chars" % longest)


## PROF-015: gathered ingredients at one place share its days; at two places they add up.
func _fake_gather_data(second_place_for_b: bool) -> GameData:
	var d := GameData.load_from_dir()
	var table_a: Array = [{"item": "herb_a", "weight": 1, "min": 1, "max": 1}]
	var table_b: Array = [{"item": "herb_b", "weight": 1, "min": 1, "max": 1}]
	var places: Array = []
	if second_place_for_b:
		places = [
			{"id": "p1", "type": "gather", "gather_days": 1, "gather_table": table_a},
			{"id": "p2", "type": "gather", "gather_days": 1, "gather_table": table_b},
		]
	else:
		places = [{"id": "p1", "type": "gather", "gather_days": 1, "gather_table": table_a + table_b}]
	d.regions["fake_region"] = {"places": places}
	return d


func test_max_count_two_ingredients_one_place_uses_max_rule() -> void:
	var d := _fake_gather_data(false)
	var recipe := {"ingredients": {"herb_a": 2, "herb_b": 2}, "output": {"item": "x", "count": 1}}
	var c := new_character()
	var rate := Exploration.gather_rate(c, d, "herb_a", "fake_region")
	assert_true(rate > 0.0)
	var one := {"ingredients": {"herb_a": 2}, "output": {"item": "x", "count": 1}}
	assert_eq(Commissions.max_count(c, d, recipe, "fake_region", 0, 100), Commissions.max_count(c, d, one, "fake_region", 0, 100), "same place: max rule")
	assert_eq(Commissions.max_count(c, d, one, "fake_region", 0, 100), floori(100.0 * Commissions.FILL_SHARE / (2.0 / rate)))


func test_max_count_two_places_sums_days() -> void:
	var d := _fake_gather_data(true)
	var c := new_character()
	var recipe := {"ingredients": {"herb_a": 2, "herb_b": 2}, "output": {"item": "x", "count": 1}}
	var one := {"ingredients": {"herb_a": 2}, "output": {"item": "x", "count": 1}}
	var both := Commissions.max_count(c, d, recipe, "fake_region", 0, 100)
	var single := Commissions.max_count(c, d, one, "fake_region", 0, 100)
	assert_eq(Exploration.best_gather_place(c, d, "herb_b", "fake_region"), "p2")
	assert_true(absi(both * 2 - single) <= 1, "about half: %d vs %d" % [both, single])


func _array_order(count: int) -> Dictionary:
	return {"profession": "array_master", "recipe": "minor_spirit_gathering_array", "item": "minor_spirit_gathering_array", "count": count, "reward": 10, "xp": 5.0, "due_day": 100}


## PROF-016: an order short only of spirit stones says so instead of "you have the ingredients".
func test_missing_line_names_a_stone_shortfall() -> void:
	var c := _alchemist()
	c.inventory = {}
	c.add_item("talisman_paper", 2)
	c.add_item("spirit_herb", 2)
	var need: int = int(data().recipes["minor_spirit_gathering_array"].ingredients["spirit_stone"])
	c.add_item("spirit_stone", 1)
	assert_eq(Commissions.short_ingredient(c, data(), _array_order(2)), "spirit_stone")
	assert_eq(Commissions.missing_line(c, data(), _array_order(2), "qingshi_village", 10), "Needs %d more %s for the crafts." % [need - 1, Items.item_plural(data(), "spirit_stone", need - 1)])
	c.add_item("spirit_stone", need - 2)
	assert_eq(Commissions.missing_line(c, data(), _array_order(2), "qingshi_village", 10), "Needs 1 more %s for the crafts." % Items.item_plural(data(), "spirit_stone", 1))
	c.add_item("spirit_stone", 1)
	assert_eq(Commissions.short_ingredient(c, data(), _array_order(2)), "")
	assert_eq(Commissions.missing_line(c, data(), _array_order(2), "qingshi_village", 10), "You have the ingredients: craft it at a workshop.")


func test_a_short_herb_still_outranks_stones() -> void:
	var c := _alchemist()
	c.inventory = {}
	assert_eq(Commissions.short_ingredient(c, data(), _array_order(2)), "talisman_paper")
	assert_true(Commissions.missing_line(c, data(), _array_order(2), "qingshi_village", 10).begins_with("Needs Blank Talisman Paper"))


func test_lapse_text_names_spirit_stones() -> void:
	var c := _alchemist()
	c.inventory = {}
	c.add_item("talisman_paper", 2)
	c.add_item("spirit_herb", 2)
	var text := Commissions.lapse_text(c, data(), _array_order(2))
	assert_true(text.ends_with(" lapsed. You were short of %s." % Items.item_plural(data(), "spirit_stone", 2)), text)


## GUIDE-177: an order that gathering cannot finish in time stops taking a hint slot.
func test_due_soon_hint_skips_a_doomed_order() -> void:
	var c := _alchemist()
	var d := GameData.load_from_dir()  # a private copy: the price is mutated below
	var doomed := _pill_order(2, 11)
	var short := Commissions.short_ingredient(c, d, doomed)
	assert_true(short != "")
	d.items[short]["price"] = 0  # no merchant stocks it any more, so only gathering can finish the order
	d.source_cache.clear()
	assert_false(Guidance.merchant_sells_nearby(d, short, "qingshi_village"))
	assert_true(Commissions.missing_line(c, d, doomed, "qingshi_village", 10).contains("longer than the order has"))
	assert_false(Commissions.can_meet_in_time(c, d, doomed, "qingshi_village", 10))
	c.commissions = [doomed]
	assert_eq(Commissions.due_soon_hint(c, d, "qingshi_village", 10), "")
	var roomy := _pill_order(2, 100)
	assert_true(Commissions.can_meet_in_time(c, d, roomy, "qingshi_village", 10))
	c.commissions = [roomy]
	assert_true(Commissions.due_soon_hint(c, d, "qingshi_village", 90).begins_with("Order due in "))


## GUIDE-178: orders prefer recipes whose ingredients are all in the region.
func _only_recipes(ids: Array) -> GameData:
	var d := GameData.load_from_dir()
	for rid: String in d.recipes.keys():
		if String(d.recipes[rid]["profession"]) == "alchemist" and not ids.has(rid):
			d.recipes.erase(rid)
	return d


func _rolled_orders(d: GameData, region: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 40:
		var c := _alchemist()
		c.professions["alchemist"]["rank"] = 1
		out.append_array(Commissions.roll(c, d, seeded_rng(i + 1), 0, "alchemist", region))
	return out


func test_orders_prefer_local_ingredients() -> void:
	var d := _only_recipes(["qi_gathering_pill", "bone_setting_salve"])
	var orders := _rolled_orders(d, "qingshi_village")
	assert_eq(orders.size(), 40)
	for o in orders:
		assert_eq(String(o["recipe"]), "qi_gathering_pill")


func test_orders_needing_a_neighbours_ingredient_ask_for_one() -> void:
	var d := _only_recipes(["bone_setting_salve", "spirit_gathering_pill"])
	for o in _rolled_orders(d, "qingshi_village"):
		assert_eq(int(o["count"]), 1)


func test_available_nearby_local_only_ignores_neighbours() -> void:
	var d := data()
	var c := _alchemist()
	assert_false(Guidance.available_nearby(c, d, "qi_condensing_grass", "qingshi_village", -1, true))
	assert_true(Guidance.available_nearby(c, d, "qi_condensing_grass", "misty_forest", -1, true))


## QA-166: an order the player can still meet shows its due-soon line even with 3 days left, whether
## the ingredients are missing, in the pack, or the craft is the only step left.
func test_due_soon_hint_shows_an_order_due_in_three_days() -> void:
	var c := _alchemist()
	c.commissions = [_pill_order(2, 13)]
	var hint := Commissions.due_soon_hint(c, data(), "qingshi_village", 10)
	assert_true(hint.begins_with("Order due in 3 days"), hint)
	assert_true(Guidance.hints(c, data(), 1.0, 8, {}, {}, "qingshi_village", 10).has(hint))
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	hint = Commissions.due_soon_hint(c, data(), "qingshi_village", 10)
	assert_true(hint.contains("craft it at a workshop"), hint)


## GUIDE-194: an order due in 3 days or less jumps ahead of the herb/untried hints; one due later keeps its old slot.
func test_urgent_due_order_leads_the_hints() -> void:
	var c := _alchemist()
	c.commissions = [_pill_order(2, 13)]
	var d := data()
	var due := Commissions.due_soon_hint(c, d, "qingshi_village", 10)
	var hints := Guidance.hints(c, d, 1.0, 8, {}, {}, "qingshi_village", 10)
	var herb := Guidance.herb_here_hint(c, d, "qingshi_village", 10)
	assert_true(hints.has(due), due)
	var due_i := hints.find(due)
	if herb != "":
		assert_true(due_i < hints.find(herb), "urgent due line before the herb hint")
	assert_true(due_i < 3, "within the top 3")
	c.commissions = [_pill_order(2, 20)]
	due = Commissions.due_soon_hint(c, d, "qingshi_village", 10)
	hints = Guidance.hints(c, d, 1.0, 8, {}, {}, "qingshi_village", 10)
	assert_true(hints.has(due), due)
	if herb != "":
		assert_true(hints.find(due) > hints.find(herb), "a later order keeps its old slot")
	assert_eq(Commissions.due_soon_order(c, d, "qingshi_village", 10)["line"], due)


func test_order_needs_item_and_ingredients() -> void:
	var c := _alchemist()
	assert_eq(Commissions.order_needs(c, data()), {}, "no orders")
	c.commissions = [_pill_order(2, 100)]
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	var per_craft := maxi(1, int(recipe["output"].get("count", 1)))
	var crafts := ceili(2.0 / per_craft)
	var needs := Commissions.order_needs(c, data())
	assert_eq(int(needs["qi_gathering_pill"]), 2)
	for id: String in recipe["ingredients"]:
		if id != "spirit_stone":
			assert_eq(int(needs[id]), int(recipe["ingredients"][id]) * crafts, id)
	assert_false(needs.has("spirit_stone"))
	c.add_item("qi_gathering_pill", 2)
	assert_eq(Commissions.order_needs(c, data()), {"qi_gathering_pill": 2}, "held in full: only the item")
