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
	assert_eq(r._stage.alpha_of(1), 1.0)
	assert_eq(r._stage.dark_of(1), 0.3)
	assert_eq(r._stage.dark_of(0), 0.0)
	r.show_fight("Foe", false, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	r.skip()
	assert_eq(r._stage.alpha_of(0), 1.0)
	assert_eq(r._stage.dark_of(0), 0.3)
	r.queue_free()


func test_toppled_tilt_depends_on_body() -> void:
	assert_eq(DuelStage.toppled_tilt(false), PI / 2.0)
	assert_eq(DuelStage.toppled_tilt(true), PI / 2.0)  # GFX-033: beasts lie on their side too
	assert_true(DuelStage.FALLEN_DARKEN <= 0.4)


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
	assert_eq(r._stage.dark_of(1), 0.0)
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


func test_beast_kind_by_id() -> void:
	assert_eq(DuelStage.beast_kind("wild_boar"), "boar")
	assert_eq(DuelStage.beast_kind("mist_wolf"), "wolf")
	assert_eq(DuelStage.beast_kind("mist_python"), "snake")
	assert_eq(DuelStage.beast_kind("azure_crane"), "bird")
	assert_eq(DuelStage.beast_kind("flame_tailed_fox"), "wolf")
	assert_eq(DuelStage.beast_kind("stone_ape"), "")


func test_beast_kinds_look_different_and_cache() -> void:
	var fur := Color("8a8d92")
	var kinds: Array[String] = ["", "wolf", "boar", "tiger", "snake", "bird"]
	for a in kinds.size():
		for b in range(a + 1, kinds.size()):
			var ia := PixelFigure.beast_frame(fur, 0, kinds[a]).get_image()
			var ib := PixelFigure.beast_frame(fur, 0, kinds[b]).get_image()
			assert_true(ia.get_data() != ib.get_data(), "%s differs from %s" % [kinds[a], kinds[b]])
	assert_true(PixelFigure.beast_frame(fur, 0, "wolf") == PixelFigure.beast_frame(fur, 0, "wolf"), "cached per kind")


func test_stage_is_taller_and_report_fits_720() -> void:
	assert_true(DuelStage.STAGE_HEIGHT >= 130.0)
	var r := _report()
	var long_lines := PackedStringArray()
	for i in 30:
		long_lines.append("You strike for 5.")
	r.show_fight("Wild Boar", true, long_lines, "", PackedStringArray(), TRACE, 20, 10, false, "", "wild_boar", ["beast"])
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(r.get_combined_minimum_size().y <= 720.0, "report fits 1280x720: %s" % r.get_combined_minimum_size().y)
	r.free()


func test_foe_name_label() -> void:
	var r := _report()
	r.show_fight("Wild Boar", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, false, "", "wild_boar", ["beast"])
	assert_eq(r._foe_name.text, "Wild Boar")
	assert_eq(r._you_name.text, "You")
	r.free()


func test_backdrop_silhouettes() -> void:  # GFX-035
	assert_eq(DuelStage.silhouette_for("misty_forest"), "pines")
	assert_eq(DuelStage.silhouette_for("qingshi_village"), "roofs")
	assert_eq(DuelStage.silhouette_for("withered_bone_marsh"), "reeds")
	assert_eq(DuelStage.silhouette_for("nowhere"), "hills")
	assert_eq((DuelStage.sky_colors("winter") as Array).size(), 2)


func test_stage_is_taller() -> void:  # GFX-035
	assert_true(DuelStage.STAGE_HEIGHT >= 130.0 * 1.4)
	assert_eq(DuelStage.new().custom_minimum_size.y, DuelStage.STAGE_HEIGHT)
