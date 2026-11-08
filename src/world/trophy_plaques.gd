class_name TrophyPlaques
extends RefCounted
## WU-494: the trophies hung in the player's home (CharacterData.hung_trophies, max 3) drawn as 8x8 pixel plaques on the
## front wall: antlers, tusk, feather, horn, or a plain plaque. Rendering only; the picker is a pure static.

const OUTLINE := Color("1c1612")
const BOARD := Color("6b4a2b")
const KINDS := ["antler", "tusk", "feather", "horn", "plaque"]

## Row maps (8x8): 'o' outline, 'a' the trophy, 'b' its highlight, 'w' the wooden board, '.' empty.
const ROWS := {
	"antler": ["o.o..o.o", "oao..oao", "oaoooaao", ".oaaaao.", "..oaao..", "..owwo..", "..owwo..", "...oo..."],
	"tusk": ["..oooo..", ".oaaabo.", "oaa..oao", "oa....oa", "ob....oa", "oa.....o", ".o......", "........"],
	"feather": ["......oo", ".....oab", "....oaab", "...oaab.", "..oaab..", ".oaab...", "owoo....", "o......."],
	"horn": ["..ooo...", ".oaaao..", "oabaaao.", "oaoooaao", "ow.ooaao", "ow...oao", ".o....o.", "........"],
	"plaque": ["oooooooo", "owwwwwwo", "owaaaawo", "owabbawo", "owaaaawo", "owwwwwwo", "oooooooo", "........"],
}
const COLORS := {
	"antler": Color("d8c49a"), "tusk": Color("efe6cf"), "feather": Color("f4f0e6"), "horn": Color("3d3a42"), "plaque": Color("b88a4a"),
}

static var _cache: Dictionary = {}


## Which icon an item takes, by its id words then its name words; "plaque" for anything else.
static func icon_kind(item_id: String, item_name: String = "") -> String:
	var words := (item_id + " " + item_name).to_lower().replace("_", " ")
	for pair: Array in [["antler", "antler"], ["tusk", "tusk"], ["plume", "feather"], ["feather", "feather"], ["horn", "horn"]]:
		if words.contains(String(pair[0])):
			return String(pair[1])
	return "plaque"


## The icon kinds for a list of hung trophy ids (at most 3, in order).
static func kinds_for(ids: Array, items: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		if out.size() >= 3:
			break
		out.append(icon_kind(String(id), String(items.get(String(id), {}).get("name", ""))))
	return out


static func texture(kind: String) -> Texture2D:
	if not ROWS.has(kind):
		kind = "plaque"
	if not _cache.has(kind):
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		var palette := {"o": OUTLINE, "a": COLORS[kind], "b": (COLORS[kind] as Color).lightened(0.4), "w": BOARD}
		var rows: Array = ROWS[kind]
		for y in 8:
			for x in 8:
				var ch := String(rows[y]).substr(x, 1)
				if palette.has(ch):
					img.set_pixel(x, y, palette[ch])
		_cache[kind] = ImageTexture.create_from_image(img)
	return _cache[kind]


## Top-left x offsets (relative to the building centre) for `n` plaques, 20 px apart and centred.
static func slots(n: int, pitch: float = 20.0, width: float = 16.0) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append((float(i) - float(n - 1) / 2.0) * pitch - width / 2.0)
	return out


## Draws the plaques on a place of `size` centred on the origin (the front wall: lower third).
static func draw(ci: CanvasItem, size: Vector2, kinds: Array[String]) -> void:
	var xs := slots(kinds.size())
	for i in kinds.size():
		ci.draw_texture_rect(texture(kinds[i]), Rect2(Vector2(xs[i], size.y * 0.04), Vector2(16, 16)), false)
