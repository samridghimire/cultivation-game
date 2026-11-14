extends TestCase
## LOG-004: folding repeated practice/cultivate lines, one-line gifts, and fewer forecast lines.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var c := CharacterFactory.create("Fold", _gs().data, seeded_rng(11))
	c.spiritual_roots = {"fire": 80}
	_gs().start_session(c)
	return c


func test_fold_same_technique() -> void:
	var got := LogFold.fold("You practice the Iron Fist for 5 days.", 10, "You practice the Iron Fist for 5 days.", 11)
	assert_eq(got, "You practice the Iron Fist for 10 days.")


func test_fold_does_not_merge_different_technique_or_template_or_gap() -> void:
	var a := "You practice the Iron Fist for 5 days."
	assert_eq(LogFold.fold(a, 10, "You practice the Basic Breathing for 5 days.", 10), "")
	assert_eq(LogFold.fold(a, 10, "You cultivate for 5 days and gather 3 qi (1/2 qi to the 2nd Layer).", 10), "")
	assert_eq(LogFold.fold(a, 10, a, 12), "")
	assert_eq(LogFold.fold(a, 10, "Something else.", 10), "")
	assert_eq(LogFold.fold("Something else.", 10, a, 10), "")


func test_fold_cultivate_sums_qi_and_days() -> void:
	var got := LogFold.fold("You cultivate for 5 days and gather 12 qi (3/40 qi to the 2nd Layer).", 4,
			"You cultivate for 1 month and gather 30 qi (33/40 qi to the 2nd Layer).", 5)
	assert_eq(got, "You cultivate for 1 month and 5 days and gather 42 qi (33/40 qi to the 2nd Layer).")


func test_parse_duration_roundtrip() -> void:
	for d: int in [1, 5, 30, 35, 360, 400, 800]:
		assert_eq(LogFold.parse_duration(Calendar.format_duration(d)), d)


func test_back_to_back_summaries_fold_in_the_log() -> void:
	_start()
	var gs := _gs()
	var before := EventBus.history.size()
	var day: int = GameClock.total_days
	gs._post_foldable(3, "You practice the Iron Fist for 3 days.")
	gs._post_foldable(2, "You practice the Iron Fist for 2 days.")
	assert_eq(EventBus.history.size() - before, 1)
	assert_eq(String(EventBus.history[-1]["text"]), "You practice the Iron Fist for 5 days.")
	EventBus.post("Something else.")  # another line in between: no fold
	gs._post_foldable(2, "You practice the Iron Fist for 2 days.")
	assert_eq(EventBus.history.size() - before, 3)
	assert_eq(GameClock.total_days, day)
	gs.end_session()


func test_practice_action_posts_through_the_fold() -> void:
	var c := _start()
	var gs := _gs()
	Techniques.learn(c, gs.data, "basic_breathing")
	gs.practice_technique("basic_breathing", 1)
	assert_false(gs._fold_prev.is_empty())
	assert_true(String(gs._fold_prev["text"]).begins_with("You practice the"))
	gs.end_session()


func test_loved_gift_posts_one_line() -> void:
	var c := _start()
	var gs := _gs()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(8), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var liked := ""
	for item_id: String in gs.data.items:
		if Family.gift_taste(gs.data, npc.id, item_id) > 0 and Family.gift_value(gs.data, item_id) > 0:
			liked = item_id
			break
	assert_true(liked != "")
	c.add_item(liked, 1)
	gs.npc_favor[npc.id] = 0
	var before := EventBus.history.size()
	gs.give_gift(npc.id, liked)
	var delighted := 0
	for i in range(before, EventBus.history.size()):
		var t := String(EventBus.history[i]["text"])
		if t.contains("is delighted"):
			delighted += 1
			assert_true(t.contains("accepts your"), t)
	assert_eq(delighted, 1)
	gs.end_session()


func test_forecast_only_when_changed_or_bad() -> void:
	_start()
	var gs := _gs()
	gs.current_region = "qingshi_village"
	var clear := "Expect mostly clear weather in Qingshi Village."
	assert_true(gs._forecast_worth_posting(clear))
	assert_false(gs._forecast_worth_posting(clear))
	assert_true(gs._forecast_worth_posting("Expect mostly cloudy weather in Qingshi Village."))
	assert_true(gs._forecast_worth_posting("Expect mostly rain weather in Qingshi Village."))
	assert_true(gs._forecast_worth_posting("Expect mostly rain weather in Qingshi Village."))
	assert_true(gs._forecast_worth_posting("In season in Qingshi Village: mugwort."))
	assert_eq(Guidance.forecast_kind(clear), "clear")
	gs.end_session()


## LOG-005: dawn lines between two practice summaries do not stop the fold.
func test_fold_across_dawn_lines() -> void:
	_start()
	var gs := _gs()
	var before := EventBus.history.size()
	gs._post_foldable(3, "You practice the Iron Fist for 3 days.")
	EventBus.post("Tomorrow: market day.", "world", "", true)
	gs._post_foldable(2, "You practice the Iron Fist for 2 days.")
	assert_eq(EventBus.history.size() - before, 2)
	assert_eq(String(EventBus.history[-1]["text"]), "You practice the Iron Fist for 5 days.")
	assert_eq(String(EventBus.history[-2]["text"]), "Tomorrow: market day.")
	EventBus.post("A good omen.", "almanac", "", true)
	gs._post_foldable(1, "You practice the Iron Fist for 1 day.")
	assert_eq(EventBus.history.size() - before, 3)
	assert_eq(String(EventBus.history[-1]["text"]), "You practice the Iron Fist for 6 days.")
	gs.end_session()


func test_fight_between_stops_the_fold() -> void:
	_start()
	var gs := _gs()
	var before := EventBus.history.size()
	gs._post_foldable(3, "You practice the Iron Fist for 3 days.")
	EventBus.post("You win the fight.", "combat")
	EventBus.post("Tomorrow: market day.", "world", "", true)
	gs._post_foldable(2, "You practice the Iron Fist for 2 days.")
	assert_eq(EventBus.history.size() - before, 4)
	gs.end_session()


func test_great_beast_eve_needs_a_reason() -> void:
	var c := _start()
	var gs := _gs()
	var any := false
	for rid: String in gs.data.regions:
		var day := Wildlife.next_great_day(gs.data, rid, GameClock.total_days, c.realm_index, c)
		if day < 0:
			continue
		var enemy := Wildlife.active_great_enemy(c, gs.data, rid)
		any = true
		assert_false(VillageCalendar._beast_matters(gs.data, {}, rid, enemy, day))
		assert_true(VillageCalendar._beast_matters(gs.data, {Wildlife.bait_flag(rid): day}, rid, enemy, day))
		break
	assert_true(any)
	gs.end_session()


## LOG-007: a folded row is found by id even when the HUD collapsed an earlier "(x2)" row.
func test_fold_addresses_row_by_id() -> void:
	_start()
	var gs := _gs()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	EventBus.post("You practice the Iron Fist for 3 days.")
	gs._fold_prev = {"text": "You practice the Iron Fist for 3 days.", "day": GameClock.total_days}
	EventBus.post("Dawn line.", "world", "", true)
	EventBus.post("Dawn line.", "world", "", true)  # collapsed into (x2) by the HUD
	gs._post_foldable(2, "You practice the Iron Fist for 2 days.")
	var lines: Array = hud.get("_log_lines")
	var ids: Array = hud.get("_log_ids")
	assert_true(String(lines[-1]).contains("5 days"), String(lines[-1]))
	assert_eq(lines.size(), ids.size())
	hud.free()
	gs.end_session()
