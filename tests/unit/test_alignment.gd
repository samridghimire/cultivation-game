extends TestCase


func test_tiers() -> void:
	assert_eq(Alignment.tier(0, data())["id"], "neutral")
	assert_eq(Alignment.tier(-1000, data())["id"], "demonic")
	assert_eq(Alignment.tier(1000, data())["id"], "righteous")


func test_shift_is_clamped() -> void:
	var c := new_character()
	Alignment.shift(c, data(), 99999)
	assert_eq(c.alignment, data().alignment_max)
	Alignment.shift(c, data(), -99999)
	assert_eq(c.alignment, data().alignment_min)
