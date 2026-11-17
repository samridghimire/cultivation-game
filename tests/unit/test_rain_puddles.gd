extends TestCase
## GFX-184: puddles on paths and yards of rainy days.

const REGION := {"id": "t", "map": {"ground_style": "grass", "paths": [[0, 400, 2000, 60], [900, 0, 60, 1000]],
	"landmarks": [{"kind": "pond", "pos": [500, 430], "size": [200, 120]}]},
	"places": [{"name": "Hut", "type": "house", "pos": [1500, 430], "size": [120, 90]}]}
const SIZE := Vector2(2000, 1000)


func test_puddles_on_paths_only_and_clear_of_places_and_water() -> void:
	var ps := RainPuddles.layout(REGION, SIZE, 12, "rain")
	assert_true(ps.size() >= 4)
	var lm := Scenery.landmark_rects(REGION)
	for p in ps:
		var c: Vector2 = p["pos"]
		var on_path := Rect2(0, 400, 2000, 60).has_point(c) or Rect2(900, 0, 60, 1000).has_point(c)
		assert_true(on_path, "puddle %s off the paths" % c)
		for r in lm:
			assert_false(r.has_point(c))
		assert_false(Npcs.place_keepout(REGION["places"][0]).has_point(c))


func test_after_rain_keeps_half_and_dry_or_snow_none() -> void:
	var full := RainPuddles.layout(REGION, SIZE, 12, "rain")
	var after := RainPuddles.layout(REGION, SIZE, 12, "after")
	assert_eq(after.size(), full.size() / 2)
	assert_eq(RainPuddles.layout(REGION, SIZE, 12, "").size(), 0)
	assert_eq(RainPuddles.phase_for("rain", "clear", true), "")
	assert_eq(RainPuddles.phase_for("storm", "clear", false), "rain")
	assert_eq(RainPuddles.phase_for("clear", "rain", false), "after")
	assert_eq(RainPuddles.phase_for("clear", "cloudy", false), "")


func test_paved_regions_have_none_and_layout_is_seeded() -> void:
	var paved: Dictionary = REGION.duplicate(true)
	paved["map"]["ground_style"] = "paved"
	assert_eq(RainPuddles.layout(paved, SIZE, 3, "rain").size(), 0)
	assert_eq(RainPuddles.layout(REGION, SIZE, 3, "rain"), RainPuddles.layout(REGION, SIZE, 3, "rain"))


func test_ripples_only_while_raining_and_not_reduced() -> void:
	var n := RainPuddles.new()
	n.setup(REGION, SIZE, 5, "rain", "clear", false, {}, false)
	for i in 300:
		n.advance(1.0 / 60.0)
	assert_true(n.ripple_count() > 0)
	var after := RainPuddles.new()
	after.setup(REGION, SIZE, 5, "clear", "rain", false, {}, false)
	for i in 300:
		after.advance(1.0 / 60.0)
	assert_eq(after.ripple_count(), 0)
	assert_true(after.puddles().size() > 0)
	n.free()
	after.free()
