## C-058: every named NPC has gift tastes, and most are satisfiable from the shops.
extends TestCase


func test_every_named_npc_likes_something() -> void:
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		assert_true(not (def.get("likes", []) as Array).is_empty(), "%s likes nothing" % npc_id)


func test_a_like_never_doubles_as_a_dislike() -> void:
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		for entry in def.get("likes", []):
			assert_false((def.get("dislikes", []) as Array).has(entry), "%s both likes and dislikes %s" % [npc_id, entry])


## C-284: every named NPC has >= 2 likes, at most 2 dislikes and one cheap village gift among the likes.
func test_every_named_npc_has_a_full_set_of_tastes() -> void:
	var cheap: Array = ["herb", "moon_cake", "paper_lantern", "boar_roast", "venison_broth", "food", "fish"]
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		var likes: Array = def.get("likes", [])
		assert_true(likes.size() >= 2, "%s has fewer than 2 likes" % npc_id)
		assert_true((def.get("dislikes", []) as Array).size() <= 2, "%s has more than 2 dislikes" % npc_id)
		var has_cheap := false
		for entry in likes:
			if cheap.has(entry) or String(entry).ends_with("_loach") or String(entry).ends_with("_bream"):
				has_cheap = true
		assert_true(has_cheap, "%s likes no cheap village gift" % npc_id)
