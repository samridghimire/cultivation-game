extends TestCase
## GUIDE-296: an open catch/gather season task a Qingshi place serves shows in the first four Next steps until done.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Seasonal", gs.data, seeded_rng(96))
	gs.start_session(c)
	c.home_region = "qingshi_village"
	gs.current_region = "qingshi_village"
	return c


func _hints(c: CharacterData, region: String, day: int) -> PackedStringArray:
	var gs := _gs()
	return Guidance.hints(c, gs.data, 1.0, 12, gs.npcs, gs.world_flags, region, day, gs.npc_favor)


func _index(lines: PackedStringArray) -> int:
	for i in lines.size():
		if lines[i].begins_with("Season task: "):
			return i
	return -1


func test_open_task_in_first_three_then_gone_when_done() -> void:
	var c := _start()
	var gs := _gs()
	var lines := _hints(c, "qingshi_village", 3)
	var i := _index(lines)
	assert_true(i >= 0 and i < 4, "season line among the first 4: %s" % str(lines))
	assert_eq(_index(_hints(c, "withered_bone_marsh", 3)), -1)
	var tasks := SeasonTasks.tasks_for(gs.data, 3)
	for t: Dictionary in tasks:
		SeasonTasks.note(c, gs.data, String(t["kind"]), String(t["target"]), int(t["count"]), 3)
	assert_eq(_index(_hints(c, "qingshi_village", 3)), -1)


func test_hint_empty_without_day_or_in_other_region() -> void:
	var c := _start()
	assert_eq(Guidance.season_task_hint(c, _gs().data, "qingshi_village", -1), "")
	assert_eq(Guidance.season_task_hint(c, _gs().data, "withered_bone_marsh", 3), "")
