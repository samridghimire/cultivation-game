extends TestCase
## Text helpers for messages built from data names.


func test_indefinite_article() -> void:
	assert_eq(Text.a("Alchemist"), "an Alchemist")
	assert_eq(Text.a("Wild Boar"), "a Wild Boar")
	assert_eq(Text.a("Outer Disciple"), "an Outer Disciple")
	assert_eq(Text.a("8th Grade Doctor"), "an 8th Grade Doctor")
	assert_eq(Text.a("1st Grade Doctor"), "a 1st Grade Doctor")
	assert_eq(Text.a(""), "")


func test_profession_messages_use_the_right_article() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wordsmith", gs.data, seeded_rng()))
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	var before: int = bus.history.size()
	gs.work_profession("alchemist", Calendar.DAYS_PER_MONTH)
	var lines: Array = bus.history.slice(before).map(func(e: Dictionary) -> String: return e["text"])
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("You work as an Alchemist")), str(lines))
	gs.end_session()
