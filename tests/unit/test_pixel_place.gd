extends TestCase
## GFX-021: generated pixel buildings.

const MAP := {"merchant": "merchant", "workshop": "workshop", "sect_hall": "sect_hall", "clinic": "clinic",
	"orphanage": "orphanage", "bounty_board": "bounty_board", "travel": "travel", "auction": "auction"}


func _all_kinds() -> Array:
	return PixelPlace.KINDS + PixelPlace.NATURE_KINDS


func _variants(kind: String) -> Array:
	return [true, false] if kind == "travel" else [true]


func test_templates_are_well_formed() -> void:
	for kind in _all_kinds():
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
	for kind in PixelPlace.NATURE_KINDS:
		assert_true(PixelPlace.supports(kind), kind)
	assert_true(PixelPlace.supports("fishing"))
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
	for kind in _all_kinds():
		for horizontal in _variants(kind):
			var size := Vector2(120, 40) if horizontal else Vector2(40, 120)
			var img := PixelPlace.texture(kind, size, Color("aa4433")).get_image()
			var found := false
			for y in img.get_height():
				for x in img.get_width():
					if not found and img.get_pixel(x, y).a > 0.0:
						found = true
						assert_eq(img.get_pixel(x, y), PixelPlace.OUTLINE, kind + " outline")


func test_secret_realm_active_differs() -> void:
	var off := PixelPlace.texture("secret_realm", Vector2(90, 70), Color("7755cc"), false)
	var on := PixelPlace.texture("secret_realm", Vector2(90, 70), Color("7755cc"), true)
	assert_true(off.get_image().get_data() != on.get_image().get_data(), "active rift looks different")


func test_landmarks_well_formed_and_cached() -> void:
	for kind in PixelLandmark.KINDS:
		var size := Vector2(160, 60)
		var r := PixelLandmark.rows(kind, size)
		assert_true(r.size() > 0, kind)
		for row in r:
			assert_eq(row.length(), r[0].length(), kind + " row width")
			for ch in row:
				assert_true(PixelPlace.PALETTE.contains(ch), "%s unknown char %s" % [kind, ch])
		assert_true(PixelLandmark.texture(kind, size) == PixelLandmark.texture(kind, size), kind + " cached")
	assert_false(PixelLandmark.supports("lantern_post"))
	for kind in ["wall", "cliff", "stream"]:
		assert_true(PixelLandmark.supports(kind), kind)
		var rr := PixelLandmark.rows(kind, Vector2(160, 64))
		assert_true(rr.size() > 10 and rr[0].length() > 10, kind)


func test_landmarks_fit_data() -> void:
	var scale := float(Sprites.scale())
	for region: Dictionary in data().regions.values():
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if not PixelLandmark.supports(lm["kind"]):
				continue
			var size := Vector2(lm["size"][0], lm["size"][1])
			var px := Vector2(PixelLandmark.texture(lm["kind"], size).get_size()) * scale
			assert_true(px.x <= size.x + 8.0 and px.y <= size.y + 8.0, "%s %s: %s vs %s" % [region.get("id", "?"), lm["kind"], px, size])


func test_wide_merchants_draw_a_shop_front() -> void:
	assert_true(PixelPlace.supports("shop"))
	var r := PixelPlace.rows("shop")
	assert_true(r.size() > 40, "shop rows")
	var stall := PixelPlace.texture("merchant", Vector2(90, 60), Color("c9823a"))
	var shop := PixelPlace.texture("merchant", Vector2(140, 100), Color("c9823a"))
	assert_true(shop.get_height() > stall.get_height() and shop.get_width() > stall.get_width(), "wide merchant is a building")
	assert_true(shop == PixelPlace.texture("shop", Vector2(140, 100), Color("c9823a")), "same cache entry as the shop kind")
	var scale := float(Sprites.scale())
	assert_true(Vector2(shop.get_size()) * scale <= Vector2(148, 108), "fits the Pill Pavilion")


## GFX-064: merchants from 110 px wide are shops; the smithy and the scroll pavilion have their own look.
func test_big_shops_are_buildings() -> void:
	assert_eq(PixelPlace.SHOP_MIN_WIDTH, 110.0)
	assert_eq(PixelPlace.shop_look("Heavenforge Smithy"), "shop_smithy")
	assert_eq(PixelPlace.shop_look("Ten Thousand Scrolls Pavilion"), "shop_scrolls")
	assert_eq(PixelPlace.shop_look("Pill Pavilion"), "shop")
	var stall := PixelPlace.texture("merchant", Vector2(100, 70), Color("aa4433"))
	var shop := PixelPlace.texture("merchant", Vector2(110, 80), Color("aa4433"))
	var smithy := PixelPlace.texture("merchant", Vector2(110, 80), Color("aa4433"), false, "Heavenforge Smithy")
	var scrolls := PixelPlace.texture("merchant", Vector2(110, 80), Color("aa4433"), false, "Ten Thousand Scrolls Pavilion")
	assert_true(shop.get_height() > stall.get_height(), "110 px is a shop, 100 px a stall")
	assert_true(smithy.get_image().get_data() != shop.get_image().get_data(), "smithy differs")
	assert_true(scrolls.get_image().get_data() != shop.get_image().get_data(), "scrolls differ")
	assert_eq(smithy.get_size(), shop.get_size())
	assert_true(Vector2(shop.get_size()) * float(Sprites.scale()) <= Vector2(118, 88), "110 px shop fits its rect")



func test_explore_looks_are_well_formed() -> void:
	for look: String in PixelPlace.EXPLORE_LOOKS:
		var kind := PixelPlace.explore_kind(look)
		assert_true(PixelPlace.supports(kind), look + " supported")
		var r := PixelPlace.rows(kind)
		assert_true(r.size() > 8, look + " has rows")
		for row in r:
			assert_eq(row.length(), r[0].length(), look + " row width")
			for ch in row:
				assert_true(PixelPlace.PALETTE.contains(ch), "%s unknown char %s" % [look, ch])
	assert_eq(PixelPlace.explore_kind("cave"), "explore")
	assert_eq(PixelPlace.explore_kind("bogus"), "explore")
	assert_eq(PixelPlace.rows("explore"), PixelPlace.rows(PixelPlace.explore_kind("cave")))
	var distinct := {}
	for look: String in PixelPlace.EXPLORE_LOOKS:
		distinct["".join(PixelPlace.rows(PixelPlace.explore_kind(look)))] = true
	assert_eq(distinct.size(), PixelPlace.EXPLORE_LOOKS.size(), "every look is its own picture")


func test_every_explore_place_has_a_valid_look() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.load_errors.size(), 0, str(data.load_errors))
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "explore":
				assert_true(PixelPlace.EXPLORE_LOOKS.has(String(place.get("look", ""))), "%s needs a look" % place.get("display_name", ""))


func test_game_data_rejects_unknown_explore_look() -> void:
	for look: String in PixelPlace.EXPLORE_LOOKS + ["swamp"]:
		var data := GameData.load_from_dir()
		var place: Dictionary = {}
		for p: Dictionary in data.regions["qingshi_village"]["places"]:
			if p.get("type", "") == "explore":
				place = p
		place["look"] = look
		data.load_errors.clear()
		data._validate_world()
		var bad := look == "swamp"
		assert_eq("\n".join(data.load_errors).contains("unknown explore look"), bad, look)
