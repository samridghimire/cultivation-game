extends TestCase
## GFX-027: the celebration bow finds the nearest stall/house; confetti is deterministic and settles.


func test_nearest_landmark_picks_stall_or_house() -> void:
	var lms: Array = [
		{"kind": "pond", "pos": [100, 100], "size": [10, 10]},
		{"kind": "house", "pos": [500, 100], "size": [100, 80]},
		{"kind": "stall", "pos": [300, 100], "size": [80, 50]},
	]
	var lm := CelebrationBow.nearest_landmark(lms, Vector2(120, 100))
	assert_eq(lm["kind"], "stall", "the pond is nearer but is not a stall or house")
	assert_eq(CelebrationBow.nearest_landmark(lms, Vector2(520, 100))["kind"], "house")


func test_nearest_landmark_empty_when_none() -> void:
	assert_true(CelebrationBow.nearest_landmark([{"kind": "pond", "pos": [0, 0], "size": [1, 1]}], Vector2.ZERO).is_empty())
	assert_true(CelebrationBow.nearest_landmark([], Vector2.ZERO).is_empty())


func test_confetti_pieces_start_at_origin_and_are_deterministic() -> void:
	for i in ConfettiPuff.PIECES:
		assert_eq(ConfettiPuff.piece_offset(i, 0.0), Vector2.ZERO)
		assert_eq(ConfettiPuff.piece_offset(i, 0.5), ConfettiPuff.piece_offset(i, 0.5))
	assert_true(ConfettiPuff.piece_offset(3, 1.0) != ConfettiPuff.piece_offset(4, 1.0))


func test_confetti_frees_itself() -> void:
	var puff := ConfettiPuff.new()
	((Engine.get_main_loop() as SceneTree).root).add_child(puff)
	puff._process(ConfettiPuff.LIFETIME + 0.1)
	assert_true(puff.is_queued_for_deletion())
