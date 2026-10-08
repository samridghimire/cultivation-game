extends TestCase
## WU-058: NPCs bob and shuffle near home without touching the shared rng.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func _npc(id: String, pos: Vector2) -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var n: Node = NPC_SCRIPT.new()
	n.npc_id = id
	n.position = pos
	root.add_child(n)
	return n


func test_stays_within_ten_pixels_of_home() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var state: int = gs.rng.state
	var n := _npc("idle_a", Vector2(300, 200))
	var moved := false
	for i in 600:
		n.breathe(1.0 / 60.0)
		assert_true(n.position.distance_to(Vector2(300, 200)) <= 10.0, "step %d" % i)
		moved = moved or n.position != Vector2(300, 200)
	assert_true(moved)
	assert_eq(n.home, Vector2(300, 200))
	assert_eq(gs.rng.state, state)
	n.free()


func test_phases_differ_and_are_deterministic() -> void:
	var a := _npc("idle_a", Vector2.ZERO)
	var b := _npc("idle_b", Vector2.ZERO)
	var a2 := _npc("idle_a", Vector2.ZERO)
	assert_true(a._phase != b._phase)
	assert_eq(a._phase, a2._phase)
	a.free()
	b.free()
	a2.free()


func test_holds_still_while_modal_open() -> void:
	var n := _npc("idle_a", Vector2(50, 50))
	EventBus_emit(true)
	n._physics_process(2.0)
	assert_eq(n.position, Vector2(50, 50))
	EventBus_emit(false)
	n._physics_process(2.0)
	assert_true(n.position != Vector2(50, 50))
	n.free()


func EventBus_emit(open: bool) -> void:
	(Engine.get_main_loop() as SceneTree).root.get_node("EventBus").ui_modal_changed.emit(open)
