extends TestCase
## Temporary combat buffs (Buffs) and activating forbidden secret arts (Techniques.activate).

const ART := "blood_demon_rage"


func _artist() -> CharacterData:
	var c := new_character()
	c.techniques[ART] = {"level": 1, "xp": 0.0}
	return c


func test_buff_multiplies_combat_stats() -> void:
	var c := new_character()
	var before := Combat.stats(c, data())
	assert_true(Buffs.add(c, "rage", "Rage", 10, {"attack": 0.5}))
	var after := Combat.stats(c, data())
	assert_eq(after["attack"], roundi(before["attack"] * 1.5))
	assert_eq(after["defense"], before["defense"])


func test_buffs_refresh_instead_of_stacking() -> void:
	var c := new_character()
	Buffs.add(c, "rage", "Rage", 10, {"attack": 0.5})
	Buffs.add(c, "rage", "Rage", 20, {"attack": 0.5})
	assert_almost_eq(Buffs.multiplier(c, "attack"), 1.5)
	assert_eq(int(c.buffs["rage"]["days"]), 20)
	assert_false(Buffs.add(c, "other", "Other", 0, {"attack": 1.0}))


func test_buffs_expire() -> void:
	var c := new_character()
	Buffs.add(c, "rage", "Rage", 10, {"speed": 0.3})
	assert_eq(Buffs.pass_days(c, 4).size(), 0)
	assert_eq(int(c.buffs["rage"]["days"]), 6)
	assert_eq(Buffs.pass_days(c, 6), PackedStringArray(["Rage"]))
	assert_false(Buffs.has_any(c))
	assert_almost_eq(Buffs.multiplier(c, "speed"), 1.0)


func test_buffs_survive_save() -> void:
	var c := new_character()
	Buffs.add(c, "rage", "Rage", 10, {"attack": 0.5})
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_almost_eq(Buffs.multiplier(loaded, "attack"), 1.5)
	assert_eq(int(loaded.buffs["rage"]["days"]), 10)
	var old := c.to_dict()
	old.erase("buffs")
	assert_false(Buffs.has_any(CharacterData.from_dict(old)), "old saves load without buffs")


func test_secret_art_data_is_valid() -> void:
	var def: TechniqueDef = data().techniques[ART]
	assert_gt(int(def.activation["lifespan_cost"]), 0)
	assert_true(data().items.has(def.manual_item))
	assert_true(data().load_errors.is_empty(), ", ".join(data().load_errors))


func test_activate_burns_lifespan_and_buffs() -> void:
	var c := _artist()
	var def: TechniqueDef = data().techniques[ART]
	var years_before := Cultivation.years_left(c, data())
	var attack_before: int = Combat.stats(c, data())["attack"]
	var result := Techniques.activate(c, data(), ART)
	assert_true(result["ok"], result["reason"])
	assert_eq(Cultivation.years_left(c, data()), years_before - int(def.activation["lifespan_cost"]))
	assert_gt(Combat.stats(c, data())["attack"], attack_before)
	assert_eq(int(c.buffs[ART]["days"]), int(def.activation["days"]))


func test_activation_refusals() -> void:
	var c := new_character()
	assert_true(Techniques.can_activate(c, data(), ART) != "", "unknown technique")
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	assert_true(Techniques.can_activate(c, data(), "iron_fist").contains("cannot be activated"))
	var artist := _artist()
	artist.lifespan_spent_years = Cultivation.lifespan_years(artist, data()) - artist.age_years() - 5
	var spent := artist.lifespan_spent_years
	assert_false(Techniques.activate(artist, data(), ART)["ok"], "would burn the last years")
	assert_eq(artist.lifespan_spent_years, spent)
	assert_false(Buffs.has_any(artist))


func test_describe_activation_shows_cost() -> void:
	var c := _artist()
	var text := Techniques.describe_activation(c, data(), ART)
	assert_true(text.begins_with("Burns 10 years"), text)
	assert_true(text.contains("attack"), text)
	assert_eq(Techniques.describe_activation(c, data(), "iron_fist"), "")


func test_game_state_activate_technique() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var clock := tree.root.get_node("GameClock")
	var c := CharacterFactory.create("Rager", gs.data, seeded_rng())
	gs.start_session(c)
	gs.activate_technique(ART)
	assert_false(Buffs.has_any(c), "unknown art does nothing")
	c.techniques[ART] = {"level": 1, "xp": 0.0}
	gs.activate_technique(ART)
	assert_eq(clock.total_days, 0, "activation takes no time")
	assert_true(Buffs.has_any(c))
	assert_eq(c.lifespan_spent_years, int(gs.data.techniques[ART].activation["lifespan_cost"]))
	clock.advance(int(gs.data.techniques[ART].activation["days"]))
	assert_false(Buffs.has_any(c), "the buff wears off with time")
	gs.end_session()
