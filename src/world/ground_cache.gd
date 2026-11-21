class_name GroundCache
extends RefCounted
## PERF-013: a disk cache for generated ground textures. A ground texture is a pure function of the arguments
## GroundTiles.ground_texture builds its memory key from (base color, region id, size, flowers, season, style, zones,
## scree density, life: avoid/worn/path_color/speckle/alpine_meadow); the key here hashes that same text plus VERSION.
## Bump VERSION whenever a ground pass changes its output. Only user:// is ever written.

const VERSION := 6
const MIN_PIXELS := 40000  ## smaller textures (duel stage strips, test tiles) are cheap and not cached

static var enabled := true
static var dir := "user://cache/ground"


static var _salt := "?"


static func key(parts: Array) -> String:
	return str([VERSION, Image.FORMAT_RGBA8, _source_salt(), parts]).sha256_text().substr(0, 24)


## REVIEW (PERF-013): when the script source is readable (editor runs, tests, screenshot scripts) the key also hashes
## ground_tiles.gd, so a changed ground pass never reads back stale ground during development even if VERSION was not
## bumped. Exported builds ship no source text, so there VERSION alone decides.
static func _source_salt() -> String:
	if _salt == "?":
		var s: Script = load("res://src/world/ground_tiles.gd")
		_salt = s.source_code.sha256_text() if s != null and s.source_code != "" else ""
	return _salt


static func _path(k: String) -> String:
	return "%s/%s.png" % [dir, k]


static func has(k: String) -> bool:
	return FileAccess.file_exists(_path(k))


## The cached image, or null on a miss, a size mismatch or a decode error.
static func load_image(k: String, size_px: Vector2i) -> Image:
	if not enabled or size_px.x * size_px.y < MIN_PIXELS:
		return null
	var p := _path(k)
	if not FileAccess.file_exists(p):
		return null
	var bytes := FileAccess.get_file_as_bytes(p)
	if bytes.size() < 64 or bytes.slice(0, 4) != PackedByteArray([0x89, 0x50, 0x4E, 0x47]):
		return null  # junk: skip decoding so the engine logs no error
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK or img.get_size() != size_px:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## PERF-016: the PNG is encoded and written from a WorkerThreadPool task (the image is copied first; the thread never
## touches the scene tree). The bytes go to `<key>.tmp` and are renamed when complete, so a crash mid-write leaves no
## corrupt .png (the reader ignores .tmp files and falls back on a bad file anyway).
static var threaded := true
static var _tasks: Array[int] = []


static func save_image(k: String, img: Image) -> void:
	if not enabled or img.get_width() * img.get_height() < MIN_PIXELS:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if not threaded:
		_write(dir, k, img)
		return
	var copy := Image.new()
	copy.copy_from(img)
	var d := dir
	_reap()
	_tasks.append(WorkerThreadPool.add_task(func() -> void: _write(d, k, copy)))


## REVIEW (PERF-016): every WorkerThreadPool task must be waited on once to free it; finished ones are collected here
## (the wait returns at once) so a long session that never calls flush() does not keep every task id.
static func _reap() -> void:
	var pending: Array[int] = []
	for id in _tasks:
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			pending.append(id)
	_tasks = pending


## Blocks until every pending background write has finished (tests, quit).
static func flush() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()


static func _write(d: String, k: String, img: Image) -> void:
	var tmp := "%s/%s.tmp" % [d, k]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(img.save_png_to_buffer())
	f.close()
	DirAccess.rename_absolute(tmp, "%s/%s.png" % [d, k])
	prune(d)


## Deletes the oldest files beyond `keep`.
static func prune(d: String = dir, keep: int = 120) -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".png"):
			files.append([FileAccess.get_modified_time("%s/%s" % [d, f]), f])
	if files.size() <= keep:
		return
	files.sort_custom(func(a, b): return a[0] < b[0])
	for i in files.size() - keep:
		DirAccess.remove_absolute("%s/%s" % [d, files[i][1]])
