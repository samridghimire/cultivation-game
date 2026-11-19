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
	GroundCache.flush()
	_wipe()
	GroundCache.dir = "user://cache/ground"
	GroundCache.enabled = true
	GroundTiles.clear_cache()


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):  # REVIEW: a fresh container has no cache dir yet (get_files_at logs an error)
		return
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEST_DIR, f])


func _files() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return PackedStringArray()
	return DirAccess.get_files_at(TEST_DIR)


func _grass(season: String) -> Image:
	GroundCache.flush()
	GroundTiles.clear_cache()
	var img: Image = GroundTiles.ground_texture(Color("4d6b3c"), "qingshi_village", SIZE, true, season, "grass", [], 1.0, {}).get_image()
	GroundCache.flush()
	return img


func _paved(season: String) -> Image:
	GroundCache.flush()
	GroundTiles.clear_cache()
	var img: Image = GroundTiles.ground_texture(Color("8b8272"), "fallen_star_market", SIZE, false, season, "paved", [Rect2(10, 10, 120, 80)], 1.0, {}).get_image()
	GroundCache.flush()
	return img


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


func test_threaded_write_appears_after_flush_and_leaves_no_tmp() -> void:
	_begin()
	assert_true(GroundCache.threaded, "background writes are the default")
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.5, 0.3, 1.0))
	var k := GroundCache.key(["threaded-test"])
	GroundCache.save_image(k, img)
	img.fill(Color.RED)  # the task works on a copy
	GroundCache.flush()
	assert_eq(_files().size(), 1, "one file, no .tmp left")
	assert_true(_files()[0].ends_with(".png"))
	var back := GroundCache.load_image(k, Vector2i(256, 256))
	assert_true(back != null)
	assert_true(abs(back.get_pixel(5, 5).g - 0.5) < 0.01, "copy was written, not the later fill")
	_end()


## REVIEW (PERF-016): finished background writes are collected on the next save, so the task list does not grow forever.
func test_finished_tasks_are_reaped() -> void:
	_begin()
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for i in 3:
		GroundCache.save_image(GroundCache.key(["reap", i]), img)
	var waited := 0
	while GroundCache._tasks.size() > 0 and not GroundCache._tasks.all(func(id: int) -> bool: return WorkerThreadPool.is_task_completed(id)) and waited < 200:
		OS.delay_msec(5)
		waited += 1
	GroundCache.save_image(GroundCache.key(["reap", 9]), img)
	assert_eq(GroundCache._tasks.size(), 1, "only the newest write is still tracked")
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



func test_key_hashes_ground_source_in_dev_runs() -> void:
	# REVIEW (PERF-013): a ground pass edited without a VERSION bump must not read back stale ground in dev runs.
	assert_true(GroundCache._source_salt() != "", "ground_tiles.gd source is readable when running from the project")
