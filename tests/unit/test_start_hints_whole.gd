extends TestCase
## GUIDE-284: in each of the six start regions the day-1 Next steps and the goal row read whole:
## no dangling word, no ellipsis, within the short-hint length; the goal fits the HUD goal row.

const HudScript := preload("res://src/ui/hud.gd")
const STARTS: Array[String] = ["qingshi_village", "withered_bone_marsh", "myriad_peaks_ridge", "azure_peak", "fallen_star_market", "misty_forest"]


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _lines_for(region: String) -> Dictionary:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Newcomer", gs.data, seeded_rng(7))
	gs.start_session(c)
	gs.current_region = region
	var clock: Node = _root().get_node("GameClock")
	var hints := Guidance.hints(c, gs.data, gs.hint_density(), 7, gs.npcs, gs.world_flags, region, clock.total_days, gs.npc_favor, true)
	var goal: String = HudScript.goal_text(c, gs.data, gs.world_flags, gs.clan, gs.hint_density(), region, clock.total_days)
	return {"hints": hints, "goal": Guidance.short_goal(goal, gs.data), "raw_goal": goal}


func _dangling(s: String) -> bool:
	var last := s.rstrip(" .:;,-(").get_slice(" ", s.rstrip(" .:;,-(").get_slice_count(" ") - 1).to_lower()
	return Guidance.STOP_WORDS.has(last) or Guidance.DANGLING_WORDS.has(last)


func test_every_start_reads_whole() -> void:
	for region in STARTS:
		var got := _lines_for(region)
		for line: String in got["hints"]:
			assert_false(_dangling(line), "%s: dangling: %s" % [region, line])
			assert_false(line.contains("...") or line.contains("…"), "%s: ellipsis: %s" % [region, line])
			assert_true(line.length() <= Guidance.SHORT_HINT_CHARS + 30, "%s: long (%d): %s" % [region, line.length(), line])
		var goal: String = got["goal"]
		assert_false(_dangling(goal), "%s: goal dangling: %s" % [region, goal])
		assert_false(goal.contains("...") or goal.contains("…"), "%s: goal ellipsis: %s (raw %s)" % [region, goal, got["raw_goal"]])
		var font := ThemeDB.fallback_font
		assert_true(HudScript.wrapped_lines(goal, font, 14, HudScript.GOAL_W).size() <= 2, "%s: goal wraps past 2 rows: %s" % [region, goal])


func test_elder_mo_short_forms() -> void:
	assert_eq(Guidance.short_hint("Ask Elder Mo in Qingshi Village where to begin; he also teaches a breathing technique.", data()), "Ask Elder Mo in Qingshi where to begin")
	assert_eq(Guidance.short_hint("Ask Elder Mo in Qingshi Village where to begin.", data()), "Ask Elder Mo in Qingshi where to begin")


func test_interrogative_cut_is_dangling() -> void:
	for w in ["where", "what", "how", "who", "when", "why", "on", "from", "into", "about", "your", "his", "her", "their"]:
		assert_true(Guidance.DANGLING_WORDS.has(w) or Guidance.STOP_WORDS.has(w), w)
