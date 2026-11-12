extends TestCase
## ART-011: the artifact remembers what fed it.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_record_gain_merges_appends_trims_ignores() -> void:
	var c := new_character()
	ArtifactFunctions.record_gain(c, "stage", 15, 3)
	ArtifactFunctions.record_gain(c, "stage", 15, 3)
	assert_eq(c.artifact_gains.size(), 1)
	assert_eq(int(c.artifact_gains[0]["amount"]), 30)
	ArtifactFunctions.record_gain(c, "realm", 60, 3)
	assert_eq(c.artifact_gains.size(), 2)
	ArtifactFunctions.record_gain(c, "stage", 0, 4)
	assert_eq(c.artifact_gains.size(), 2, "zero is ignored")
	for i in 10:
		ArtifactFunctions.record_gain(c, "discovery", 5, 10 + i)
	assert_eq(c.artifact_gains.size(), ArtifactFunctions.GAINS_KEPT)
	assert_eq(int(c.artifact_gains[c.artifact_gains.size() - 1]["day"]), 19)


func test_gain_text() -> void:
	var d := data()
	assert_eq(ArtifactFunctions.gain_text(d, {"source": "stage", "amount": 15}), "+15 a new stage")
	assert_eq(ArtifactFunctions.gain_text(d, {"source": "stage", "amount": 30}), "+30 new stages")
	assert_eq(ArtifactFunctions.gain_text(d, {"source": "stones", "amount": 100}), "+100 spirit stones")
	assert_eq(ArtifactFunctions.gain_text(d, {"source": "offering", "amount": 12}), "+12 an offering")


func test_energy_sources_follow_data() -> void:
	var d := data()
	assert_eq(ArtifactFunctions.energy_sources(d)[0], "+15 each new stage")
	var saved: Variant = d.artifact["energy"]["progress"]["stage"]
	d.artifact["energy"]["progress"]["stage"] = 20
	assert_eq(ArtifactFunctions.energy_sources(d)[0], "+20 each new stage")
	d.artifact["energy"]["progress"]["stage"] = saved
	var all := ArtifactFunctions.energy_sources(d)
	assert_eq(all[all.size() - 1], "1 per spirit stone fed")


func test_next_seal_line() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.artifact_energy = 55
	assert_eq(ArtifactFunctions.next_seal_line(c, d, {}), "Artifact: 55 / 100 energy toward Storage Space")
	for id: String in ArtifactFunctions.KNOWN:
		c.artifact_functions.append(id)
	assert_eq(ArtifactFunctions.next_seal_line(c, d, {}), "")


func test_feed_and_save() -> void:
	var d := data()
	var c := new_character()
	c.add_item("spirit_stone", 10)
	ArtifactFunctions.feed(c, d, "spirit_stone", 10, 5)
	assert_eq(c.artifact_gains.size(), 1)
	assert_eq(String(c.artifact_gains[0]["source"]), "stones")
	assert_eq(int(c.artifact_gains[0]["amount"]), 10)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.artifact_gains.size(), 1)
	var old := c.to_dict()
	old.erase("artifact_gains")
	assert_true(CharacterData.from_dict(old).artifact_gains.is_empty())


func test_game_state_records_gains() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Gains", gs.data, seeded_rng(5))
	gs.start_session(c)
	c.add_item("spirit_stone", 10)
	gs.feed_artifact("spirit_stone", 10)
	var last: Dictionary = c.artifact_gains[c.artifact_gains.size() - 1]
	assert_eq(String(last["source"]), "stones")
	assert_eq(int(last["day"]), GameClock.total_days)
	c.realm_index = 1
	c.artifact_energy = 55
	var lines: PackedStringArray = gs.today_lines()
	assert_true(Array(lines).any(func(l: Variant) -> bool: return String(l).begins_with("Artifact: 55 /")), str(lines))
	gs.end_session()
