extends TestCase
## BODY-001: body tempering stages, combat bonuses, injury resistance and risk.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _stock(c: CharacterData) -> void:
	for item_id in BodyTempering.next_stage(c, data()).get("items", {}):
		c.add_item(item_id, int(BodyTempering.next_stage(c, data())["items"][item_id]))


func test_data_is_valid() -> void:
	assert_true(BodyTempering.validate(data()).is_empty(), str(BodyTempering.validate(data())))
	assert_gt(BodyTempering.stages(data()).size(), 3)


func test_untempered_character_has_no_bonus() -> void:
	var c := new_character()
	assert_eq(BodyTempering.stage_name(c, data()), "Untempered")
	assert_eq(BodyTempering.bonus(c, data(), "max_hp"), 0.0)
	assert_eq(BodyTempering.injury_resistance(c, data()), 0.0)


func test_check_temper_reasons() -> void:
	var c := new_character()
	assert_true(BodyTempering.check_temper(c, data()).begins_with("You lack"))
	_stock(c)
	assert_eq(BodyTempering.check_temper(c, data()), "")
	Injuries.inflict(c, data(), "broken_bones")
	assert_true(BodyTempering.check_temper(c, data()).contains("injuries"))
	c.injuries.clear()
	c.body_stage = 1
	_stock(c)
	assert_true(BodyTempering.check_temper(c, data()).contains("Qi Refining"), "Iron Bone is realm gated")
	c.body_stage = BodyTempering.stages(data()).size()
	assert_true(BodyTempering.next_stage(c, data()).is_empty())
	assert_true(BodyTempering.check_temper(c, data()) != "")


func test_temper_consumes_items_and_raises_stats() -> void:
	var c := new_character()
	c.attributes["constitution"] = 60  # minimum risk
	var before := Combat.stats(c, data())
	_stock(c)
	var result := BodyTempering.temper(c, data(), seeded_rng())
	assert_true(result["ok"], result["reason"])
	assert_eq(c.body_stage, 1)
	assert_eq(result["stage_id"], "copper_skin")
	for item_id in BodyTempering.stages(data())[0]["items"]:
		assert_eq(c.item_count(item_id), 0)
	assert_eq(BodyTempering.risk(c, data()), float(data().body_tempering["min_risk"]))
	if result["injury"] == "":
		var after := Combat.stats(c, data())
		assert_gt(after["max_hp"], before["max_hp"])
		assert_gt(after["defense"], before["defense"])


func test_constitution_lowers_risk() -> void:
	var c := new_character()
	c.attributes["constitution"] = 5
	var weak := BodyTempering.risk(c, data())
	c.attributes["constitution"] = 15
	assert_gt(weak, BodyTempering.risk(c, data()))


func test_injury_resistance_lowers_injury_chance() -> void:
	var c := new_character()
	c.attributes["fortune"] = 10
	c.body_stage = BodyTempering.stages(data()).size()
	var resist := BodyTempering.injury_resistance(c, data())
	assert_gt(resist, 0.0)
	assert_true(resist <= float(data().body_tempering["max_injury_resist"]))
	var hurt := 0
	var rng := seeded_rng()
	for i in 400:
		c.injuries.clear()
		if Injuries.roll(c, data(), "combat_defeat", rng) != "":
			hurt += 1
	assert_true(hurt < 400, "a tempered body sometimes shrugs off a defeat")


func test_body_stage_saves() -> void:
	var c := new_character()
	c.body_stage = 2
	assert_eq(CharacterData.from_dict(c.to_dict()).body_stage, 2)
	assert_eq(CharacterData.from_dict({}).body_stage, 0, "old saves load untempered")


func test_game_state_temper_body_and_meditation_entry() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Body", gs.data, seeded_rng(9))
	gs.start_session(c)
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var entries: Array = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Temper your body"))
	assert_eq(entries.size(), 1)
	assert_true(entries[0]["disabled"], "no materials yet")
	_stock(c)
	entries = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Temper your body"))
	assert_false(entries[0]["disabled"], entries[0]["label"])
	var age := c.age_days
	gs.temper_body()
	assert_eq(c.body_stage, 1)
	assert_eq(c.age_days, age + int(BodyTempering.stages(gs.data)[0]["days"]))
	spot.free()
	var sheet := CharacterSheet.new()
	_root().add_child(sheet)
	sheet.open()
	assert_true(sheet._text.get_parsed_text().contains("Body: Copper Skin"))
	sheet.free()
	gs.end_session()
