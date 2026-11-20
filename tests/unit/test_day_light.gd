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


func test_night_is_blue_dusk_is_warm() -> void:
	var n := DayLight.tint_at(0.5, Color.WHITE)
	assert_true(n.b > n.r + 0.3 and n.b > n.g + 0.25)
	var d := DayLight.tint_at(0.35, Color.WHITE)
	assert_true(d.r > d.b)


func test_plays_cycle_rule() -> void:
	assert_true(DayLight.plays_cycle(3, false, true))
	assert_false(DayLight.plays_cycle(0, false, true))
	assert_false(DayLight.plays_cycle(3, true, true))
	assert_false(DayLight.plays_cycle(3, false, false))


func _lm(kind: String) -> Dictionary:
	return {"kind": kind, "pos": [100, 100], "size": [40, 40]}


func _pl(type: String) -> Dictionary:
	return {"type": type, "pos": [200, 200], "size": [70, 60]}


func test_night_glow_places_and_cap() -> void:
	var g := NightGlow.new()
	g.setup([_lm("house")], [_pl("workshop"), _pl("merchant"), _pl("explore")])
	assert_eq(g.spot_count(), 4)
	var many: Array = []
	for i in 60:
		many.append(_pl("clinic"))
	g.setup([], many)
	assert_eq(g.spot_count(), 40)
	g.free()


func test_overlay_dim_follows_cycle() -> void:
	var o := TimeSkipOverlay.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(o)
	o.show_skip({"title": "Resting", "days": 3, "lines": []}, false)
	assert_true(absf(o._dim.color.a - 0.45) < 0.001)
	o.show_skip({"title": "Resting", "days": 3, "lines": []}, true)
	assert_true(absf(o._dim.color.a - 0.25) < 0.001)
	o.queue_free()
