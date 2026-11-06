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
	"hoe": {"colors": {"a": Color("b8c0cc"), "c": Color("a9743c")}, "rows": ["............", "...oooooo...", "..oaaaaaao..", "..oaaaaaao..", "..ooocooo...", "....occo....", "....occo....", "....occo....", "....occo....", "....occo....", "....oooo....", "............"]},
}

## Price trend arrows for the shop (WU-415): "up" is dear (warm red), "down" is cheap (green).
const TRENDS := {
	"up": {"colors": {"a": Color("e0553c")}, "rows": ["............", ".....oo.....", "....oaao....", "...oaaaao...", "..oaaaaaao..", ".oaaaaaaaao.", ".ooooaaoooo.", "....oaao....", "....oaao....", "....oaao....", ".....oo.....", "............"]},
	"down": {"colors": {"a": Color("4fae5c")}, "rows": ["............", ".....oo.....", "....oaao....", "....oaao....", "....oaao....", ".ooooaaoooo.", ".oaaaaaaaao.", "..oaaaaaao..", "...oaaaao...", "....oaao....", ".....oo.....", "............"]},
}

## Calendar kind glyphs (WU-419): market stall, birthday cake, festival lantern, snowflake and leaf for season starts.
const CALENDAR := {
	"market": {"colors": {"a": Color("d9534f"), "b": Color("f4e9d0"), "c": Color("a9743c")}, "rows": ["............", "............", ".oooooooooo.", "oabababababo", "oabababababo", ".oooooooooo.", "..oc....co..", "..oc....co..", "..occcccco..", "..oc....co..", "............", "............"]},
	"birthday": {"colors": {"a": Color("f2a7c3"), "b": Color("fff1a8"), "c": Color("f6c44a")}, "rows": ["............", ".....c......", ".....c......", "....obo.....", "..oooooooo..", ".oabababaao.", ".oaaaaaaaao.", ".oooooooooo.", ".obbbbbbbbo.", ".oooooooooo.", "............", "............"]},
	"festival": {"colors": {"a": Color("d9302f"), "b": Color("f6c44a"), "c": Color("8a4a22")}, "rows": ["............", ".....cc.....", ".....cc.....", "....oooo....", "...oaabao...", "..oaabbaao..", "..oaabbaao..", "..oaabbaao..", "...oaabao...", "....oooo....", ".....bb.....", "............"]},
}

## WU-422 kinds: crop sprout, rent coin, request letter, secret realm gate, world event star.
const CALENDAR_MORE := {
	"field": {"colors": {"a": Color("5fbf5a"), "b": Color("a8e08a"), "c": Color("8a5a2c")}, "rows": ["............", "............", "..oo....oo..", ".oabo..obao.", ".oaabooabao.", "..oaabbaao..", "...ooabo....", ".....ac.....", ".....ac.....", "..occcccco..", "............", "............"]},
	"rent": {"colors": {"a": Color("e8c76a"), "b": Color("fff1a8"), "c": Color("b8943a")}, "rows": ["............", "....oooo....", "..ooabbaoo..", ".oabaaaacao.", ".oaaooooaao.", ".oaaoccoaao.", ".oaaooooaao.", ".oacaaaaaao.", "..ooaaaaoo..", "....oooo....", "............", "............"]},
	"request": {"colors": {"a": Color("f4e9d0"), "b": Color("d9534f"), "c": Color("b8a98a")}, "rows": ["............", "............", ".oooooooooo.", ".oaaaaaaaao.", ".ocaaaaaaco.", ".oacaaaacao.", ".oaaccccaao.", ".oaaabbaaao.", ".oaaabbaaao.", ".oooooooooo.", "............", "............"]},
	"secret_realm": {"colors": {"a": Color("7a5cd6"), "b": Color("c9b8ff"), "c": Color("3a2a7a")}, "rows": ["............", "....oooo....", "..ooabbaoo..", ".oabaccabao.", ".oabaccabao.", ".oabaccabao.", ".oabaccabao.", ".oabaccabao.", ".oabaccabao.", ".oooooooooo.", "............", "............"]},
	"forage": {"colors": {"a": Color("5fbf5a"), "b": Color("a8e08a"), "c": Color("8a5a2c")}, "rows": ["............", "......oo....", "....ooabo...", "...oabbao...", "..oabaaao...", "..oaaaao.o..", "...oaaoooao.", "....ooabao..", "....oc.oo...", "...oc.......", "..oc........", "............"]},
	"great_beast": {"colors": {"a": Color("f2c94c"), "b": Color("fff1a8"), "c": Color("b8943a")}, "rows": ["............", "o..oo..oo..o", "oo.oaooao.oo", ".oooabbaooo.", "..oaabbaao..", ".oabaaaabao.", ".oaoacccaoao", ".oao.oaao.oa", "..o..oaao..o", "....oaoao...", "....ooooo...", "............"]},
	"event": {"colors": {"a": Color("f0a050"), "b": Color("fff1a8"), "c": Color("d9702f")}, "rows": ["............", ".....oo.....", ".....oo.....", "....oabo....", ".ooooabboooo", ".oaabbbbbaao", "..oaabbbaao.", "...oabbbao..", "..oabaaabao.", "..oao..oaao.", "...o....o...", "............"]},
}

## World map node marks (GFX-051): an open stall's coin, a roaming beast's paw, a forage leaf.
const MARKS := {
	"coin": {"colors": {"a": Color("e8c76a"), "b": Color("fff1a8"), "c": Color("b8943a")}, "rows": ["............", "....oooo....", "...oabbao...", "..oabccaao..", "..oabcaaao..", "..oabccaao..", "..oaaaaaco..", "...oaaaco...", "....oooo....", "............", "............", "............"]},
	"paw_gold": {"colors": {"a": Color("f2c94c"), "b": Color("fff1a8"), "c": Color("b8943a")}, "rows": ["............", "..oo....oo..", ".oabo..obao.", ".oaao..oaao.", "..oo.oo.oo..", "oo.oabbao.oo", "oa.oaaaao.ao", ".oo.oaaao.oo", "....oacao...", ".....ooo....", "............", "............"]},
	"paw": {"colors": {"a": Color("c9873a"), "b": Color("e8b070"), "c": Color("8a4a22")}, "rows": ["............", "..oo....oo..", ".oabo..obao.", ".oaao..oaao.", "..oo.oo.oo..", "oo.oabbao.oo", "oa.oaaaao.ao", ".oo.oaaao.oo", "....oacao...", ".....ooo....", "............", "............"]},
	"leaf": {"colors": {"a": Color("5fbf5a"), "b": Color("a8e08a"), "c": Color("3a7a3a")}, "rows": ["............", "......ooo...", "....ooabbo..", "...oabaabao.", "..oabaaaaao.", "..oaaaaacao.", "..oaaaacao..", "...oaacco...", "..occoo.....", ".oc.........", "............", "............"]},
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


## A 12x12 world-map mark glyph ("coin", "paw", "leaf"); null for anything else.
static func map_mark(name: String) -> Texture2D:
	return _glyph("mark_" + name, MARKS, name)


## A 12x12 farming tool glyph ("watering_can", "hoe"); null for anything else.
static func tool_glyph(name: String) -> Texture2D:
	return _glyph("tool_" + name, TOOLS, name)


## A 12x12 price trend arrow: +1 up (dear), -1 down (cheap); null for 0.
static func trend(direction: int) -> Texture2D:
	if direction == 0:
		return null
	return _glyph("trend_" + ("up" if direction > 0 else "down"), TRENDS, "up" if direction > 0 else "down")


## A 12x12 calendar glyph for a VillageCalendar kind; season starts use the season's own glyph (leaf for Autumn,
## snowflake for Winter, flower and sun otherwise, `season_name`). Null when unknown.
static func calendar_kind(kind: String, season_name: String = "") -> Texture2D:
	match kind:
		"market":
			return _glyph("cal_market", CALENDAR, "market")
		"birthday":
			return _glyph("cal_birthday", CALENDAR, "birthday")
		"festival_active", "festival_month":
			return _glyph("cal_festival", CALENDAR, "festival")
		"season":
			return season(season_name)
		"field", "rent", "request", "secret_realm", "event", "forage":
			return _glyph("cal_" + kind, CALENDAR_MORE, kind)
		"great_beast", "hunt":  # WILD-017: the hunt shares the beast glyph
			return _glyph("cal_great_beast", CALENDAR_MORE, "great_beast")
	return null


## WU-422: draws the glyph for a calendar entry kind into `rect` on canvas item `ci` (nearest filter, centred).
static func draw_calendar_kind(ci: CanvasItem, kind: String, rect: Rect2, season_name: String = "") -> void:
	var tex := calendar_kind(kind, season_name)
	if tex == null:
		return
	ci.draw_texture_rect(tex, rect, false)


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
