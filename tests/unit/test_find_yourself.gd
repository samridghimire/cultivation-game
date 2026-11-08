extends TestCase
## GFX-101: pixel corner brackets for the target and a one-colour silhouette for the player's outline.


func test_bracket_rects_sit_in_the_corners() -> void:
	var box := Rect2(10, 20, 100, 60)
	var rects := Interactable.bracket_rects(box)
	assert_eq(rects.size(), 8)
	for r in rects:
		assert_true(box.encloses(r), "bracket arm stays inside the box")
	assert_true(rects.has(Rect2(10, 20, 4, 2)))
	assert_true(rects.has(Rect2(108, 78, 2, 2)) == false)
	assert_true(rects.has(Rect2(106, 78, 4, 2)))
	assert_true(rects.has(Rect2(108, 76, 2, 4)))


func test_silhouette_keeps_shape_with_one_colour() -> void:
	var tex := PixelFigure.frame({}, "down", 0)
	var sil := PixelFigure.silhouette(tex, Color("f3e6c4"))
	var a := tex.get_image()
	var b := sil.get_image()
	assert_eq(b.get_size(), a.get_size())
	var opaque := 0
	for y in a.get_height():
		for x in a.get_width():
			assert_eq(a.get_pixel(x, y).a > 0.0, b.get_pixel(x, y).a > 0.0)
			if b.get_pixel(x, y).a > 0.0:
				opaque += 1
				assert_eq(b.get_pixel(x, y), Color("f3e6c4"))
	assert_true(opaque > 40)
