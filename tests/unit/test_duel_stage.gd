extends TestCase
## WU-396: the duel stage above the fight report's bars.

const LINES := ["You face the foe.", "You strike for 5.", "Foe hits you for 3.", "You defeat the foe!"]
const TRACE := [[20, 10], [20, 5], [17, 5], [17, 0]]


func _report() -> CombatReport:
	var r := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	return r


func test_blow_side() -> void:
	assert_eq(DuelStage.blow_side([20, 10], [20, 5]), 1)
	assert_eq(DuelStage.blow_side([20, 5], [17, 5]), -1)
	assert_eq(DuelStage.blow_side([20, 10], [20, 10]), 0)
	assert_eq(DuelStage.blow_side([], [20, 10]), 0)


func test_skip_dims_the_loser() -> void:
	var r := _report()
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	assert_true(r._stage.visible)
	r.skip()
	assert_eq(r._stage.alpha_of(0), 1.0)
	assert_eq(r._stage.alpha_of(1), 0.4)
	r.show_fight("Foe", false, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	r.skip()
	assert_eq(r._stage.alpha_of(0), 0.4)
	r.queue_free()


func test_no_trace_hides_stage() -> void:
	var r := _report()
	r.show_fight("Foe", true, PackedStringArray(LINES))
	assert_false(r._stage.visible)
	r.queue_free()


func test_friendly_spar_leaves_both_standing() -> void:
	var r := _report()
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, true)
	r.skip()
	assert_eq(r._stage.alpha_of(0), 1.0)
	assert_eq(r._stage.alpha_of(1), 1.0)
	r.queue_free()


func test_ticking_with_blows_does_not_fail() -> void:
	var r := _report()
	r.show_fight("Wolf", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, false, "", "wolf", ["beast"])
	for i in 4:
		r.tick()
	assert_true(r._stage._foe_beast)
	r.queue_free()


func test_shake_offset_is_zero_when_reduced_and_bounded_otherwise() -> void:
	assert_eq(MotionFx.shake_offset(0.05, 0.15, 3.0, true), Vector2.ZERO)
	assert_eq(MotionFx.shake_offset(0.2, 0.15, 3.0, false), Vector2.ZERO)
	for i in 15:
		var o := MotionFx.shake_offset(i * 0.01, 0.15, 3.0, false)
		assert_true(absf(o.x) <= 3.0 and absf(o.y) <= 3.0)
	assert_true(MotionFx.shake_offset(0.05, 0.15, 3.0, false) != Vector2.ZERO)


func test_heavy_hit_is_over_fifteen_percent() -> void:
	assert_true(MotionFx.is_heavy_hit(4, 20))
	assert_false(MotionFx.is_heavy_hit(3, 20))
	assert_false(MotionFx.is_heavy_hit(5, 0))


## GFX-014: beasts get fur by id and a generated 24x16 texture with two leg frames.
func test_beast_fur_and_frames() -> void:
	assert_eq(DuelStage.fur_for("grey_wolf"), DuelStage.BEAST_FURS["wolf"])
	assert_eq(DuelStage.fur_for("wild_boar"), DuelStage.BEAST_FURS["boar"])
	assert_eq(DuelStage.fur_for("mystery"), DuelStage.DEFAULT_FUR)
	var a := PixelFigure.beast_frame(DuelStage.DEFAULT_FUR, 0)
	var b := PixelFigure.beast_frame(DuelStage.DEFAULT_FUR, 1)
	assert_eq(a.get_size(), Vector2(24, 16))
	assert_true(a != b, "two leg frames")
	assert_true(a.get_image().get_data() != b.get_image().get_data(), "legs differ")
	assert_true(a == PixelFigure.beast_frame(DuelStage.DEFAULT_FUR, 2), "cached by frame parity")
