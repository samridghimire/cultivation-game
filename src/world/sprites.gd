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
static var _frames: Dictionary = {}
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


## The first of `keys` that has a texture, or null (GFX-006: "npc_<id>" before "npc").
static func first(keys: PackedStringArray) -> Texture2D:
	for key: String in keys:
		var tex := texture(key)
		if tex != null:
			return tex
	return null


## Number of frames in the strip (1 when not animated or missing).
static func frame_count(key: String) -> int:
	return maxi(1, int(_entry(key).get("frames", 1)))


## Frame `index % frames` of a strip, or null when the sprite is missing. Cached per (key, index).
static func frame(key: String, index: int) -> Texture2D:
	var tex := texture(key)
	if tex == null:
		return null
	var n := frame_count(key)
	if n <= 1:
		return tex
	var slot := index % n
	var cache_key := "%s#%d" % [key, slot]
	var cached: Variant = _frames.get(cache_key)
	if cached is Array and (cached as Array)[0] == tex:
		return (cached as Array)[1]
	var size := tex.get_size()
	var w := size.x / n
	var atlas := AtlasTexture.new()
	if tex is AtlasTexture:
		var base := tex as AtlasTexture
		atlas.atlas = base.atlas
		atlas.region = Rect2(base.region.position.x + w * slot, base.region.position.y, w, size.y)
	else:
		atlas.atlas = tex
		atlas.region = Rect2(w * slot, 0, w, size.y)
	_frames[cache_key] = [tex, atlas]
	return atlas


## The nine [dst, src] Rect2 pairs that 9-slice a `src_size` texture into `rect`, `margin` source pixels at the edges;
## empty slices are left out (GFX-013).
static func nine_patch_rects(src_size: Vector2, rect: Rect2, margin: float) -> Array[Array]:
	var m := minf(margin, minf(src_size.x, src_size.y) / 2.0 - 0.5)
	var d := minf(m, minf(rect.size.x, rect.size.y) / 2.0)
	var sx := [0.0, m, src_size.x - m, src_size.x]
	var sy := [0.0, m, src_size.y - m, src_size.y]
	var dx := [rect.position.x, rect.position.x + d, rect.end.x - d, rect.end.x]
	var dy := [rect.position.y, rect.position.y + d, rect.end.y - d, rect.end.y]
	var out: Array[Array] = []
	for j in 3:
		for i in 3:
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			var from := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			if dst.size.x > 0.0 and dst.size.y > 0.0 and from.size.x > 0.0 and from.size.y > 0.0:
				out.append([dst, from])
	return out


## Draws `tex` 9-sliced into `rect` on `canvas` (call from its _draw).
static func draw_nine_patch(canvas: CanvasItem, tex: Texture2D, rect: Rect2, margin: float, modulate: Color = Color.WHITE) -> void:
	for pair: Array in nine_patch_rects(tex.get_size(), rect, margin):
		canvas.draw_texture_rect_region(tex, pair[0], pair[1], modulate)


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
	_frames.clear()
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
