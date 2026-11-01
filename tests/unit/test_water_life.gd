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
