extends TestCase
## Sect reputation (G-009): witnessed deeds, join gating, merchant prices,
## missions, leaving a sect and save compatibility.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


func _start() -> CharacterData:
	var gs := _game_state()
	var c := CharacterFactory.create("Reputation", gs.data, seeded_rng(77))
	gs.start_session(c)
	return c


func test_reputation_data_is_valid() -> void:
	assert_true(Reputation.validate(data()).is_empty(), str(Reputation.validate(data())))
	var d := GameData.new()
	d.sects = data().sects
	d.sect_reputation = {"min": 10, "max": 0, "tiers": [{"min": 0, "name": "A"}, {"min": 0, "name": "B"}]}
	d.deeds = {"x": {"id": "x", "effects": {"reputation": {"no_such_sect": 5}}}}
	assert_eq(Reputation.validate(d).size(), 3, "range, tier order, unknown sect")


func test_starts_at_start_value_and_clamps() -> void:
	var c := new_character()
	assert_eq(Reputation.value(c, data(), "azure_cloud_sect"), 0)
	assert_eq(Reputation.tier_name(c, data(), "azure_cloud_sect"), "Unknown")
	assert_eq(Reputation.change(c, data(), "azure_cloud_sect", 5000), 1000, "clamped to max")
	assert_eq(Reputation.tier_name(c, data(), "azure_cloud_sect"), "Revered")
	assert_eq(Reputation.change(c, data(), "no_such_sect", 50), 0)
	assert_false(c.reputation.has("no_such_sect"))


func test_witnessed_evil_deed_hurts_righteous_and_pleases_demonic() -> void:
	var c := new_character()
	var result := Deeds.perform(c, data(), "rob_villager", {})  # alignment -60, witnessed
	assert_true(result["ok"])
	assert_eq(Reputation.value(c, data(), "azure_cloud_sect"), -60)
	assert_eq(Reputation.value(c, data(), "blood_lotus_sect"), 30)
	assert_eq(Reputation.value(c, data(), "myriad_treasure_pavilion"), -15)
	assert_true(", ".join(result["notes"]).contains("Azure Cloud Sect reputation -60"))


func test_unwitnessed_deed_leaves_reputation_alone() -> void:
	var c := new_character()
	Deeds.perform(c, data(), "rob_traveller", {})
	assert_true(c.reputation.is_empty())


func test_explicit_reputation_effect() -> void:
	var c := new_character()
	var notes := Effects.apply(c, data(), {"reputation": {"blood_lotus_sect": -40}}, {})
	assert_eq(Reputation.value(c, data(), "blood_lotus_sect"), -40)
	assert_eq(notes.size(), 1)


func test_low_reputation_blocks_joining() -> void:
	var c := new_character()
	c.realm_index = 1
	Reputation.change(c, data(), "azure_cloud_sect", -150)
	var check := Sects.check_join(c, data(), "azure_cloud_sect")
	assert_false(check["ok"])
	assert_true(String(check["reason"]).contains("distrusted"), check["reason"])
	Reputation.change(c, data(), "azure_cloud_sect", 100)
	assert_true(Sects.check_join(c, data(), "azure_cloud_sect")["ok"])


func test_prices_follow_reputation_at_faction_merchants() -> void:
	var c := new_character()
	var base := int(data().items["qi_gathering_pill"]["price"])
	assert_eq(Reputation.buy_price(c, data(), "qi_gathering_pill", "myriad_treasure_pavilion"), base)
	Reputation.change(c, data(), "myriad_treasure_pavilion", 800)
	assert_eq(Reputation.buy_price(c, data(), "qi_gathering_pill", "myriad_treasure_pavilion"), roundi(base * 0.8))
	assert_eq(Reputation.buy_price(c, data(), "qi_gathering_pill", ""), base, "unaffiliated merchants ignore reputation")
	Reputation.change(c, data(), "blood_lotus_sect", -1000)
	assert_eq(Reputation.buy_price(c, data(), "qi_gathering_pill", "blood_lotus_sect"), roundi(base * 1.5))
	c.inventory["spirit_stone"] = 100
	var bought := Items.buy(c, data(), "qi_gathering_pill", 1, "myriad_treasure_pavilion")
	assert_eq(bought["stones"], roundi(base * 0.8))
	assert_eq(c.item_count("spirit_stone"), 100 - roundi(base * 0.8))


func test_missions_earn_reputation_with_own_sect() -> void:
	var c := new_character()
	c.realm_index = 1
	Sects.join(c, data(), "azure_cloud_sect")
	c.add_item("spirit_herb", 5)
	var result := Sects.complete_mission(c, data(), "gather_spirit_herbs", {})
	assert_true(result["ok"])
	assert_eq(Reputation.value(c, data(), "azure_cloud_sect"), Reputation.mission_gain(data(), 40))
	assert_gt(Reputation.value(c, data(), "azure_cloud_sect"), 0)


func test_reputation_survives_save_round_trip() -> void:
	var c := new_character()
	Reputation.change(c, data(), "blood_lotus_sect", 123)
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_eq(Reputation.value(loaded, data(), "blood_lotus_sect"), 123)
	var old_save := c.to_dict()
	old_save.erase("reputation")
	assert_true(CharacterData.from_dict(old_save).reputation.is_empty(), "old saves load with no reputation")


func test_describe_lists_every_sect() -> void:
	var lines := Reputation.describe(new_character(), data())
	assert_eq(lines.size(), data().sects.size())
	assert_true(" ".join(lines).contains("Azure Cloud Sect: Unknown (0)"))


func test_game_state_deed_leave_and_faction_purchase() -> void:
	var c := _start()
	var gs := _game_state()
	gs.perform_deed("help_villager")  # alignment +15, witnessed
	assert_eq(Reputation.value(c, gs.data, "azure_cloud_sect"), 15)
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	assert_false(c.is_rogue())
	gs.leave_sect()
	assert_true(c.is_rogue())
	assert_eq(Reputation.value(c, gs.data, "blood_lotus_sect"), roundi(-15 * 0.5) - 150, "deed then leave penalty")
	Reputation.change(c, gs.data, "myriad_treasure_pavilion", 400)  # Honored: 0.9
	c.inventory["spirit_stone"] = 100
	gs.buy_item("qi_gathering_pill", "myriad_treasure_pavilion")
	assert_eq(c.item_count("spirit_stone"), 100 - roundi(15 * 0.9))
	gs.end_session()


func test_notes_say_the_tier() -> void:
	var c := new_character()
	var d := data()
	var sect_id := "azure_cloud_sect"
	var tiers: Array = d.sect_reputation["tiers"]
	# Land mid-tier so a small change keeps the tier, a huge one changes it.
	c.reputation[sect_id] = int(tiers[tiers.size() - 1]["min"])
	var notes := Reputation.apply_changes(c, d, {sect_id: 1})
	var tier := Reputation.tier_name(c, d, sect_id)
	assert_eq(notes[0], "Azure Cloud Sect reputation +1 (now %s)" % tier)
	var before := Reputation.value(c, d, sect_id)
	notes = Reputation.apply_changes(c, d, {sect_id: -5000})
	var low := Reputation.tier_name(c, d, sect_id)
	assert_true(low != tier, "the tier changed")
	var applied := Reputation.value(c, d, sect_id) - before
	assert_eq(notes[0], "Azure Cloud Sect reputation %+d: you are now %s with Azure Cloud Sect" % [applied, low])
	for n in notes:
		assert_false(n.contains("%") or n.contains("{"))
