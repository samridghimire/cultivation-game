## WU-101: "Look" names the gift tastes the player has learned.
extends TestCase

const NpcScript := preload("res://src/world/interactables/npc.gd")


func _two_items() -> Array:
	var ids: Array = data().items.keys()
	ids.sort()
	return [ids[0], ids[1]]


func test_like_and_dislike() -> void:
	var ids := _two_items()
	var flags := {"taste_li_%s" % ids[0]: 1, "taste_li_%s" % ids[1]: -1}
	var text: String = NpcScript.known_tastes_text(flags, data(), "li")
	assert_true(text.contains("Likes: %s." % data().items[ids[0]]["name"]), text)
	assert_true(text.contains("Dislikes: %s." % data().items[ids[1]]["name"]), text)


func test_nothing_known_is_empty() -> void:
	assert_eq(NpcScript.known_tastes_text({}, data(), "li"), "")


func test_underscore_ids_do_not_collide() -> void:
	var ids := _two_items()
	var flags := {"taste_li_wei_%s" % ids[0]: 1}
	assert_eq(NpcScript.known_tastes_text(flags, data(), "li"), "")
	assert_true(NpcScript.known_tastes_text(flags, data(), "li_wei").begins_with("Likes:"))


func test_told_hint_when_no_like_known() -> void:
	var npc_id: String = data().npcs.keys()[0]
	var text: String = NpcScript.known_tastes_text({"taste_told_" + npc_id: true}, data(), npc_id)
	assert_eq(text, Family.taste_hint(data(), npc_id))
