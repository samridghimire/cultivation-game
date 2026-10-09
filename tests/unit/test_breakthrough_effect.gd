extends TestCase
## WU-063: the breakthrough effect plays for 1.6 s and never moves the player.

const PLAYER_SCRIPT := preload("res://src/world/player.gd")


func _player() -> Node2D:
	var p: Node2D = PLAYER_SCRIPT.new()
	p.position = Vector2(120, 80)
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	return p


func test_success_effect_runs_then_ends() -> void:
	var p := _player()
	assert_true(not p.is_celebrating())
	p.celebrate(true)
	assert_true(p.is_celebrating())
	for i in 90:
		p._process(1.0 / 60.0)
	assert_true(p.is_celebrating())
	for i in 10:
		p._process(1.0 / 60.0)
	assert_true(not p.is_celebrating())
	p.free()


func test_failure_never_moves_position() -> void:
	var p := _player()
	p.celebrate(false)
	for i in 120:
		p._process(1.0 / 60.0)
		assert_eq(p.position, Vector2(120, 80))
	p.free()


func test_second_call_restarts_timer() -> void:
	var p := _player()
	p.celebrate(true)
	for i in 80:
		p._process(1.0 / 60.0)
	p.celebrate(false)
	for i in 80:
		p._process(1.0 / 60.0)
	assert_true(p.is_celebrating())
	p.free()


func test_signal_triggers_effect() -> void:
	var p := _player()
	EventBus.breakthrough_attempted.emit(true, "Qi Refining")
	assert_true(p.is_celebrating())
	p.free()
