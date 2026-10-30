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


## A generated 24x16 beast facing right (the foe mirrors it). `index` picks one of two leg frames.
static func beast_frame(fur: Color, index: int) -> ImageTexture:
	var i := posmod(index, 2)
	var key := "beast|%s|%d" % [fur.to_html(), i]
	if not _cache.has(key):
		var img := Image.create(BEAST_SIZE.x, BEAST_SIZE.y, false, Image.FORMAT_RGBA8)
		var colors := {"o": OUTLINE, "f": fur, "F": fur.darkened(0.25), "e": Color("e8d8a0")}
		var rows: Array = BEAST_ROWS.slice(0, 9)
		rows.append_array(BEAST_LEGS[i])
		for y in rows.size():
			var row: String = rows[y]
			for x in mini(row.length(), BEAST_SIZE.x):
				if colors.has(row[x]):
					img.set_pixel(x, y + 4, colors[row[x]])
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
