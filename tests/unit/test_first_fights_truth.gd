extends TestCase
## QA-085: the rating of a first-region foe matches how often a starter character really wins.

const Truth := preload("res://tests/sim/first_fights_truth.gd")


func test_boar_rating_matches_real_rate() -> void:
	var d := data()
	var c := CharacterFactory.create("Newcomer", d, seeded_rng(5))
	c.realm_index = d.realm_index_of("qi_refining")
	c.add_item("iron_sword", 1)
	Equipment.equip(c, d, "iron_sword")
	var ids := Truth.foe_ids(c, d, d.start_region)
	assert_true(ids.has("wild_boar"), "the village boar is a first-region foe")
	for id: String in ids:
		var enemy: Dictionary = d.enemies[id]
		var gap := absf(Combat.win_chance(c, d, enemy) - Truth.real_rate(c, d, enemy, 100))
		assert_true(gap <= Truth.GAP, "%s: rated and real win rates differ by %d points" % [id, roundi(gap * 100)])
