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


## GFX-233: the off-screen friend's icon pulse: 1.0 at both ends, 1.3 at the middle, never below 1.
func test_icon_pulse_curve() -> void:
	assert_eq(Banner.icon_pulse_scale(0.0), 1.0)
	assert_eq(Banner.icon_pulse_scale(Banner.PULSE_SECONDS), 1.0)
	assert_true(absf(Banner.icon_pulse_scale(Banner.PULSE_SECONDS * 0.5) - 1.3) < 0.001)
	assert_true(Banner.icon_pulse_scale(0.1) > 1.0 and Banner.icon_pulse_scale(0.1) < 1.3)
	assert_eq(Banner.icon_pulse_scale(-1.0), 1.0)
	assert_eq(Banner.icon_pulse_scale(9.0), 1.0)
