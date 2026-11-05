extends TestCase
## GFX-066: 2D pixel snapping garbles text at fractional stretch (1280x720 = 0.9, 1080p = 1.35); it must stay off.


func test_pixel_snap_stays_off_for_text() -> void:
	assert_false(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel")), "vertex snap drops glyphs at 0.9 scale")
	assert_false(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")), "transform snap merges glyphs at 0.9 scale")
	assert_eq(String(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items")
