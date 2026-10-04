extends TestCase
## UI-002: EventBus keeps a capped message history; the message log screen
## filters and formats it, and new/loaded sessions start with an empty log.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_history_records_posts_with_day_and_is_capped() -> void:
	var bus := _root().get_node("EventBus")
	var clock := _root().get_node("GameClock")
	bus.clear_history()
	clock.total_days = 40
	bus.post("A breeze stirs.", "info")
	assert_eq(bus.history.size(), 1)
	assert_eq(bus.history[0], {"text": "A breeze stirs.", "category": "info", "day": 40, "topic": ""})
	for i in bus.HISTORY_LIMIT + 5:
		bus.post("line %d" % i, "progress")
	assert_eq(bus.history.size(), bus.HISTORY_LIMIT)
	assert_eq(bus.history[-1]["text"], "line %d" % (bus.HISTORY_LIMIT + 4))
	bus.clear_history()
	clock.reset()


func test_filtered_and_format_group_by_day() -> void:
	var history: Array = [
		{"text": "Qi gathers.", "category": "progress", "day": 0},
		{"text": "A wolf [howls].", "category": "danger", "day": 0},
		{"text": "Karma shifts.", "category": "karma", "day": 35},
	]
	assert_eq(MessageLogScreen.filtered(history, "").size(), 3)
	var danger := MessageLogScreen.filtered(history, "danger")
	assert_eq(danger.size(), 1)
	assert_eq(danger[0]["text"], "A wolf [howls].")
	var text := MessageLogScreen.format_entries(history)
	assert_eq(text.count(Calendar.format_date(0)), 1, "one date line per day")
	assert_true(text.contains(Calendar.format_date(35)), text)
	assert_true(text.contains("[lb]howls]"), "brackets in messages are escaped")


func test_new_session_clears_history_and_screen_shows_it() -> void:
	var gs := _root().get_node("GameState")
	var bus := _root().get_node("EventBus")
	bus.post("left over from an old life", "info")
	gs.start_session(CharacterFactory.create("Han Li", gs.data, seeded_rng(5), "male"))
	assert_eq(bus.history.size(), 1, "only the session start message remains")
	bus.post("Beware the beast tide.", "warning")
	var screen := MessageLogScreen.new()
	_root().add_child(screen)
	screen.open()
	assert_true(screen.visible)
	var text := screen._text.get_parsed_text()
	assert_true(text.contains("sets out on the path of cultivation"), text)
	assert_true(text.contains("Beware the beast tide."), text)
	screen._set_filter("warning")
	text = screen._text.get_parsed_text()
	assert_false(text.contains("sets out"), text)
	assert_true(text.contains("Beware the beast tide."), text)
	assert_eq(screen._count.text, "1 of 2 messages")
	screen.close()
	assert_false(screen.visible)
	screen.free()
	gs.end_session()


## UI-002b: messages carry the topic of the action that posted them, the log
## filters by topic, and the HUD log is seeded from the history.
func test_topics_tag_and_filter() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var bus := root.get_node("EventBus")
	var c := new_character()
	c.spiritual_roots = {"fire": 70}
	gs.start_session(c)
	gs.cultivate(10)
	assert_eq(String(bus.history[-1].get("topic", "")), "cultivation", str(bus.history[-1]))
	gs.buy_item("qi_gathering_pill")
	assert_eq(String(bus.history[-1].get("topic", "")), "trade")
	bus.post("A manual line", "info", "world")
	assert_eq(String(bus.history[-1]["topic"]), "world", "an explicit topic wins")
	var trade_only := MessageLogScreen.filtered(bus.history, "", "trade")
	assert_true(trade_only.size() >= 1 and trade_only.all(func(e: Dictionary) -> bool: return e["topic"] == "trade"))
	var warn_trade := MessageLogScreen.filtered(bus.history, "warning", "trade")
	assert_true(warn_trade.all(func(e: Dictionary) -> bool: return e["category"] == "warning" and e["topic"] == "trade"))
	var screen := MessageLogScreen.new()
	root.add_child(screen)
	screen.open()
	screen._set_topic("cultivation")
	assert_true(screen._count.text.begins_with("%d of" % MessageLogScreen.filtered(bus.history, "", "cultivation").size()), screen._count.text)
	screen.free()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var log_label: RichTextLabel = hud.get("_log")
	assert_true(log_label.get_parsed_text().contains("A manual line"), "the HUD log starts from the history")
	hud.free()
	gs.end_session()
