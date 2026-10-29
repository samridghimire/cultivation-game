extends TestCase
## GFX-009: the camera zoom keeps sprite pixels a whole number of screen pixels.

const _W := preload("res://src/world/world.gd")


func test_pixel_zoom_values() -> void:
	assert_eq(_W.pixel_zoom(1.0, 2), 1.0)
	assert_true(absf(_W.pixel_zoom(1.35, 2) - 3.0 / 2.7) < 0.0001)
	assert_true(absf(_W.pixel_zoom(0.9, 2) - 2.0 / 1.8) < 0.0001)
	assert_eq(_W.pixel_zoom(1.5, 2), 1.0)


func test_whole_screen_pixels() -> void:
	for stretch in [0.9, 1.0, 1.35, 1.5, 2.0, 2.4]:
		var total: float = stretch * 2 * _W.pixel_zoom(stretch, 2)
		assert_true(absf(total - roundf(total)) < 0.0001, str(stretch))
