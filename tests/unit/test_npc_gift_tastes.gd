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
