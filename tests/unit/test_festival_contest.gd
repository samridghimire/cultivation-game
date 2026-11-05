extends TestCase
## FEST-006: festival contests (FestivalContest) and the GameState action.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _npc(name: String, spirit: int) -> CharacterData:
	var n := CharacterData.new()
	n.name = name
	n.attributes = {"comprehension": spirit}
	return n


func test_real_data_is_valid() -> void:
	assert_eq(FestivalContest.validate(data()).size(), 0, ", ".join(FestivalContest.validate(data())))
	for id in ["lantern_festival", "mid_autumn_festival", "qingming_festival"]:
		assert_false(FestivalContest.contest_of(data(), id).is_empty(), id)


func test_validation_catches_bad_contests() -> void:
	var d := GameData.load_from_dir()
	var c: Dictionary = (d.world_events["lantern_festival"]["contest"] as Dictionary).duplicate(true)
	c["attribute"] = "nope"
	c["rivals"] = 5
	c["prizes"] = [{"items": {"no_such_item": 1}}]
	d.world_events["lantern_festival"]["contest"] = c
	assert_eq(FestivalContest.validate(d).size(), 3, ", ".join(FestivalContest.validate(d)))


func test_run_is_deterministic_and_strong_player_wins() -> void:
	var d := data()
	var p := new_character()
	p.attributes["comprehension"] = 30
	var rivals: Array[CharacterData] = [_npc("Mei Lan", 8), _npc("Old Wu", 8), _npc("Ah Ping", 8)]
	var a := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(5))
	var b := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(5))
	assert_eq(a, b)
	for seed_value in 20:
		var r := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(seed_value))
		assert_eq(int(r["place"]), 1)
		assert_false((r["prize"] as Dictionary).is_empty())
	assert_eq(FestivalContest.standings_lines(a).size(), 4)


func test_weak_player_loses_with_winner_named_and_no_prize_past_list() -> void:
	var d := data()
	var p := new_character()
	p.attributes["comprehension"] = 0
	var rivals: Array[CharacterData] = [_npc("Mei Lan", 40), _npc("Old Wu", 40), _npc("Ah Ping", 40)]
	var r := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(1))
	assert_eq(int(r["place"]), 4)
	assert_true((r["prize"] as Dictionary).is_empty())
	assert_false(String(r["text"]).contains("{winner}"))
	assert_true(String(r["text"]).contains(String(r["scores"][0]["name"])))


func test_ties_go_to_the_player() -> void:
	var d := GameData.load_from_dir()
	d.world_events["lantern_festival"]["contest"]["rivals"] = 2
	var p := new_character()
	p.attributes["comprehension"] = 8
	# Same rng draws on both sides cannot be forced, so make scores identical via a huge shared base.
	var rivals: Array[CharacterData] = [_npc("A", 8), _npc("B", 8)]
	for seed_value in 30:
		var r := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(seed_value))
		var mine := 0
		for s: Dictionary in r["scores"]:
			if bool(s["you"]):
				mine = int(s["score"])
		var better := 0
		for s: Dictionary in r["scores"]:
			if int(s["score"]) > mine:
				better += 1
		assert_eq(int(r["place"]), better + 1, "only strictly higher scores beat the player")


func test_check_reasons() -> void:
	var d := data()
	var p := new_character()
	var day := 100
	var active := [{"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}]
	assert_eq(FestivalContest.check(d, active, p, "lantern_festival", "qingshi_village", {}, 1), "")
	assert_true(FestivalContest.check(d, [], p, "lantern_festival", "qingshi_village", {}, 1) != "")
	assert_true(FestivalContest.check(d, active, p, "lantern_festival", "misty_forest", {}, 1) != "")
	assert_true(FestivalContest.check(d, active, p, "beast_tide", "qingshi_village", {}, 1) != "")
	var flags := {FestivalContest.flag_key("lantern_festival", 1): true}
	assert_true(FestivalContest.check(d, active, p, "lantern_festival", "qingshi_village", flags, 1) != "")
	assert_eq(FestivalContest.check(d, active, p, "lantern_festival", "qingshi_village", flags, 2), "")


func test_calendar_names_the_contest() -> void:
	var d := data()
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": 100, "end_day": 108}
	var e := VillageCalendar.upcoming(d, {}, {}, [inst], "qingshi_village", 100, 5)
	var found := false
	for x: Dictionary in e:
		if String(x["text"]).contains("(contest: Lantern riddles)"):
			found = true
	assert_true(found)


func test_game_state_enters_once_a_year() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.player.attributes["comprehension"] = 40
	gs.current_region = "qingshi_village"
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}]
	assert_eq(gs.festival_contest_here(), "lantern_festival")
	var stones: int = gs.player.item_count("spirit_stone")
	var result: Dictionary = gs.festival_contest("lantern_festival")
	assert_eq(int(result["place"]), 1)
	assert_true(gs.player.item_count("spirit_stone") > stones)
	assert_true(gs.player.item_count("paper_lantern") >= 1)
	assert_true(gs.check_festival_contest("lantern_festival") != "")
	assert_true(gs.festival_contest("lantern_festival").is_empty(), "a second entry is refused")
	assert_eq(gs.last_contest, result)
	var days_after: int = _root().get_node("GameClock").total_days
	assert_eq(days_after, day, "the contest takes no time")
	var line := Guidance.journal(gs.player, gs.data, gs.world_flags, day, "qingshi_village", 1.0, gs.npcs, gs.world_events)
	for e: Dictionary in line:
		assert_false(String(e["text"]).contains("are on at the festival stall"), "no hint after entering")
	gs.end_session()


func _won(you: bool, name: String) -> Dictionary:
	return {"scores": [{"name": name, "score": 9, "you": you}, {"name": "x", "score": 1, "you": not you}]}


func test_champion_recorded_and_only_from_a_past_year() -> void:
	var flags := {}
	FestivalContest.record(flags, "lantern_festival", 3, _won(false, "Mei Lan"))
	assert_eq(FestivalContest.champion(flags, "lantern_festival", 3), {}, "this year's winner is not last year's champion")
	assert_eq(FestivalContest.champion_rival(flags, "lantern_festival", 4), "Mei Lan")
	assert_eq(FestivalContest.champion_text(flags, "lantern_festival", 4), "Mei Lan won last year")
	assert_eq(FestivalContest.champion_text({}, "lantern_festival", 4), "")
	FestivalContest.record(flags, "lantern_festival", 4, _won(true, "You"))
	assert_eq(FestivalContest.champion_rival(flags, "lantern_festival", 5), "", "the player is no rival")
	assert_eq(FestivalContest.champion_text(flags, "lantern_festival", 5), "You won last year")


func test_champion_scores_two_more() -> void:
	var d := data()
	var p := new_character()
	var rivals: Array[CharacterData] = [_npc("Mei Lan", 8), _npc("Old Wu", 8)]
	var a := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(9))
	var b := FestivalContest.run(d, p, "lantern_festival", rivals, seeded_rng(9), "Mei Lan")
	var sa := {}
	var sb := {}
	for s: Dictionary in a["scores"]:
		sa[s["name"]] = int(s["score"])
	for s: Dictionary in b["scores"]:
		sb[s["name"]] = int(s["score"])
	assert_eq(sb["Mei Lan"], sa["Mei Lan"] + 2)
	assert_eq(sb["Old Wu"], sa["Old Wu"])


func test_three_in_a_row_sets_master_flag_once_and_awards_milestone() -> void:
	var flags := {}
	assert_eq(FestivalContest.record(flags, "lantern_festival", 1, _won(true, "You")), 1)
	assert_eq(FestivalContest.record(flags, "lantern_festival", 2, _won(true, "You")), 2)
	assert_false(flags.has("contest_master_lantern_festival"))
	FestivalContest.record(flags, "lantern_festival", 3, _won(false, "Mei Lan"))
	assert_eq(FestivalContest.record(flags, "lantern_festival", 4, _won(true, "You")), 1, "a loss resets the streak")
	FestivalContest.record(flags, "lantern_festival", 5, _won(true, "You"))
	assert_eq(FestivalContest.record(flags, "lantern_festival", 6, _won(true, "You")), 3)
	assert_true(bool(flags["contest_master_lantern_festival"]))
	var got := Milestones.newly_reached(new_character(), data(), flags)
	assert_true(got.has("riddle_master"))
	assert_false(got.has("kite_master"))


func test_calendar_names_the_champion() -> void:
	var d := data()
	var inst := {"id": "lantern_festival", "region": "qingshi_village", "start_day": 400, "end_day": 408}
	var flags := {"contest_winner_lantern_festival": {"year": Calendar.year_of(400) - 1, "name": "Mei Lan", "you": false, "streak": 0}}
	var found := false
	for x: Dictionary in VillageCalendar.upcoming(d, {}, {}, [inst], "qingshi_village", 400, 5, null, flags):
		if String(x["text"]).contains("(contest: Lantern riddles; Mei Lan won last year)"):
			found = true
	assert_true(found)


func test_game_state_champion_enters_and_greets() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var day: int = _root().get_node("GameClock").total_days
	var year := Calendar.year_of(day)
	var folk := Folk.candidates(gs.npcs, gs.data, gs.player, "qingshi_village")
	assert_true(folk.size() >= 1)
	var champ: CharacterData = folk[folk.size() - 1]
	gs.world_flags[FestivalContest.winner_key("lantern_festival")] = {"year": year - 1, "name": champ.name, "you": false, "streak": 0}
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}]
	var result: Dictionary = gs.festival_contest("lantern_festival")
	var names: Array = []
	for s: Dictionary in result["scores"]:
		names.append(s["name"])
	assert_true(names.has(champ.name), "last year's champion always enters")
	var w: Dictionary = gs.world_flags[FestivalContest.winner_key("lantern_festival")]
	assert_eq(int(w["year"]), year)
	gs.end_session()
