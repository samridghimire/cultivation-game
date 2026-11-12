extends TestCase
## ART-010: the artifact speaks once per moment per life.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _spoken(moment: String = "first_breakthrough") -> Array:
	var lines: Array = _root().get_node("GameState").data.artifact["whispers"][moment]
	return EventBus.history.filter(func(e: Dictionary) -> bool: return e["category"] == "artifact" and lines.has(e["text"]))


func _start() -> CharacterData:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Whisper", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


func _ready_to_break(c: CharacterData) -> void:
	var gs := _root().get_node("GameState")
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	Cultivation.add_qi(c, gs.data, 1e12)
	c.breakthrough_bonus = 5.0


func test_speak_once_per_moment() -> void:
	var c := new_character()
	var rng := seeded_rng(1)
	var line := ArtifactWhispers.speak(c, data(), "first_breakthrough", rng)
	assert_true(line != "")
	assert_eq(ArtifactWhispers.speak(c, data(), "first_breakthrough", rng), "")
	assert_true(ArtifactWhispers.speak(c, data(), "first_respawn", rng) != "", "another moment still speaks")


func test_no_whispers_stay_silent() -> void:
	var d := data()
	var saved: Variant = d.artifact["whispers"]
	d.artifact.erase("whispers")
	assert_eq(ArtifactWhispers.speak(new_character(), d, "first_breakthrough", seeded_rng(1)), "")
	d.artifact["whispers"] = saved


func test_every_moment_has_a_whisper() -> void:
	for moment in ArtifactWhispers.MOMENTS:
		assert_true((data().artifact["whispers"] as Dictionary).has(moment), moment)


func test_validation() -> void:
	var d := data()
	var saved: Variant = d.artifact["whispers"]
	d.artifact["whispers"] = {"bogus": ["x"], "low_lives": [], "first_respawn": ["a".repeat(141)], "first_breakthrough": ["ok"]}
	assert_eq(ArtifactWhispers.validate(d).size(), 3, str(ArtifactWhispers.validate(d)))
	d.artifact["whispers"] = saved
	assert_eq(ArtifactWhispers.validate(d).size(), 0)


func test_save_round_trip_keeps_it_silent() -> void:
	var c := new_character()
	ArtifactWhispers.speak(c, data(), "first_breakthrough", seeded_rng(1))
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(ArtifactWhispers.speak(back, data(), "first_breakthrough", seeded_rng(1)), "")
	var old := c.to_dict()
	old.erase("artifact_spoke")
	assert_true(CharacterData.from_dict(old).artifact_spoke.is_empty(), "old saves default to nothing spoken")


func test_breakthrough_speaks_once() -> void:
	var gs := _root().get_node("GameState")
	var c := _start()
	_ready_to_break(c)
	EventBus.clear_history()
	gs.attempt_breakthrough()
	assert_eq(c.realm_index, 2)
	assert_eq(_spoken().size(), 1)
	_ready_to_break(c)
	c.realm_index = 2
	c.stage = gs.data.realms[2].stage_count() - 1
	Cultivation.add_qi(c, gs.data, 1e15)
	gs.attempt_breakthrough()
	assert_eq(_spoken().size(), 1, "a second breakthrough stays quiet")
	gs.end_session()


func test_respawn_speaks_and_low_lives() -> void:
	var gs := _root().get_node("GameState")
	var c := _start()
	c.artifact_lives = 2
	EventBus.clear_history()
	gs._die_violently("Test death.")
	assert_eq(c.artifact_lives, 1)
	assert_eq(_spoken("first_respawn").size() + _spoken("low_lives").size(), 2, "first respawn and the last life")
	c.artifact_spoke.erase("first_respawn")
	c.artifact_lives = 2
	gs._die_violently("Test death.")
	assert_eq(_spoken("first_respawn").size() + _spoken("low_lives").size(), 3, "the low-lives line is not repeated")
	gs.end_session()
