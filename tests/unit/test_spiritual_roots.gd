extends TestCase


func test_roll_is_deterministic_for_a_seed() -> void:
	var a := SpiritualRoots.roll(data(), seeded_rng(7))
	var b := SpiritualRoots.roll(data(), seeded_rng(7))
	assert_eq(a, b)


func test_roll_produces_valid_roots() -> void:
	var rng := seeded_rng(99)
	var element_ids := data().root_elements.map(func(e): return e["id"])
	for i in 200:
		var roots := SpiritualRoots.roll(data(), rng)
		assert_true(roots.size() >= 1 and roots.size() <= element_ids.size())
		for element_id in roots:
			assert_true(element_ids.has(element_id))
			assert_true(roots[element_id] >= data().root_purity_min and roots[element_id] <= data().root_purity_max)


func test_fewer_elements_cultivate_faster() -> void:
	var single := SpiritualRoots.cultivation_multiplier({"fire": 60}, data())
	var all_five := SpiritualRoots.cultivation_multiplier({"metal": 60, "wood": 60, "water": 60, "fire": 60, "earth": 60}, data())
	assert_gt(single, all_five)


func test_no_root_cannot_cultivate() -> void:
	assert_eq(SpiritualRoots.cultivation_multiplier({}, data()), 0.0)
