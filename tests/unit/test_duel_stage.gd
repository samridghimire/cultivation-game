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
