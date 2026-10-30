extends TestCase
## GFX-018: deed_giver `look` parsing and validation.


func test_defaults() -> void:
	var l := PlaceLooks.figure_look({}, Color("112233"))
	assert_eq(l["robe"], Color("112233"))
	assert_eq(l["style"], "bun")
	assert_eq(l["child"], false)
	assert_false(l.has("hair"))
	assert_false(PlaceLooks.is_camp({}))


func test_parse() -> void:
	var l := PlaceLooks.figure_look({"robe": "3f6fb5", "hair": "grey", "style": "hood", "child": true}, Color.RED)
	assert_eq(l["robe"], Color("3f6fb5"))
	assert_eq(l["hair"], PlaceLooks.HAIR["grey"])
	assert_eq(l["style"], "hood")
	assert_eq(l["child"], true)
	assert_true(PlaceLooks.is_camp({"kind": "camp"}))


func test_validation_errors() -> void:
	assert_eq(PlaceLooks.errors({"style": "hood"}, "x").size(), 0)
	assert_eq(PlaceLooks.errors({"robe": "nope"}, "x").size(), 1)
	assert_eq(PlaceLooks.errors({"hair": "blue", "style": "mohawk", "kind": "tower", "child": 1, "extra": 1}, "x").size(), 5)
	assert_eq(PlaceLooks.errors("hood", "x").size(), 1)


func test_hood_frame_builds() -> void:
	var tex := PixelFigure.frame({"robe": Color("7a2f3a"), "style": "hood"}, "down", 0)
	assert_eq(tex.get_size(), Vector2(16, 20))
	for dir in ["down", "up", "right"]:
		assert_eq(PixelFigure.rows(dir, 0, "hood", false).size(), 20)


func test_every_deed_giver_has_valid_look() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.load_errors.size(), 0, str(data.load_errors))
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "deed_giver":
				assert_true(place.has("look"), "%s needs a look" % place.get("display_name", ""))
	var bad := {"id": "x", "places": [{"type": "deed_giver", "display_name": "P", "look": {"style": "zzz"}}]}
	assert_eq(PlaceLooks.errors(bad["places"][0]["look"], "x").size(), 1)
