extends TestCase
## WEATHER-006: timed world flags, the peddler's herb discount, storm greetings, lightning injury path.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_flag_active() -> void:
	assert_true(Effects.flag_active({"a": true}, "a", 5))
	assert_true(Effects.flag_active({"a": 1}, "a", 5))
	assert_true(Effects.flag_active({"a": {"until": 10}}, "a", 9))
	assert_false(Effects.flag_active({"a": {"until": 10}}, "a", 10))
	assert_false(Effects.flag_active({}, "a", 5))
	assert_false(Effects.flag_active({"a": false}, "a", 5))


func test_flag_days_stores_until_and_plain_flags_stay_true() -> void:
	var c := new_character()
	var flags := {}
	Effects.apply(c, data(), {"set_flag": "x", "flag_days": 30}, flags, "", 100)
	assert_eq(int(flags["x"]["until"]), 130)
	Effects.apply(c, data(), {"set_flag": "y"}, flags, "", 100)
	assert_eq(flags["y"], true)
	Effects.apply(c, data(), {"set_flag": "z", "flag_days": 30}, flags)
	assert_eq(flags["z"], true, "no day known: plain flag")
	assert_true(Effects.validate(data(), {"flag_days": 0, "set_flag": "x"}, "t").size() > 0)
	assert_true(Effects.validate(data(), {"flag_days": 3}, "t").size() > 0)
	assert_eq(Effects.validate(data(), {"flag_days": 3, "set_flag": "x"}, "t").size(), 0)


func test_expired_timed_flag_does_not_gate_encounters() -> void:
	var c := new_character()
	var d := data()
	d.encounters["t_req"] = {"id": "t_req", "tags": ["wt"], "weight": 1, "kind": "neutral", "days": 0, "text": "x", "requires_flag": "tf"}
	var live := Exploration.eligible_encounters(c, d, ["wt"], {"tf": {"until": 20}}, null, 1.0, "", "", 0, Callable(), 19)
	var dead := Exploration.eligible_encounters(c, d, ["wt"], {"tf": {"until": 20}}, null, 1.0, "", "", 0, Callable(), 20)
	assert_eq(live.size(), 1)
	assert_eq(dead.size(), 0)


func test_discount_mult_by_item_tag_and_day() -> void:
	var d := data()
	var flags := {"storm_peddler_discount": {"until": 130}}
	var herb := ""
	for id: String in d.items:
		if Items.has_tag(d, id, ["herb"]):
			herb = id
			break
	assert_true(herb != "")
	assert_almost_eq(ShopDiscounts.discount_mult(d, "qingshi_village", "Village Herb Seller", herb, flags, 129), 0.8, 0.0001)
	assert_almost_eq(ShopDiscounts.discount_mult(d, "qingshi_village", "Village Herb Seller", herb, flags, 130), 1.0, 0.0001)
	assert_almost_eq(ShopDiscounts.discount_mult(d, "qingshi_village", "Village Herb Seller", "spirit_stone", flags, 129), 1.0, 0.0001)
	assert_almost_eq(ShopDiscounts.discount_mult(d, "qingshi_village", "Nobody", herb, flags, 129), 1.0, 0.0001)
	assert_true(ShopDiscounts.validate({"flag": "", "buy_mult": 0.2, "tags": []}, "t").size() >= 3)


func test_peddler_choice_discounts_herbs_for_a_month() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var c := CharacterFactory.create("Peddler", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	c.attributes["constitution"] = 15
	gs.current_region = "qingshi_village"
	clock.total_days = 100
	gs.pending_encounter = "village_storm_stranded_peddler"
	gs.choose_encounter(0)
	assert_eq(int(gs.world_flags["storm_peddler_discount"]["until"]), 130)
	gs.shop_name = "Village Herb Seller"
	var herb := ""
	for id: String in gs.data.items:
		if Items.has_tag(gs.data, id, ["herb"]):
			herb = id
			break
	clock.total_days = 129
	var cheap: float = gs.buy_multiplier(herb)
	clock.total_days = 130
	var normal: float = gs.buy_multiplier(herb)
	assert_almost_eq(cheap / normal, 0.8, 0.0001)
	assert_almost_eq(gs.buy_multiplier(), normal, 0.0001)


func test_old_save_plain_flag_still_counts() -> void:
	var d := data()
	assert_almost_eq(ShopDiscounts.discount_mult(d, "qingshi_village", "Village Herb Seller", "dew_grass", {"storm_peddler_discount": true}, 5000), 0.8, 0.0001)


func test_storm_greeting_for_warm_villagers_only() -> void:
	var d := data()
	var npc := CharacterData.new()
	npc.id = "villager_a"
	var storm: Array = d.family["folk_greetings"]["weather"]["storm"]
	assert_true(storm.has(Folk.greeting(npc, 50, 9, d, {}, "storm")))
	assert_false(storm.has(Folk.greeting(npc, 50, 9, d, {}, "clear")))
	assert_eq(Folk.greeting(npc, 0, 9, d, {}, "storm"), "", "neutral favor: nothing")
	assert_eq(Folk.greeting(npc, 50, 9, d, {}), Folk.greeting(npc, 50, 9, d, {}, "clear"))


func test_storm_explore_applies_a_test_injury() -> void:
	var d := data()
	d.weather_effects["storm"]["explore"] = {"lightning_chance": 1.0, "lightning_damage_frac": 0.15, "thunderwood_chance": 0.0, "injury": "test_scorched"}
	var plain := CharacterData.new()
	var r := Weather.storm_explore(d, "storm", plain, seeded_rng(5))
	assert_eq(r["event"], "lightning")
	assert_eq(r["injury"], "test_scorched")


## Review: every choice that sets the peddler's discount (he promises it "for a month") makes it a timed flag.
func test_every_peddler_discount_choice_expires() -> void:
	var count := 0
	for e: Dictionary in data().encounters.values():
		for effects in encounter_outcomes(e):
			if Effects.flag_list(effects.get("set_flag", "")).has("storm_peddler_discount"):
				count += 1
				assert_eq(int(effects.get("flag_days", 0)), 30, "%s sets the discount without flag_days" % e["id"])
	assert_gt(count, 1)
