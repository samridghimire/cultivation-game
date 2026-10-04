extends TestCase
## Spirit beast companions (BEAST-001): taming after a victory, companion
## combat bonuses, release, saves and data validation.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _tamer(rank: int = 0) -> CharacterData:
	var c := new_character()
	c.professions[Beasts.PROFESSION] = {"rank": rank, "xp": 0.0}
	return c


func test_beasts_data_is_valid() -> void:
	assert_eq(Beasts.validate(data()).size(), 0, str(Beasts.validate(data())))
	assert_eq(Beasts.beast_for_enemy(data(), "mist_wolf"), "mist_wolf")
	assert_eq(Beasts.beast_for_enemy(data(), "mountain_bandit"), "", "people are not beasts")


func test_tame_chance_grows_with_rank_and_caps() -> void:
	var tame: Dictionary = data().beast_rules["tame"]
	assert_almost_eq(Beasts.tame_chance(_tamer(0), data()), float(tame["base_chance"]))
	assert_gt(Beasts.tame_chance(_tamer(2), data()), Beasts.tame_chance(_tamer(0), data()))
	assert_almost_eq(Beasts.tame_chance(_tamer(Professions.max_rank(data())), data()), minf(float(tame["max_chance"]), float(tame["base_chance"]) + float(tame["chance_per_rank"]) * Professions.max_rank(data())))


func test_check_tame_rules() -> void:
	assert_true(Beasts.check_tame(new_character(), data(), "boar").contains("Beast Tamer"), "non-tamers cannot tame")
	assert_eq(Beasts.check_tame(_tamer(0), data(), "boar"), "")
	assert_true(Beasts.check_tame(_tamer(0), data(), "thunderwing_roc") != "", "the roc needs a higher rank")
	assert_true(Beasts.check_tame(_tamer(0), data(), "nope") != "")
	var full := _tamer(0)
	for i in Beasts.max_companions(data()):
		full.companions.append("boar")
	assert_true(Beasts.check_tame(full, data(), "mist_wolf").contains("another companion"))


func test_try_tame_rolls_and_gives_xp() -> void:
	var tamed := 0
	for i in 200:
		var c := _tamer(0)
		var r := Beasts.try_tame(c, data(), "wild_boar", seeded_rng(i))
		assert_true(r["attempted"])
		assert_gt(Professions.xp_of(c, Beasts.PROFESSION), 0.0)
		if r["tamed"]:
			tamed += 1
			assert_eq(c.companions, ["boar"] as Array[String])
		else:
			assert_true(c.companions.is_empty())
	var expected := Beasts.tame_chance(_tamer(0), data()) * 200
	assert_true(abs(tamed - expected) < 25, "tamed %d of 200, expected ~%d" % [tamed, expected])
	var not_tamer := new_character()
	assert_false(Beasts.try_tame(not_tamer, data(), "wild_boar", seeded_rng())["attempted"])
	assert_false(Beasts.try_tame(_tamer(0), data(), "mountain_bandit", seeded_rng())["attempted"])


func test_companion_raises_combat_stats() -> void:
	var c := _tamer(0)
	c.realm_index = data().realm_index_of("qi_refining")
	var before := Combat.stats(c, data())
	c.companions.append("mist_wolf")
	var after := Combat.stats(c, data())
	assert_gt(after["attack"], before["attack"])
	assert_eq(after["defense"], before["defense"], "the wolf adds no defense")
	assert_eq(Beasts.describe(c, data()).size(), 1)


func test_rank_strengthens_and_outgrowing_weakens() -> void:
	var c := _tamer(0)
	c.realm_index = data().realm_index_of("qi_refining")
	var base := Beasts.strength_of(c, data(), "mist_wolf")
	assert_almost_eq(base, 1.0)
	c.professions[Beasts.PROFESSION]["rank"] = 3
	assert_gt(Beasts.strength_of(c, data(), "mist_wolf"), base)
	c.professions[Beasts.PROFESSION]["rank"] = 0
	c.realm_index = data().realm_index_of("core_formation")
	var outgrown := Beasts.strength_of(c, data(), "mist_wolf")
	assert_almost_eq(outgrown, pow(float(data().beast_rules["outgrown_scale"]), 2))
	assert_almost_eq(Beasts.strength_of(c, data(), "jade_python"), 1.0, 0.001, "a Core Formation beast keeps up")


func test_release() -> void:
	var c := _tamer(0)
	c.companions.append("boar")
	assert_eq(Beasts.release(c, data(), 3), "")
	assert_eq(Beasts.release(c, data(), 0), "Fields Boar")
	assert_true(c.companions.is_empty())


func test_companions_survive_saves() -> void:
	var c := _tamer(0)
	c.companions.append("mist_wolf")
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(loaded.companions, ["mist_wolf"] as Array[String])
	var old := c.to_dict()
	old.erase("companions")
	assert_true(CharacterData.from_dict(old).companions.is_empty(), "older saves load without companions")


func test_validation_rejects_bad_beasts() -> void:
	var d := GameData.new()
	d.enemies = data().enemies
	d.professions = data().professions
	d.profession_rank_names = data().profession_rank_names
	d.beast_rules = {"max_companions": 0, "tame": {"base_chance": 0.1, "max_chance": 2.0}, "outgrown_scale": 0.0}
	d.beasts = {
		"a": {"id": "a", "enemy": "ghost", "bonuses": {"luck": 0.1}},
		"b": {"id": "b", "enemy": "wild_boar", "min_rank": 99, "bonuses": {}},
		"c": {"id": "c", "enemy": "wild_boar", "bonuses": {"attack": -0.1}},
	}
	# max_companions, max_chance, outgrown_scale, unknown enemy, unknown bonus,
	# min_rank, no bonuses, shared enemy, negative bonus
	assert_eq(Beasts.validate(d).size(), 9, str(Beasts.validate(d)))


func test_game_state_tames_after_victory_and_releases() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Tamer", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.professions[Beasts.PROFESSION] = {"rank": 0, "xp": 0.0}
	var tame: Dictionary = gs.data.beast_rules["tame"]
	var saved := tame.duplicate()
	tame["base_chance"] = 1.0
	tame["max_chance"] = 1.0
	assert_true(gs.fight_enemy(gs.data.enemies["wild_boar"]), "a Foundation cultivator beats a boar")
	gs.data.beast_rules["tame"] = saved
	assert_eq(c.companions, ["boar"] as Array[String])
	gs.release_companion(0)
	assert_true(c.companions.is_empty())
	gs.end_session()


## BEAST-001d: feeding raises a companion's level, which offsets outgrowing it.
func test_feeding_levels_companions() -> void:
	var d := data()
	var c := new_character()
	c.companions = ["mist_wolf"] as Array[String]
	c.realm_index = d.realm_index_of("core_formation")
	var weak := Beasts.strength_of(c, d, "mist_wolf")
	assert_eq(Beasts.level(c, d, "mist_wolf"), 1)
	assert_true(Beasts.check_feed(c, d, "mist_wolf", "spirit_herb").contains("You have no"))
	assert_true(Beasts.check_feed(c, d, "mist_wolf", "iron_sword") != "", "not food")
	c.inventory = {"blood_ginseng": 5, "spirit_herb": 1}
	assert_eq(Beasts.best_food(c, d), "blood_ginseng")
	for i in 4:
		assert_true(Beasts.feed(c, d, "mist_wolf", "blood_ginseng")["ok"])
	assert_eq(Beasts.level(c, d, "mist_wolf"), 3)
	assert_gt(Beasts.strength_of(c, d, "mist_wolf"), weak, "levels offset outgrowing")
	assert_true(Beasts.describe(c, d)[0].contains("(level 3)"))
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(back.companion_xp["mist_wolf"]), int(c.companion_xp["mist_wolf"]))
	Beasts.release(c, d, 0)
	assert_false(c.companion_xp.has("mist_wolf"), "released beasts take their growth with them")


## BEAST-001b: the character sheet lists companions with a Feed button.
func test_sheet_shows_and_feeds_companions() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.companions = ["boar"] as Array[String]
	c.inventory = {"spirit_herb": 3}
	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	sheet.open()
	assert_true(sheet._text.get_parsed_text().contains("Spirit Beasts"))
	var feed := sheet._equip_row.get_node("feed_boar") as Button
	assert_true(feed != null and not feed.disabled, "feed button")
	feed.pressed.emit()
	assert_eq(c.item_count("spirit_herb"), 2)
	assert_gt(int(c.companion_xp.get("boar", 0)), 0)
	sheet.free()
	gs.end_session()
