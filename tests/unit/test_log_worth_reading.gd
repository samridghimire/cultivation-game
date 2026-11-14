extends TestCase
## LOG-003: the log forecasts only what a plan needs, and skips the mission intro the combat report repeats.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _omen(key: String) -> Dictionary:
	var out: Dictionary = {}
	for o: Dictionary in data().almanac.get("omens", []):
		if (o.get("boost", {}) as Dictionary).has(key):
			return o
	return out


func _plain() -> Dictionary:
	for o: Dictionary in data().almanac.get("omens", []):
		if Almanac.is_plain(o):
			return o
	return {}


func _task_day() -> int:
	return 5  # spring of year 1: has a catch task


func test_flavour_omen_never_matters() -> void:
	var c := new_character()
	assert_false(Almanac.matters_for_tasks(_plain(), c, data(), 5))
	assert_false(Almanac.matters_for_tasks(_omen("gift_favor"), c, data(), 5))
	assert_false(Almanac.matters_for_tasks(_omen("practice_mult"), c, data(), 5))


func test_fishing_omen_matters_only_with_an_open_catch_task() -> void:
	var c := new_character()
	var day := -1
	for d in range(0, 360, 30):
		if SeasonTasks.has_open(c, data(), d, "catch"):
			day = d
			break
	assert_true(day != -1, "some season has a catch task")
	assert_true(Almanac.matters_for_tasks(_omen("fishing_mult"), c, data(), day))
	# finish every catch task of that season: the omen no longer matters
	var st := {"season_key": SeasonTasks.season_key(day), "progress": {}, "done": false}
	for t: Dictionary in SeasonTasks.tasks_for(data(), day):
		st["progress"][String(t["id"])] = int(t["count"])
	c.season_tasks = st
	assert_false(Almanac.matters_for_tasks(_omen("fishing_mult"), c, data(), day))


func test_has_open_does_not_reset_the_season_record() -> void:
	var c := new_character()
	c.season_tasks = {"season_key": "old", "progress": {"x": 1}, "done": false}
	SeasonTasks.has_open(c, data(), 100, "catch")
	assert_eq(String(c.season_tasks["season_key"]), "old")


func test_dawn_posts_tomorrows_flavour_omen_not_at_all() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Sage", gs.data, seeded_rng())
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var salt := Almanac.salt_of(c)
	var day := -1
	for d in range(5, 400):
		var o := Almanac.omen_for(gs.data, d + 1, salt)
		var k := Almanac.boost_key(o)
		if k in ["gift_favor", "practice_mult", "sell_mult"] and Almanac.is_plain(Almanac.omen_for(gs.data, d, salt)) \
				and VillageCalendar.reminders(gs.data, gs.npcs, gs.npc_favor, gs.world_events, "qingshi_village", d, c, gs.world_flags).is_empty():
			day = d
			break
	assert_true(day != -1)
	GameClock.total_days = day
	gs._last_reminder_day = -1
	var heard: Array[String] = []
	var cb := func(text: String, _cat: String) -> void: heard.append(text)
	EventBus.message_posted.connect(cb)
	gs._post_reminders()
	EventBus.message_posted.disconnect(cb)
	assert_eq(heard.filter(func(t: String) -> bool: return t.begins_with("Tomorrow:")).size(), 0, str(heard))
	assert_true(String(gs.today_omen(1).get("name", "")) != "", "the omen still exists for Today and the journal")
	gs.end_session()


func test_mission_intro_skipped_when_the_report_opens() -> void:
	var gs: Node = _root().get_node("GameState")
	for shown in [true, false]:
		var c := CharacterFactory.create("Disciple", gs.data, seeded_rng())
		gs.start_session(c)
		c.realm_index = 1
		c.stage = 1
		gs.join_sect("azure_cloud_sect")
		var wolf: Dictionary = gs.data.enemies["mist_wolf"]
		wolf["hp"] = 1
		wolf["attack"] = 0
		gs.combat_report_shown = shown
		var heard: Array[String] = []
		var cb := func(text: String, _cat: String) -> void: heard.append(text)
		EventBus.message_posted.connect(cb)
		gs.take_mission("cull_mist_wolves")
		EventBus.message_posted.disconnect(cb)
		gs.combat_report_shown = false
		assert_eq(heard.filter(func(t: String) -> bool: return t.contains("You face")).size(), 0 if shown else 1, "report shown: %s" % shown)
		assert_gt(heard.size(), 0, "the outcome line is still posted")
		gs.end_session()


## C-360: every non-plain omen has an `eve` forecast text and the joined Tomorrow line uses it.
func test_eve_texts_validate_and_feed_the_joined_line() -> void:
	var d := data()
	for o: Dictionary in d.almanac["omens"]:
		if Almanac.is_plain(o):
			continue
		var e := String(o.get("eve", ""))
		assert_true(e != "" and e.length() <= 60, "%s eve" % o["id"])
		assert_eq(Almanac.eve_of(o), e)
	assert_eq(Almanac.eve_of({"name": "Good Day"}), "good day")
	var bad := data()
	bad.almanac["omens"][2]["eve"] = "x".repeat(61)
	assert_gt(Almanac.validate(bad).size(), 0)
	var fish := _omen("fishing_mult")
	var lines := VillageCalendar.dawn_lines(PackedStringArray(), "", PackedStringArray(["Tomorrow: market day in Fallen Star Market.", "Tomorrow: %s." % Almanac.eve_of(fish)]))
	assert_true(String(lines[0]["text"]).ends_with(" and %s." % String(fish["eve"])), str(lines))
