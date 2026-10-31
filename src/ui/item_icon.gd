class_name ItemIcon
extends RefCounted
## Generated 12x12 pixel item glyphs (GFX-019) for inventory, shop and crafting rows, until the icon pack lands.
## A Sprites key "icon_<item id>" then "icon_<kind>" overrides the generated glyph.

const SIZE := 12
const ZOOM := 2
const OUTLINE := Color("1c1612")
const TINTS: Array[Color] = [Color("d9534f"), Color("e8b04a"), Color("6cc070"), Color("56a6d8"), Color("b07ad8"), Color("e8e0cc")]

## Glyph rows: 'o' outline, 'a' body (tinted per item for pills and herbs), 'b' highlight, '.' empty.
const GLYPHS := {
	"pill": ["............", "....oooo....", "...oabbao...", "..oabaaaao..", "..obaaaaao..", "..oaaaaaao..", "..oaaaaaao..", "...oaaaao...", "....oooo....", "............", "............", "............"],
	"herb": ["............", "......oo....", ".....oaao...", "..oo.oabo...", ".oaao.oao...", ".oabaooao...", "..oaaaao....", "...oaao.....", "....oao.....", "....oao.....", "....ooo.....", "............"],
	"ore": ["............", "............", "....ooo.....", "...oabbo....", "..oabaaoo...", ".oabaaaabo..", ".oaaaaaaao..", ".oaaaaaaaao.", "..oooaaaaoo.", ".....oooo...", "............", "............"],
	"beast_material": ["............", "...oo..oo...", "..oaao.oao..", "..oabaooao..", "...oaaaao...", "....oaao....", "...oabbao...", "..oabaaao...", "...oaaao....", "....ooo.....", "............", "............"],
	"spirit_stone": ["............", "....oooo....", "...obbbao...", "..obbaaaao..", "..oabaaaao..", "..oaaaaaao..", "...oaaaao...", "....oaao....", ".....oo.....", "............", "............", "............"],
	"weapon": ["..........oo", ".........oao", "........oabo", ".......oabo.", "......oabo..", "..o..oabo...", "..oooabo....", "...oabo.....", "..ooaoo.....", ".obo.oo.....", ".oo.........", "............"],
	"armor": ["............", "..oo....oo..", ".oaaooooaao.", ".oabaaaabao.", "..oaaaaaao..", "..oabaaabo..", "..oaaaaaao..", "..oaaaaaao..", "..oaaaaaao..", "...oaaaao...", "....oooo....", "............"],
	"accessory": ["............", "....oooo....", "...oaaaao...", "..oa....ao..", "..oa....ao..", "..oa....ao..", "...oaaaao...", "....oabo....", "....obao....", ".....oo.....", "............", "............"],
	"talisman": ["............", "...oooooo...", "...oaaaao...", "...oabbao...", "...oabbao...", "...oaaaao...", "...obaabo...", "...oaaaao...", "...oabbao...", "...oaaaao...", "...oooooo...", "............"],
	"manual": ["............", "..ooooooo...", ".oaaaaaaao..", ".oabbbbbao..", ".oaaaaaaao..", ".oabbbbbao..", ".oaaaaaaao..", ".oabbbbbao..", ".oaaaaaaao..", "..ooooooo...", "............", "............"],
	"scroll": ["............", ".ooooooooo..", "oabaaaaabo..", "oaaoooooao..", ".oaabbbaao..", ".oaaaaaaao..", ".oaabbbaao..", "oaaoooooao..", "oabaaaaabo..", ".ooooooooo..", "............", "............"],
	"fish": ["............", "............", "....oooo..o.", "..ooabaaoooo", ".oabaaaaaaao", ".oaaaoaaaaao", ".oaaaaaaaaao", "..oooaaaoooo", "....oooo..o.", "............", "............", "............"],
	"pouch": ["............", "....o..o....", "....oooo....", "...oabbao...", "..oaaaaaao..", ".oabaaaaaao.", ".oabaaaaaao.", ".oaaaaaaaao.", "..oaaaaaao..", "...oooooo...", "............", "............"],
}

const BODY := {
	"pill": Color("e8b04a"), "herb": Color("5aa65a"), "ore": Color("8a8f9c"), "beast_material": Color("c9b18a"),
	"spirit_stone": Color("7cc8e8"), "weapon": Color("b8c0cc"), "armor": Color("9a7a52"), "accessory": Color("d9a441"),
	"fish": Color("c88a5a"), "talisman": Color("e8d27a"), "manual": Color("8a5a3a"), "scroll": Color("e8dcc0"), "pouch": Color("a8784a"),
}

static var _cache: Dictionary = {}


## Glyph kind for an item definition (see GLYPHS).
static func kind_of(item: Dictionary) -> String:
	var tags: Array = item.get("tags", [])
	var effects: Dictionary = item.get("effects", {})
	if str(item.get("id", "")) == "spirit_stone":
		return "spirit_stone"
	if item.has("equip"):
		var slot := str((item["equip"] as Dictionary).get("slot", ""))
		return slot if slot in ["weapon", "accessory"] else "armor"
	if tags.has("talisman") or item.has("combat"):
		return "talisman"
	if effects.has("learn_recipe") or effects.has("learn_technique"):
		return "manual"
	if tags.has("scripture") or tags.has("inscription") or tags.has("formation"):
		return "scroll"
	if tags.has("fish"):
		return "fish"
	if tags.has("herb"):
		return "herb"
	if tags.has("ore"):
		return "ore"
	if tags.has("beast_material"):
		return "beast_material"
	if bool(item.get("usable", false)):
		return "pill"
	return "pouch"


## WU-417: the item's own `color` (html string) if it has one, else a stable hue from a hash of the id
## (fixed saturation/value so it reads on the dark slot).
static func tint_for(item_id: String, item: Dictionary) -> Color:
	if item.has("color") and str(item["color"]) != "":
		return Color(str(item["color"]))
	return Color.from_hsv(float(absi(item_id.hash()) % 360) / 360.0, 0.6, 0.85)


## The icon for an item: a Sprites override when present, else the generated glyph (cached per item id).
static func texture(item_id: String, item: Dictionary) -> Texture2D:
	var kind := kind_of(item)
	var override := Sprites.first(PackedStringArray(["icon_" + item_id, "icon_" + kind]))
	if override != null:
		return override
	if _cache.has(item_id):
		return _cache[item_id]
	var body: Color = BODY[kind]
	if kind == "pill" or kind == "herb":
		body = body.lerp(TINTS[absi(item_id.hash()) % TINTS.size()], 0.7)
	elif kind == "fish":
		body = tint_for(item_id, item)
	var palette := {"o": OUTLINE, "a": body, "b": body.lightened(0.45)}
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rows: Array = GLYPHS[kind]
	for y in SIZE:
		var row: String = rows[y]
		for x in SIZE:
			var ch := row.substr(x, 1)
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	img.resize(SIZE * ZOOM, SIZE * ZOOM, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[item_id] = tex
	return tex


## Icon for `item_id` from game data, or null when the id is unknown.
static func for_id(data: GameData, item_id: String) -> Texture2D:
	if not data.items.has(item_id):
		return null
	return texture(item_id, data.items[item_id])


## Gives a list button its icon (generated glyphs are already x2) with a nearest filter (focus and navigation are unchanged).
static func apply(b: Button, tex: Texture2D) -> void:
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = false
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("icon_max_width", SIZE * ZOOM)
