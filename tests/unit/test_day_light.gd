extends TestCase
## GFX-217: the day-night curve and the world's day cycle on a time skip.


func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


func test_ends_match_base() -> void:
	var c := Color(0.9, 0.95, 0.8)
	assert_eq(DayLight.tint_at(0.0, c), c)
	assert_eq(DayLight.tint_at(1.0, c), c)


func test_night_darker_than_dusk_darker_than_morning() -> void:
	var c := Color.WHITE
	assert_true(_lum(DayLight.tint_at(0.5, c)) < _lum(DayLight.tint_at(0.35, c)))
	assert_true(_lum(DayLight.tint_at(0.35, c)) < _lum(DayLight.tint_at(0.0, c)))


func test_cycles_and_night() -> void:
	for d in range(0, 41):
		var n := DayLight.cycles_for(d)
		assert_true(n >= 1 and n <= 3, str(d))
	assert_true(DayLight.is_night(0.5))
	assert_false(DayLight.is_night(0.0))
	assert_false(DayLight.is_night(0.2))
	assert_true(DayLight.lamp_strength(0.5) > 0.9)
	assert_eq(DayLight.lamp_strength(0.0), 0.0)


func _world() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	return world


func test_world_cycle_ends_on_season_tint() -> void:
	var settings := (Engine.get_main_loop() as SceneTree).root.get_node("Settings")
	settings.set_value("ambient_effects", true)
	settings.set_value("reduce_motion", false)
	var world := _world()
	EventBus.time_skipped.emit(5, {})
	assert_true(world._day_tween != null)
	for i in 400:
		await (Engine.get_main_loop() as SceneTree).process_frame
		if world._day_tween == null:
			break
	assert_true(world._day_tween == null)
	assert_eq(world._season_tint.color, world._tint_for(world._season))
	world.free()


func test_reduce_motion_never_changes_tint() -> void:
	var settings := (Engine.get_main_loop() as SceneTree).root.get_node("Settings")
	settings.set_value("reduce_motion", true)
	var world := _world()
	EventBus.time_skipped.emit(5, {})
	assert_true(world._day_tween == null)
	world.free()
	settings.set_value("reduce_motion", false)
