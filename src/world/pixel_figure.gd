class_name PixelFigure
extends RefCounted
## Generated 16x20 pixel-art people (GFX-011): the player and NPCs use these until a sprite pack is mapped
## in data/sprites.json (GFX-004). Templates are text rows, one char per pixel:
## . transparent, o outline, s skin, h hair, r robe, R robe shade, b sash, e eye, f shoes.
## Rendering only: pure and deterministic, no node access.

const SIZE := Vector2i(16, 20)
const OUTLINE := Color("2b2118")
const SHOES := Color("3a2f26")
const DEFAULT_ROBE := Color("6e5a46")
const DEFAULT_SASH := Color("9a9a9a")
const DEFAULT_SKIN := Color("e8c9a0")
const DEFAULT_HAIR := Color("2a2018")
const CHILD_CUT_ROWS := [12, 13, 14, 15]
const PALETTE := ".oshrRbef"

## Head rows 0-7 per direction (bun style; `long` is derived from it).
const HEAD := {
	"down": [
		"......oooo......",
		".....ohhhho.....",
		"....oohhhhoo....",
		"...ohhhhhhhho...",
		"...ohhhhhhhho...",
		"...ohssssssho...",
		"...osesssseso...",
		"....osssssso....",
	],
	"up": [
		"......oooo......",
		".....ohhhho.....",
		"....oohhhhoo....",
		"...ohhhhhhhho...",
		"...ohhhhhhhho...",
		"...ohhhhhhhho...",
		"...ohhhhhhhho...",
		"....ohhhhhho....",
	],
	"side": [
		"......oooo......",
		".....ohhhho.....",
		"....ohhhhhho....",
		"...ohhhhhhhho...",
		"...ohhhhssssso..",
		"...ohhhsssesso..",
		"...ohhhhssssso..",
		"....ohhhsssso...",
	],
}
## Body rows 8-19 per direction: neck, shoulders, sleeves, sash, shade, robe x3, shaded edge, hem, two feet rows.
const BODY := {
	"front": [
		"......osso......",
		"...orrrrrrrro...",
		"..ossrrrrrrsso..",
		"..orrrbbbbrrro..",
		"..orrRRRRRRrro..",
		"..orrrrrrrrrro..",
		"..orrrrrrrrrro..",
		"..orrrrrrrrrro..",
		"..oRrrrrrrrRro..",
		"..oRRRRRRRRRRo..",
	],
	"side": [
		"......osso......",
		"....orrrrrro....",
		"....orrrrrrsso..",
		"....obbbbbbro...",
		"....orrrRRrro...",
		"....orrrrrrro...",
		"....orrrrrrro...",
		"....orrrrrrro...",
		"....oRrrrrrRo...",
		"....oRRRRRRRo...",
	],
}
## Feet rows 18-19 per direction family and frame (stand, step A, step B).
const FEET := {
	"front": [
		["....offo.offo...", "....oooo.oooo..."],
		["....offo........", "....oooo..offo.."],
		["........offo....", "..offo..oooo...."],
	],
	"side": [
		["....offfffo.....", "....ooooooo....."],
		["...offo...offo..", "...oooo...oooo.."],
		["......offo......", "......oooo......"],
	],
}

static var _cache: Dictionary = {}


## The 20 text rows of a figure facing `dir` ("down", "up", "right"; "left" is mirrored later).
static func rows(dir: String, index: int, style: String, child: bool) -> PackedStringArray:
	var head_key := "side" if dir == "right" or dir == "left" else dir
	var family := "side" if head_key == "side" else "front"
	var out := PackedStringArray()
	for r in HEAD[head_key]:
		out.append(r)
	for r in BODY[family]:
		out.append(r)
	for r in FEET[family][posmod(index, 3)]:
		out.append(r)
	if style == "long":
		out[0] = "................"
		out[1] = "......oooo......"
		for y in [4, 5, 6, 7, 8, 9]:
			out[y] = _hair_edges(out[y], family == "side")
	if style == "hood":
		for y in 10:
			out[y] = out[y].replace("h", "r")
		out[1] = out[1].replace("r", "R")
	if child:
		var short := PackedStringArray()
		for _i in 4:
			short.append("................")
		for y in out.size():
			if not CHILD_CUT_ROWS.has(y):
				short.append(out[y])
		return short
	return out


## Turns the outer outline pixels of a row into hair (both sides, or the back side only when seen from the side).
static func _hair_edges(row: String, side: bool) -> String:
	var first := row.length()
	var last := -1
	for x in row.length():
		if row[x] != ".":
			first = mini(first, x)
			last = x
	if last < 0:
		return row
	var out := row.substr(0, first) + "h" + row.substr(first + 1)
	if not side:
		out = out.substr(0, last) + "h" + out.substr(last + 1)
	return out


## A 16x20 texture for `look` ({robe, sash, skin, hair, style, child}), facing `dir`, walk frame `index`.
static func frame(look: Dictionary, dir: String, index: int) -> ImageTexture:
	var robe: Color = look.get("robe", DEFAULT_ROBE)
	var sash: Color = look.get("sash", DEFAULT_SASH)
	var skin: Color = look.get("skin", DEFAULT_SKIN)
	var hair: Color = look.get("hair", DEFAULT_HAIR)
	var style := String(look.get("style", "bun"))
	var child := bool(look.get("child", false))
	var i := posmod(index, 3)
	var key := "%s|%s|%s|%s|%s|%s|%s|%d" % [robe.to_html(), sash.to_html(), skin.to_html(), hair.to_html(), style, child, dir, i]
	if not _cache.has(key):
		var colors := {"o": OUTLINE, "s": skin, "h": hair, "r": robe, "R": robe.darkened(0.25), "b": sash, "e": OUTLINE, "f": SHOES}
		_cache[key] = _build(rows("right" if dir == "left" else dir, i, style, child), colors, dir == "left")
	return _cache[key]


static func _build(template: PackedStringArray, colors: Dictionary, mirror: bool) -> ImageTexture:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y in SIZE.y:
		for x in SIZE.x:
			var ch := template[y][SIZE.x - 1 - x if mirror else x]
			if ch != ".":
				img.set_pixel(x, y, colors[ch])
	return ImageTexture.create_from_image(img)


## GFX-014: 24x16 side-view quadruped facing right, rows 0-11 body and head, then two leg frames.
## . transparent, o outline, f fur, F fur shade, e eye.
const BEAST_ROWS := [
	"..................oo....",
	"................oofoo...",
	"...ooooooooooo.oofffeoo.",
	"..offffffffffooffffffffo",
	".offffffffffffofffffffo.",
	"offfffffffffffffffffooo.",
	"offFFFFFFFFFFFFffffoo...",
	".offffffffffffffffo.....",
	"..oFFFFFFFFFFFFFFo......",
	"..ofo.ofo....ofo.ofo....",
]
const BEAST_LEGS := [
	["..ofo.ofo....ofo.ofo...", "..ooo.ooo....ooo.ooo...."],
	["...ofo.ofo..ofo.ofo....", "...ooo.ooo..ooo.ooo....."],
]
const BEAST_SIZE := Vector2i(24, 16)


## GFX-028: kinds that are not the plain quadruped. Snake and bird are drawn from their own rows (same 24x16 frame);
## wolf, boar and tiger edit the plain body (ears and tail, tusks and bristles, stripes) in `_beast_marks`.
const SNAKE_ROWS := [
	"........................",
	"........................",
	"........................",
	"........................",
	"..............oooo......",
	".............offffoo....",
	"....oooooo...offfefffo..",
	"..ooffffffoo.offffffoo..",
	".offFFFFFFffoofffffoo...",
	"offfffooooFFfffffoo.....",
	"offfoo...ooFFFFFFo......",
	".ooo.......oooooo.......",
]
const BIRD_ROWS := [
	"........................",
	"........................",
	"..........oo............",
	".........offo...........",
	"...oo....offfoo.....oo..",
	"..offo..offffffo...offo.",
	"..offfooffFFFFfffooofffo",
	"...offfffFFFFFFfffffffo.",
	"....ooffffffffffffffooo.",
	".....ooofffffffooo.eeoo.",
	"........oofooffo.eoo....",
	"........oo.oo.oo........",
]
const BEAST_KINDS := ["wolf", "boar", "tiger", "snake", "bird"]


## A generated 24x16 beast facing right (the foe mirrors it). `index` picks one of two leg frames;
## `kind` (one of BEAST_KINDS, "" = the plain body) picks the silhouette.
static func beast_frame(fur: Color, index: int, kind: String = "") -> ImageTexture:
	var i := posmod(index, 2)
	var key := "beast|%s|%d|%s" % [fur.to_html(), i, kind]
	if not _cache.has(key):
		var img := Image.create(BEAST_SIZE.x, BEAST_SIZE.y, false, Image.FORMAT_RGBA8)
		var colors := {"o": OUTLINE, "f": fur, "F": fur.darkened(0.25), "e": Color("e8d8a0")}
		var rows: Array = BEAST_ROWS.slice(0, 9)
		var top := 4
		if kind == "snake":
			rows = SNAKE_ROWS.duplicate()
			top = 3
		elif kind == "bird":
			rows = BIRD_ROWS.duplicate()
			top = 3
			if i == 1:  # wings up on the second frame
				rows[4] = "..oo...ooffooo.....oo..."
				rows[5] = "..ofo.ooffffffo...ofo..."
		else:
			rows.append_array(BEAST_LEGS[i])
		for y in rows.size():
			var row: String = rows[y]
			for x in mini(row.length(), BEAST_SIZE.x):
				if colors.has(row[x]):
					img.set_pixel(x, y + top, colors[row[x]])
		_beast_marks(img, fur, kind)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Kind-specific marks on the plain body: wolf ears and a long tail, boar tusks and a bristle ridge, tiger stripes.
static func _beast_marks(img: Image, fur: Color, kind: String) -> void:
	match kind:
		"wolf":
			for p in [Vector2i(16, 3), Vector2i(21, 3), Vector2i(16, 2), Vector2i(21, 2)]:
				img.set_pixelv(p, OUTLINE)
			for p in [Vector2i(0, 7), Vector2i(0, 8), Vector2i(1, 6), Vector2i(0, 6)]:
				img.set_pixelv(p, fur.darkened(0.25))
			img.set_pixelv(Vector2i(0, 5), OUTLINE)
		"boar":
			for x in range(4, 13):
				img.set_pixelv(Vector2i(x, 6), fur.darkened(0.4))
			for p in [Vector2i(22, 11), Vector2i(23, 10), Vector2i(21, 11)]:
				img.set_pixelv(p, Color("f0e8d0"))
		"tiger":
			for x in range(3, 14, 3):
				for y in range(7, 12):
					if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y) != OUTLINE:
						img.set_pixel(x, y, OUTLINE.lightened(0.1))
