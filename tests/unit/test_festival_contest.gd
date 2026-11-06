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


## FEST-008: practice for the contest.
const LANTERN_START := 270  # day 1 of month 10, year 1


func test_practice_window_is_the_week_before() -> void:
	var d := data()
	assert_eq(FestivalContest.start_within_window(d, "lantern_festival", LANTERN_START - 7), LANTERN_START)
	assert_eq(FestivalContest.start_within_window(d, "lantern_festival", LANTERN_START - 1), LANTERN_START)
	assert_eq(FestivalContest.start_within_window(d, "lantern_festival", LANTERN_START - 8), -1)
	assert_eq(FestivalContest.start_within_window(d, "lantern_festival", LANTERN_START), -1)
	assert_eq(FestivalContest.practice_event_for(d, ["elder"], LANTERN_START - 3), "lantern_festival")
	assert_eq(FestivalContest.practice_event_for(d, ["jetty"], LANTERN_START - 3), "")
	assert_eq(FestivalContest.practice_event_for(d, ["elder"], 100), "")


func test_practice_bonus_caps_and_expires_next_year() -> void:
	var d := data()
	var flags := {}
	for i in 5:
		FestivalContest.practise(d, "lantern_festival", LANTERN_START - 4, flags)
	assert_eq(FestivalContest.practice_bonus(flags, "lantern_festival", 1), 6)
	assert_true(FestivalContest.check_practice(d, "lantern_festival", LANTERN_START - 4, flags) != "")
	assert_eq(FestivalContest.practice_bonus(flags, "lantern_festival", 2), 0)
	var next_year := LANTERN_START + Calendar.DAYS_PER_YEAR - 2
	assert_eq(FestivalContest.check_practice(d, "lantern_festival", next_year, flags), "")


func test_run_adds_practice() -> void:
	var d := data()
	var p := new_character()
	var a := FestivalContest.run(d, p, "lantern_festival", [], seeded_rng(3))
	var b := FestivalContest.run(d, p, "lantern_festival", [], seeded_rng(3), "", 6)
	var mine_a := 0
	var mine_b := 0
	for s: Dictionary in a["scores"]:
		if bool(s["you"]):
			mine_a = int(s["score"])
	for s: Dictionary in b["scores"]:
		if bool(s["you"]):
			mine_b = int(s["score"])
	assert_eq(mine_b, mine_a + 6)
	assert_eq(int(b["practice"]), 6)


func test_validation_catches_unmatched_practice_place() -> void:
	var d := GameData.load_from_dir()
	d.world_events["lantern_festival"]["contest"]["practice_place"] = "nowhere"
	assert_eq(FestivalContest.validate(d).size(), 1)


func test_game_state_practice_then_contest() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	clock.total_days = LANTERN_START - 3
	assert_eq(gs.practice_offer(["elder"]), "lantern_festival")
	assert_true(gs.practise_for_contest("lantern_festival"))
	assert_eq(clock.total_days, LANTERN_START - 2)
	assert_true(gs.practise_for_contest("lantern_festival"))
	assert_eq(FestivalContest.practice_bonus(gs.world_flags, "lantern_festival", 1), 4)
	clock.total_days = LANTERN_START
	assert_eq(gs.practice_offer(["elder"]), "")
	assert_false(gs.practise_for_contest("lantern_festival"))
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": LANTERN_START, "end_day": LANTERN_START + 8}]
	var result: Dictionary = gs.festival_contest("lantern_festival")
	assert_eq(int(result["practice"]), 4)
	gs.end_session()


## FEST-009: the rival at the festival.
func test_rival_flag_in_scores_and_standings() -> void:
	var p := new_character()
	var rivals: Array[CharacterData] = [_npc("Mei Lan", 8), _npc("Old Wu", 8)]
	var r := FestivalContest.run(data(), p, "lantern_festival", rivals, seeded_rng(3), "", 0, "Old Wu")
	var flagged := 0
	for s: Dictionary in r["scores"]:
		if bool(s.get("rival", false)):
			flagged += 1
			assert_eq(s["name"], "Old Wu")
	assert_eq(flagged, 1)
	assert_true("\n".join(FestivalContest.standings_lines(r)).contains("Old Wu (your rival)"))


func test_rival_enters_rules_and_tally() -> void:
	var p := new_character()
	var rv := _npc("Zhou", 8)
	rv.realm_index = p.realm_index + 1
	var met := {Rivals.FIRST_MEETING_FLAG: true}
	assert_true(Rivals.enters_festival(p, rv, met))
	assert_false(Rivals.enters_festival(p, rv, {}), "unmet")
	rv.realm_index = p.realm_index + 2
	assert_false(Rivals.enters_festival(p, rv, met), "two realms apart")
	rv.realm_index = p.realm_index
	rv.alive = false
	assert_false(Rivals.enters_festival(p, rv, met), "dead")
	assert_false(Rivals.enters_festival(p, null, met))
	var flags := {}
	Rivals.note_festival(flags, true)
	Rivals.note_festival(flags, true)
	Rivals.note_festival(flags, false)
	assert_eq(Rivals.bout_record_text(flags), "bouts 0 won, 0 lost, festivals 2-1")
	assert_eq(Rivals.bout_record_text({Rivals.BOUTS_WON_FLAG: 1}), "bouts 1 won, 0 lost")


func test_rival_festival_lines_and_validation() -> void:
	var rv := _npc("Zhou", 8)
	for won in [true, false]:
		for y in 4:
			var line := Rivals.festival_line(data(), rv, won, y)
			assert_true(line.contains("Zhou"), line)
	assert_eq(Rivals.validate(data()).size(), 0, ", ".join(Rivals.validate(data())))
	var d := GameData.load_from_dir()
	d.karma["rival"]["festival"] = {"win": [], "lose": ["x"]}
	assert_eq(Rivals.validate(d).size(), 1)


func test_game_state_rival_enters_festival() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var day: int = _root().get_node("GameClock").total_days
	var rival := Rivals.spawn(gs.player, gs.npcs, gs.data, gs.rng, "azure_peak")
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}]
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	rival.realm_index = gs.player.realm_index
	var result: Dictionary = gs.festival_contest("lantern_festival")
	var found := false
	for s: Dictionary in result["scores"]:
		if bool(s.get("rival", false)):
			found = true
			assert_eq(s["name"], rival.name)
	assert_true(found, "the rival enters from another region")
	assert_eq(result["scores"].size(), int(FestivalContest.contest_of(gs.data, "lantern_festival")["rivals"]) + 1)
	var t := Rivals.festival_tally(gs.world_flags)
	assert_eq(int(t["won"]) + int(t["lost"]), 1)
	gs.end_session()


## FEST-010: festival memories.
func test_history_empty_and_ordered() -> void:
	var h := FestivalContest.history(data(), {}, new_character(), 1)
	assert_eq(h.size(), 4)
	for i in h.size() - 1:
		assert_true(int(h[i]["month"]) <= int(h[i + 1]["month"]))
	for e in h:
		assert_eq(int(e["last_place"]), 0)
		assert_false(bool(e["keepsake_owned"]))
		assert_true(String(e["keepsake"]) != "", e["event_id"])
	assert_true("\n".join(FestivalContest.history_lines(data(), {}, new_character(), 1)).contains("not yet entered"))


func test_record_stores_history_and_streak() -> void:
	var flags := {}
	var win := {"place": 1, "scores": [{"name": "You", "score": 9, "you": true}]}
	var lose := {"place": 2, "scores": [{"name": "Mei", "score": 9, "you": false}, {"name": "You", "score": 5, "you": true}]}
	FestivalContest.record(flags, "lantern_festival", 1, lose)
	var h := FestivalContest.history(data(), flags, new_character(), 2)
	var lantern: Dictionary = h.filter(func(e: Dictionary) -> bool: return e["event_id"] == "lantern_festival")[0]
	assert_eq(int(lantern["last_place"]), 2)
	assert_eq(lantern["champion"], "Mei")
	assert_false(bool(lantern["keepsake_owned"]))
	for y in [2, 3, 4]:
		FestivalContest.record(flags, "lantern_festival", y, win)
	h = FestivalContest.history(data(), flags, new_character(), 5)
	lantern = h.filter(func(e: Dictionary) -> bool: return e["event_id"] == "lantern_festival")[0]
	assert_eq(int(lantern["streak"]), 3)
	assert_eq(lantern["champion"], "You")
	assert_true(bool(lantern["keepsake_owned"]), "a 1st place flags the keepsake")
	for y in range(5, 20):
		FestivalContest.record(flags, "lantern_festival", y, win)
	assert_eq((flags[FestivalContest.history_key("lantern_festival")] as Dictionary).size(), FestivalContest.HISTORY_YEARS)


func test_text_lists_pick_by_year_and_validate() -> void:
	assert_eq(FestivalContest.pick_text(["a", "b", "c"], 4), "b")
	assert_eq(FestivalContest.pick_text("solo", 7), "solo")
	var d := GameData.load_from_dir()
	var c: Dictionary = (d.world_events["lantern_festival"]["contest"] as Dictionary).duplicate(true)
	c["win_text"] = ["one", "two"]
	c["lose_text"] = ["lost to {winner}", "beaten by {winner}"]
	d.world_events["lantern_festival"]["contest"] = c
	assert_eq(FestivalContest.validate(d).size(), 0, ", ".join(FestivalContest.validate(d)))
	c["win_text"] = []
	assert_true(FestivalContest.validate(d).size() >= 1)
	c["win_text"] = [3]
	assert_true(FestivalContest.validate(d).size() >= 1)


## FOLK-012: friends at the festival.
func _friend_setup() -> Array:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var folk := Folk.candidates(gs.npcs, gs.data, gs.player, "qingshi_village")
	return [gs, folk]


func test_cheerers_cap_and_tier() -> void:
	var setup := _friend_setup()
	var gs: Node = setup[0]
	var folk: Array = setup[1]
	assert_true(folk.size() >= 4)
	var favor := {}
	assert_eq(FestivalContest.cheerers(gs.npcs, gs.data, favor, "qingshi_village").size(), 0)
	for i in 4:
		favor[(folk[i] as CharacterData).id] = 45 + i
	var who := FestivalContest.cheerers(gs.npcs, gs.data, favor, "qingshi_village")
	assert_eq(who.size(), 3, "capped at 3")
	assert_eq(who[0].id, (folk[3] as CharacterData).id, "best friend first")
	assert_true(FestivalContest.cheer_line(who).contains("cheer you on (+3)"))
	var entrants: Array[CharacterData] = [folk[3] as CharacterData]
	var others := FestivalContest.cheerers(gs.npcs, gs.data, favor, "qingshi_village", entrants)
	assert_eq(others.size(), 3, "the next friend steps in")
	assert_false(others.has(folk[3]), "a friend who enters the contest does not cheer")
	gs.end_session()


func test_run_adds_cheer_to_roll() -> void:
	var d := data()
	var p := new_character()
	var a := FestivalContest.run(d, p, "lantern_festival", [] as Array[CharacterData], seeded_rng(9))
	var b := FestivalContest.run(d, p, "lantern_festival", [] as Array[CharacterData], seeded_rng(9), "", 0, "", 0, 3)
	assert_eq(int(b["scores"].filter(func(s: Dictionary) -> bool: return s["you"])[0]["score"]) - int(a["scores"].filter(func(s: Dictionary) -> bool: return s["you"])[0]["score"]), 3)
	assert_eq(int(b["cheer"]), 3)


func test_invitation_picks_closest_friend_the_day_before() -> void:
	var setup := _friend_setup()
	var gs: Node = setup[0]
	var folk: Array = setup[1]
	var favor := {(folk[0] as CharacterData).id: 65, (folk[1] as CharacterData).id: 90, (folk[2] as CharacterData).id: 50}
	assert_true(FestivalContest.invitation(gs.data, gs.npcs, favor, LANTERN_START - 1).is_empty(), "only on the festival's first day")
	var inv := FestivalContest.invitation(gs.data, gs.npcs, favor, LANTERN_START)
	assert_eq(inv["npc"].id, (folk[1] as CharacterData).id)
	assert_true(FestivalContest.invitation_line(gs.data, inv).contains("asked you to the"))
	var rem := VillageCalendar.reminders(gs.data, gs.npcs, favor, [], "qingshi_village", LANTERN_START - 1, gs.player)
	assert_true(rem[0].contains("asked you to the"))
	assert_true(FestivalContest.invitation(gs.data, gs.npcs, {(folk[2] as CharacterData).id: 50}, LANTERN_START).is_empty())
	gs.end_session()


func test_attending_with_inviter_gives_favor_and_line() -> void:
	var setup := _friend_setup()
	var gs: Node = setup[0]
	var folk: Array = setup[1]
	var friend: CharacterData = folk[folk.size() - 1]  # the last villager: not one of the entrants
	assert_true(folk.size() > int(FestivalContest.contest_of(gs.data, "lantern_festival")["rivals"]))
	gs.npc_favor[friend.id] = 70
	_root().get_node("GameClock").total_days = LANTERN_START
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": LANTERN_START, "end_day": LANTERN_START + 8}]
	var result: Dictionary = gs.festival_contest("lantern_festival")
	assert_false((result["scores"] as Array).any(func(sc: Dictionary) -> bool: return String(sc["name"]) == friend.name), "the friend watches")
	assert_eq(int(result["cheer"]), 1)
	assert_eq(int(gs.npc_favor[friend.id]), 74 + (int((result["prize"] as Dictionary).get("favor_all", 0))))
	gs.end_session()


func test_festival_company_validation() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Folk.validate(d).size(), 0, ", ".join(Folk.validate(d)))
	assert_true((d.family["festival_company"] as Array).size() >= 4)
	d.family["festival_company"] = ["no placeholder"]
	assert_eq(Folk.validate(d).size(), 1)
