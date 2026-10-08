extends TestCase


func test_new_character_is_mortal() -> void:
	var c := new_character()
	assert_eq(c.realm_index, 0)
	assert_eq(c.stage, 0)
	assert_eq(c.qi, 0.0)


func test_cultivating_gathers_qi() -> void:
	var c := new_character()
	var result := Cultivation.cultivate(c, data(), 10)
	assert_gt(result["qi_gained"], 0.0)
	assert_almost_eq(c.qi, result["qi_gained"])


func test_qi_per_day_scales_with_density() -> void:
	var c := new_character()
	var base := Cultivation.qi_per_day(c, data(), 1.0)
	assert_almost_eq(Cultivation.qi_per_day(c, data(), 2.0), base * 2.0)


func test_stages_advance_automatically_within_a_realm() -> void:
	var c := new_character()
	c.realm_index = 1  # Qi Refining, 1st layer
	var needed := data().realms[1].qi_required(0)
	var result := Cultivation.add_qi(c, data(), needed + 1.0)
	assert_eq(c.stage, 1)
	assert_eq(result["stages_gained"], 1)
	assert_almost_eq(c.qi, 1.0)


func test_qi_caps_at_bottleneck() -> void:
	var c := new_character()
	var cap := data().realms[0].qi_required(0)
	var result := Cultivation.add_qi(c, data(), cap * 10.0)
	assert_almost_eq(c.qi, cap)
	assert_almost_eq(result["qi_gained"], cap)
	assert_true(result["at_bottleneck"])
	assert_true(Cultivation.can_attempt_breakthrough(c, data()))


func test_cannot_break_through_before_bottleneck() -> void:
	var c := new_character()
	var result := Cultivation.attempt_breakthrough(c, data(), seeded_rng())
	assert_false(result["attempted"])
	assert_eq(c.realm_index, 0)


func test_successful_breakthrough_enters_next_realm() -> void:
	var c := new_character()
	Cultivation.add_qi(c, data(), 1e9)
	c.breakthrough_bonus = 1.0  # guarantees success (chance clamps to 0.99)
	var rng := seeded_rng()
	var result := {}
	for i in 20:  # 0.99 per try; effectively certain
		result = Cultivation.attempt_breakthrough(c, data(), rng)
		if result["success"]:
			break
		c.breakthrough_bonus = 1.0
		Cultivation.add_qi(c, data(), 1e9)
	assert_true(result["success"])
	assert_eq(c.realm_index, 1)
	assert_eq(c.stage, 0)
	assert_eq(c.qi, 0.0)
	assert_eq(c.breakthrough_bonus, 0.0)


func test_failed_breakthrough_loses_qi() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = data().realms[1].stage_count() - 1
	Cultivation.add_qi(c, data(), 1e12)
	var before := c.qi
	c.breakthrough_bonus = -5.0  # forces minimum chance (1%)
	var rng := seeded_rng()
	var result := Cultivation.attempt_breakthrough(c, data(), rng)
	while result["success"]:  # astronomically unlikely, but stay deterministic-safe
		c.realm_index = 1
		Cultivation.add_qi(c, data(), 1e12)
		before = c.qi
		c.breakthrough_bonus = -5.0
		result = Cultivation.attempt_breakthrough(c, data(), rng)
	assert_eq(c.realm_index, 1)
	assert_almost_eq(c.qi, before * (1.0 - data().realms[2].failure_qi_loss), 0.01)


func test_cannot_break_through_past_final_realm() -> void:
	var c := new_character()
	c.realm_index = data().realms.size() - 1
	c.stage = data().realms[c.realm_index].stage_count() - 1
	Cultivation.add_qi(c, data(), 1e15)
	assert_false(Cultivation.can_attempt_breakthrough(c, data()))


func test_lifespan_grows_with_realm() -> void:
	var c := new_character()
	var mortal := Cultivation.lifespan_years(c, data())
	c.realm_index = 2
	assert_gt(Cultivation.lifespan_years(c, data()), mortal)


func test_expected_realm_years_counts_stages_and_failed_attempts() -> void:
	var realm: RealmDef = data().realms[2]
	var next: RealmDef = data().realms[3]
	var qi := 0.0
	for stage in realm.stage_count():
		qi += realm.qi_required(stage)
	var failures := (1.0 - next.breakthrough_chance) / next.breakthrough_chance
	qi += failures * realm.qi_required(realm.stage_count() - 1) * next.failure_qi_loss
	var expected := qi / realm.base_qi_per_day / Calendar.DAYS_PER_YEAR
	assert_almost_eq(Cultivation.expected_realm_years(data(), 2), expected, 0.001)
	assert_almost_eq(Cultivation.expected_realm_years(data(), 2, 2.0), expected / 2.0, 0.001)


func test_expected_realm_years_final_realm_has_no_breakthrough() -> void:
	var last := data().realms.size() - 1
	var realm: RealmDef = data().realms[last]
	var qi := 0.0
	for stage in realm.stage_count():
		qi += realm.qi_required(stage)
	assert_almost_eq(Cultivation.expected_realm_years(data(), last), qi / realm.base_qi_per_day / Calendar.DAYS_PER_YEAR, 0.001)


func test_days_to_bottleneck_matches_hand_computation() -> void:
	var c := new_character()
	var realm: RealmDef = data().realms[0]
	var per_day := Cultivation.qi_per_day(c, data())
	var remaining := 0.0
	for stage in realm.stage_count():
		remaining += realm.qi_required(stage)
	assert_eq(Cultivation.days_to_bottleneck(c, data()), ceili(remaining / per_day - 0.000001))
	c.qi = 0.0
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	assert_eq(Cultivation.days_to_bottleneck(c, data()), 0)


func test_days_to_bottleneck_without_qi_rate_is_minus_one() -> void:
	var c := new_character()
	c.spiritual_roots = {}
	assert_eq(Cultivation.days_to_bottleneck(c, data()), -1)
