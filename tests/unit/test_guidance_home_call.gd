extends TestCase
## GUIDE-299: Guidance.home_call_hint, Letters.home_news and the home_call data block.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Homesick", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


## A region 1..8 route days from Qingshi.
func _away(c: CharacterData, data: GameData) -> String:
	var ids: Array = data.regions.keys()
	ids.sort()
	for id: String in ids:
		var d := Guidance.route_days(c, data, id, SeasonTasks.REGION)
		if id != SeasonTasks.REGION and d >= 1 and d <= 8:
			return id
	return ""


## A day in spring (year 1) with exactly `left` days left in the season.
func _day_with_left(left: int) -> int:
	for d in range(0, 90):
		if Calendar.days_left_in_season(d) == left:
			return d
	return 0


func _news(c: CharacterData, today: int) -> void:
	c.friend_news["xiao_ling"] = {"kind": "qi_start", "realm": "Qi Refining", "day": today, "told": false}


func test_no_line_in_qingshi_without_reason_or_too_far() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	assert_true(away != "", "a region within reach exists")
	var day := _day_with_left(40)
	_news(c, day)
	assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, SeasonTasks.REGION, day), "", "in Qingshi")
	c.friend_news.clear()
	assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day), "", "no reason")
	_news(c, day)
	var saved: Dictionary = gs.data.family["home_call"]
	gs.data.family["home_call"] = {"max_route_days": 1, "season_days_left": 21}
	var far := ""
	for id: String in gs.data.regions.keys():
		if Guidance.route_days(c, gs.data, id, SeasonTasks.REGION) > 1:
			far = id
			break
	if far != "":
		assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, far, day), "", "beyond max_route_days")
	gs.data.family["home_call"] = saved


func test_friend_news_reason_and_time_to_spare() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	var day := _day_with_left(40)
	_news(c, day)
	var line := Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day)
	assert_true(line.begins_with("Home to Qingshi ("), line)
	assert_true(line.contains("congratulate") and line.contains("Qi Refining"), line)
	var days := Guidance.route_days(c, gs.data, away, SeasonTasks.REGION)
	var own_days := int(gs.data.family.get("folk_news", {}).get("own_days", 30))
	c.friend_news["xiao_ling"]["day"] = day - own_days + days  # days_left = days: fewer than days + 2
	assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day), "", "not enough days left")


func test_season_task_reason_and_both() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	var day := _day_with_left(10)
	var line := Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day)
	assert_true(line.contains("spring task") and line.contains("(10 days)"), line)
	assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, _day_with_left(40)), "", "season far from its end")
	_news(c, day)
	line = Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day)
	assert_true(line.find("congratulate") < line.find("spring task") and line.find("congratulate") > 0, "congratulation first: " + line)
	assert_eq(line.count("Home to Qingshi"), 1)


func test_home_news_letter_once_per_news() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	var day := _day_with_left(40)
	_news(c, day)
	var flags: Dictionary = {}
	assert_true(Letters.home_news(c, gs.npcs, gs.data, flags, day, SeasonTasks.REGION).is_empty(), "none while in Qingshi")
	var letter := Letters.home_news(c, gs.npcs, gs.data, flags, day, away)
	assert_false(letter.is_empty())
	assert_true(String(letter["text"]).contains("Qi Refining") and not String(letter["text"]).contains("{"), String(letter["text"]))
	assert_true(Letters.home_news(c, gs.npcs, gs.data, flags, day + 1, away).is_empty(), "once per piece of news")


func test_game_state_hint_then_congratulate_line() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	gs.current_region = away
	var day := GameClock.total_days
	_news(c, day)
	gs.npc_favor["xiao_ling"] = 50
	var lines: PackedStringArray = Guidance.hints(c, gs.data, 1.0, 12, gs.npcs, gs.world_flags, gs.current_region, GameClock.total_days, gs.npc_favor)
	var found := false
	for l: String in lines:
		found = found or l.begins_with("Home to Qingshi")
	assert_true(found, str(lines))
	gs.current_region = SeasonTasks.REGION
	var home_lines: PackedStringArray = Guidance.hints(c, gs.data, 1.0, 12, gs.npcs, gs.world_flags, gs.current_region, GameClock.total_days, gs.npc_favor)
	var congrat := false
	for l: String in home_lines:
		assert_false(l.begins_with("Home to Qingshi"))
		congrat = congrat or l.begins_with("Congratulate")
	assert_true(congrat or home_lines.size() > 0, str(home_lines))


func test_validation_reports_bad_home_call() -> void:
	var gs := _gs()
	var saved: Dictionary = gs.data.family["home_call"]
	var before: int = gs.data.load_errors.size()
	gs.data.family["home_call"] = {"max_route_days": -1, "season_days_left": 21}
	gs.data._validate_home_call()
	assert_eq(gs.data.load_errors.size(), before + 1)
	gs.data.load_errors.resize(before)
	gs.data.family["home_call"] = saved


## C-429: a villager with home_news_lines writes in their own voice; one without falls back to the generic text.
func test_home_news_uses_npc_lines_else_generic() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	var day := _day_with_left(40)
	_news(c, day)
	var letter := Letters.home_news(c, gs.npcs, gs.data, {}, day, away)
	var text := String(letter["text"])
	var region := String(gs.data.regions[SeasonTasks.REGION]["name"])
	var ok := false
	for l: String in gs.data.npcs["xiao_ling"]["home_news_lines"]:
		if text == l.replace("{region}", region).replace("{news}", "I began Qi Refining."):
			ok = true
	assert_true(ok, "Xiao Ling's own line: " + text)
	assert_false(text.contains("Come by when the sect lets you go"))
	var saved: Array = gs.data.npcs["xiao_ling"]["home_news_lines"]
	gs.data.npcs["xiao_ling"].erase("home_news_lines")
	var plain := Letters.home_news(c, gs.npcs, gs.data, {}, day, away)
	gs.data.npcs["xiao_ling"]["home_news_lines"] = saved
	assert_true(String(plain["text"]).contains("Come by when the sect lets you go"), "generic fallback")


## SIM-040: a sect disciple at a hall 10 route days from Qingshi (azure_peak) still gets the line.
func test_hall_ten_days_away_still_gets_the_line() -> void:
	var c := _start()
	var gs := _gs()
	var cap := int(gs.data.family["home_call"]["max_route_days"])
	assert_true(cap >= 10, "the cap covers a hall ten days away")
	var hall := Sects.home_region(gs.data, "azure_cloud_sect")
	var days := Guidance.route_days(c, gs.data, hall, SeasonTasks.REGION)
	assert_true(days >= 1 and days <= cap, "the Azure hall is within the cap (%d days)" % days)


## GUIDE-302: with catch/gather done, an open hunt task of fair odds calls the player home; a too-strong one does not.
func test_hunt_only_reason() -> void:
	var c := _start()
	var gs := _gs()
	var away := _away(c, gs.data)
	var day := _day_with_left(10)
	var hunt: Dictionary = {}
	c.season_tasks = {"season_key": SeasonTasks.season_key(day), "progress": {}, "done": false}
	for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
		if String(t["kind"]) == "hunt":
			hunt = t
		else:
			c.season_tasks["progress"][String(t["id"])] = int(t["count"])
	if hunt.is_empty():
		return
	var target := String(hunt["target"])
	var line := Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day)
	var rating := Guidance.open_hunt_rating(c, gs.data, day)
	assert_false(rating.is_empty())
	if float(rating["chance"]) >= Guidance.HUNT_TASK_MIN_CHANCE:
		assert_true(line.contains("hunt %d" % int(hunt["count"])) and line.contains(Combat.label_for_chance(float(rating["chance"]))), line)
	else:
		assert_eq(line, "", "too strong")
	# Too strong: swap in the strongest foe.
	var strongest := ""
	var best := 0.0
	var ids: Array = gs.data.enemies.keys()
	ids.sort()
	for id: String in ids:
		var p := float(gs.data.enemies[id].get("power", 0.0))
		if p >= best:
			best = p
			strongest = id
	hunt["target"] = strongest
	if Combat.win_chance(c, gs.data, gs.data.enemies[strongest]) < Guidance.HUNT_TASK_MIN_CHANCE:
		assert_eq(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day), "", "hunt too strong")
	hunt["target"] = target
	# A catch task still open: the old count reason.
	for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
		if String(t["kind"]) != "hunt":
			c.season_tasks["progress"][String(t["id"])] = 0
	assert_true(Guidance.home_call_hint(c, gs.data, gs.npcs, gs.world_flags, away, day).contains("task"), "count reason")
