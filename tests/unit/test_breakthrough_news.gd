## NEWS-001: word of a major-realm breakthrough spreads.
extends TestCase


func _people() -> Dictionary:
	var out := {}
	for id in ["warm", "cold", "gone"]:
		var npc := new_character(5)
		npc.id = id
		out[id] = npc
	out["gone"].alive = false
	return out


func test_known_living_npcs_gain_favor() -> void:
	var favor := {"warm": 20, "cold": 5, "gone": 50, "ghost": 50}
	var raised := Family.breakthrough_news(new_character(), data(), _people(), favor)
	assert_eq(raised, ["warm"])
	assert_eq(favor["warm"], 23)
	assert_eq(favor["cold"], 5)
	assert_eq(favor["gone"], 50)


func test_favor_is_capped() -> void:
	var favor := {"warm": 99}
	Family.breakthrough_news(new_character(), data(), _people(), favor)
	assert_eq(favor["warm"], 100)
	assert_true(Family.breakthrough_news(new_character(), data(), _people(), favor).is_empty(), "already at the cap")


func test_sect_member_gains_reputation() -> void:
	var c := new_character()
	c.sect = {"id": "azure_cloud_sect", "rank": 0}
	var before := Reputation.value(c, data(), "azure_cloud_sect")
	Family.breakthrough_news(c, data(), {}, {})
	assert_eq(Reputation.value(c, data(), "azure_cloud_sect"), before + 10)
	var rogue := new_character()
	Family.breakthrough_news(rogue, data(), {}, {})
	assert_true(rogue.reputation.is_empty())


func test_no_config_changes_nothing() -> void:
	var d := GameData.load_from_dir()
	d.family.erase("breakthrough_news")
	var favor := {"warm": 20}
	var c := new_character()
	c.sect = {"id": "azure_cloud_sect", "rank": 0}
	assert_true(Family.breakthrough_news(c, d, _people(), favor).is_empty())
	assert_eq(favor["warm"], 20)
	assert_true(c.reputation.is_empty())


func test_data_validates() -> void:
	assert_eq(Family.validate(data()).size(), 0)
	var d := GameData.load_from_dir()
	d.family["breakthrough_news"]["favor"] = -1
	assert_eq(Family.validate(d).size(), 1)


func test_gamestate_breakthrough_spreads_word_but_a_layer_does_not() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Famous", gs.data, seeded_rng(4242))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var friend := new_character(5)
	friend.id = "friend_t"
	gs.npcs["friend_t"] = friend
	gs.npc_favor["friend_t"] = 20
	var done := false
	for i in 60:
		c.realm_index = 0
		c.stage = 0
		Cultivation.add_qi(c, gs.data, 1e12)
		c.breakthrough_bonus = 5.0
		gs.attempt_breakthrough()
		if c.realm_index == 1:
			done = true
			break
	assert_true(done)
	assert_eq(gs.npc_favor["friend_t"], 23)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).begins_with("Word of your")))
	gs.end_session()
