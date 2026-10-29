extends TestCase
## GFX-001: sprite lookup with placeholder fallback.


func _tex(w: int, h: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))


func test_missing_keys_are_null() -> void:
	assert_true(Sprites.texture("nope") == null)
	for dir in ["down", "up", "left", "right"]:
		assert_true(Sprites.texture("player_" + dir) == null)
	for kind in PlaceArt.KINDS:
		assert_true(Sprites.texture("place_" + kind) == null, kind)
	assert_true(Sprites.frame("nope", 3) == null)


func test_override_and_clear() -> void:
	var t := _tex(16, 16)
	Sprites.override("player_down", t)
	assert_true(Sprites.texture("player_down") == t)
	Sprites.clear_overrides()
	assert_true(Sprites.texture("player_down") == null)


func test_strip_frames() -> void:
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	var strip := ImageTexture.create_from_image(img)
	Sprites._set_entry_for_test("player_down", {"frames": 4, "fps": 6.0}, strip)
	assert_eq(Sprites.frame_count("player_down"), 4)
	assert_eq(Sprites.fps("player_down"), 6.0)
	var regions := {}
	for i in 4:
		var f := Sprites.frame("player_down", i) as AtlasTexture
		assert_eq(f.get_size(), Vector2(16, 16))
		regions[f.region.position.x] = true
	assert_eq(regions.size(), 4)
	assert_eq((Sprites.frame("player_down", 5) as AtlasTexture).region.position.x, 16.0)
	Sprites.clear_overrides()
	assert_true(Sprites.texture("player_down") == null)


func test_json_shape() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	assert_true(parsed is Dictionary)
	var d: Dictionary = parsed
	for k in ["tile_size", "scale", "packs", "sprites"]:
		assert_true(d.has(k), k)
	for key: String in d["sprites"]:
		assert_true(d["sprites"][key].get("path") is String, key)
	assert_eq(Sprites.scale(), int(d["scale"]))
	assert_eq(Sprites.credits().size(), (d["packs"] as Array).size())
