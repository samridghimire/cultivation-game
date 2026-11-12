## WU-518: small text stays legible: project font settings are pinned and no UIStyle label drops below the 14 px floor.
extends TestCase


func test_font_settings_pinned() -> void:
	assert_eq(int(ProjectSettings.get_setting("gui/theme/default_font_subpixel_positioning")), 0)
	assert_eq(int(ProjectSettings.get_setting("gui/theme/default_font_hinting")), 2)
	# GFX-066: snapping stays off.
	assert_false(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")))


func test_label_floor() -> void:
	for size in [8, 11, 12, 13, 14, 20]:
		var l: Label = UIStyle.label("x", size)
		var got: int = l.get_theme_font_size("font_size")
		assert_true(got >= 14, "size %d gave %d" % [size, got])
		if size >= 14:
			assert_eq(got, size)
		l.free()
