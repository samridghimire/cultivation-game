extends TestCase
## WU-491: Banner tests.


## WU-491: dismissing the arrival card removes it, showing or queued.
func test_dismiss_titled_drops_card() -> void:
	var b := Banner.new()
	b.set_held(true)
	b.announce("Qingshi Village", "Qi x1.05", Color.WHITE)
	b.announce("Other", "", Color.WHITE)
	b.dismiss_titled("Qingshi Village")
	assert_eq(b.queued_count(), 1)
	b.free()
