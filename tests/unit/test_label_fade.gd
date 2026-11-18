extends TestCase
## WU-508: labels fade over the player, hide under the chip, and idle spots keep off the signpost.

func test_fade_over_player() -> void:
	var body := LabelFade.player_rect(Vector2(100, 100))
	assert_eq(LabelFade.alpha_for(Rect2(90, 90, 80, 16), body), 0.35)
	assert_eq(LabelFade.alpha_for(Rect2(300, 90, 80, 16), body), 1.0)


func test_chip_hides_label() -> void:
	assert_true(LabelFade.hidden_by_chip(Rect2(0, 0, 50, 10), Rect2(40, 5, 50, 20)))
	assert_false(LabelFade.hidden_by_chip(Rect2(0, 0, 50, 10), Rect2()))
	assert_false(LabelFade.hidden_by_chip(Rect2(0, 0, 50, 10), Rect2(60, 0, 20, 20)))



func test_keep_nearest_over_player() -> void:
	var p := Vector2(100, 100)
	var rects: Array[Rect2] = [Rect2(90, 90, 80, 16), Rect2(95, 95, 80, 16), Rect2(500, 90, 80, 16)]
	var pos: Array[Vector2] = [Vector2(150, 100), Vector2(110, 100), Vector2(500, 100)]
	assert_eq(LabelFade.keep_nearest(rects, pos, p), [0.0, 0.35, 1.0] as Array[float])


func test_keep_nearest_single_and_none() -> void:
	var p := Vector2(100, 100)
	var one: Array[Rect2] = [Rect2(90, 90, 80, 16)]
	var pos: Array[Vector2] = [Vector2(120, 100)]
	assert_eq(LabelFade.keep_nearest(one, pos, p), [0.35] as Array[float])
	var far: Array[Rect2] = [Rect2(400, 0, 10, 10)]
	assert_eq(LabelFade.keep_nearest(far, pos, p), [1.0] as Array[float])


func test_npc_yields_to_place_label() -> void:
	var places: Array[Rect2] = [Rect2(0, 0, 100, 16)]
	assert_eq(LabelFade.npc_alpha(Rect2(50, 5, 60, 16), places), 0.35)
	assert_eq(LabelFade.npc_alpha(Rect2(200, 5, 60, 16), places), 1.0)


## WU-564: name labels draw above the player sprite (label layer z 10, player z 0), so the player never covers one.
func test_labels_draw_above_the_player() -> void:
	var player: Node2D = load("res://src/world/player.tscn").instantiate()
	assert_eq(player.z_index, 0)
	var node := Interactable.new()
	node.size = Vector2(40, 40)
	node.display_name = "Test"
	Engine.get_main_loop().root.add_child(node)
	var z := -1
	for c: Node in node.get_children():
		if c is Node2D and (c as Node2D).z_index > 0:
			z = (c as Node2D).z_index
	node.queue_free()
	player.queue_free()
	assert_true(z > player.z_index, "label z %d above the player" % z)
