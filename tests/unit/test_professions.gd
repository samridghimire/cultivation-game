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
