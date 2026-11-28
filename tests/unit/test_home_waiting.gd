extends TestCase
## WU-644: the Qingshi arrival banner lists up to three lines of what waits after 30+ days away.

const HUD := preload("res://src/ui/hud.gd")


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Homebody", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


func test_nothing_after_a_short_trip_or_when_nothing_waits() -> void:
	var gs := _gs()
	var c := _start()
	c.friend_news["xiao_ling"] = {"kind": "qi_start", "realm": "Qi Refining", "day": 0, "told": false}
	assert_true(Guidance.home_waiting_lines(c, gs.data, gs.npcs, 5, 10).is_empty(), "short trip")
	c.friend_news.clear()
	c.field_plots.clear()
	var lines := Guidance.home_waiting_lines(c, gs.data, gs.npcs, 5, 40)
	for l in lines:
		assert_false(String(l).contains("ripe"), l)
		assert_false(String(l).contains("news"), l)


func test_lines_capped_and_ripe_plot_counted() -> void:
	var gs := _gs()
	var c := _start()
	c.friend_news["xiao_ling"] = {"kind": "qi_start", "realm": "Qi Refining", "day": 5, "told": false}
	c.field_plots["qingshi_village:Field"] = {"crops": [{"item": "x", "days_left": 0}, {"item": "x", "days_left": 0}]}
	var lines := Guidance.home_waiting_lines(c, gs.data, gs.npcs, 6, 45)
	assert_true(lines.size() <= Guidance.HOME_LINES_MAX, "max three")
	var joined := "\n".join(lines)
	assert_true(joined.contains("2 crops ripe"), joined)


func test_hud_text_only_for_qingshi() -> void:
	var flags := {"home_lines": ["A", "B", "C", "D"]}
	assert_eq(HUD.home_lines_text(flags, "azure_peak"), "")
	assert_eq(HUD.home_lines_text(flags, SeasonTasks.REGION), "A\nB\nC")
	assert_eq(HUD.home_lines_text({}, SeasonTasks.REGION), "")


func test_note_home_lines_uses_the_left_day_flag() -> void:
	var gs := _gs()
	var c := _start()
	c.field_plots["qingshi_village:Field"] = {"crops": [{"item": "x", "days_left": 0}]}
	gs.current_region = SeasonTasks.REGION
	gs.world_flags["home_left_day"] = GameClock.total_days - 3
	gs._note_home_lines()
	assert_false(gs.world_flags.has("home_lines"), "3 days is a short trip")
	gs.world_flags["home_left_day"] = GameClock.total_days - 50
	gs._note_home_lines()
	assert_true(gs.world_flags.has("home_lines"))
	assert_false(gs.world_flags.has("home_left_day"), "cleared once home")


func test_leaving_home_by_any_road_is_noted() -> void:
	var gs := _gs()
	var c := _start()
	c.field_plots["qingshi_village:Field"] = {"crops": [{"item": "x", "days_left": 0}]}
	gs.current_region = SeasonTasks.REGION
	gs.world_flags.erase("home_left_day")
	gs._set_region("azure_peak")  # an anchor or respawn moves the player without travel()
	assert_true(gs.world_flags.has("home_left_day"), "left Qingshi")
	gs.world_flags["home_left_day"] = GameClock.total_days - 30
	gs._set_region(SeasonTasks.REGION)
	assert_true(gs.world_flags.has("home_left_day"), "arriving does not clear it by itself")
	gs._note_home_lines()
	assert_true(gs.world_flags.has("home_lines"), "30 days away, then home")


func test_waiting_season_line_names_days_left() -> void:
	var gs := _gs()
	var c := _start()
	var today := 10
	var lines := Guidance.home_waiting(c, gs.data, gs.npcs, today)
	var left := Calendar.days_left_in_season(today)
	var found := false
	for l in lines:
		if String(l).begins_with("Season tasks"):
			found = true
			assert_true(String(l).ends_with("(%d %s left)" % [left, "day" if left == 1 else "days"]), l)
	assert_true(found, str(lines))


## C-433: a friend with favor >= 25 welcomes you home first; none below 25; the line is in their voice.
func test_welcome_home_line_comes_from_the_best_friend() -> void:
	var gs := _gs()
	_start()
	gs.current_region = SeasonTasks.REGION
	gs.npc_favor.clear()
	gs.world_flags["home_left_day"] = GameClock.total_days - 40
	gs._note_home_lines()
	assert_eq(Folk.welcome_home_line(gs.data, gs.npc_favor, "P", 5, 40), "", "nobody fond enough")
	gs.npc_favor["hunter_ma"] = 30
	gs.npc_favor["xiao_ling"] = 60
	gs.world_flags["home_left_day"] = GameClock.total_days - 40
	gs._note_home_lines()
	var first := String(gs.world_flags["home_lines"][0])
	var ok := false
	for l: String in gs.data.npcs["xiao_ling"]["welcome_home_lines"]:
		ok = ok or first == l.replace("{player}", gs.player.name).replace("{days}", "40")
	assert_true(ok, first)
	assert_true(gs.world_flags["home_lines"].size() <= Guidance.HOME_LINES_MAX)


func test_welcome_home_lines_validation() -> void:
	var d := data()
	var mo: Array = d.npcs["elder_mo"]["welcome_home_lines"]
	var ma: Array = d.npcs["hunter_ma"]["welcome_home_lines"]
	d.npcs["elder_mo"]["welcome_home_lines"] = ["a", "b", "c"]
	d.npcs["hunter_ma"]["welcome_home_lines"] = ["x".repeat(121)]
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	d.npcs["elder_mo"]["welcome_home_lines"] = mo
	d.npcs["hunter_ma"]["welcome_home_lines"] = ma
	d.load_errors.clear()
	assert_true(text.contains("'elder_mo' welcome_home_lines needs 1-2"), text)
	assert_true(text.contains("'hunter_ma' welcome_home_lines entries"), text)
