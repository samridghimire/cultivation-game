extends TestCase
## GFX-069: label ranking (great beasts after the target), the re-spread throttle, and blockers in the spread.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const VIEW := Rect2(0, 0, 1280, 800)


func _npc(label: String, pos: Vector2) -> Interactable:
	var n: Interactable = NPC_SCRIPT.new()
	n.display_name = label
	n.position = pos
	n.size = Vector2(28, 28)
	return n


func _beast(label: String, pos: Vector2, is_great: bool) -> Interactable:
	var r := Roamer.new()
	r.display_name = label
	r.position = pos
	r.size = Vector2(28, 28)
	r.great = is_great
	return r


func test_great_beast_outranks_a_villager_but_not_the_target() -> void:
	var player := Vector2(300, 300)
	var villager := _npc("Hermit Gu", Vector2(300, 300))
	var great := _beast("Great Cloud Crane", Vector2(600, 300), true)
	var plain := _beast("Wolf", Vector2(310, 300), false)
	assert_true(Interactable.label_rank(great, player) < Interactable.label_rank(villager, player))
	assert_eq(Interactable.label_rank(plain, player), Interactable.label_rank(villager, player), "ordinary roamers rank with NPCs")
	villager.highlighted = true
	assert_true(Interactable.label_rank(villager, player) < Interactable.label_rank(great, player))
	var place := Interactable.new()
	place.display_name = "Hunters' Bounty Board"
	place.position = Vector2(900, 300)
	assert_true(Interactable.label_rank(place, player) < Interactable.label_rank(plain, player), "places outrank moving labels")
	place.free()
	for n: Node in [villager, great, plain]:
		n.free()


func test_faded_label_near_the_player_ranks_as_highlighted() -> void:
	var n := _npc("Far Elder", Vector2(100, 100))
	n.label_covered = true
	assert_eq(Interactable.label_rank(n, Vector2(150, 100)), 0)
	assert_true(Interactable.label_rank(n, Vector2(500, 100)) > 0)
	n.free()


func test_respread_throttle() -> void:
	assert_false(Interactable.respread_due(1.0, 0.0), "nothing moved")
	assert_false(Interactable.respread_due(1.0, 3.0), "under 4 px")
	assert_false(Interactable.respread_due(0.1, 5.0), "too soon")
	assert_true(Interactable.respread_due(0.25, 5.0))


func test_moving_labels_are_separated_on_the_next_pass() -> void:
	var a := _npc("Hermit Gu (Retired Azure Cloud Elder)", Vector2(600, 400))
	var b := _beast("Great Cloud Crane (Weak)", Vector2(900, 400), true)
	Interactable.spread_on_screen([a, b], VIEW, [], Vector2(600, 400))
	var apart := a.drawn_label_rect(VIEW).intersects(b.drawn_label_rect(VIEW))
	assert_false(apart, "start apart")
	b.position = Vector2(604, 404)
	Interactable.spread_on_screen([a, b], VIEW, [], Vector2(600, 400))
	var ra := a.drawn_label_rect(VIEW)
	var rb := b.drawn_label_rect(VIEW)
	assert_true(b.label_covered or not ra.intersects(rb), "overlapping labels are lifted or faded")
	a.free()
	b.free()


func test_a_blocker_rect_moves_or_fades_the_label_under_it() -> void:
	var a := _npc("Village Pond Jetty", Vector2(600, 400))
	var chip: Array[Rect2] = [a.drawn_label_rect(VIEW).grow(4.0)]
	Interactable.spread_on_screen([a], VIEW, chip, Vector2(0, 0))
	assert_true(a.screen_lift != 0.0 or a.label_covered)
	a.free()
