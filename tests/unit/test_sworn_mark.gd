extends TestCase
## GFX-238: Sworn friends get a red cord on the People card and a knot on their name plate (favor >= 85, non-family only).

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func _root() -> Node:
	return Engine.get_main_loop().root


func test_sworn_needs_favor_and_not_family() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	assert_false(Folk.is_sworn(gs.data, gs.player, "hunter_ma", 84))
	assert_true(Folk.is_sworn(gs.data, gs.player, "hunter_ma", 85))
	gs.player.spouses.append("hunter_ma")
	assert_false(Folk.is_sworn(gs.data, gs.player, "hunter_ma", 100), "family never gets the mark")
	gs.end_session()


func test_plate_mark_width_follows_sworn() -> void:
	var n: Interactable = NPC_SCRIPT.new()
	assert_eq(n.name_mark_width(), 0.0)
	n._sworn = true
	assert_true(n.name_mark_width() > 0.0)
	n.free()


func test_cord_and_knot_sizes() -> void:
	assert_eq(HudIcons.cord(2).get_size(), Vector2(20, 12))
	assert_eq(HudIcons.knot(2).get_size(), Vector2(10, 10))
