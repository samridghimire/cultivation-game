class_name Sprites
extends RefCounted
## Sprite lookup (GFX-001) for the pixel-art pipeline. Reads data/sprites.json once and hands out textures by key
## ("player_down", "place_merchant", ...). Every lookup returns null when the key or its file is missing, so callers
## fall back to their _draw() placeholder. Lives in src/world: core stays free of rendering.

const PATH := "res://data/sprites.json"

static var _loaded := false
static var _data: Dictionary = {}
static var _cache: Dictionary = {}
static var _overrides: Dictionary = {}
static var _test_entries: Array[String] = []


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


static func _entry(key: String) -> Dictionary:
	_ensure()
	var sprites: Variant = _data.get("sprites", {})
	if sprites is Dictionary and (sprites as Dictionary).get(key) is Dictionary:
		return (sprites as Dictionary)[key]
	return {}


## The whole sprite (the first frame's strip for animated ones), or null.
static func texture(key: String) -> Texture2D:
	if _overrides.has(key):
		return _overrides[key]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var entry := _entry(key)
	var path := str(entry.get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D:
			tex = loaded
			var region: Variant = entry.get("region")
			if region is Array and (region as Array).size() == 4:
				var r: Array = region
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
				tex = atlas
	_cache[key] = tex
	return tex


## Number of frames in the strip (1 when not animated or missing).
static func frame_count(key: String) -> int:
	return maxi(1, int(_entry(key).get("frames", 1)))


## Frame `index % frames` of a strip, or null when the sprite is missing.
static func frame(key: String, index: int) -> Texture2D:
	var tex := texture(key)
	if tex == null:
		return null
	var n := frame_count(key)
	if n <= 1:
		return tex
	var size := tex.get_size()
	var w := size.x / n
	var atlas := AtlasTexture.new()
	if tex is AtlasTexture:
		var base := tex as AtlasTexture
		atlas.atlas = base.atlas
		atlas.region = Rect2(base.region.position.x + w * (index % n), base.region.position.y, w, size.y)
	else:
		atlas.atlas = tex
		atlas.region = Rect2(w * (index % n), 0, w, size.y)
	return atlas


static func fps(key: String) -> float:
	return float(_entry(key).get("fps", 8.0))


## Integer on-screen scale.
static func scale() -> int:
	_ensure()
	return maxi(1, int(_data.get("scale", 2)))


## Credits for the packs in use: [{id, name, author, license, url}].
static func credits() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	var packs: Variant = _data.get("packs", [])
	if packs is Array:
		for p: Variant in packs:
			if p is Dictionary:
				out.append(p)
	return out


## Test hook: replaces a key's texture.
static func override(key: String, tex: Texture2D) -> void:
	_overrides[key] = tex


static func clear_overrides() -> void:
	_overrides.clear()
	for key: String in _test_entries:
		(_data["sprites"] as Dictionary).erase(key)
	_test_entries.clear()


## Test hook: installs a sprite entry (e.g. {"frames": 4}) with its texture.
static func _set_entry_for_test(key: String, entry: Dictionary, tex: Texture2D) -> void:
	_ensure()
	if not _data.has("sprites") or not (_data["sprites"] is Dictionary):
		_data["sprites"] = {}
	(_data["sprites"] as Dictionary)[key] = entry
	_test_entries.append(key)
	_overrides[key] = tex
