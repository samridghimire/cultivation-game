extends TestCase
## DayDigest (DAY-001): grouping, ordering, cap, short actions; GameState integration.


func _e(text: String, cat: String = "info") -> Dictionary:
	return {"text": text, "category": cat}


func test_nothing_for_short_actions() -> void:
	var entries: Array[Dictionary] = [_e("Your Spirit Herb is ready to harvest.")]
	assert_true(DayDigest.summarize(entries, 4).is_empty())


func test_grouping_and_order() -> void:
	var entries: Array[Dictionary] = [
		_e("A storm rolls in."), _e("Your Spirit Herb is ready to harvest."), _e("Another storm."),
		_e("You break through to the next stage!", "progress"), _e("Nothing special."),
	]
	var lines := DayDigest.summarize(entries, 15)
	assert_eq(lines[0], "You break through to the next stage!")
	assert_eq(lines[1], "Your Spirit Herb is ready to harvest.")
	assert_true(lines[2].begins_with("A storm rolls in."))
	assert_true(lines[2].contains("1 more"))
	assert_eq(lines[lines.size() - 1], "...and 1 more in the log")


func test_cap() -> void:
	var entries: Array[Dictionary] = []
	for t in ["breakthrough", "ready to harvest", "a visit", "a quarrel", "festival", "storm"]:
		entries.append(_e("x %s" % t))
	entries.append(_e("plain"))
	var lines := DayDigest.summarize(entries, 30)
	assert_true(lines.size() <= DayDigest.MAX_LINES)
	assert_true(lines[lines.size() - 1].contains("more in the log"))


func test_gamestate_long_meditation_fills_digest() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Digest", gs.data, seeded_rng(7))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs._pass_time(2)
	assert_true(gs.last_digest.is_empty())
	gs.last_digest = {"days": 1, "lines": ["old"]}
	var hist_before: int = EventBus.posted_count
	gs._pass_time(15)
	assert_true(gs.last_digest.is_empty() or int(gs.last_digest["days"]) == 15)
	EventBus.post("You break through to the next stage!", "progress")
	gs._record_digest(15, 1)
	assert_eq(int(gs.last_digest["days"]), 15)
	assert_eq(String(gs.last_digest["lines"][0]), "You break through to the next stage!")
	gs._pass_time(1)
	assert_true(gs.last_digest.is_empty(), "cleared when a new action starts")
	assert_true(EventBus.posted_count >= hist_before)
