extends TestCase
## ART-003b: the artifact's Inner World.


func _cultivator() -> CharacterData:
	var c := new_character()
	c.spiritual_roots = {"fire": 70}
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.stage = 0
	c.qi = 0.0
	return c


func test_real_def_is_valid() -> void:
	assert_eq(InnerWorld.validate(data()).size(), 0)
	assert_false(InnerWorld.def(data()).is_empty())


func test_sealed_and_bounds() -> void:
	var c := _cultivator()
	assert_true(InnerWorld.check_enter(c, data(), 30).contains("sealed"))
	c.artifact_functions.append(InnerWorld.FUNCTION)
	assert_eq(InnerWorld.check_enter(c, data(), 30), "")
	assert_true(InnerWorld.check_enter(c, data(), InnerWorld.max_days(data()) + 1) != "")
	assert_true(InnerWorld.check_enter(c, data(), 0) != "")


func test_cultivation_is_dilated_and_ages_the_body() -> void:
	var c := _cultivator()
	c.artifact_functions.append(InnerWorld.FUNCTION)
	var twin := _cultivator()
	var age := c.age_days
	var result := InnerWorld.cultivate(c, data(), 30)
	assert_true(result["ok"], result["reason"])
	assert_eq(int(result["inner_days"]), 30 * int(InnerWorld.def(data())["dilation"]))
	assert_eq(c.age_days - age, int(result["inner_days"]) - 30, "the extra inner days age you (world days are passed by the caller)")
	var outside := Cultivation.cultivate(twin, data(), 30, 1.0)
	assert_gt(float(result["qi_gained"]), float(outside["qi_gained"]) * 2.0, "faster than a month at an ordinary spot")


func test_game_state_enter_inner_world() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var clock := (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	var c := _cultivator()
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.qi = 0.0
	gs.enter_inner_world(30)
	assert_eq(c.qi, 0.0, "sealed: nothing happens")
	c.artifact_functions.append(InnerWorld.FUNCTION)
	var day: int = clock.total_days
	gs.enter_inner_world(30)
	assert_eq(clock.total_days - day, 30)
	assert_gt(c.qi + c.stage * 1000000.0, 0.0)
	var screen := ArtifactScreen.new()
	screen.open()
	assert_true(screen.buttons().any(func(b: Button) -> bool: return b.name == "inner_world" and not b.disabled))
	screen.free()
	gs.end_session()
