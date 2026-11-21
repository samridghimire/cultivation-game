extends TestCase
## WU-587: when a named villager's name row overlaps a place label, the place label yields; the person's row stays.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const VIEW := Rect2(0, 0, 1280, 800)


func test_person_row_stays_over_place_label() -> void:
	var place := Interactable.new()
	place.display_name = "Meditation Rock"
	place.size = Vector2(20, 20)
	place.position = Vector2(400, 300)
	var npc: Interactable = NPC_SCRIPT.new()
	npc.npc_id = "elder_mo"
	npc.display_name = "Elder Mo"
	npc.size = Vector2(28, 28)
	npc.position = Vector2(400, 300)
	var nodes: Array = [place, npc]
	Interactable.spread_on_screen(nodes, VIEW, [] as Array[Rect2], Vector2(400, 300))
	if npc.label_drawn() and place.label_drawn():
		var pr := npc.drawn_label_rect(VIEW)
		var lr := place.drawn_label_rect(VIEW)
		assert_false(pr.intersects(lr), "labels must not overlap")
	assert_true(npc.label_drawn() and not npc.label_covered, "the person's row is neither faded nor hidden")
	place.free()
	npc.free()
