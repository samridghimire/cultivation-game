extends TestCase
## GFX-219: villagers at their work: validation, frame clock, a working NPC stays at home.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func test_frame_alternates_and_reduced_pins_zero() -> void:
	assert_eq(WorkProps.frame_at(0.0, 0.0, false), 0)
	assert_eq(WorkProps.frame_at(0.7, 0.0, false), 1)
	assert_eq(WorkProps.frame_at(1.3, 0.0, false), 0)
	for t in 20:
		assert_eq(WorkProps.frame_at(float(t) * 0.37, 0.5, true), 0)


func test_validation_rejects_unknown_activity() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.load_errors.size(), 0, ", ".join(data.load_errors))
	data.npcs["elder_mo"]["activity"] = "juggle"
	data.regions["qingshi_village"]["places"][0]["activity"] = "dance"
	data.load_errors.clear()
	data._validate_world()
	var text := ", ".join(data.load_errors)
	assert_true(text.contains("NPC 'elder_mo' has unknown activity 'juggle'"), text)
	assert_true(text.contains("unknown activity 'dance'"), text)


func test_tagged_villagers_exist() -> void:
	var data := GameData.load_from_dir()
	var n := 0
	for r: Dictionary in data.regions.values():
		for p: Dictionary in r.get("places", []):
			if p.has("activity"):
				n += 1
	for npc: Dictionary in data.npcs.values():
		if npc.has("activity"):
			n += 1
	assert_true(n >= 12, "about 12 villagers work: %d" % n)


func test_working_npc_stays_home() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var n: Node = NPC_SCRIPT.new()
	n.npc_id = "elder_mo"
	n.position = Vector2(300, 200)
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	if gs.data != null and gs.data.npcs.has("elder_mo"):
		assert_eq(n.activity, "read")
	n.activity = "read"
	var frames := {}
	for i in 600:
		n.breathe(1.0 / 60.0)
		assert_eq(n.position, n.home)
		frames[n._work_frame] = true
	assert_eq(frames.size(), 2, "the prop frame alternates")
	n.free()
