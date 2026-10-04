extends TestCase
## ART-006c: the artifact awakening's three answers (small alignment, attribute
## and flag effects), the `attributes` effect key and artifact function flavor.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_attributes_effect() -> void:
	var c := new_character()
	var before := c.attribute("fortune")
	var notes := Effects.apply(c, data(), {"attributes": {"fortune": 2, "charisma": -1}}, {})
	assert_eq(c.attribute("fortune"), before + 2)
	assert_true(notes.has("Fortune +2"), str(notes))
	assert_true(notes.has("Charisma -1"), str(notes))


func test_dialogue_validation_rejects_unknown_attributes() -> void:
	var dialogue := {"id": "bad", "entries": [{"node": "a"}], "nodes": {"a": {"text": "x", "choices": [{"label": "y", "next": "end", "effects": {"attributes": {"luckiness": 1}}}]}}}
	var errors := Dialogue.validate(dialogue, data())
	assert_true(Array(errors).any(func(e: String) -> bool: return e.contains("unknown attribute 'luckiness'")), str(errors))


func test_every_function_has_flavor() -> void:
	for def: Dictionary in data().artifact["functions"]:
		assert_true(String(def.get("flavor", "")) != "", "%s has flavor text" % def["id"])


## Plays the intro, answering the "what will you do" question with the choice
## whose effects set `flag`.
func _play_intro(gs: Node, flag: String) -> void:
	gs.start_pending_event()
	var steps := 0
	while gs.in_dialogue() and steps < 12:
		var choices: Array = gs.dialogue_view()["choices"]
		var pick: int = int(choices[-1]["index"])  # the last choice moves the story on
		for choice: Dictionary in choices:
			if String(choice["label"]).contains(_label_for(flag)):
				pick = int(choice["index"])
		gs.choose_dialogue(pick)
		steps += 1


func _label_for(flag: String) -> String:
	return {"intro_path_righteous": "Protect", "intro_path_neutral": "Walk my own road", "intro_path_ambitious": "Stand above"}[flag]


func test_intro_answers_shape_the_character() -> void:
	var gs: Node = _root().get_node("GameState")
	var expected := {
		"intro_path_righteous": ["charisma", 20],
		"intro_path_neutral": ["fortune", 0],
		"intro_path_ambitious": ["comprehension", -20],
	}
	for flag: String in expected:
		var c := CharacterFactory.create("Bearer", gs.data, seeded_rng())
		var attr: String = expected[flag][0]
		var before := c.attribute(attr)
		var alignment := c.alignment
		gs.start_session(c)
		_play_intro(gs, flag)
		assert_false(gs.in_dialogue(), "the intro ends")
		assert_true(gs.world_flags.get(flag, false), flag)
		assert_eq(c.attribute(attr), before + 1, "%s raises %s" % [flag, attr])
		assert_eq(c.alignment - alignment, int(expected[flag][1]))
		gs.end_session()


func test_unsealing_posts_the_flavor() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Bearer", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.artifact_energy = 1000
	gs.unlock_artifact_function("storage")
	var flavor := String(ArtifactFunctions.get_def(gs.data, "storage")["flavor"])
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return e["text"] == flavor))
	gs.end_session()
