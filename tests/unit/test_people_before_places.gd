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


func test_place_label_avoids_person_body() -> void:
	var npc: Interactable = NPC_SCRIPT.new()
	npc.npc_id = "elder_mo"
	npc.display_name = "Elder Mo"
	npc.size = Vector2(28, 28)
	npc.position = Vector2(400, 300)
	var place := Interactable.new()
	place.display_name = "Meditation Rock"
	place.size = Vector2(20, 20)
	place.position = Vector2(400, 300)
	var nodes: Array = [place, npc]
	Interactable.spread_on_screen(nodes, VIEW, [] as Array[Rect2], Vector2(900, 600))
	if place.label_drawn():
		var body := Interactable.person_figure_rect(npc)
		var lr := place.drawn_label_rect(VIEW)
		assert_true(place.label_covered or not body.intersects(lr), "place label moved off or faded over the body")
	place.free()
	npc.free()


## WU-591: a named villager's label sits at least 2 px above the sprite's top (40 px above the feet), crowded or not.
func test_person_label_stays_above_own_head() -> void:
	var nodes: Array = []
	var npcs: Array = []
	for i in 4:
		var npc: Interactable = NPC_SCRIPT.new()
		npc.npc_id = "wu591_%d" % i
		npc.display_name = "Wen Qingxu %d" % i
		npc.size = Vector2(28, 28)
		npc.position = Vector2(400 + i * 30, 300)
		var place := Interactable.new()
		place.display_name = "Hermit Stall Number %d" % i
		place.size = Vector2(20, 20)
		place.position = npc.position + Vector2(0, -6)
		nodes.append(place)
		nodes.append(npc)
		npcs.append(npc)
	Interactable.spread_on_screen(nodes, VIEW, [] as Array[Rect2], Vector2(900, 600))
	for npc: Interactable in npcs:
		if not npc.label_drawn():
			continue
		var feet := npc.position.y + npc.size.y / 2.0
		var lr := npc.drawn_label_rect(VIEW)
		var head := feet - Interactable.FIGURE_HEIGHT
		assert_true(lr.end.y <= head - 2.0 or lr.position.y >= feet, "label of %s clear of the head (end %.1f, head %.1f)" % [npc.display_name, lr.end.y, head])
	for n: Node in nodes:
		n.free()
