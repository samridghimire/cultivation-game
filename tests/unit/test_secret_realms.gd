extends TestCase
## W-005: secret realms (data/secret_realms.json, SecretRealms).

const Y := Calendar.DAYS_PER_YEAR


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _def() -> Dictionary:
	return {"id": "test_realm", "name": "Test Realm", "region": "misty_forest", "period_years": 5, "offset_years": 1, "open_days": 60,
		"min_realm": "qi_refining", "max_realm": "qi_refining", "entry_stones": 10,
		"floors": [
			{"name": "One", "days": 2, "guardian": "", "treasures": [{"weight": 1, "effects": {"items": {"spirit_herb": 2}}}]},
			{"name": "Two", "days": 3, "guardian": "", "treasures": [{"weight": 1, "effects": {"qi": 10}}]},
		]}


func _cultivator() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.inventory = {"spirit_stone": 100}
	return c


func test_opening_schedule() -> void:
	var def := _def()
	assert_eq(SecretRealms.opening_index(def, 0), -1)
	assert_false(SecretRealms.is_open(def, 0))
	assert_eq(SecretRealms.days_until_open(def, 0), Y)
	assert_true(SecretRealms.is_open(def, Y))
	assert_eq(SecretRealms.days_until_close(def, Y + 10), 50)
	assert_false(SecretRealms.is_open(def, Y + 60))
	assert_eq(SecretRealms.days_until_open(def, Y + 60), 5 * Y - 60)
	assert_true(SecretRealms.is_open(def, 6 * Y + 1))
	assert_eq(SecretRealms.opening_index(def, 6 * Y + 1), 1)


func test_entry_checks() -> void:
	var data := data()
	data.secret_realms["test_realm"] = _def()
	var c := _cultivator()
	assert_eq(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", Y), "")
	assert_true(SecretRealms.check_enter(c, data, "nope", "misty_forest", Y) != "", "unknown")
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "qingshi_village", Y) != "", "wrong region")
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", 0) != "", "sealed")
	c.realm_index = 0
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", Y) != "", "too weak")
	c.realm_index = 2
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", Y) != "", "too strong")
	c.realm_index = 1
	c.inventory = {"spirit_stone": 5}
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", Y) != "", "too poor")
	data.secret_realms.erase("test_realm")


func test_floors_progress_and_reset_next_opening() -> void:
	var data := data()
	var def := _def()
	data.secret_realms["test_realm"] = def
	var c := _cultivator()
	var rng := seeded_rng()
	assert_eq(SecretRealms.pay_entry(c, def, Y), 10)
	assert_eq(SecretRealms.entry_cost(c, def, Y), 0, "paid once per opening")
	var first := SecretRealms.claim_floor(c, data, "test_realm", Y, {}, rng)
	assert_eq(first["floor_name"], "One")
	assert_false(first["last"])
	assert_eq(c.item_count("spirit_herb"), 2)
	assert_eq(SecretRealms.pay_entry(c, def, Y + 5), 0, "no second fee")
	assert_true(SecretRealms.claim_floor(c, data, "test_realm", Y + 5, {}, rng)["last"])
	assert_true(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", Y + 10) != "", "plundered")
	assert_eq(SecretRealms.floors_cleared(c, def, 6 * Y), 0, "next opening starts fresh")
	assert_eq(SecretRealms.entry_cost(c, def, 6 * Y), 10)
	assert_eq(SecretRealms.check_enter(c, data, "test_realm", "misty_forest", 6 * Y), "")
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(SecretRealms.floors_cleared(restored, def, Y + 10), 2, "progress is saved")
	data.secret_realms.erase("test_realm")


func test_data_is_valid() -> void:
	assert_gt(data().secret_realms.size(), 0)
	assert_eq(SecretRealms.validate(data()).size(), 0)
	assert_eq(SecretRealms.in_region(data(), "misty_forest"), ["verdant_remnant"])
	var c := _cultivator()
	assert_true(SecretRealms.status_text(c, data(), "verdant_remnant", 0).begins_with("Sealed"))


# --- GameState integration ----------------------------------------------------

func test_game_state_delves_the_verdant_remnant() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var c := CharacterFactory.create("Delver", gs.data, seeded_rng(9))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs.current_region = "misty_forest"
	c.realm_index = 1
	c.stage = 8
	# Geared like a typical player: since QA-007d a bare one wins only ~70% of these fights.
	c.equipment = {"weapon": "iron_sword", "armor": "iron_scale_armor"}
	c.techniques["iron_fist"] = {"level": 3, "xp": 0.0}
	c.add_item("spirit_stone", 50)
	var def := SecretRealms.realm(gs.data, "verdant_remnant")
	gs.enter_secret_realm("verdant_remnant")
	assert_eq(SecretRealms.floors_cleared(c, def, clock.total_days), 0, "sealed at the start of the game")
	clock.total_days = SecretRealms.days_until_open(def, clock.total_days)
	var stones := c.item_count("spirit_stone")
	gs.enter_secret_realm("verdant_remnant")
	assert_eq(SecretRealms.floors_cleared(c, def, clock.total_days), 1, "a late Qi Refining cultivator beats the mist wolf")
	assert_true(c.item_count("spirit_stone") >= stones - int(def["entry_stones"]))
	c.realm_index = 2
	gs.enter_secret_realm("verdant_remnant")
	assert_eq(SecretRealms.floors_cleared(c, def, clock.total_days), 1, "too strong to pass the barrier now")


# --- W-005d: expulsion and inheritances -----------------------------------------

func test_closing_realm_expels_mid_floor() -> void:
	var data := data()
	var def := _def()
	def["expulsion_injury"] = "broken_bones"
	data.secret_realms["test_realm"] = def
	var c := _cultivator()
	var close_day := Y + 59  # one day left, the first floor takes two
	assert_false(SecretRealms.closes_mid_floor(c, def, Y), "plenty of time")
	assert_true(SecretRealms.closes_mid_floor(c, def, close_day))
	assert_false(SecretRealms.closes_mid_floor(c, def, Y + 60), "closed realms do not expel")
	assert_true(SecretRealms.status_text(c, data, "test_realm", close_day).ends_with("closing before the next floor ends"))
	var result := SecretRealms.expel(c, data, def, close_day)
	assert_eq(result["days"], 1)
	assert_eq(result["injury"], "broken_bones")
	assert_true(c.injuries.has("broken_bones"))
	def.erase("expulsion_injury")
	assert_eq(SecretRealms.expel(c, data, def, close_day)["injury"], "", "no injury configured")
	data.secret_realms.erase("test_realm")


func test_inheritance_once_per_life() -> void:
	var data := data()
	var def := _def()
	def["inheritance"] = {"name": "Test Legacy", "text": "", "min_comprehension": 12, "effects": {"learn_technique": "iron_fist"}}
	data.secret_realms["test_realm"] = def
	var c := _cultivator()
	c.attributes["comprehension"] = 8
	assert_true(SecretRealms.check_inheritance(c, data, "test_realm").contains("comprehension"), "too dull")
	c.attributes["comprehension"] = 12
	assert_eq(SecretRealms.check_inheritance(c, data, "test_realm"), "")
	var notes := SecretRealms.claim_inheritance(c, data, "test_realm", {})
	assert_true(Techniques.knows(c, "iron_fist"))
	assert_eq(notes.size(), 1)
	assert_true(SecretRealms.has_inherited(c, "test_realm"))
	assert_true(SecretRealms.check_inheritance(c, data, "test_realm") != "", "only once")
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(SecretRealms.has_inherited(restored, "test_realm"), "saved")
	def.erase("inheritance")
	assert_true(SecretRealms.check_inheritance(new_character(), data, "test_realm") != "", "no inheritance")
	data.secret_realms.erase("test_realm")


func test_validate_rejects_bad_depth_fields() -> void:
	var data := data()
	var def := _def()
	def["id"] = "bad_realm"
	def["expulsion_injury"] = "nope"
	def["inheritance"] = {"name": "", "effects": {"learn_technique": "nope"}}
	(def["floors"] as Array)[0]["days"] = 60
	data.secret_realms["bad_realm"] = def
	var errors := SecretRealms.validate(data)
	data.secret_realms.erase("bad_realm")
	assert_eq(errors.size(), 4, str(errors))


func test_game_state_inheritance_and_expulsion() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var c := CharacterFactory.create("Heir", gs.data, seeded_rng(9))
	gs.start_session(c)
	gs.current_region = "misty_forest"
	c.realm_index = 1
	c.stage = 8
	c.attributes["comprehension"] = 15
	var def := SecretRealms.realm(gs.data, "verdant_remnant")
	var opening := SecretRealms.days_until_open(def, clock.total_days)
	# Skip the guarded floors: the last one is left.
	var floors: int = (def["floors"] as Array).size()
	c.secret_realms["verdant_remnant"] = {"opening": SecretRealms.opening_index(def, opening), "floor": floors - 1}
	clock.total_days = opening + int(def["open_days"]) - 1
	gs.enter_secret_realm("verdant_remnant")
	assert_eq(SecretRealms.floors_cleared(c, def, opening), floors - 1, "expelled without the floor")
	assert_true(c.injuries.has(String(def["expulsion_injury"])))
	assert_false(SecretRealms.is_open(def, clock.total_days), "time ran out with the realm")
	# Next opening, with time to spare: clear the last floor (its guardian set aside for the test).
	c.injuries.clear()
	var last_floor: Dictionary = (def["floors"] as Array)[floors - 1]
	var guardian: String = last_floor["guardian"]
	last_floor["guardian"] = ""
	var next_open: int = clock.total_days + SecretRealms.days_until_open(def, clock.total_days)
	c.secret_realms["verdant_remnant"] = {"opening": SecretRealms.opening_index(def, next_open), "floor": floors - 1}
	clock.total_days = next_open
	var tech := String(def["inheritance"]["effects"]["learn_technique"])
	c.techniques.erase(tech)
	gs.enter_secret_realm("verdant_remnant")
	last_floor["guardian"] = guardian
	assert_eq(SecretRealms.floors_cleared(c, def, next_open), floors, "the heart pavilion is plundered")
	assert_true(SecretRealms.has_inherited(c, "verdant_remnant"))
	assert_true(Techniques.knows(c, tech))


## W-005c: one secret realm per region, Qi Refining to Nascent Soul, each with
## an entrance place.
func test_secret_realm_content_per_region() -> void:
	var d := data()
	var top := 0
	for region_id: String in d.regions:
		var realms := SecretRealms.in_region(d, region_id)
		assert_false(realms.is_empty(), "%s has no secret realm" % region_id)
		var has_entrance: bool = (d.regions[region_id].get("places", []) as Array).any(func(p: Dictionary) -> bool: return p.get("type", "") == "secret_realm")
		assert_true(has_entrance, "%s has no entrance" % region_id)
		for realm_id in realms:
			var def := SecretRealms.realm(d, realm_id)
			var floors: int = (def["floors"] as Array).size()
			assert_true(floors >= 3 and floors <= 5, "%s has %d floors" % [realm_id, floors])
			top = maxi(top, d.realm_index_of(String(def["max_realm"])))
	assert_eq(top, d.realm_index_of("nascent_soul"), "some realm reaches Nascent Soul")


## W-005f: rivals inside realms and rivals claiming inheritances.
func test_realm_rivals() -> void:
	var d := data()
	var def := SecretRealms.realm(d, "sunken_sword_tomb")
	var people := {}
	var rival := SecretRealms.spawn_rival(people, d, def, seeded_rng())
	assert_true(rival.realm_index >= d.realm_index_of(String(def["min_realm"])) and rival.realm_index <= d.realm_index_of(String(def["max_realm"])))
	assert_eq(rival.home_region, String(def["region"]))
	var hits := 0
	for i in 200:
		if SecretRealms.roll_rival(d, seeded_rng(i)):
			hits += 1
	assert_true(hits > 20 and hits < 120, "about chance_per_floor of floors: %d / 200" % hits)


func test_closing_and_lost_inheritance() -> void:
	var d := data()
	var def := SecretRealms.realm(d, "verdant_remnant")
	var open_day := int(def["offset_years"]) * Calendar.DAYS_PER_YEAR
	var close_day := open_day + int(def["open_days"])
	assert_false(SecretRealms.closed_between(def, open_day, close_day - 1))
	assert_true(SecretRealms.closed_between(def, close_day - 1, close_day))
	assert_true(SecretRealms.closed_between(def, open_day + 5, close_day + 200))
	var c := new_character()
	assert_false(SecretRealms.cleared_last_opening(c, def, close_day))
	c.secret_realms["verdant_remnant"] = {"opening": 0, "floor": (def["floors"] as Array).size()}
	assert_true(SecretRealms.cleared_last_opening(c, def, close_day))
	var flags := {}
	assert_false(SecretRealms.rival_claims_inheritance(c, d, "verdant_remnant", true, flags, seeded_rng()), "cleared: nobody beats you to it")
	var lost := false
	for i in 40:
		if SecretRealms.rival_claims_inheritance(c, d, "verdant_remnant", false, flags, seeded_rng(i)):
			lost = true
			break
	assert_true(lost)
	assert_true(SecretRealms.check_inheritance(c, d, "verdant_remnant", flags).contains("rival claimed"))
