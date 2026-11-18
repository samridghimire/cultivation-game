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


## GFX-190: puddle bodies are painted by the world between the path/yard ground and the props.
func test_world_paints_puddles_between_ground_and_props() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/world.gd")
	var ground := src.find("_draw_market_ground()\n\tif _rain_puddles")
	var paint := src.find("_rain_puddles.paint_puddles(self)")
	var props := src.find("_draw_yard_props()\n\t_draw_square_props()")
	assert_true(ground >= 0 and paint > ground and props > paint, "puddles paint after the ground, before props")
	var n := RainPuddles.new()
	assert_eq(n.z_index, 0)
	n.free()


func test_eaves_drip_only_in_rain_not_snow() -> void:
	var region := {"id": "t", "places": [{"name": "Hut", "type": "family_home", "pos": [300, 300], "size": [100, 80]},
		{"name": "Pond", "type": "gather", "pos": [600, 300], "size": [60, 60]}]}
	var rain := RainEaves.layout(region, "rain", false)
	assert_eq(rain.size(), 1)  # buildings only
	var n: int = (rain[0]["drips"] as Array).size()
	assert_true(n >= 3 and n <= 6)
	assert_eq(RainEaves.layout(region, "rain", false), rain)  # seeded
	assert_eq(RainEaves.layout(region, "rain", true).size(), 0)
	assert_eq(RainEaves.layout(region, "clear", false).size(), 0)
	var wet: Rect2 = rain[0]["base"]
	assert_eq(wet.size.y, 3.0)


## GFX-194: the ripple rings paint in the world's ground pass with the bodies, not in a node above the props.
func test_ripples_paint_with_the_bodies_not_in_the_node_draw() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/rain_puddles.gd")
	var node_draw := src.substr(src.find("func _draw()"), src.find("func paint_puddles") - src.find("func _draw()"))
	assert_false(node_draw.contains("_ripples"))
	assert_true(src.substr(src.find("func paint_puddles")).contains("_ripples"))
