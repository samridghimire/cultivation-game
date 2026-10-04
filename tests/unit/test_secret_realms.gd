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
