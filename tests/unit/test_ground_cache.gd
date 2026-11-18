extends TestCase
## PERF-013: the ground disk cache returns the same pixels as a cold build, keys follow every input, and a corrupt file
## falls back to a cold build. Uses its own cache directory, removed afterwards.

const TEST_DIR := "user://cache/ground_test"
const SIZE := Vector2i(256, 256)


func _begin() -> void:
	GroundCache.dir = TEST_DIR
	GroundCache.enabled = true
	_wipe()


func _end() -> void:
	_wipe()
	GroundCache.dir = "user://cache/ground"
	GroundCache.enabled = true
	GroundTiles.clear_cache()


func _wipe() -> void:
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, f])


func _files() -> PackedStringArray:
	return DirAccess.get_files_at(TEST_DIR)


func _grass(season: String) -> Image:
	GroundTiles.clear_cache()
	return GroundTiles.ground_texture(Color("4d6b3c"), "qingshi_village", SIZE, true, season, "grass", [], 1.0, {}).get_image()


func _paved(season: String) -> Image:
	GroundTiles.clear_cache()
	return GroundTiles.ground_texture(Color("8b8272"), "fallen_star_market", SIZE, false, season, "paved", [Rect2(10, 10, 120, 80)], 1.0, {}).get_image()


func test_cached_load_is_byte_identical() -> void:
	_begin()
	for pair in [["grass", "Summer"], ["paved", "Winter"]]:
		_wipe()
		var cold: Image = (_grass if pair[0] == "grass" else _paved).call(pair[1])
		assert_eq(_files().size(), 1, "first build writes one file")
		var warm: Image = (_grass if pair[0] == "grass" else _paved).call(pair[1])
		assert_true(cold.get_data() == warm.get_data(), "%s %s identical from cache" % pair)
	_end()


func test_key_follows_inputs() -> void:
	_begin()
	var a := GroundCache.key(["x|Summer|zones"])
	assert_true(a != GroundCache.key(["x|Winter|zones"]))
	assert_true(a != GroundCache.key(["x|Summer|zones2"]))
	assert_eq(a, GroundCache.key(["x|Summer|zones"]))
	_end()


func test_corrupt_file_falls_back_and_is_rewritten() -> void:
	_begin()
	var cold := _grass("Summer")
	var path := "%s/%s" % [TEST_DIR, _files()[0]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
	f.close()
	var again := _grass("Summer")
	assert_true(cold.get_data() == again.get_data(), "fallback equals cold build")
	assert_true(FileAccess.get_file_as_bytes(path).size() > 100, "file rewritten")
	_end()


func test_disabled_never_touches_disk() -> void:
	_begin()
	GroundCache.enabled = false
	_grass("Summer")
	assert_eq(_files().size(), 0)
	_end()


func test_small_textures_not_cached() -> void:
	_begin()
	GroundTiles.clear_cache()
	GroundTiles.ground_texture(Color("4d6b3c"), "qingshi_village", Vector2i(64, 64), false, "Summer")
	assert_eq(_files().size(), 0)
	_end()

