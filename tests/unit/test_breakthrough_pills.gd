extends TestCase
## Breakthrough pills only work for the realm they are made for, one per attempt (RV-005).


func _use(c: CharacterData, item_id: String) -> Dictionary:
	return Items.use(c, data(), item_id, {})


func test_foundation_pill_refused_at_core_formation() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.add_item("foundation_establishment_pill", 1)
	var result := _use(c, "foundation_establishment_pill")
	assert_false(result["ok"])
	assert_true(String(result["reason"]).contains("Foundation Establishment"))
	assert_eq(c.breakthrough_bonus, 0.0)
	assert_eq(c.item_count("foundation_establishment_pill"), 1)


func test_matching_pill_works_then_no_stacking() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	c.add_item("foundation_establishment_pill", 2)
	assert_true(_use(c, "foundation_establishment_pill")["ok"])
	assert_almost_eq(c.breakthrough_bonus, 0.25)
	var second := _use(c, "foundation_establishment_pill")
	assert_false(second["ok"])
	assert_almost_eq(c.breakthrough_bonus, 0.25)
	assert_eq(c.item_count("foundation_establishment_pill"), 1)


func test_realm_pill_works_at_its_realm() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("core_formation")
	c.add_item("nascent_soul_pill", 1)
	c.add_item("core_forming_pill", 1)
	assert_false(_use(c, "core_forming_pill")["ok"])
	assert_true(_use(c, "nascent_soul_pill")["ok"])


func test_every_pill_names_a_valid_realm() -> void:
	for item: Dictionary in data().items.values():
		var fx: Dictionary = item.get("effects", {})
		if fx.has("breakthrough_realm"):
			assert_true(data().realm_index_of(String(fx["breakthrough_realm"])) >= 1, item["id"])
	assert_true(data().load_errors.is_empty())


func test_herb_bonus_does_not_block_realm_pill() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	c.add_item("blood_ginseng", 1)
	c.add_item("foundation_establishment_pill", 2)
	assert_true(_use(c, "blood_ginseng")["ok"])
	assert_eq(c.breakthrough_pill, "")
	assert_true(_use(c, "foundation_establishment_pill")["ok"])
	assert_eq(c.breakthrough_pill, "foundation_establishment")
	assert_almost_eq(c.breakthrough_bonus, 0.30)
	assert_false(_use(c, "foundation_establishment_pill")["ok"])
	Cultivation.add_qi(c, data(), 1e9)
	Cultivation.attempt_breakthrough(c, data(), seeded_rng())
	assert_eq(c.breakthrough_pill, "")


func test_breakthrough_pill_round_trips() -> void:
	var c := new_character()
	c.breakthrough_pill = "foundation_establishment"
	assert_eq(CharacterData.from_dict(c.to_dict()).breakthrough_pill, "foundation_establishment")
	var d := c.to_dict()
	d.erase("breakthrough_pill")
	assert_eq(CharacterData.from_dict(d).breakthrough_pill, "")
