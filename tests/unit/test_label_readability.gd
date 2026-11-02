extends TestCase
## GFX-052: far labels stay opaque and outlined; only fade 0 hides them.


func test_far_label_stays_readable() -> void:
	for fade: float in [0.05, 0.35, 0.7, 1.0]:
		var p := Interactable.label_paint(fade, Color(1, 0.9, 0.5))
		assert_true((p["fill"] as Color).a >= 0.85, "fill alpha at %s" % fade)
		assert_true(absf((p["outline"] as Color).a - 0.85) < 0.001)


func test_zero_fade_hides() -> void:
	var p := Interactable.label_paint(0.0, Color.WHITE)
	assert_eq((p["fill"] as Color).a, 0.0)


func test_full_fade_keeps_colour() -> void:
	var p := Interactable.label_paint(1.0, Color(1, 0.9, 0.5))
	assert_eq((p["fill"] as Color).r, 1.0)


func test_clamp_wide_label_near_edges() -> void:
	assert_eq(Interactable.clamp_label_left(1200.0, 200.0, 0.0, 1280.0), 1076.0)
	assert_eq(Interactable.clamp_label_left(-50.0, 200.0, 0.0, 1280.0), 4.0)
