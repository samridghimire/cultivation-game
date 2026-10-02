extends TestCase
## Lifespan as a resource: burning years for power, extending them with longevity treasures.


func test_lifespan_accounts_for_spent_and_bonus_years() -> void:
	var c := new_character()
	var base := Cultivation.lifespan_years(c, data())
	c.lifespan_bonus_years = 30
	c.lifespan_spent_years = 12
	assert_eq(Cultivation.lifespan_years(c, data()), base + 18)


func test_years_left_never_negative() -> void:
	var c := new_character()
	c.age_days = Calendar.DAYS_PER_YEAR * 20
	assert_eq(Cultivation.years_left(c, data()), Cultivation.lifespan_years(c, data()) - 20)
	c.lifespan_spent_years = 10000
	assert_eq(Cultivation.years_left(c, data()), 0)


func test_burn_and_extend_reject_non_positive() -> void:
	var c := new_character()
	assert_false(Cultivation.burn_lifespan(c, 0))
	assert_false(Cultivation.extend_lifespan(c, -3))
	assert_true(Cultivation.burn_lifespan(c, 4))
	assert_true(Cultivation.extend_lifespan(c, 7))
	assert_eq(c.lifespan_spent_years, 4)
	assert_eq(c.lifespan_bonus_years, 7)


func test_bonus_and_spent_years_survive_breakthrough_and_save() -> void:
	var c := new_character()
	c.lifespan_spent_years = 5
	c.lifespan_bonus_years = 20
	var before := Cultivation.lifespan_years(c, data())
	c.realm_index = 1
	var gain: int = data().realms[1].lifespan_years - data().realms[0].lifespan_years
	assert_eq(Cultivation.lifespan_years(c, data()), before + gain)
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(loaded.lifespan_spent_years, 5)
	assert_eq(loaded.lifespan_bonus_years, 20)


func test_old_saves_default_to_no_change() -> void:
	var d := new_character().to_dict()
	d.erase("lifespan_spent_years")
	d.erase("lifespan_bonus_years")
	var loaded := CharacterData.from_dict(d)
	assert_eq(loaded.lifespan_spent_years, 0)
	assert_eq(loaded.lifespan_bonus_years, 0)


func test_burning_pill_trades_years_for_qi() -> void:
	var c := new_character()
	c.add_item("blood_essence_pill", 1)
	var lifespan := Cultivation.lifespan_years(c, data())
	var result := Items.use(c, data(), "blood_essence_pill", {})
	assert_true(result["ok"], str(result))
	var burn := int(data().items["blood_essence_pill"]["effects"]["burn_lifespan"])
	assert_eq(Cultivation.lifespan_years(c, data()), lifespan - burn)
	assert_true(", ".join(result["notes"]).contains("years of lifespan"))


func test_cannot_burn_the_last_years() -> void:
	var c := new_character()
	c.add_item("blood_essence_pill", 1)
	var burn := int(data().items["blood_essence_pill"]["effects"]["burn_lifespan"])
	c.age_days = (Cultivation.lifespan_years(c, data()) - burn) * Calendar.DAYS_PER_YEAR
	var result := Items.use(c, data(), "blood_essence_pill", {})
	assert_false(result["ok"])
	assert_true(String(result["reason"]).contains("kill you"))
	assert_eq(c.item_count("blood_essence_pill"), 1)
	assert_eq(c.lifespan_spent_years, 0)


func test_longevity_pill_extends_life() -> void:
	var c := new_character()
	c.add_item("longevity_pill", 1)
	var lifespan := Cultivation.lifespan_years(c, data())
	assert_true(Items.use(c, data(), "longevity_pill", {})["ok"])
	assert_eq(Cultivation.lifespan_years(c, data()), lifespan + int(data().items["longevity_pill"]["effects"]["extend_lifespan"]))


func test_inventory_text_warns_about_lifespan_cost() -> void:
	var lines := InventoryScreen.describe_effects(data().items["blood_essence_pill"]["effects"], data())
	assert_true(", ".join(lines).contains("WARNING"))


func test_game_state_burning_and_old_age() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Reckless", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("blood_essence_pill", 1)
	var qi_before := c.qi + c.stage * 1000000.0 + c.realm_index * 1000000000.0
	gs.use_item("blood_essence_pill")
	assert_eq(c.item_count("blood_essence_pill"), 0)
	assert_gt(c.lifespan_spent_years, 0)
	assert_gt(c.qi + c.stage * 1000000.0 + c.realm_index * 1000000000.0, qi_before)
	# Burned years make old age arrive sooner.
	c.age_days = (Cultivation.lifespan_years(c, gs.data) - 1) * Calendar.DAYS_PER_YEAR
	gs.call("_on_days_advanced", Calendar.DAYS_PER_YEAR)
	assert_false(c.alive)
	gs.end_session()
