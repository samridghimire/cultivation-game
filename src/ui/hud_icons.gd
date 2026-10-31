class_name HudIcons
extends RefCounted
## Code-drawn pixel icons for the HUD status card (GFX-031): soul lamps, season and weather glyphs.
## Textures are drawn once from small row maps and cached; unknown names return null.

const LAMP_SIZE := Vector2i(10, 12)
const GLYPH_SIZE := 12
const OUTLINE := Color("1c1612")

## Row maps: 'o' outline, 'a' main colour, 'b' highlight, 'c' second colour, '.' empty.
const LAMP_LIT := ["....b.....", "...bcb....", "..bbcbb...", "..bbcbb...", "...bbb....", "....o.....", ".oooooooo.", "oaaaaaaaao", "oaaaaaaao.", ".oaaaaao..", "..oooooo..", ".........."]
const LAMP_OUT := ["..........", "..........", "..........", "..........", "..........", "....o.....", ".oooooooo.", "oaaaaaaaao", "oaaaaaaao.", ".oaaaaao..", "..oooooo..", ".........."]

const SEASONS := {
	"Spring": {"colors": {"a": Color("f2a7c3"), "b": Color("fde1ec"), "c": Color("e8c76a")}, "rows": ["............", "....oo.oo...", "...oaaoaao..", "...oabcbao..", "....oacao...", "..oo.ooo.oo.", ".oaaoaaaoaao", ".oabcbacbao.", "..oaaoooaao.", "...oo.oo.oo.", "............", "............"]},
	"Summer": {"colors": {"a": Color("f0c33c"), "b": Color("fff1a8"), "c": Color("f0c33c")}, "rows": ["............", ".....c......", "..c..c..c...", "...oooo.....", "..oabbao....", "cc.oabaoc.cc", "..oaaaao....", "...oooo.....", "..c..c..c...", ".....c......", "............", "............"]},
	"Autumn": {"colors": {"a": Color("d9702f"), "b": Color("f0a050"), "c": Color("8a4a22")}, "rows": ["............", ".....oo.....", "....oaao....", "...oabbao...", "..oabaaaao..", ".oaabaaaaao.", ".oaaabaaaao.", "..oaaabaao..", "...ooaboo...", ".....oco....", ".....c......", "............"]},
	"Winter": {"colors": {"a": Color("cfe8f5"), "b": Color("ffffff"), "c": Color("8fb8d6")}, "rows": ["............", ".....cc.....", "..c..cc..c..", "...c.cc.c...", "....cbbc....", "cccccbbccccc", "cccccbbccccc", "....cbbc....", "...c.cc.c...", "..c..cc..c..", ".....cc.....", "............"]},
}

const WEATHER := {
	"clear": {"colors": {"a": Color("f0c33c"), "b": Color("fff1a8"), "c": Color("f0c33c")}, "rows": ["............", ".....c......", "..c..c..c...", "...oooo.....", "..oabbao....", "cc.oabaoc.cc", "..oaaaao....", "...oooo.....", "..c..c..c...", ".....c......", "............", "............"]},
	"cloudy": {"colors": {"a": Color("c4cbd6"), "b": Color("eef1f6"), "c": Color("8a93a3")}, "rows": ["............", "............", "....ooo.....", "...obbbo.oo.", "..oabaaooaao", ".oabaaaaaabo", ".oaaaaaaaaao", ".oaaaaaaaaco", "..ooooooooo.", "............", "............", "............"]},
	"rain": {"colors": {"a": Color("a4acb9"), "b": Color("d8dde6"), "c": Color("4f9de0")}, "rows": ["............", "....ooo.....", "...obbbo.oo.", "..oabaaooaao", ".oabaaaaaabo", ".oaaaaaaaaao", "..ooooooooo.", "..c..c..c...", "...c..c..c..", "..c..c..c...", "............", "............"]},
	"snow": {"colors": {"a": Color("a4acb9"), "b": Color("d8dde6"), "c": Color("ffffff")}, "rows": ["............", "....ooo.....", "...obbbo.oo.", "..oabaaooaao", ".oabaaaaaabo", ".oaaaaaaaaao", "..ooooooooo.", "..c..c..c...", "....c..c....", "..c..c..c...", "............", "............"]},
	"fog": {"colors": {"a": Color("b9c0cb"), "b": Color("b9c0cb"), "c": Color("b9c0cb")}, "rows": ["............", "............", ".aaaaaaaa...", "............", "...aaaaaaaa.", "............", ".aaaaaaaaa..", "............", "..aaaaaaa...", "............", "............", "............"]},
	"storm": {"colors": {"a": Color("6c7486"), "b": Color("98a0b2"), "c": Color("f4d03f")}, "rows": ["............", "....ooo.....", "...obbbo.oo.", "..oabaaooaao", ".oabaaaaaabo", ".oaaaaaaaaao", "..ooooooooo.", ".....cc.....", "....cc......", "...cccc.....", ".....c......", "....c......."]},
}

## Farming tool glyphs for field menu entries (WU-413).
const TOOLS := {
	"watering_can": {"colors": {"a": Color("6fa8d6"), "b": Color("b9dcf2")}, "rows": ["............", "....oooo....", "...o....o...", "oo.oaaaao...", "oboaabaaao..", "oaaaabaaao..", ".oaaaaaaao..", "..oaaaaao...", "...ooooo....", "............", "............", "............"]},
	"hoe": {"colors": {"a": Color("b8c0cc"), "c": Color("a9743c")}, "rows": ["............", "........ooo.", ".......oaaao", "......oaoooo", ".....oc.....", "....oc......", "...oc.......", "..oc........", ".oc.........", "oc..........", "............", "............"]},
}

## Price trend arrows for the shop (WU-415): "up" is dear (warm red), "down" is cheap (green).
const TRENDS := {
	"up": {"colors": {"a": Color("e0553c")}, "rows": ["............", ".....oo.....", "....oaao....", "...oaaaao...", "..oaaaaaao..", ".oaaaaaaaao.", ".ooooaaoooo.", "....oaao....", "....oaao....", "....oaao....", ".....oo.....", "............"]},
	"down": {"colors": {"a": Color("4fae5c")}, "rows": ["............", ".....oo.....", "....oaao....", "....oaao....", "....oaao....", ".ooooaaoooo.", ".oaaaaaaaao.", "..oaaaaaao..", "...oaaaao...", "....oaao....", ".....oo.....", "............"]},
}

## Friendship heart, 5x5: 'a' fill, 'o' outline, 'b' highlight (WU-418).
const HEART := ["oo.oo", "oaooa", "oaaao", ".oao.", "..o.."]
const HEART_FILL := Color("e0553c")
const HEART_EMPTY := Color("3a2f33")

static var _cache: Dictionary = {}


## A soul lamp, 10x12: lit has a flame over the bowl, unlit is just the dark bowl.
static func lamp(lit: bool) -> Texture2D:
	var key := "lamp_lit" if lit else "lamp_out"
	if not _cache.has(key):
		var palette := {"o": OUTLINE, "a": Color("3a3a46"), "b": Color("f6c44a"), "c": Color("c9873a")}
		_cache[key] = _draw(LAMP_LIT if lit else LAMP_OUT, palette, LAMP_SIZE)
	return _cache[key]


## A 12x12 season glyph ("Spring", "Summer", "Autumn", "Winter"); null for anything else.
static func season(season_name: String) -> Texture2D:
	return _glyph("season_" + season_name, SEASONS, season_name)


## A 12x12 weather glyph for a Weather.KINDS id; null for anything else.
static func weather(kind: String) -> Texture2D:
	return _glyph("weather_" + kind, WEATHER, kind)


## A 12x12 farming tool glyph ("watering_can", "hoe"); null for anything else.
static func tool_glyph(name: String) -> Texture2D:
	return _glyph("tool_" + name, TOOLS, name)


## A 12x12 price trend arrow: +1 up (dear), -1 down (cheap); null for 0.
static func trend(direction: int) -> Texture2D:
	if direction == 0:
		return null
	return _glyph("trend_" + ("up" if direction > 0 else "down"), TRENDS, "up" if direction > 0 else "down")


## A row of `count` pixel hearts, the first `filled` red and the rest dark (WU-418); each heart is 5 px wide
## with 1 px between, scaled by `px`.
static func hearts(count: int, filled: int, px: int = 2) -> Texture2D:
	count = maxi(count, 1)
	filled = clampi(filled, 0, count)
	px = maxi(px, 1)
	var key := "hearts_%d_%d_%d" % [count, filled, px]
	if not _cache.has(key):
		var img := Image.create((count * 6 - 1) * px, 5 * px, false, Image.FORMAT_RGBA8)
		for i in count:
			var fill := HEART_FILL if i < filled else HEART_EMPTY
			for y in 5:
				var row: String = HEART[y]
				for x in 5:
					var ch := row.substr(x, 1)
					if ch == ".":
						continue
					var col: Color = OUTLINE if ch == "o" else fill
					if ch == "o" and i >= filled:
						col = Color("6b5a60")
					img.fill_rect(Rect2i((i * 6 + x) * px, y * px, px, px), col)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func _glyph(key: String, defs: Dictionary, name: String) -> Texture2D:
	if not defs.has(name):
		return null
	if not _cache.has(key):
		var def: Dictionary = defs[name]
		var palette: Dictionary = (def["colors"] as Dictionary).duplicate()
		palette["o"] = OUTLINE
		_cache[key] = _draw(def["rows"], palette, Vector2i(GLYPH_SIZE, GLYPH_SIZE))
	return _cache[key]


static func _draw(rows: Array, palette: Dictionary, size: Vector2i) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var row: String = rows[y]
		for x in size.x:
			var ch := row.substr(x, 1)
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)
