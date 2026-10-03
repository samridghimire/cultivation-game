extends TestCase
## FAM-002h: chatting and gifts raise favor with NPCs that have no dialogue,
## up to the courtship threshold (data/family.json acquaintance).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _rules() -> Dictionary:
	return data().family["acquaintance"]


func _stranger() -> CharacterData:
	return Npcs.spawn({}, data(), seeded_rng(), {"gender": "female", "age_years": 20, "realm": "qi_refining"})


func test_chat_gain_scales_with_charisma_and_caps() -> void:
	var c := new_character()
	var she := _stranger()
	c.attributes["charisma"] = 10
	var result := Family.chat(c, she, 0, data())
	assert_true(result["ok"])
	assert_eq(result["favor"], int(_rules()["chat_favor"]))
	assert_eq(result["days"], int(_rules()["chat_days"]))
	c.attributes["charisma"] = 10 + 2 * int(_rules()["charisma_step"])
	assert_eq(Family.chat(c, she, 0, data())["favor"], int(_rules()["chat_favor"]) + 2)
	c.attributes["charisma"] = 0
	assert_eq(Family.chat(c, she, 0, data())["favor"], 1, "always at least 1")
	var cap := int(_rules()["chat_max_favor"])
	assert_eq(Family.chat(c, she, cap - 1, data())["favor"], 1, "never past the cap")
	assert_false(Family.chat(c, she, cap, data())["ok"], "small talk tops out")


func test_chat_reaches_courtship_threshold() -> void:
	assert_true(int(_rules()["chat_max_favor"]) >= int(data().family["courtship"]["min_favor"]))
	assert_true(int(_rules()["gift_max_favor"]) < int(data().family["proposal"]["min_favor"]), "marriage still needs courtship")


func test_chat_refusals() -> void:
	var c := new_character()
	assert_false(Family.chat(c, null, 0, data())["ok"])
	var dead := _stranger()
	dead.alive = false
	assert_false(Family.chat(c, dead, 0, data())["ok"])
	var named := Npcs.create(data().npcs["xiao_ling"], data(), seeded_rng())
	assert_true(Family.check_chat(c, named, 0, data()).contains("properly"), "NPCs with dialogue use it")


func test_gift_value_from_price() -> void:
	var per := int(_rules()["gift_price_per_favor"])
	assert_eq(Family.gift_value(data(), "spirit_stone"), 0, "worthless")
	assert_eq(Family.gift_value(data(), "dew_grass"), 1, "at least 1")
	assert_eq(Family.gift_value(data(), "qi_gathering_pill"), clampi(int(15.0 / per), 1, int(_rules()["gift_max_per_item"])))
	assert_eq(Family.gift_value(data(), "core_forming_pill"), int(_rules()["gift_max_per_item"]), "capped per gift")


func test_give_gift_consumes_item_and_caps() -> void:
	var c := new_character()
	var she := _stranger()
	assert_false(Family.give_gift(c, she, 0, "qi_gathering_pill", data())["ok"], "nothing to give")
	c.add_item("spirit_stone", 50)
	var stones := c.item_count("spirit_stone")
	assert_false(Family.give_gift(c, she, 0, "spirit_stone", data())["ok"], "worthless gift")
	assert_eq(c.item_count("spirit_stone"), stones)
	c.add_item("core_forming_pill", 2)
	var result := Family.give_gift(c, she, 0, "core_forming_pill", data())
	assert_true(result["ok"])
	assert_eq(c.item_count("core_forming_pill"), 1)
	assert_eq(result["favor"], int(_rules()["gift_max_per_item"]))
	var cap := int(_rules()["gift_max_favor"])
	assert_eq(Family.give_gift(c, she, cap - 3, "core_forming_pill", data())["favor"], 3, "never past the cap")
	c.add_item("core_forming_pill", 1)
	assert_false(Family.give_gift(c, she, cap, "core_forming_pill", data())["ok"], "gifts top out")
	assert_eq(c.item_count("core_forming_pill"), 1, "refused gifts are kept")


func test_acquaintance_validation() -> void:
	var d := GameData.new()
	d.names = data().names
	d.family = data().family.duplicate(true)
	d.family["acquaintance"] = {"chat_days": 1}
	assert_gt(Family.validate(d).size(), 0)


func test_game_state_chat_and_gift_unlock_courtship() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Suitor", gs.data, seeded_rng())
	c.gender = "male"
	gs.start_session(c)
	var she := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"gender": "female", "age_years": 20, "realm": "mortal"})
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.chat(she.id)
	assert_gt(int(gs.npc_favor.get(she.id, 0)), 0, "chatting raises favor")
	assert_gt(clock.total_days, days, "chatting takes time")
	gs.chat("xiao_ling")
	assert_eq(int(gs.npc_favor.get("xiao_ling", 0)), 0, "named NPCs are talked to through dialogue")
	for i in 40:
		gs.chat(she.id)
	assert_eq(int(gs.npc_favor[she.id]), int(gs.data.family["acquaintance"]["chat_max_favor"]))
	c.add_item("core_forming_pill", 1)
	gs.give_gift(she.id, "core_forming_pill")
	assert_eq(c.item_count("core_forming_pill"), 0)
	assert_eq(int(gs.npc_favor[she.id]), int(gs.data.family["acquaintance"]["chat_max_favor"]) + int(gs.data.family["acquaintance"]["gift_max_per_item"]))
	var before := int(gs.npc_favor[she.id])
	gs.court(she.id)
	assert_gt(int(gs.npc_favor[she.id]), before, "courtship is now possible")
	gs.end_session()
