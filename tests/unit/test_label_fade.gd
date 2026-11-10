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

