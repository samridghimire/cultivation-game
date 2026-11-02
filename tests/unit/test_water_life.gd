extends TestCase
## GFX-047: living water (scrolling stream dashes, pond shimmer, rain ripples).

const REGION := {"id": "t", "map": {"paths": [], "landmarks": [
	{"kind": "stream", "pos": [300, 100], "size": [400, 40]},
	{"kind": "pond", "pos": [100, 300], "size": [120, 80]}]}}


func _life(rain: bool, frozen: bool, reduce: bool) -> WaterLife:
	var w := WaterLife.new()
	w.setup(REGION, rain, frozen, reduce)
	return w


func test_stream_dashes_scroll_unless_reduce_motion() -> void:
	var still := _life(false, false, true)
	for i in 30:
		still.advance(1.0 / 60.0)
	assert_eq(still.flow_offset, 0.0)
	assert_false(still.is_processing())
	still.free()
	var moving := _life(false, false, false)
	for i in 30:
		moving.advance(1.0 / 60.0)
	assert_true(moving.flow_offset > 0.0)
	moving.free()


func test_rain_ripples_on_ponds_but_not_frozen_or_dry() -> void:
	var rainy := _life(true, false, false)
	for i in 600:
		rainy.advance(1.0 / 60.0)
	assert_true(rainy.ripple_count() > 0)
	assert_true(rainy.ripple_count() <= WaterLife.ripple_cap(1))
	rainy.free()
	var frozen := _life(true, true, false)
	var dry := _life(false, false, false)
	for i in 600:
		frozen.advance(1.0 / 60.0)
		dry.advance(1.0 / 60.0)
	assert_eq(frozen.ripple_count(), 0)
	assert_eq(dry.ripple_count(), 0)
	frozen.free()
	dry.free()


func test_shimmer_alpha_stays_in_range() -> void:
	for i in 40:
		var a := WaterLife.shimmer_alpha(float(i) * 0.25)
		assert_true(a >= WaterLife.SHIMMER_LOW - 0.001 and a <= WaterLife.SHIMMER_HIGH + 0.001)


func test_ripples_never_land_on_jetty_planks() -> void:
	var region := {"id": "j", "map": {"paths": [], "landmarks": [
		{"kind": "pond", "pos": [100, 100], "size": [120, 80]},
		{"kind": "jetty", "pos": [100, 150], "size": [28, 88]}]}}
	var w := WaterLife.new()
	w.setup(region, true, false, false)
	assert_true(w.on_jetty(Vector2(100, 140)))
	assert_false(w.on_jetty(Vector2(10, 10)))
	for i in 3000:
		w.advance(1.0 / 60.0)
		for r in w._ripples:
			assert_false(w.on_jetty(r["pos"]))
	w.free()


## WU-431: every pond landmark of every region is a drawable `pond` (PixelLandmark) with room to draw.
func test_every_pond_landmark_is_drawable() -> void:
	var gd := data()
	var n := 0
	for id: String in gd.regions:
		for lm: Dictionary in gd.regions[id].get("map", {}).get("landmarks", []):
			if lm["kind"] == "pond":
				n += 1
				assert_true(PixelLandmark.supports("pond"))
				var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
				var px := PixelLandmark.pixel_size("pond", size)
				assert_true(px.x >= 3 and px.y >= 3, "%s pond too small" % id)
				assert_true(PixelLandmark.texture("pond", size).get_width() > 0)
	assert_true(n >= 4)
