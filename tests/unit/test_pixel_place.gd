extends TestCase
## GFX-021: generated pixel buildings.

const MAP := {"merchant": "merchant", "workshop": "workshop", "sect_hall": "sect_hall", "clinic": "clinic",
	"orphanage": "orphanage", "bounty_board": "bounty_board", "travel": "travel", "auction": "auction"}


func _variants(kind: String) -> Array:
	return [true, false] if kind == "travel" else [true]


func test_templates_are_well_formed() -> void:
	for kind in PixelPlace.KINDS:
		for horizontal in _variants(kind):
			var r := PixelPlace.rows(kind, horizontal)
			assert_true(r.size() > 8, kind + " has rows")
			for row in r:
				assert_eq(row.length(), r[0].length(), "%s row width" % kind)
				for ch in row:
					assert_true(PixelPlace.PALETTE.contains(ch), "%s unknown char %s" % [kind, ch])


func test_supports() -> void:
	for kind in PixelPlace.KINDS:
		assert_true(PixelPlace.supports(kind), kind)
	assert_eq(PixelPlace.KINDS.size(), 9)
	assert_false(PixelPlace.supports("meditation"))
	assert_false(PixelPlace.supports("deed_giver"))


func test_art_fits_every_place() -> void:
	var scale := float(Sprites.scale())
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			var kind: String = place["type"]
			if not PixelPlace.supports(kind):
				continue
			var size := Vector2(place["size"][0], place["size"][1])
			var tex := PixelPlace.texture(kind, size, Color("aa4433"))
			var px := Vector2(tex.get_size()) * scale
			assert_true(px.x <= size.x + 8.0 and px.y <= size.y + 8.0, "%s %s: %s vs %s" % [region.get("id", "?"), kind, px, size])
	for t: Vector2 in [Vector2(90, 64)]:
		var tex := PixelPlace.texture("family_home", t, Color.WHITE)
		assert_true(Vector2(tex.get_size()) * scale <= t + Vector2(8, 8), "family home fits")


func test_cache_and_colour() -> void:
	var a := PixelPlace.texture("merchant", Vector2(60, 60), Color("aa3322"))
	assert_true(a == PixelPlace.texture("merchant", Vector2(60, 60), Color("aa3322")), "cached")
	var b := PixelPlace.texture("merchant", Vector2(60, 60), Color("2233aa"))
	assert_true(a.get_image().get_data() != b.get_image().get_data(), "colour changes pixels")
	var h := PixelPlace.texture("travel", Vector2(120, 40), Color.RED)
	var v := PixelPlace.texture("travel", Vector2(40, 120), Color.RED)
	assert_true(h.get_width() > h.get_height() and v.get_height() > v.get_width(), "gate orientations")


func test_outline_first_pixel() -> void:
	for kind in PixelPlace.KINDS:
		for horizontal in _variants(kind):
			var size := Vector2(120, 40) if horizontal else Vector2(40, 120)
			var img := PixelPlace.texture(kind, size, Color("aa4433")).get_image()
			var found := false
			for y in img.get_height():
				for x in img.get_width():
					if not found and img.get_pixel(x, y).a > 0.0:
						found = true
						assert_eq(img.get_pixel(x, y), PixelPlace.OUTLINE, kind + " outline")
