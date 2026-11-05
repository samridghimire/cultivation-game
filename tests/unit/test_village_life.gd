extends TestCase
## GFX-040: village ambient touches (smoke, ripples, fish, birds).


func test_smoke_is_small_and_thinner_in_summer() -> void:
	var spring := VillageLife.make_smoke(Vector2.ZERO, "Spring", false)
	var summer := VillageLife.make_smoke(Vector2.ZERO, "Summer", false)
	assert_true(spring.amount <= VillageLife.MAX_SMOKE_AMOUNT)
	assert_true(summer.amount < spring.amount)
	assert_true(spring.emitting)
	spring.free()
	summer.free()


func test_reduce_motion_stops_emitting() -> void:
	var p := VillageLife.make_smoke(Vector2.ZERO, "Spring", true)
	assert_false(p.emitting)
	p.free()
	assert_false(VillageLife.birds_fly("clear", true))
	assert_false(VillageLife.birds_fly("rain", false))
	assert_true(VillageLife.birds_fly("clear", false))


func test_frozen_pond_has_no_ripples() -> void:
	assert_true(VillageLife.pond_frozen("Winter"))
	assert_false(VillageLife.pond_frozen("Summer"))
	var region := {"id": "t", "map": {"landmarks": [
		{"kind": "pond", "pos": [100, 100], "size": [80, 60]},
		{"kind": "house", "pos": [300, 100], "size": [100, 80]}]}}
	var life := VillageLife.new()
	life.setup(region, "Winter", "clear", false, Vector2(600, 400))
	assert_eq(life._ponds.size(), 0)
	life.setup(region, "Summer", "clear", false, Vector2(600, 400))
	assert_eq(life._ponds.size(), 1)
	life.setup(region, "Summer", "clear", true, Vector2(600, 400))
	assert_eq(life._ponds.size(), 0)
	life.free()


func test_ripple_point_is_inside_pond_and_deterministic() -> void:
	var rect := Rect2(100, 100, 150, 100)
	for n in 20:
		var p := VillageLife.point_in(rect, 5, n)
		assert_true(rect.has_point(p))
		assert_eq(p, VillageLife.point_in(rect, 5, n))


## GFX-067: the Heavenforge Smithy smokes; reduce_motion keeps the emitter silent.
func test_smithy_chimney_smokes() -> void:
	var region: Dictionary = data().regions["fallen_star_market"]
	for reduce in [false, true]:
		var vl := VillageLife.new()
		vl.setup(region, "Spring", "clear", reduce, Vector2(1600, 1000))
		var found := false
		for c in vl.get_children():
			if c.name == "SmithySmoke":
				found = true
				assert_eq((c as CPUParticles2D).emitting, not reduce)
		assert_true(found, "smithy emitter exists")
		vl.free()
	var off := PixelPlace.smithy_smoke_offset(Vector2(110, 80))
	assert_true(off.y < 0.0 and off.x > 0.0, "above and right of the shop centre")
