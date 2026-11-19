class_name QiMotes
extends RefCounted
## GFX-213: pure helpers for the qi motes that gather around a meditating player.

const MIN_COUNT := 12
const MAX_COUNT := 24
const HIGH_MULTIPLIER := 2.5
const FALLBACK := Color("f0d98a")


## Colours of the player's two strongest spiritual-root elements (the root-bar colours);
## a single pale gold when there is no root.
static func colors_for(c: CharacterData, data: GameData) -> Array[Color]:
	var out: Array[Color] = []
	if c == null:
		out.append(FALLBACK)
		return out
	var rows: Array[Dictionary] = []
	for e in data.root_elements:
		var v := int(c.spiritual_roots.get(e["id"], 0))
		if v > 0:
			rows.append({"id": String(e["id"]), "value": v})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["value"]) > int(b["value"]))
	for i in mini(2, rows.size()):
		out.append(CharacterSheet.ELEMENT_COLORS.get(rows[i]["id"], FALLBACK))
	if out.is_empty():
		out.append(FALLBACK)
	return out


## 12 motes at x1.0 (or less), 24 at x2.5 and up, linear between.
static func count_for(multiplier: float) -> int:
	var t := clampf((multiplier - 1.0) / (HIGH_MULTIPLIER - 1.0), 0.0, 1.0)
	return MIN_COUNT + int(round(t * (MAX_COUNT - MIN_COUNT)))


## Position of mote `i` of `n` at gather phase `phase` (0..1, 1 = at the body): it drifts in from RADIUS.
const RADIUS := 60.0

static func mote_offset(i: int, n: int, phase: float) -> Vector2:
	var angle := TAU * float(i) / float(maxi(n, 1)) + float(i % 3) * 0.7
	var dist := RADIUS * (1.0 - clampf(phase, 0.0, 1.0)) + 6.0
	return Vector2.from_angle(angle) * dist * Vector2(1.0, 0.8)
