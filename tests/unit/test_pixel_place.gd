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
	assert_eq(PixelPlace.KINDS.size(), 10)
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


func test_realm_looks_are_well_formed() -> void:
	var distinct := {}
	for look: String in PixelPlace.REALM_LOOKS:
		var kind := PixelPlace.realm_kind(look)
		assert_true(PixelPlace.supports(kind), look + " supported")
		for active: bool in [false, true]:
			var r := PixelPlace.rows(kind, true, active)
			assert_true(r.size() > 8, look + " has rows")
			for row in r:
				assert_eq(row.length(), r[0].length(), look + " row width")
				for ch in row:
					assert_true(PixelPlace.PALETTE.contains(ch), "%s unknown char %s" % [look, ch])
			distinct["".join(r)] = true
		assert_true("".join(PixelPlace.rows(kind, true, true)) != "".join(PixelPlace.rows(kind, true, false)), look + " open differs from closed")
	assert_eq(distinct.size(), PixelPlace.REALM_LOOKS.size() * 2, "every look and state is its own picture")
	assert_eq(PixelPlace.realm_kind("rift"), "secret_realm")
	assert_eq(PixelPlace.realm_kind("gate"), "secret_realm_gate")
	assert_eq(PixelPlace.realm_kind("castle"), "secret_realm")


func test_every_secret_realm_place_has_a_look() -> void:
	var data := GameData.load_from_dir()
	var n := 0
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "secret_realm":
				n += 1
				assert_true(PixelPlace.REALM_LOOKS.has(String(place.get("look", ""))), "%s needs a look" % place.get("display_name", ""))
	assert_eq(n, 6)


func test_game_data_rejects_unknown_realm_look() -> void:
	for look: String in PixelPlace.REALM_LOOKS + ["castle"]:
		var data := GameData.load_from_dir()
		for p: Dictionary in data.regions["qingshi_village"]["places"]:
			if p.get("type", "") == "secret_realm":
				p["look"] = look
		data.load_errors.clear()
		data._validate_world()
		assert_eq("\n".join(data.load_errors).contains("unknown secret_realm look"), look == "castle", look)


## GFX-100
func test_building_styles() -> void:
	var size := Vector2(60, 50)
	var base := PixelPlace.texture("workshop", size, Color("a0522d"))
	assert_eq(PixelPlace.texture("workshop", size, Color("a0522d"), false, "", "thatch"), base)
	for style: String in PixelPlace.STYLES:
		for kind in ["workshop", "clinic", "orphanage", "family_home", "auction", "merchant"]:
			var t := PixelPlace.texture(kind, size, Color("a0522d"), false, "", style)
			var t0 := PixelPlace.texture(kind, size, Color("a0522d"))
			assert_eq(t.get_size(), t0.get_size(), "%s %s keeps its size" % [style, kind])
	var tile := PixelPlace.texture("workshop", size, Color("a0522d"), false, "", "tile")
	assert_true(tile != base)
	assert_true(tile.get_image().get_data() != base.get_image().get_data())
	# Non-building kinds ignore the style.
	assert_eq(PixelPlace.texture("sect_hall", size, Color("a0522d"), false, "", "stone"), PixelPlace.texture("sect_hall", size, Color("a0522d")))
	var stilt := PixelPlace.texture("workshop", size, Color("a0522d"), false, "", "stilt").get_image()
	assert_eq(stilt.get_pixel(3, stilt.get_height() - 1).a, 0.0, "gap between posts")


func test_game_data_rejects_unknown_building_style() -> void:
	for style: String in PixelPlace.STYLES + ["pagoda"]:
		var data := GameData.load_from_dir()
		data.regions["qingshi_village"]["map"]["building_style"] = style
		data.load_errors.clear()
		data._validate_world()
		assert_eq("\n".join(data.load_errors).contains("building_style"), style == "pagoda", style)
	var fresh := GameData.load_from_dir()
	assert_eq(fresh.load_errors.size(), 0, str(fresh.load_errors))


func test_gather_looks_are_well_formed() -> void:
	var base := PixelPlace.rows("gather")
	var distinct := {}
	for look: String in PixelPlace.GATHER_LOOKS:
		var kind := PixelPlace.gather_kind(look)
		assert_true(PixelPlace.supports(kind), look + " supported")
		var r := PixelPlace.rows(kind)
		assert_eq(r.size(), base.size(), look + " same height as the herb bed")
		for row in r:
			assert_eq(row.length(), base[0].length(), look + " row width")
			for ch in row:
				assert_true(PixelPlace.PALETTE.contains(ch), "%s unknown char %s" % [look, ch])
		distinct["".join(r)] = true
	assert_eq(distinct.size(), PixelPlace.GATHER_LOOKS.size(), "every gather look is its own picture")
	assert_eq(PixelPlace.gather_kind("patch"), "gather")
	assert_eq(PixelPlace.gather_kind("bogus"), "gather")


func test_every_gather_place_has_a_valid_look() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.load_errors.size(), 0, str(data.load_errors))
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "gather":
				assert_true(PixelPlace.GATHER_LOOKS.has(String(place.get("look", "patch"))), place.get("display_name", ""))


func test_game_data_rejects_unknown_gather_look() -> void:
	for look: String in PixelPlace.GATHER_LOOKS + ["swamp"]:
		var data := GameData.load_from_dir()
		for p: Dictionary in data.regions["qingshi_village"]["places"]:
			if p.get("type", "") == "gather":
				p["look"] = look
		data.load_errors.clear()
		data._validate_world()
		assert_eq("\n".join(data.load_errors).contains("unknown gather look"), look == "swamp", look)


## GFX-104: woods are separate crowns on a 54x38 canvas; herb woods add sprigs; the crown colour follows the region.
func test_woods_canvas_and_herb_variant() -> void:
	var plain := PixelPlace.rows("explore_woods")
	assert_eq(plain.size(), 38)
	assert_eq(plain[0].length(), 54)
	var herbs := PixelPlace.rows(PixelPlace.explore_kind("woods", ["herbs"]))
	assert_eq(herbs.size(), 38)
	assert_eq(herbs[0].length(), 54)
	assert_true("".join(herbs) != "".join(plain))
	assert_eq(PixelPlace.explore_kind("woods", ["ruins"]), "explore_woods")
	assert_true(PixelPlace.supports("explore_woods_herbs"))
	assert_false(plain[37].contains("o") and plain[37].count("o") > 20, "no full-width bar along the bottom")


func test_woods_color_falls_back_to_place_color() -> void:
	var place := Color("6f9f4a")
	assert_eq(PixelPlace.woods_color({}, place), place)
	assert_eq(PixelPlace.woods_color({"decor": {"trees": 3}}, place), place)
	assert_eq(PixelPlace.woods_color({"decor": {"tree_color": "183427"}}, place), Color("183427"))


## WU-496: a crown shades only its own pixels; drawing crown 2 leaves crown 1's shading and pixel count alone.
func test_crown_shades_only_its_own_pixels() -> void:
	var c := PixelPlace.canvas(40, 20)
	PixelPlace.crown(c, 10, 10, 8, 7)
	var before := c.duplicate(true)
	var count_before := 0
	for row: Array in c:
		for ch: Variant in row:
			count_before += 1 if ch != "." else 0
	PixelPlace.crown(c, 30, 10, 8, 7)  # far apart: no overlap
	for y in 20:
		for x in 20:
			assert_eq(c[y][x], before[y][x], "crown 1 unchanged at %d,%d" % [x, y])
	var lone := PixelPlace.canvas(40, 20)
	PixelPlace.crown(lone, 30, 10, 8, 7)
	var count_after := 0
	for row: Array in c:
		for ch: Variant in row:
			count_after += 1 if ch != "." else 0
	var lone_count := 0
	for row: Array in lone:
		for ch: Variant in row:
			lone_count += 1 if ch != "." else 0
	assert_eq(count_after, count_before + lone_count, "pixel count is the sum of both crowns")
	# overlapping: crown 1's far upper-left stays highlighted after crown 2 overlaps its lower right
	var o := PixelPlace.canvas(40, 20)
	PixelPlace.crown(o, 12, 10, 8, 7)
	var tl: String = o[5][8]
	PixelPlace.crown(o, 20, 10, 8, 7)
	assert_eq(o[5][8], tl, "crown 1's shading survives an overlapping crown 2")


## GFX-114: winter changes woods crowns (snow caps) and gather beds (dormant), other kinds are untouched.
func test_winter_look() -> void:
	var summer := PixelPlace.rows("explore_woods")
	var winter := PixelPlace.rows("explore_woods", true, false, false, "thatch", true)
	assert_true(summer != winter, "woods differ in winter")
	assert_true("".join(winter).contains("n"), "snow cap pixels")
	assert_true(PixelPlace.rows("gather") != PixelPlace.rows("gather", true, false, false, "thatch", true), "dormant herb bed")
	assert_eq(PixelPlace.rows("explore_ruins"), PixelPlace.rows("explore_ruins", true, false, false, "thatch", true))
	assert_false(PixelPlace.winter_kind("gather_frost"))
	assert_true(PixelPlace.winter_crown(Color("2e7a2a")).get_luminance() < Color("2e7a2a").get_luminance())
