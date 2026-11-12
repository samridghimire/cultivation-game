## GFX-122: paving slabs stay within a gentle band (no near-black holes); winter boardwalk planks stay brown.
extends TestCase


func test_paving_shade_band() -> void:
	var base := Color("8a8a90")
	for i in 400:
		var c := Scenery.paving_shade(base, i * 7919)
		assert_true(c.v >= base.v * 0.85, "slab %d not darker than 0.85x" % i)
		assert_true(c.v <= base.v * 1.15, "slab %d not far lighter" % i)
		assert_eq(c, Scenery.paving_shade(base, i * 7919), "deterministic")


func test_paving_has_worn_light_slabs() -> void:
	var base := Color("8a8a90")
	var lighter := 0
	for i in 400:
		if Scenery.paving_shade(base, i).v > base.v * 1.04:
			lighter += 1
	assert_true(lighter > 10, "some worn slabs are lighter")


func test_winter_planks_stay_brown() -> void:
	for snowy in [false, true]:
		var c := SectCourt.plank_color(snowy)
		assert_true(c.r / c.b > 1.0, "plank red over blue (snowy=%s)" % snowy)
