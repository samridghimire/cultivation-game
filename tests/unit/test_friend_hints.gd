extends TestCase
## GUIDE-294: the congratulate and meditate-beside lines in the Next steps appear only when their helpers allow them.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Hinty", gs.data, seeded_rng(88))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	c.home_region = "qingshi_village"
	gs.current_region = "qingshi_village"
	return c


func _hints(c: CharacterData, short: bool = false) -> PackedStringArray:
	var gs := _gs()
	return Guidance.hints(c, gs.data, 1.0, 12, gs.npcs, gs.world_flags, gs.current_region, GameClock.total_days, gs.npc_favor, short)


func _has_prefix(lines: PackedStringArray, prefix: String) -> String:
	for l in lines:
		if l.begins_with(prefix):
			return l
	return ""


func test_congratulate_line_only_with_fresh_news() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["xiao_ling"] = 50
	assert_eq(_has_prefix(_hints(c), "Congratulate "), "")
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	var line := _has_prefix(_hints(c), "Congratulate ")
	assert_true(line.begins_with("Congratulate %s on Qi Refining (" % gs.npcs["xiao_ling"].name) and line.ends_with(" days left)"), line)
	assert_eq(_has_prefix(_hints(c, true), "Congratulate "), "Congratulate %s" % gs.npcs["xiao_ling"].name)
	gs.congratulate("xiao_ling")
	assert_eq(_has_prefix(_hints(c), "Congratulate "), "", "gone once congratulated")


func test_meditation_line_names_the_family_percent() -> void:
	var c := _start()
	var gs := _gs()
	var npc: CharacterData = gs.npcs["xiao_ling"]
	npc.realm_index = 1
	gs.npc_favor["xiao_ling"] = 10
	assert_eq(_has_prefix(_hints(c), "Meditate beside "), "", "not a friend yet")
	gs.npc_favor["xiao_ling"] = 60
	var rules := Folk.meditation_rules(gs.data)
	var line := _has_prefix(_hints(c), "Meditate beside ")
	if Folk.meditation_block(c, gs.data, npc, 60, gs.world_flags, gs.current_region, GameClock.total_days) != "":
		assert_eq(line, "", "no line when the helper refuses")
		return
	assert_true(line.contains("+%d%% qi for %d days" % [roundi((float(rules["qi_mult"]) - 1.0) * 100.0), int(rules["days"])]), line)
	assert_eq(_has_prefix(_hints(c, true), "Meditate beside "), "")
	assert_true(_hints(c, true).has("Sit with %s" % npc.name) or _has_prefix(_hints(c, true), "Meditate beside ") != "", "short form")
	# the hinted meditation is takeable
	var before := c.last_meditated_day
	gs.meditate_with_friend("xiao_ling", 1.0)
	assert_true(int(gs.world_flags.get("friend_med_xiao_ling", -1)) >= 0, "sat together")
	assert_eq(_has_prefix(_hints(c), "Meditate beside "), "", "cooldown hides the line")
	assert_true(c.last_meditated_day >= before)
