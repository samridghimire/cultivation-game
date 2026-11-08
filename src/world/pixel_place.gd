class_name PixelPlace
extends RefCounted
## Generated pixel-art buildings and stalls (GFX-021): village places use these until a sprite pack is mapped
## in data/sprites.json (GFX-002/003). Each kind is a small canvas of text rows (one char per pixel, drawn at
## Sprites.scale()), assembled from rectangles and hip roofs, then outlined on its silhouette edge.
## . transparent, o outline, w wall, W wall shade, r roof (the place colour), R roof shade, h roof highlight,
## d door / dark opening, t timber, T timber shade, p paper / window, g gold trim, s stone, S stone shade,
## e earth, v foliage (GFX-022 nature places: meditation, gather, explore, inheritance, abode, secret_realm, camp).
## Rendering only: pure and deterministic, no node access.

const KINDS := ["merchant", "workshop", "sect_hall", "clinic", "orphanage", "family_home", "bounty_board", "travel", "auction"]
const SHOP_MIN_WIDTH := 110.0  ## GFX-058: merchants at least this wide draw as the two-storey "shop" instead of a stall
const NATURE_KINDS := ["meditation", "gather", "explore", "inheritance", "abode", "secret_realm", "camp", "fishing"]
## GFX-095: the pictures an explore place can have (regions.json `look`); "cave" is the original dome.
const EXPLORE_LOOKS := PlaceLooks.EXPLORE_LOOKS  # GUIDE-219: owned by core
## GFX-102: the pictures a gather place can have (regions.json `look`); "patch" is the original herb bed.
const GATHER_LOOKS := PlaceLooks.GATHER_LOOKS
## GFX-098: the pictures a secret-realm entrance can have (regions.json `look`); "rift" is the original ring.
const REALM_LOOKS := PlaceLooks.REALM_LOOKS
const PALETTE := ".owWrRhdtTpgsSevbBnmfk"
const OUTLINE := Color("2b2118")
const DOOR := Color("3a2f26")
const COLORS := {
	"o": OUTLINE, "w": Color("d9cdb4"), "W": Color("b3a68c"), "d": DOOR, "t": Color("6e5636"), "T": Color("4f3d26"),
	"p": Color("e8dcc0"), "g": Color("c9a24a"), "s": Color("8a8478"), "S": Color("6a6559"), "e": Color("6e5a3c"), "v": Color("4f7a3a"),
	"b": Color("bfe3f2"), "B": Color("6fa6d0"), "n": Color("eef4f8"), "m": Color("2f3a2c"), "f": Color("e8742a"), "k": Color("2a2624"),
}

## GFX-100: regions.json `map.building_style`; thatch is the base look (COLORS), the others override these entries
## (and the roof colour) on building kinds only. `roof` (optional) replaces the place colour.
const STYLES := PlaceLooks.BUILDING_STYLES
const STYLE_COLORS := {
	"thatch": {},
	"tile": {"w": Color("ece8de"), "W": Color("c4beb0"), "t": Color("a8332b"), "T": Color("7a2420"), "roof": Color("5d7388")},
	"stone": {"w": Color("9a968c"), "W": Color("746f65"), "t": Color("5a5f68"), "T": Color("40444c"), "roof": Color("4d5f7a")},
	"stilt": {"w": Color("6b5a44"), "W": Color("4a3d2d"), "t": Color("4a3a28"), "T": Color("33281b"), "roof": Color("7a6444")},
	"log": {"w": Color("5a4330"), "W": Color("3d2d20"), "t": Color("463525"), "T": Color("2e2218"), "roof": Color("4c6a3a")},
}

static var _cache: Dictionary = {}


## GFX-100: kinds that take a building style (sect halls, nature and explore looks never do).
static func is_building(kind: String) -> bool:
	return ["workshop", "clinic", "orphanage", "family_home", "auction", "merchant"].has(kind) or kind.begins_with("shop")


## GFX-100: the style that actually applies to `kind` ("thatch" for non-buildings and unknown styles).
static func effective_style(kind: String, style: String) -> String:
	return style if is_building(kind) and STYLE_COLORS.has(style) else "thatch"


static func supports(kind: String) -> bool:
	return KINDS.has(kind) or NATURE_KINDS.has(kind) or kind.begins_with("shop") or _explore_look(kind) != "" or _gather_look(kind) != "" or _realm_look(kind) != ""


## The art kind for an explore place with `look`: plain "explore" for cave or an unknown look.
static func explore_kind(look: String) -> String:
	return "explore_" + look if look != "cave" and EXPLORE_LOOKS.has(look) else "explore"


## GFX-102: the art kind for a gather place with `look`: plain "gather" for patch or an unknown look.
static func gather_kind(look: String) -> String:
	return "gather_" + look if look != "patch" and GATHER_LOOKS.has(look) else "gather"


static func _gather_look(kind: String) -> String:
	if kind.begins_with("gather_") and GATHER_LOOKS.has(kind.substr(7)):
		return kind.substr(7)
	return ""


## The art kind for a secret-realm entrance with `look`: "secret_realm" for rift or an unknown look.
static func realm_kind(look: String) -> String:
	return "secret_realm_" + look if look != "rift" and REALM_LOOKS.has(look) else "secret_realm"


static func _realm_look(kind: String) -> String:
	if kind.begins_with("secret_realm_") and REALM_LOOKS.has(kind.substr(13)):
		return kind.substr(13)
	return ""


static func _explore_look(kind: String) -> String:
	if kind.begins_with("explore_") and EXPLORE_LOOKS.has(kind.substr(8)):
		return kind.substr(8)
	return ""


## Pixel size of the template for `kind` (travel flips with the gate's orientation).
static func template_size(kind: String, horizontal: bool = true) -> Vector2i:
	var r := rows(kind, horizontal)
	return Vector2i(r[0].length(), r.size()) if not r.is_empty() else Vector2i.ZERO


## GFX-067: where a smithy's smoke leaves its chimney, relative to the place's centre (matches `_shop`'s stack).
static func smithy_smoke_offset(size: Vector2) -> Vector2:
	var compact := size.x < 120.0
	var tex_w := 58 if compact else 66
	var tex_h := 44 if compact else 46
	var sc := float(Sprites.scale())
	return Vector2((tex_w - 17 + 3.5 - tex_w / 2.0) * sc, size.y / 2.0 - tex_h * sc)


## GFX-064: the shop variant for a merchant's name: "shop_smithy" (chimney with a glow) or "shop_scrolls" (scroll sign), else "shop".
static func shop_look(place_name: String) -> String:
	var n := place_name.to_lower()
	if n.contains("smith") or n.contains("forge"):
		return "shop_smithy"
	if n.contains("scroll"):
		return "shop_scrolls"
	return "shop"


static func texture(kind: String, size: Vector2, color: Color, active: bool = false, place_name: String = "", style: String = "thatch") -> ImageTexture:
	var compact := false
	if kind == "merchant" and size.x >= SHOP_MIN_WIDTH:
		kind = shop_look(place_name)
		compact = size.x < 120.0
	var horizontal := size.x >= size.y
	style = effective_style(kind, style)
	var key := "%s|%s|%s|%s" % [kind + ("_c" if compact else ""), color.to_html(), horizontal if kind == "travel" else true, active]
	if style != "thatch":
		key += "|" + style
	if not _cache.has(key):
		_cache[key] = from_rows(rows(kind, horizontal, active, compact, style), color, active, style)
	return _cache[key]


## Builds a texture from template rows; `r` takes `color` (brighter when `active`), R / h are its shade / highlight.
static func from_rows(r: Array[String], color: Color, active: bool = false, style: String = "thatch") -> ImageTexture:
	var img := Image.create(r[0].length(), r.size(), false, Image.FORMAT_RGBA8)
	var palette := COLORS.duplicate()
	var over: Dictionary = STYLE_COLORS.get(style, {})
	for ch: String in over:
		if ch != "roof":
			palette[ch] = over[ch]
	var base: Color = over.get("roof", color) if over.has("roof") else color
	if active:
		base = base.lightened(0.25)
	palette["r"] = base
	palette["R"] = base.darkened(0.3)
	palette["h"] = base.lightened(0.2)
	for y in r.size():
		for x in r[y].length():
			var ch := r[y][x]
			img.set_pixel(x, y, palette[ch] if palette.has(ch) else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## Template rows for `kind` (empty for unsupported kinds); each row has the same length.
static func rows(kind: String, horizontal: bool = true, active: bool = false, compact: bool = false, style: String = "thatch") -> Array[String]:
	var c: Array
	match kind:
		"merchant":
			c = _merchant()
		"shop":
			c = _shop("", compact)
		"shop_smithy":
			c = _shop("smithy", compact)
		"shop_scrolls":
			c = _shop("scrolls", compact)
		"workshop":
			c = _workshop()
		"sect_hall":
			c = _sect_hall()
		"clinic":
			c = _clinic()
		"orphanage":
			c = _orphanage()
		"family_home":
			c = _family_home()
		"bounty_board":
			c = _bounty_board()
		"auction":
			c = _auction()
		"travel":
			c = _gate_h() if horizontal else _gate_v()
		"meditation":
			c = _meditation()
		"gather":
			c = _gather()
		"gather_rubble":
			c = _gather_rubble()
		"gather_crater":
			c = _gather_crater()
		"gather_crystal":
			c = _gather_crystal()
		"gather_frost":
			c = _gather_frost()
		"gather_terrace":
			c = _gather_terrace()
		"gather_bog":
			c = _gather_bog()
		"explore":
			c = _cave()
		"inheritance":
			c = _stele()
		"abode":
			c = _dwelling()
		"secret_realm":
			c = _rift(active)
		"secret_realm_cleft":
			c = _realm_cleft(active)
		"secret_realm_seal":
			c = _realm_seal(active)
		"secret_realm_gate":
			c = _realm_gate(active)
		"secret_realm_tomb":
			c = _realm_tomb(active)
		"secret_realm_pavilion":
			c = _realm_pavilion(active)
		"camp":
			c = _camp()
		"fishing":
			c = _jetty()
		"explore_woods":
			c = _woods()
		"explore_ruins":
			c = _ruins()
		"explore_reeds":
			c = _reeds()
		"explore_ridge":
			c = _ridge()
		"explore_trail":
			c = _trail()
		_:
			return []
	apply_style_rows(c, effective_style(kind, style))
	outline(c)
	var out: Array[String] = []
	for row: Array in c:
		out.append("".join(row))
	return out


## GFX-100: small row edits per style, before the outline: stilt raises the base on posts (the bottom 3 rows keep a
## 2 px post every 8 px, mud-dark between is cleared); log draws a horizontal seam on every 3rd wall row.
static func apply_style_rows(c: Array, style: String) -> void:
	var h := c.size()
	if style == "stilt":
		for y in range(h - 3, h):
			for x in c[y].size():
				if x % 8 >= 2:
					c[y][x] = "."
				elif c[y][x] != ".":
					c[y][x] = "T"
	elif style == "log":
		for y in range(0, h - 3):
			if y % 3 != 0:
				continue
			for x in c[y].size():
				if c[y][x] == "w":
					c[y][x] = "W"


static func canvas(w: int, h: int) -> Array:
	var c: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		c.append(row)
	return c


static func rect(c: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for yy in range(maxi(y, 0), mini(y + h, c.size())):
		for xx in range(maxi(x, 0), mini(x + w, c[yy].size())):
			c[yy][xx] = ch


## A filled box with the bottom row and right column in the shade char (light from the top-left).
static func box(c: Array, x: int, y: int, w: int, h: int, main: String, shade: String) -> void:
	rect(c, x, y, w, h, main)
	rect(c, x, y + h - 1, w, 1, shade)
	rect(c, x + w - 1, y, 1, h, shade)


## A hip roof: row i is inset (h-1-i) pixels, highlight on top/left, shade at the bottom/right, a tile line every 3rd row.
static func roof(c: Array, x: int, y: int, w: int, h: int) -> void:
	for i in h:
		var inset := h - 1 - i
		var rw := w - 2 * inset
		var rx := x + inset
		rect(c, rx, y + i, rw, 1, "h" if i == 0 else ("R" if i % 3 == 2 else "r"))
		if i > 0:
			rect(c, rx, y + i, 1, 1, "h")
			rect(c, rx + rw - 1, y + i, 1, 1, "R")
	rect(c, x, y + h - 1, w, 1, "R")


## A filled ellipse centred on (cx, cy) with radii rx, ry.
static func ell(c: Array, cx: float, cy: float, rx: float, ry: float, ch: String) -> void:
	for y in c.size():
		for x in c[y].size():
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				c[y][x] = ch


static func outline(c: Array) -> void:
	var edge: Array[Vector2i] = []
	var h := c.size()
	var w: int = c[0].size()
	for y in h:
		for x in w:
			if c[y][x] == ".":
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or c[ny][nx] == ".":
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		c[p.y][p.x] = "o"


static func _merchant() -> Array:
	var c := canvas(30, 28)
	rect(c, 2, 8, 2, 20, "t")
	rect(c, 26, 8, 2, 20, "t")
	rect(c, 4, 10, 22, 9, "d")
	rect(c, 6, 15, 3, 3, "h")
	rect(c, 12, 14, 3, 4, "g")
	rect(c, 18, 15, 3, 3, "h")
	rect(c, 23, 16, 2, 2, "p")
	box(c, 3, 19, 24, 9, "t", "T")
	for x in 30:
		var red := (x / 3) % 2 == 0
		rect(c, x, 1, 1, 8, "r" if red else "p")
		if red:
			rect(c, x, 1, 1, 1, "h")
			rect(c, x, 8, 1, 1, "R")
	return c


## GFX-058: a two-storey shop front for wide merchants (>= SHOP_MIN_WIDTH): upper floor with a hanging sign, shuttered
## windows, a striped awning over a counter and the door.
static func _shop(look: String = "", compact: bool = false) -> Array:
	# The 110-119 px shops use a 58x44 canvas (so the art fits the place rect), the wider ones 66x46.
	var w := 58 if compact else 66
	var h := 44 if compact else 46
	var c := canvas(w, h)
	var bw := w - 12  # wall width
	var wh := h - 16  # wall height
	box(c, 6, 16, bw, wh, "w", "W")
	rect(c, 6, 16, 2, wh, "t")
	rect(c, 6 + bw - 2, 16, 2, wh, "T")
	rect(c, 6, 28, bw, 2, "t")
	for wx in ([12, 24] if compact else [13, 29, 45]):
		rect(c, wx, 20, 8, 6, "p")
		rect(c, wx, 20, 1, 6, "T")
	for x in range(8, 6 + bw - 2):
		rect(c, x, 31, 1, 4, "r" if (x / 3) % 2 == 0 else "p")
	rect(c, 8, 35, bw - 4, 1, "R")
	var dx := 32 if compact else 38  # the door
	var wx2 := dx + (11 if compact else 12)  # the side window
	rect(c, 12, 37, 14, h - 37, "T")
	rect(c, 14, 37, 10, 3, "h")
	rect(c, dx, 36, 10, h - 36, "d")
	rect(c, dx + 2, 41, 6, h - 41, "g")
	rect(c, wx2, 38, 6, h - 38, "p")
	roof(c, 2, 4, w - 4, 13)
	var sx := (w - 18) / 2
	rect(c, sx, 3, 18, 7, "t")
	rect(c, sx + 1, 4, 16, 5, "g")
	rect(c, sx + 4, 6, 10, 1, "T")
	match look:
		"smithy":
			# A stone chimney rising from the roof, its mouth glowing gold.
			# GFX-067: dark soot-stained stack with a cap, standing out from the grey roof; a bright furnace mouth.
			var cx := w - 17
			box(c, cx, 0, 7, 14, "T", "o")
			rect(c, cx - 1, 0, 9, 2, "o")
			rect(c, cx + 1, 1, 5, 1, "d")
			rect(c, cx + 2, 1, 3, 1, "g")
			rect(c, cx + 3, 1, 1, 1, "p")
		"scrolls":
			# A hanging scroll sign by the door: paper with gold rods and dark text strokes.
			rect(c, wx2, 33, 8, 1, "g")
			rect(c, wx2 + 1, 34, 6, h - 36, "p")
			rect(c, wx2, h - 2, 8, 1, "g")
			rect(c, wx2 + 2, 36, 4, 1, "T")
			rect(c, wx2 + 2, 38, 4, 1, "T")
			rect(c, wx2 + 2, 40, 3, 1, "T")
	return c


static func _workshop() -> Array:
	var c := canvas(64, 44)
	box(c, 6, 20, 52, 24, "w", "W")
	rect(c, 6, 20, 2, 24, "t")
	rect(c, 56, 20, 2, 24, "T")
	rect(c, 10, 27, 8, 6, "p")
	rect(c, 46, 27, 8, 6, "p")
	rect(c, 26, 29, 12, 15, "d")
	rect(c, 28, 35, 8, 9, "g")
	rect(c, 30, 38, 4, 6, "p")
	roof(c, 2, 8, 60, 14)
	box(c, 46, 0, 6, 12, "s", "S")
	return c


static func _sect_hall() -> Array:
	var c := canvas(78, 54)
	box(c, 10, 49, 58, 5, "s", "S")
	box(c, 12, 30, 54, 19, "w", "W")
	for px in [14, 28, 48, 62]:
		rect(c, px, 30, 3, 19, "r")
	rect(c, 34, 36, 10, 13, "d")
	roof(c, 2, 22, 74, 10)
	box(c, 22, 13, 34, 10, "w", "W")
	rect(c, 36, 16, 6, 5, "p")
	roof(c, 12, 3, 54, 10)
	rect(c, 26, 3, 26, 1, "g")
	rect(c, 38, 0, 2, 4, "g")
	return c


static func _clinic() -> Array:
	var c := canvas(50, 36)
	box(c, 4, 14, 42, 22, "w", "W")
	rect(c, 8, 21, 7, 7, "p")
	rect(c, 35, 21, 7, 7, "p")
	rect(c, 21, 22, 8, 14, "d")
	rect(c, 17, 20, 1, 3, "t")
	rect(c, 16, 23, 3, 3, "g")
	rect(c, 15, 26, 5, 4, "g")
	roof(c, 1, 4, 48, 11)
	return c


static func _orphanage() -> Array:
	var c := canvas(54, 38)
	box(c, 6, 34, 42, 4, "s", "S")
	box(c, 8, 18, 38, 17, "w", "W")
	rect(c, 23, 23, 8, 12, "R")
	rect(c, 29, 29, 1, 1, "g")
	rect(c, 11, 24, 3, 5, "g")
	rect(c, 40, 24, 3, 5, "g")
	roof(c, 1, 4, 52, 15)
	rect(c, 20, 3, 14, 2, "g")
	return c


static func _family_home() -> Array:
	var c := canvas(40, 30)
	box(c, 4, 13, 32, 17, "w", "W")
	rect(c, 7, 18, 6, 5, "g")
	rect(c, 27, 18, 6, 5, "g")
	rect(c, 17, 19, 7, 11, "d")
	roof(c, 1, 3, 38, 11)
	box(c, 28, 0, 4, 7, "s", "S")
	return c


static func _bounty_board() -> Array:
	var c := canvas(34, 28)
	rect(c, 3, 6, 3, 22, "t")
	rect(c, 28, 6, 3, 22, "T")
	box(c, 1, 3, 32, 17, "t", "T")
	rect(c, 3, 5, 28, 13, "w")
	for n: Array in [[5, 7, 6, 7], [14, 6, 6, 8], [23, 8, 6, 6]]:
		rect(c, n[0], n[1], n[2], n[3], "p")
		rect(c, n[0] + 1, n[1] + 2, n[2] - 2, 1, "d")
	return c


static func _auction() -> Array:
	var c := canvas(68, 48)
	box(c, 6, 44, 56, 4, "s", "S")
	box(c, 8, 22, 52, 23, "w", "W")
	rect(c, 8, 22, 2, 23, "t")
	rect(c, 58, 22, 2, 23, "T")
	rect(c, 12, 28, 7, 7, "p")
	rect(c, 49, 28, 7, 7, "p")
	rect(c, 27, 34, 14, 11, "d")
	roof(c, 1, 8, 66, 15)
	rect(c, 20, 8, 28, 1, "g")
	rect(c, 30, 20, 8, 13, "R")
	rect(c, 30, 20, 8, 2, "g")
	rect(c, 33, 26, 2, 4, "g")
	rect(c, 33, 0, 1, 8, "t")
	rect(c, 34, 0, 5, 3, "R")
	return c


static func _gate_h() -> Array:
	var c := canvas(58, 18)
	box(c, 2, 4, 5, 14, "t", "T")
	box(c, 51, 4, 5, 14, "t", "T")
	rect(c, 1, 16, 7, 2, "s")
	rect(c, 50, 16, 7, 2, "s")
	box(c, 7, 5, 44, 3, "t", "T")
	rect(c, 0, 0, 58, 4, "r")
	rect(c, 0, 0, 58, 1, "h")
	rect(c, 0, 3, 58, 1, "R")
	rect(c, 24, 8, 10, 5, "g")
	rect(c, 27, 10, 4, 1, "d")
	return c


## The same gate seen side-on: end posts at the top and bottom, the roof beam running between them.
static func _gate_v() -> Array:
	var c := canvas(18, 58)
	box(c, 3, 0, 12, 7, "t", "T")
	box(c, 3, 51, 12, 7, "t", "T")
	rect(c, 2, 7, 14, 1, "S")
	rect(c, 4, 7, 10, 44, "r")
	rect(c, 4, 7, 1, 44, "h")
	rect(c, 13, 7, 1, 44, "R")
	rect(c, 6, 25, 6, 10, "g")
	rect(c, 8, 28, 2, 4, "d")
	return c


## A flat stone dais ringed with boulders and a cushion in the middle.
static func _meditation() -> Array:
	var c := canvas(44, 30)
	ell(c, 22, 17, 21, 12, "S")
	ell(c, 22, 15, 20, 11, "s")
	ell(c, 22, 15, 14, 7, "S")
	ell(c, 22, 14, 13, 6, "W")
	ell(c, 22, 13, 5, 3, "r")
	rect(c, 17, 12, 10, 1, "h")
	for p: Array in [[2, 8], [10, 2], [32, 2], [40, 8], [3, 20], [38, 21]]:
		rect(c, p[0], p[1], 4, 3, "s")
		rect(c, p[0], p[1] + 2, 4, 1, "S")
	return c


## A mound of turned earth with sprouting herbs (tinted by the place colour).
static func _gather() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 21, 24, 12, "e")
	ell(c, 25, 19, 22, 10, "e")
	for p: Array in [[8, 14], [18, 9], [30, 11], [40, 16], [13, 22], [25, 19], [35, 24]]:
		rect(c, p[0], p[1] + 2, 1, 5, "v")
		rect(c, p[0] - 2, p[1] + 1, 5, 2, "r")
		rect(c, p[0] - 1, p[1], 3, 1, "h")
		rect(c, p[0], p[1] - 2, 1, 2, "h")
	return c


## GFX-102: grey stone chips and two broken blocks with one rusty ore glint.
static func _gather_rubble() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 21, 24, 12, "S")
	ell(c, 25, 19, 22, 10, "s")
	for p: Array in [[6, 18], [14, 25], [22, 13], [31, 26], [40, 19], [44, 24], [28, 18], [10, 12]]:
		rect(c, p[0], p[1], 3, 2, "S")
		rect(c, p[0], p[1], 2, 1, "w")
	for p: Array in [[13, 12], [30, 14]]:
		box(c, p[0], p[1], 9, 7, "s", "S")
		rect(c, p[0] + 1, p[1] + 1, 4, 1, "w")
		rect(c, p[0] + 4, p[1] + 3, 1, 4, "S")
	rect(c, 33, 17, 2, 2, "e")
	rect(c, 33, 17, 1, 1, "g")
	return c


## GFX-102: a scorched ring round a cracked black rock with ember glints.
static func _gather_crater() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 21, 24, 12, "k")
	ell(c, 25, 20, 20, 10, "T")
	ell(c, 25, 20, 14, 7, "k")
	ell(c, 25, 18, 9, 6, "S")
	rect(c, 21, 15, 9, 6, "k")
	rect(c, 25, 15, 1, 6, "T")
	rect(c, 23, 18, 4, 1, "T")
	for p: Array in [[10, 20], [38, 22], [27, 26], [17, 13]]:
		rect(c, p[0], p[1], 2, 2, "f")
		rect(c, p[0], p[1], 1, 1, "g")
	return c


## GFX-102: a rock outcrop with pale-blue crystal spikes.
static func _gather_crystal() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 24, 23, 9, "S")
	ell(c, 25, 22, 21, 8, "s")
	for p: Array in [[11, 20, 4, 11], [19, 14, 5, 16], [28, 10, 5, 20], [37, 18, 4, 12]]:
		var x: int = p[0]
		var h: int = p[3]
		var w: int = p[2]
		for i in h:
			var inset := 0 if i > h / 3 else 1
			rect(c, x + inset, 28 - i, w - inset * 2, 1, "B")
			rect(c, x + inset, 28 - i, maxi(1, (w - inset * 2) / 2), 1, "b")
	return c


## GFX-102: a white-blue rock shelf under snow with two tiny blue flowers.
static func _gather_frost() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 22, 24, 11, "B")
	ell(c, 25, 20, 22, 9, "b")
	ell(c, 25, 18, 18, 6, "n")
	rect(c, 4, 22, 42, 2, "B")
	for p: Array in [[12, 14], [34, 16], [20, 26]]:
		rect(c, p[0], p[1], 5, 2, "n")
	for p: Array in [[17, 18], [31, 21]]:
		rect(c, p[0], p[1] + 1, 1, 3, "v")
		rect(c, p[0] - 1, p[1], 3, 2, "B")
		rect(c, p[0], p[1], 1, 1, "n")
	return c


## GFX-102: stepped green bands with stone edges and orchid dots (tinted by the place colour).
static func _gather_terrace() -> Array:
	var c := canvas(50, 34)
	for i in 3:
		var y := 4 + i * 9
		var inset := 6 - i * 2
		rect(c, inset, y, 50 - inset * 2, 6, "v")
		rect(c, inset, y, 50 - inset * 2, 1, "h")
		rect(c, inset, y + 6, 50 - inset * 2, 3, "S")
		rect(c, inset, y + 6, 50 - inset * 2, 1, "s")
		for x in range(inset + 4, 50 - inset - 3, 8):
			rect(c, x + i * 2, y + 2, 2, 2, "r")
			rect(c, x + i * 2, y + 2, 1, 1, "n")
	return c


## GFX-102: a dark murky pool, reeds at the rim and two pale lilies.
static func _gather_bog() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 21, 24, 12, "T")
	ell(c, 25, 21, 22, 10, "m")
	ell(c, 25, 21, 15, 6, "t")
	ell(c, 25, 21, 14, 5, "m")
	for p: Array in [[5, 14], [9, 26], [41, 13], [45, 22], [37, 29], [18, 10]]:
		rect(c, p[0], p[1], 1, 7, "v")
		rect(c, p[0] + 1, p[1] + 2, 1, 5, "v")
		rect(c, p[0], p[1] - 1, 2, 2, "T")
	for p: Array in [[19, 20], [30, 23]]:
		rect(c, p[0], p[1], 5, 3, "v")
		rect(c, p[0] + 1, p[1], 2, 2, "n")
		rect(c, p[0] + 2, p[1], 1, 1, "g")
	return c


## A fishing spot (WU-405): a rod, line and float and a few reeds; the planks and posts are the `jetty` landmark
## drawn underneath (GFX-045), so its snow cap applies. `rect`s below use the old 44x22 layout.
static func _jetty() -> Array:
	var c := canvas(44, 22)
	rect(c, 38, 3, 1, 9, "T")
	rect(c, 36, 3, 3, 1, "T")
	rect(c, 38, 12, 2, 2, "g")
	rect(c, 38, 11, 2, 1, "p")
	rect(c, 36, 16, 8, 1, "S")
	rect(c, 38, 18, 5, 1, "S")
	for x: int in [41, 43]:
		rect(c, x, 8, 1, 6, "v")
	return c


## A cave mouth in a rock face.
static func _cave() -> Array:
	var c := canvas(54, 38)
	ell(c, 27, 24, 26, 12, "s")
	ell(c, 27, 17, 23, 16, "s")
	ell(c, 30, 19, 17, 12, "S")
	ell(c, 27, 16, 23, 15, "s")
	rect(c, 0, 28, 54, 10, ".")
	rect(c, 3, 28, 48, 7, "s")
	rect(c, 3, 34, 48, 3, "S")
	ell(c, 27, 28, 10, 13, "d")
	rect(c, 17, 28, 20, 8, "d")
	rect(c, 23, 34, 8, 3, "S")
	for p: Array in [[10, 10], [38, 8], [15, 5], [42, 15]]:
		rect(c, p[0], p[1], 5, 2, "v")
	return c


## GFX-095: a dark clump of tree crowns with a narrow earth path into a gap.
static func _woods() -> Array:
	var c := canvas(54, 38)
	rect(c, 0, 30, 54, 8, "v")
	ell(c, 14, 18, 13, 12, "v")
	ell(c, 40, 17, 13, 12, "v")
	ell(c, 27, 12, 14, 11, "v")
	for p: Array in [[8, 22], [20, 18], [34, 22], [44, 20], [24, 8]]:
		ell(c, p[0], p[1], 5, 3, "S")
	for p: Array in [[10, 12], [30, 6], [42, 10], [18, 14]]:
		rect(c, p[0], p[1], 4, 2, "v")
	rect(c, 22, 26, 10, 12, "e")
	rect(c, 25, 20, 4, 6, "e")
	rect(c, 25, 14, 4, 6, "d")
	rect(c, 4, 34, 46, 3, "v")
	rect(c, 22, 34, 10, 4, "e")
	return c


## GFX-095: broken wall stubs, a fallen pillar and a torn banner.
static func _ruins() -> Array:
	var c := canvas(54, 38)
	box(c, 3, 18, 12, 16, "s", "S")
	box(c, 18, 24, 14, 10, "s", "S")
	box(c, 36, 14, 11, 20, "s", "S")
	for p: Array in [[5, 21], [9, 26], [20, 27], [38, 18], [41, 24]]:
		rect(c, p[0], p[1], 3, 1, "S")
	rect(c, 4, 16, 4, 2, "s")
	rect(c, 38, 12, 3, 2, "s")
	box(c, 12, 33, 24, 4, "s", "S")
	rect(c, 14, 34, 2, 1, "w")
	rect(c, 27, 4, 2, 24, "t")
	rect(c, 29, 5, 9, 7, "r")
	rect(c, 29, 11, 5, 3, "r")
	rect(c, 29, 5, 9, 1, "h")
	rect(c, 0, 36, 54, 2, "e")
	return c


## GFX-095: a dark water patch ringed with reed stalks.
static func _reeds() -> Array:
	var c := canvas(54, 38)
	ell(c, 27, 28, 22, 8, "e")
	ell(c, 27, 28, 18, 6, "d")
	for x: int in [4, 8, 12, 15, 38, 42, 46, 50, 22, 32]:
		var top := 8 + (x * 7) % 11
		rect(c, x, top, 1, 36 - top, "v")
		rect(c, x - 1, top - 3, 3, 4, "t")
	rect(c, 0, 36, 54, 2, "v")
	return c


## GFX-095: jagged grey crags with a thin trail between them.
static func _ridge() -> Array:
	var c := canvas(54, 38)
	for spec: Array in [[2, 14, 16], [18, 4, 18], [36, 10, 16]]:
		var x0: int = spec[0]
		var top: int = spec[1]
		var w: int = spec[2]
		for y in range(top, 36):
			var inset := clampi(w / 2 + 2 - (y - top) * 2 / 3, 0, w / 2)
			rect(c, x0 + inset, y, w - 2 * inset, 1, "s")
		rect(c, x0 + w / 2, top + 2, w / 2 - 1, 34 - top, "S")
		rect(c, x0 + w / 2 - 1, top, 2, 3, "s")
	rect(c, 0, 33, 54, 5, ".")
	rect(c, 12, 30, 30, 8, "s")
	rect(c, 24, 28, 6, 2, "e")
	rect(c, 22, 30, 10, 3, "e")
	rect(c, 20, 33, 14, 5, "e")
	rect(c, 10, 34, 6, 3, "S")
	return c


## GFX-095: a trail marker post with a sign board beside a worn path patch and two shrubs.
static func _trail() -> Array:
	var c := canvas(54, 38)
	ell(c, 30, 31, 22, 5, "e")
	rect(c, 8, 33, 38, 2, "e")
	rect(c, 14, 6, 3, 28, "t")
	rect(c, 16, 6, 1, 28, "T")
	box(c, 6, 8, 18, 8, "t", "T")
	rect(c, 8, 10, 14, 1, "p")
	rect(c, 8, 12, 9, 1, "p")
	rect(c, 20, 18, 14, 6, "t")
	rect(c, 22, 20, 10, 1, "p")
	ell(c, 40, 26, 6, 5, "v")
	ell(c, 47, 29, 5, 4, "v")
	rect(c, 0, 36, 54, 2, "v")
	return c


## A tall carved stone stele on a stepped base, glowing gold characters.
static func _stele() -> Array:
	var c := canvas(44, 32)
	box(c, 6, 26, 32, 6, "s", "S")
	box(c, 11, 22, 22, 5, "s", "S")
	box(c, 15, 2, 14, 21, "s", "S")
	rect(c, 17, 0, 10, 3, "s")
	rect(c, 15, 2, 14, 1, "W")
	for y in [7, 12, 17]:
		rect(c, 18, y, 8, 1, "g")
		rect(c, 20, y + 2, 4, 1, "g")
	return c


## A hermit's cave dwelling: a rock mound with a plank door and a paper window.
static func _dwelling() -> Array:
	var c := canvas(48, 36)
	ell(c, 24, 24, 23, 13, "s")
	ell(c, 24, 18, 20, 16, "s")
	ell(c, 28, 20, 15, 12, "S")
	ell(c, 24, 17, 19, 15, "s")
	rect(c, 0, 30, 48, 6, ".")
	rect(c, 3, 30, 42, 5, "s")
	rect(c, 3, 34, 42, 2, "S")
	box(c, 19, 20, 10, 15, "t", "T")
	rect(c, 23, 24, 2, 10, "T")
	rect(c, 9, 22, 6, 5, "p")
	rect(c, 9, 24, 6, 1, "d")
	rect(c, 34, 20, 4, 2, "v")
	rect(c, 8, 8, 4, 2, "v")
	return c


## A swirling ring of light; `active` (a realm is open) fills the middle with bright qi.
static func _rift(active: bool) -> Array:
	var c := canvas(48, 38)
	ell(c, 24, 19, 23, 18, "R")
	ell(c, 24, 19, 21, 16, "r")
	ell(c, 24, 19, 16, 12, "R")
	ell(c, 24, 19, 12, 9, "d")
	for p: Array in [[4, 14], [8, 6], [16, 1], [30, 1], [40, 8], [42, 20], [36, 31], [20, 35], [8, 29]]:
		rect(c, p[0], p[1], 3, 2, "h")
	if active:
		ell(c, 24, 19, 8, 6, "h")
		ell(c, 24, 19, 4, 3, "p")
	else:
		ell(c, 24, 19, 3, 2, "S")
	return c


## A grassy hillock split by a dark jagged crack; open, the crack glows and sparks drift out.
static func _realm_cleft(active: bool) -> Array:
	var c := canvas(48, 38)
	ell(c, 24, 26, 23, 12, "s")
	ell(c, 24, 20, 19, 15, "s")
	ell(c, 29, 23, 13, 11, "S")
	ell(c, 24, 18, 18, 13, "s")
	rect(c, 8, 6, 28, 3, "v")
	rect(c, 14, 4, 16, 2, "v")
	rect(c, 4, 30, 40, 2, "v")
	rect(c, 22, 6, 3, 5, "d")
	rect(c, 20, 11, 4, 6, "d")
	rect(c, 23, 16, 4, 6, "d")
	rect(c, 21, 21, 4, 7, "d")
	rect(c, 19, 27, 5, 6, "d")
	if active:
		rect(c, 23, 8, 1, 3, "h")
		rect(c, 21, 12, 2, 4, "p")
		rect(c, 24, 17, 2, 4, "h")
		rect(c, 22, 22, 2, 5, "p")
		rect(c, 20, 28, 3, 4, "h")
		for q: Array in [[14, 3], [32, 5], [38, 13], [10, 12]]:
			rect(c, q[0], q[1], 2, 2, "r")
	else:
		rect(c, 22, 18, 1, 3, "S")
	return c


## A round stone lid set in a ring of rubble, carved with a cross of runes.
static func _realm_seal(active: bool) -> Array:
	var c := canvas(48, 36)
	ell(c, 24, 18, 23, 17, "S")
	for q: Array in [[2, 14], [6, 6], [14, 1], [32, 1], [41, 7], [43, 20], [38, 29], [10, 29], [3, 23]]:
		rect(c, q[0], q[1], 4, 3, "s")
	ell(c, 24, 18, 19, 14, "s")
	ell(c, 25, 19, 17, 12, "S")
	ell(c, 24, 18, 17, 12, "s")
	rect(c, 23, 8, 2, 20, "r" if not active else "h")
	rect(c, 12, 17, 24, 2, "r" if not active else "h")
	rect(c, 20, 9, 8, 1, "r")
	rect(c, 20, 27, 8, 1, "r")
	rect(c, 13, 14, 1, 8, "r")
	rect(c, 34, 14, 1, 8, "r")
	if active:
		ell(c, 24, 18, 3, 2, "p")
		rect(c, 8, 18, 3, 1, "p")
		rect(c, 37, 18, 3, 1, "p")
	else:
		rect(c, 7, 18, 3, 1, "S")
	return c


## Two stone pillars and a lintel half sunk in dark water, a dark doorway between them.
static func _realm_gate(active: bool) -> Array:
	var c := canvas(48, 38)
	ell(c, 24, 31, 23, 6, "d")
	box(c, 7, 8, 8, 24, "s", "S")
	box(c, 33, 8, 8, 24, "s", "S")
	box(c, 4, 3, 40, 6, "s", "S")
	rect(c, 14, 9, 20, 22, "d")
	rect(c, 4, 3, 40, 1, "W")
	rect(c, 9, 12, 4, 1, "S")
	rect(c, 35, 16, 4, 1, "S")
	if active:
		rect(c, 17, 12, 14, 18, "p")
		rect(c, 20, 14, 8, 14, "h")
		rect(c, 18, 31, 12, 1, "p")
		rect(c, 10, 33, 6, 1, "h")
		rect(c, 32, 34, 6, 1, "h")
	else:
		rect(c, 22, 14, 4, 1, "S")
		rect(c, 10, 33, 6, 1, "S")
		rect(c, 32, 34, 6, 1, "S")
	return c


## A low earth mound with a stone door and two small guardian stones.
static func _realm_tomb(active: bool) -> Array:
	var c := canvas(48, 36)
	ell(c, 24, 28, 23, 10, "e")
	ell(c, 24, 22, 20, 15, "e")
	ell(c, 29, 24, 13, 11, "t")
	ell(c, 24, 21, 19, 14, "e")
	rect(c, 8, 8, 12, 2, "v")
	rect(c, 28, 7, 8, 2, "v")
	box(c, 17, 16, 14, 18, "s", "S")
	rect(c, 19, 18, 10, 14, "d")
	rect(c, 15, 14, 18, 3, "S")
	box(c, 5, 24, 6, 9, "s", "S")
	box(c, 37, 24, 6, 9, "s", "S")
	rect(c, 6, 22, 4, 2, "s")
	rect(c, 38, 22, 4, 2, "s")
	if active:
		rect(c, 19, 18, 10, 14, "h")
		rect(c, 21, 20, 6, 10, "p")
		rect(c, 17, 16, 4, 18, "s")
	else:
		rect(c, 23, 18, 2, 14, "S")
	return c


## A small tiered roof on four thin posts over a stone plinth; open, a bright orb hangs under it.
static func _realm_pavilion(active: bool) -> Array:
	var c := canvas(48, 40)
	box(c, 4, 32, 40, 6, "s", "S")
	rect(c, 8, 30, 32, 2, "s")
	for x in [10, 17, 29, 36]:
		rect(c, x, 15, 2, 15, "t")
	rect(c, 10, 15, 28, 1, "T")
	for i in 7:
		rect(c, 11 - i, 8 + i, 26 + i * 2, 1, "r")
		rect(c, 11 - i, 8 + i, 26 + i * 2, 1, "r")
	rect(c, 4, 14, 40, 1, "R")
	rect(c, 12, 1, 24, 3, "r")
	rect(c, 14, 4, 20, 4, "r")
	rect(c, 12, 3, 24, 1, "h")
	rect(c, 23, 0, 2, 2, "g")
	rect(c, 14, 7, 20, 1, "R")
	if active:
		ell(c, 24, 23, 6, 6, "h")
		ell(c, 24, 23, 3, 3, "p")
	else:
		ell(c, 24, 25, 2, 2, "S")
	return c


## A small tent, a ring of stones and a campfire.
static func _camp() -> Array:
	var c := canvas(30, 19)
	_roof_tent(c)
	rect(c, 20, 15, 8, 3, "s")
	rect(c, 21, 17, 6, 1, "S")
	rect(c, 22, 12, 4, 4, "g")
	rect(c, 23, 10, 2, 3, "h")
	rect(c, 21, 17, 6, 1, "t")
	return c


static func _roof_tent(c: Array) -> void:
	for i in 14:
		var half := i / 2 + 1
		rect(c, 9 - half, 2 + i, half * 2, 1, "r")
		rect(c, 9 - half, 2 + i, 1, 1, "h")
		rect(c, 9 + half - 1, 2 + i, 1, 1, "R")
	rect(c, 7, 12, 4, 4, "d")
	rect(c, 9, 0, 1, 3, "t")
