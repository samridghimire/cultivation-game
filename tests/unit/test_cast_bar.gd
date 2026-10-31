extends TestCase
## WU-412: the fishing timing bar (CastBar) and the auto-cast setting.


func test_quality_for_zone_edges() -> void:
	assert_eq(CastBar.quality_for(0.5, 0.5, 0.2), 1.0)
	assert_eq(CastBar.quality_for(0.6, 0.5, 0.2), 1.0, "right edge")
	assert_eq(CastBar.quality_for(0.4, 0.5, 0.2), 1.0, "left edge")
	assert_eq(CastBar.quality_for(0.7, 0.5, 0.2), 0.5, "near")
	assert_eq(CastBar.quality_for(0.8, 0.5, 0.2), 0.5, "near edge")
	assert_eq(CastBar.quality_for(0.9, 0.5, 0.2), 0.0, "far")
	assert_eq(CastBar.quality_for(0.0, 0.5, 0.2), 0.0)


func test_zone_center_is_seeded_in_range() -> void:
	var a := CastBar.zone_center_from(seeded_rng(5))
	var b := CastBar.zone_center_from(seeded_rng(5))
	assert_eq(a, b)
	for i in 50:
		var c := CastBar.zone_center_from(seeded_rng(i))
		assert_true(c >= 0.2 and c <= 0.8, "center %f" % c)


func test_outcome_lines() -> void:
	assert_eq(CastBar.outcome_text(1.0, false), "A clean strike!")
	assert_eq(CastBar.outcome_text(0.5, false), "A fair cast.")
	assert_eq(CastBar.outcome_text(0.0, false), "You strike too late.")


func test_strike_fishes_with_the_quality() -> void:
	var bar := CastBar.new()
	_session()
	bar.open_for([{"item": "", "weight": 1}], 1, "pond", seeded_rng(3))
	bar.marker = bar.zone_center
	var xp: int = _gs().player.fishing_xp
	bar.strike()
	assert_false(bar.visible)
	assert_eq(_gs().player.fishing_xp, xp + 1, "the trip counted")
	bar.free()


func test_three_sweeps_is_a_miss() -> void:
	var bar := CastBar.new()
	_session()
	bar.open_for([{"item": "", "weight": 1}], 1, "pond", seeded_rng(3))
	var guard := 0
	while bar.visible and guard < 100:
		bar.advance(0.5)
		guard += 1
	assert_false(bar.visible, "timed out")
	assert_eq(bar.sweeps_done, CastBar.SWEEPS)
	bar.free()


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _session() -> void:
	_gs().start_session(CharacterFactory.create("Angler", _gs().data, seeded_rng(1)))


func test_auto_cast_default_off() -> void:
	assert_eq(SettingsScript_defaults()["auto_cast"], false)
	assert_eq(Settings.sanitize("auto_cast", "yes"), false)


func SettingsScript_defaults() -> Dictionary:
	return preload("res://src/autoload/settings.gd").DEFAULTS
