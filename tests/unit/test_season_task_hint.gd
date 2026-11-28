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


func _finish_gathers(c: CharacterData, day: int) -> void:
	for t: Dictionary in SeasonTasks.tasks_for(_gs().data, day):
		if String(t["kind"]) != "hunt":
			SeasonTasks.note(c, _gs().data, String(t["kind"]), String(t["target"]), int(t["count"]), day)


## GUIDE-300: with only the hunt left the line names the foe's odds, or says it is too strong.
func test_hunt_line_shows_odds_or_too_strong() -> void:
	var c := _start()
	var gs := _gs()
	_finish_gathers(c, 3)
	var line := Guidance.season_task_hint(c, gs.data, "qingshi_village", 3)
	assert_true(line.begins_with("Season task: "), line)
	assert_true(line.contains(" in 100) (0/"), line)
	var t: Dictionary = {}
	for x: Dictionary in SeasonTasks.tasks_for(gs.data, 3):
		if String(x["kind"]) == "hunt":
			t = x
	var enemy: Dictionary = gs.data.enemies[String(t["target"])]
	var chance := Combat.win_chance(c, gs.data, enemy)
	if chance >= 0.4:
		assert_true(line.contains(Combat.odds_word(chance)), line)
	c.realm_index = 0
	c.stage = 0
	var strong: Dictionary = gs.data.enemies["fog_antler_stag"]
	var old: Dictionary = gs.data.enemies[String(t["target"])]
	gs.data.enemies[String(t["target"])] = strong
	var hard := Guidance.season_task_hint(c, gs.data, "qingshi_village", 3)
	gs.data.enemies[String(t["target"])] = old
	if Combat.win_chance(c, gs.data, strong) < 0.4:
		assert_true(hard.contains("too strong for now: "), hard)


func test_days_left_suffix_near_season_end() -> void:
	var c := _start()
	var gs := _gs()
	_finish_gathers(c, 3)
	assert_false(Guidance.season_task_hint(c, gs.data, "qingshi_village", 3).contains("left in"))
	var late := 80
	var left := Calendar.days_left_in_season(late)
	assert_true(left <= 21)
	_finish_gathers(c, late)
	var line := Guidance.season_task_hint(c, gs.data, "qingshi_village", late)
	assert_true(line.ends_with("%d days left in %s" % [left, Calendar.season_of(late).to_lower()]) or line == "", line)


func _day_of(season: String) -> int:
	for d in range(0, 400):
		if Calendar.season_of(d) == season and Calendar.year_of(d) == Calendar.year_of(3):
			return d + 10
	return -1


## SIM-047: with catch/gather/hunt done, an open contest or sell_wanted task is named with where it is served.
func test_contest_and_sell_wanted_tasks_are_named() -> void:
	var gs := _gs()
	for season: String in ["Summer", "Autumn", "Winter"]:
		var c := _start()
		var day := _day_of(season)
		var other := ""
		for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
			if ["contest", "sell_wanted"].has(String(t["kind"])):
				other = String(t["kind"])
			else:
				SeasonTasks.note(c, gs.data, String(t["kind"]), String(t["target"]), int(t["count"]), day)
		if other == "":
			continue
		var line := Guidance.season_task_hint(c, gs.data, "qingshi_village", day)
		var where := ""
		for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
			if String(t["kind"]) == other:
				where = SeasonTasks.where(t, c, gs.data, day)
		if where == "":
			assert_eq(line, "", "%s: no place serves it, no line" % season)
		else:
			assert_true(line.begins_with("Season task: ") and line.contains(where) and line.contains("(0/"), line)
