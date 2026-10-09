## RENOWN-001: local renown per region.
extends TestCase


func _errors_after(mutate: Callable) -> Array:
	var d := GameData.load_from_dir()
	mutate.call(d)
	d.load_errors.clear()
	d._validate_world()
	return Array(d.load_errors).filter(func(m: String) -> bool: return m.contains("renown"))


func test_gain_caps_and_ignores_unknown_sources() -> void:
	var c := new_character()
	assert_eq(Renown.gain(c, data(), "misty_forest", "bounty")["gained"], 15)
	assert_eq(Renown.value(c, "misty_forest"), 15)
	assert_eq(Renown.gain(c, data(), "misty_forest", "nonsense")["gained"], 0)
	c.renown["misty_forest"] = 148
	assert_eq(Renown.gain(c, data(), "misty_forest", "bounty")["gained"], 2)
	assert_eq(Renown.value(c, "misty_forest"), 150)
	assert_eq(Renown.gain(c, data(), "misty_forest", "bounty")["gained"], 0)


func test_empty_config_does_nothing() -> void:
	var d := GameData.load_from_dir()
	d.renown = {}
	var c := new_character()
	assert_eq(Renown.gain(c, d, "misty_forest", "bounty")["gained"], 0)
	assert_eq(Renown.buy_multiplier(c, d, "misty_forest"), 1.0)
	assert_eq(Renown.title(c, d, "misty_forest"), "")
	assert_true(c.renown.is_empty())


func test_tier_crossing_reports_the_new_title() -> void:
	var c := new_character()
	Renown.gain(c, data(), "misty_forest", "bounty")
	var r := Renown.gain(c, data(), "misty_forest", "bounty")
	assert_eq(r["new_tier"], "Known")
	assert_eq(Renown.gain(c, data(), "misty_forest", "discovery")["new_tier"], "")


func test_buy_multiplier_and_describe() -> void:
	var c := new_character()
	assert_eq(Renown.buy_multiplier(c, data(), "misty_forest"), 1.0)
	assert_eq(Renown.describe(c, data()).size(), 0)
	c.renown["misty_forest"] = 54
	assert_eq(Renown.buy_multiplier(c, data(), "misty_forest"), 0.94)
	assert_eq(Renown.buy_multiplier(c, data(), "qingshi_village"), 1.0)
	assert_eq(Array(Renown.describe(c, data())), ["Misty Forest: Respected (54)"])


func test_validator() -> void:
	assert_eq(_errors_after(func(_d: GameData) -> void: pass), [])
	var bad := {
		"first": func(d: GameData) -> void: d.renown["tiers"][0]["min"] = 5,
		"rising": func(d: GameData) -> void: d.renown["tiers"][2]["min"] = 20,
		"zero": func(d: GameData) -> void: d.renown["tiers"][1]["buy_mult"] = 0.0,
		"over": func(d: GameData) -> void: d.renown["tiers"][1]["buy_mult"] = 1.2,
		"source": func(d: GameData) -> void: d.renown["sources"]["bounty"] = -1,
		"max": func(d: GameData) -> void: d.renown["max"] = 0,
	}
	for key: String in bad:
		assert_false(_errors_after(bad[key]).is_empty(), key)


func test_renown_round_trips_and_old_saves_default() -> void:
	var c := new_character()
	c.renown = {"misty_forest": 30}
	assert_eq(CharacterData.from_dict(c.to_dict()).renown, {"misty_forest": 30})
	var d := c.to_dict()
	d.erase("renown")
	assert_eq(CharacterData.from_dict(d).renown, {})


func test_journal_line() -> void:
	var c := new_character()
	c.renown["misty_forest"] = 25
	var rows := Guidance.journal(c, data(), {}, 5, "misty_forest")
	assert_true(rows.any(func(r: Dictionary) -> bool: return String(r.get("text", "")) == "Your name in Misty Forest: Known (merchants give you 3% off)."), str(rows))


func test_gamestate_bounty_raises_renown_and_discount_applies_to_buying_only() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Hunter", gs.data, seeded_rng(9))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs.current_region = "misty_forest"
	gs.world_flags["discovered_misty_forest"] = true
	gs.data.bounties["t_bounty"] = {"id": "t_bounty", "enemy": "wild_boar", "region": "misty_forest", "reward_stones": 25, "days": 30, "cooldown_days": 10, "text": "Test posting."}
	gs.data.bounty_config["hunt_chance"] = 1.0
	gs.take_bounty("t_bounty")
	gs.explore()
	assert_eq(Renown.value(c, "misty_forest"), 15)
	c.renown["misty_forest"] = 20
	assert_eq(gs.buy_multiplier(), 0.97)
	assert_eq(gs.market_multiplier(), 1.0)
	var base := Reputation.buy_price(c, gs.data, "spirit_herb", "", 1.0)
	assert_true(Reputation.buy_price(c, gs.data, "spirit_herb", "", gs.buy_multiplier()) <= base)
	c.renown["misty_forest"] = 100
	gs._gain_renown("righteous_deed")
	assert_eq(LifeStats.get_stat(c, "best_renown"), 103)
	gs.data.bounties.erase("t_bounty")
	gs.data.bounty_config["hunt_chance"] = 0.3
	gs.end_session()
