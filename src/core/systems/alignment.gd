class_name Alignment
extends RefCounted
## The righteous <-> demonic moral axis.


static func tier(value: int, data: GameData) -> Dictionary:
	var result: Dictionary = data.alignment_tiers[0] if not data.alignment_tiers.is_empty() else {}
	for t in data.alignment_tiers:
		if value >= int(t["min"]):
			result = t
	return result


static func tier_name(value: int, data: GameData) -> String:
	return tier(value, data).get("name", "Unknown")


## Shifts alignment, clamped to the data-defined range. Returns the new value.
static func shift(c: CharacterData, data: GameData, delta: int) -> int:
	c.alignment = clampi(c.alignment + delta, data.alignment_min, data.alignment_max)
	return c.alignment
