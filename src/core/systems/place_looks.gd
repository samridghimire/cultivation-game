class_name PlaceLooks
extends RefCounted
## The optional `look` of a deed_giver place in regions.json (GFX-018): parsing and validation.
## Keys: robe (hex), hair ("dark"/"grey"), style ("bun"/"long"/"hood"), child (bool), kind ("figure"/"camp").
## Pure data helpers, no node access.

const KEYS := ["robe", "hair", "style", "child", "kind"]
const HAIR := {"dark": Color("2a2018"), "grey": Color("b8b8b8")}
const STYLES := ["bun", "long", "hood"]
const KINDS := ["figure", "camp"]


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
