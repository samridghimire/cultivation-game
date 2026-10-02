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
