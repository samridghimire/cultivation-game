extends TestCase


func test_starts_as_apprentice() -> void:
	assert_eq(Professions.rank_of(new_character(), "alchemist"), 0)


func test_xp_promotes_multiple_ranks() -> void:
	var c := new_character()
	var def: ProfessionDef = data().professions["alchemist"]
	var gained := Professions.add_xp(c, data(), "alchemist", def.xp_to_next(0) + def.xp_to_next(1) + 1.0)
	assert_eq(gained, 2)
	assert_eq(Professions.rank_of(c, "alchemist"), 2)
	assert_almost_eq(Professions.xp_of(c, "alchemist"), 1.0)


func test_rank_caps_at_grandmaster() -> void:
	var c := new_character()
	Professions.add_xp(c, data(), "doctor", 1e15)
	assert_eq(Professions.rank_of(c, "doctor"), Professions.max_rank(data()))


func test_work_pays_spirit_stones() -> void:
	var c := new_character()
	var before := c.item_count("spirit_stone")
	var result := Professions.work(c, data(), "blacksmith", Calendar.DAYS_PER_MONTH)
	assert_gt(result["income"], 0)
	assert_eq(c.item_count("spirit_stone"), before + result["income"])


func test_work_preview_matches_work() -> void:
	var a := new_character()
	var b := new_character()
	var days := Calendar.DAYS_PER_MONTH
	var preview := Professions.work_preview(a, data(), "blacksmith", days)
	var stones := b.item_count("spirit_stone")
	var xp := Professions.xp_of(b, "blacksmith")
	var result := Professions.work(b, data(), "blacksmith", days)
	assert_eq(result["income"], preview["income"])
	assert_almost_eq(result["xp"], preview["xp"])
	assert_eq(b.item_count("spirit_stone"), stones + preview["income"])
	assert_almost_eq(Professions.xp_of(b, "blacksmith"), xp + preview["xp"])


func test_rank_ups_are_counted_in_life_stats() -> void:
	var c := new_character()
	var def: ProfessionDef = data().professions["alchemist"]
	Professions.add_xp(c, data(), "alchemist", def.xp_to_next(0) + 1.0)
	assert_eq(LifeStats.get_stat(c, "profession_ranks"), 1)
	Professions.add_xp(c, data(), "alchemist", 0.5)
	assert_eq(LifeStats.get_stat(c, "profession_ranks"), 1)
	Professions.add_xp(c, data(), "alchemist", def.xp_to_next(1) + def.xp_to_next(2))
	assert_eq(LifeStats.get_stat(c, "profession_ranks"), 3)


func test_work_and_crafted_sales_count_as_craft_stones() -> void:
	var c := new_character()
	var result := Professions.work(c, data(), "blacksmith", 30)
	assert_eq(LifeStats.get_stat(c, "profession_stones"), int(result["income"]))
	var before := LifeStats.get_stat(c, "profession_stones")
	c.add_item("spirit_herb", 2)
	assert_true(Items.material_value(data(), "spirit_herb") < 0.0)
	Items.sell(c, data(), "spirit_herb", 2)
	assert_eq(LifeStats.get_stat(c, "profession_stones"), before, "raw herbs are not craft income")
	c.add_item("qi_gathering_pill", 2)
	Items.sell(c, data(), "qi_gathering_pill", 1)
	assert_eq(LifeStats.get_stat(c, "profession_stones"), before, "a pill sold by a non-alchemist is not craft income")
	Professions.add_xp(c, data(), "alchemist", 0.0)
	var sold := Items.sell(c, data(), "qi_gathering_pill", 1)
	assert_eq(LifeStats.get_stat(c, "profession_stones"), before + int(sold["stones"]))


func _set_rank(c: CharacterData, prof_id: String, rank: int) -> void:
	c.professions[prof_id] = {"rank": rank, "xp": 0.0}


func test_rank_up_line_names_known_recipes() -> void:
	var c := new_character()
	_set_rank(c, "alchemist", 1)
	var names: PackedStringArray = []
	for id: String in Alchemy.known_recipes(c, data(), "alchemist"):
		if int(data().recipes[id].get("min_rank", 0)) == 1:
			names.append(String(data().recipes[id]["name"]))
	assert_eq(names.size(), 2)
	assert_eq(Professions.rank_up_line(c, data(), "alchemist"), "You can now refine %s and %s." % [names[0], names[1]])


func test_rank_up_line_counts_extras() -> void:
	var c := new_character()
	_set_rank(c, "blacksmith", 1)
	var line := Professions.rank_up_line(c, data(), "blacksmith")
	assert_true(line.begins_with("You can now refine "), line)
	assert_true(line.ends_with(" and 1 more."), line)


func test_rank_up_line_many_known_recipes() -> void:
	var c := new_character()
	_set_rank(c, "talisman_master", 1)
	var d := data()
	var known := 0
	for id: String in Alchemy.known_recipes(c, d, "talisman_master"):
		if int(d.recipes[id].get("min_rank", 0)) == 1:
			known += 1
	assert_gt(known, 2)
	assert_true(Professions.rank_up_line(c, d, "talisman_master").ends_with("more."))


func test_rank_up_line_points_to_scroll() -> void:
	var c := new_character()
	_set_rank(c, "alchemist", 1)
	# Forget every rank-1 recipe so only the scroll hint can apply.
	var d := data()
	var saved: Dictionary = d.recipes.duplicate(true)
	for id: String in d.recipes:
		if d.recipes[id]["profession"] == "alchemist" and int(d.recipes[id].get("min_rank", 0)) == 1:
			d.recipes[id]["starter"] = false
	var next_id := Professions.next_unknown_recipe(c, d, "alchemist")
	assert_true(next_id != "")
	var line := Professions.rank_up_line(c, d, "alchemist")
	d.recipes = saved
	assert_true(line.contains("is now within your skill; find its recipe scroll."), line)


func test_rank_up_line_doctor_empty() -> void:
	var c := new_character()
	_set_rank(c, "doctor", 2)
	assert_eq(Professions.rank_up_line(c, data(), "doctor"), "")


func test_next_unknown_recipe_skips_known_and_too_high() -> void:
	var c := new_character()
	var d := data()
	_set_rank(c, "alchemist", 0)
	var first := Professions.next_unknown_recipe(c, d, "alchemist")
	assert_true(first != "")
	assert_true(int(d.recipes[first].get("min_rank", 0)) <= 1)
	assert_false(Alchemy.knows(c, d, first))
	c.known_recipes.append(first)
	var second := Professions.next_unknown_recipe(c, d, "alchemist")
	assert_true(second != first)
	for id: String in d.recipes:
		if d.recipes[id]["profession"] == "alchemist":
			c.known_recipes.append(id)
	assert_eq(Professions.next_unknown_recipe(c, d, "alchemist"), "")


func test_rank_up_line_after_a_two_rank_jump_names_both_ranks() -> void:
	var c := new_character()
	_set_rank(c, "alchemist", 2)
	var d := data()
	var one: String = ""
	var two: String = ""
	for id: String in Alchemy.known_recipes(c, d, "alchemist"):
		var mr := int(d.recipes[id].get("min_rank", 0))
		if mr == 1 and one == "":
			one = String(d.recipes[id]["name"])
		elif mr == 2 and two == "":
			two = String(d.recipes[id]["name"])
	assert_true(one != "" and two != "", "a known rank-1 and rank-2 alchemist recipe")
	var jump := Professions.rank_up_line(c, d, "alchemist", 0)
	assert_true(jump.contains(one) and jump.contains(two), "a jump from 0 to 2 names both: " + jump)
	var step := Professions.rank_up_line(c, d, "alchemist", 1)
	assert_true(step.contains(two) and not step.contains(one), "a one-rank step names only rank 2: " + step)
	assert_eq(Professions.rank_up_line(c, d, "alchemist"), step)
