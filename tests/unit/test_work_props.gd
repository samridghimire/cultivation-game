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


## GFX-224: every activity used in data/npcs.json draws both frames without error.
class _Canvas extends Node2D:
	var activity := ""
	var frame := 0
	var drawn := 0

	func _draw() -> void:
		WorkProps.draw(self, activity, frame, Vector2(40, 40), 2.0)
		drawn += 1


func test_every_used_activity_draws_both_frames() -> void:
	var data := GameData.load_from_dir()
	var used := {"sit": true}
	for npc: Dictionary in data.npcs.values():
		if npc.has("activity"):
			used[String(npc["activity"])] = true
	for r: Dictionary in data.regions.values():
		for p: Dictionary in r.get("places", []):
			if p.has("activity"):
				used[String(p["activity"])] = true
	var c := _Canvas.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	for act: String in used.keys():
		assert_true(WorkProps.is_valid(act), act)
		for f in 2:
			c.activity = act
			c.frame = f
			var before := c.drawn
			c.queue_redraw()
			await (Engine.get_main_loop() as SceneTree).process_frame
			assert_true(c.drawn > before, "%s frame %d drew" % [act, f])
	c.free()
