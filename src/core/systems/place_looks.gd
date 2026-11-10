class_name PlaceLooks
extends RefCounted
## The optional `look` of a deed_giver place in regions.json (GFX-018): parsing and validation.
## Keys: robe (hex), hair ("dark"/"grey"), style ("bun"/"long"/"hood"), child (bool), kind ("figure"/"camp").
## Pure data helpers, no node access.

const KEYS := ["robe", "hair", "style", "child", "kind"]
const HAIR := {"dark": Color("2a2018"), "grey": Color("b8b8b8")}
const STYLES := ["bun", "long", "hood"]
const KINDS := ["figure", "camp"]
## Explore-place looks (regions.json `look` on explore places); PixelPlace draws one picture for each.
const EXPLORE_LOOKS := ["cave", "woods", "ruins", "reeds", "ridge", "trail"]
## WU-506: the scene an encounter happens in: its own `scene`, else the explore place's look, else the region's
## `map.wild_look`, else "village". Unknown values are skipped. Pure.
const VILLAGE_SCENE := "village"


static func scene_look(enc_scene: String, explore_look: String, wild_look: String) -> String:
	for candidate: String in [enc_scene, explore_look, wild_look]:
		if EXPLORE_LOOKS.has(candidate) or candidate == VILLAGE_SCENE:
			return candidate
	return VILLAGE_SCENE


## Gather-place looks (GFX-102, regions.json `look` on gather places); "patch" is the original herb bed.
const GATHER_LOOKS := ["patch", "rubble", "crater", "crystal", "frost", "terrace", "bog"]
## Pond water kinds (GFX-103, regions.json `map.water`); "clear" is the original blue pond.
const WATER_KINDS := ["clear", "murky", "icy"]
## The water colour of a pond landmark without its own `color`.
const WATER_TINTS := {"clear": "3f7fa8", "murky": "3a4a2c", "icy": "bcd8ea"}
## Secret-realm entrance looks (GFX-098); "rift" is the original ring.
const REALM_LOOKS := ["rift", "cleft", "seal", "gate", "tomb", "pavilion"]
## Region building styles (regions.json `map.building_style`, GFX-100); PixelPlace.STYLE_COLORS colours each.
const BUILDING_STYLES := ["thatch", "tile", "stone", "stilt", "log"]


## Error strings for `look` (empty when valid); `who` names the place in messages.
static func errors(look: Variant, who: String) -> Array[String]:
	var out: Array[String] = []
	if not look is Dictionary:
		out.append("%s: look must be an object" % who)
		return out
	var d: Dictionary = look
	for key in d:
		if not KEYS.has(key):
			out.append("%s: unknown look key '%s'" % [who, key])
	if d.has("robe") and not (d["robe"] is String and String(d["robe"]).is_valid_html_color()):
		out.append("%s: look.robe must be a hex colour" % who)
	if d.has("hair") and not HAIR.has(d["hair"]):
		out.append("%s: look.hair must be one of %s" % [who, HAIR.keys()])
	if d.has("style") and not STYLES.has(d["style"]):
		out.append("%s: look.style must be one of %s" % [who, STYLES])
	if d.has("child") and not d["child"] is bool:
		out.append("%s: look.child must be true or false" % who)
	if d.has("kind") and not KINDS.has(d["kind"]):
		out.append("%s: look.kind must be one of %s" % [who, KINDS])
	return out


## A PixelFigure look ({robe, hair, style, child}) with defaults: robe = the place colour.
static func figure_look(look: Dictionary, place_color: Color) -> Dictionary:
	var out := {"robe": place_color, "sash": Color("9a9a9a"), "style": "bun", "child": false}
	if look.has("robe") and String(look["robe"]).is_valid_html_color():
		out["robe"] = Color(String(look["robe"]))
	if HAIR.has(look.get("hair", "")):
		out["hair"] = HAIR[look["hair"]]
	if STYLES.has(look.get("style", "")):
		out["style"] = look["style"]
	out["child"] = look.get("child", false) == true
	return out


## Whether the place is drawn as a camp (tent and fire) instead of a person.
static func is_camp(look: Dictionary) -> bool:
	return look.get("kind", "figure") == "camp"
