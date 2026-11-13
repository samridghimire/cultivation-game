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
