extends TestCase
## FOLK-011: generated villagers have stable, hash-picked gift tastes (Family.taste_lists).


func test_same_id_same_tastes() -> void:
	var d := data()
	assert_eq(Family.taste_lists(d, "villager_x"), Family.taste_lists(d, "villager_x"))
	var t := Family.taste_lists(d, "villager_x")
	assert_eq((t["likes"] as Array).size(), 2)
	assert_eq((t["dislikes"] as Array).size(), 1)


func test_ids_can_differ_and_never_overlap() -> void:
	var d := data()
	var seen := {}
	for i in 30:
		var t := Family.taste_lists(d, "npc_%d" % i)
		seen[str(t["likes"])] = true
		for e in t["dislikes"]:
			assert_false((t["likes"] as Array).has(e))
	assert_true(seen.size() > 1)


func test_named_npc_unchanged() -> void:
	var d := data()
	var id: String = d.npcs.keys()[0]
	assert_eq(Family.taste_lists(d, id)["likes"], d.npcs[id].get("likes", []))


func test_validation_rejects_bad_tastes() -> void:
	var d := data()
	assert_true(Folk.validate_tastes(d).is_empty())
	var saved: Dictionary = d.family["folk_tastes"]
	d.family["folk_tastes"] = {"likes_pool": ["fish"], "likes": 3}
	assert_false(Folk.validate_tastes(d).is_empty())
	d.family["folk_tastes"] = saved
