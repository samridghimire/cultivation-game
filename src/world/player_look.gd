class_name PlayerLook
extends RefCounted
## Placeholder appearance of a character on the world map (VIS-001): robe color
## from the sect (sects.json robe_color), sash color from the alignment tier and
## an aura that grows with the cultivation realm. Pure: reads state, no nodes.

const ROGUE_ROBE := Color("6e5a46")
const SASH_COLORS := {
	"demonic": Color("c0182b"),
	"evil": Color("8a3a8a"),
	"neutral": Color("9a9a9a"),
	"virtuous": Color("8fd18f"),
	"righteous": Color("f2e3a0"),
}
## Aura color at the first cultivated realm and at MAX_AURA_RINGS and beyond.
const AURA_LOW := Color("9fe3ff")
const AURA_HIGH := Color("ffd76a")
const MAX_AURA_RINGS := 4


## {robe: Color, sash: Color, aura_rings: int, aura: Color}. Mortals have no aura.
static func of(c: CharacterData, data: GameData) -> Dictionary:
	var robe := ROGUE_ROBE
	if not c.is_rogue():
		var sect: SectDef = data.sects.get(String(c.sect.get("id", "")))
		if sect != null and sect.robe_color != "":
			robe = Color(sect.robe_color)
	var tier_id := String(Alignment.tier(c.alignment, data).get("id", "neutral"))
	var rings := mini(c.realm_index, MAX_AURA_RINGS)
	var t := 0.0 if rings <= 1 else float(rings - 1) / float(MAX_AURA_RINGS - 1)
	return {
		"robe": robe,
		"sash": SASH_COLORS.get(tier_id, SASH_COLORS["neutral"]),
		"aura_rings": rings,
		"aura": AURA_LOW.lerp(AURA_HIGH, t),
	}
