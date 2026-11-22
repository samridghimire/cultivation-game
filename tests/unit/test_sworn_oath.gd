extends TestCase
## GFX-235: the Sworn-friend oath staging helpers.


func test_layout_burner_between_pair() -> void:
	var l := SwornOath.layout(Vector2(100, 50), 120.0)
	assert_eq(l["player"], Vector2(40, 50))
	assert_eq(l["friend"], Vector2(160, 50))
	assert_eq(l["burner"], Vector2(100, 50))
	assert_eq((l["friend"] as Vector2).x - (l["player"] as Vector2).x, 120.0)


func test_bow_curve() -> void:
	assert_eq(SwornOath.bow_amount(0.0), 0.0)
	assert_eq(SwornOath.bow_amount(SwornOath.BOW_START + 0.1), 2.0)
	assert_eq(SwornOath.bow_amount(SwornOath.BOW_START + SwornOath.BOW_LENGTH), 0.0)
	assert_true(SwornOath.DURATION <= 3.0)


func test_only_top_tier_uses_oath() -> void:
	assert_false(SwornOath.is_oath_tier(3, 4))
	assert_true(SwornOath.is_oath_tier(4, 4))
	assert_false(SwornOath.is_oath_tier(1, 0))


func test_card_lines() -> void:
	var tiers: Array = data().family["folk_tiers"]
	var lines := SwornOath.card_lines("Wei", tiers.back())
	assert_eq(lines[0], "Wei: Sworn friend")
	assert_true(lines[1].begins_with("Wei takes"))
