class_name GroundCache
extends RefCounted
## PERF-013: a disk cache for generated ground textures. A ground texture is a pure function of the arguments
## GroundTiles.ground_texture builds its memory key from (base color, region id, size, flowers, season, style, zones,
## scree density, life: avoid/worn/path_color/speckle/alpine_meadow); the key here hashes that same text plus VERSION.
## Bump VERSION whenever a ground pass changes its output. Only user:// is ever written.

const VERSION := 1
const MIN_PIXELS := 40000  ## smaller textures (duel stage strips, test tiles) are cheap and not cached

static var enabled := true
static var dir := "user://cache/ground"


static func key(parts: Array) -> String:
	return str([VERSION, Image.FORMAT_RGBA8, parts]).sha256_text().substr(0, 24)


static func _path(k: String) -> String:
	return "%s/%s.png" % [dir, k]


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


static func save_image(k: String, img: Image) -> void:
	if not enabled or img.get_width() * img.get_height() < MIN_PIXELS:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(_path(k))
	prune()


## Deletes the oldest files beyond `keep`.
static func prune(keep: int = 120) -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			files.append([FileAccess.get_modified_time("%s/%s" % [dir, f]), f])
	if files.size() <= keep:
		return
	files.sort_custom(func(a, b): return a[0] < b[0])
	for i in files.size() - keep:
		DirAccess.remove_absolute("%s/%s" % [dir, files[i][1]])
