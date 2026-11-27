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
