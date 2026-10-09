class_name Rumors
extends RefCounted
## Merchant gossip from data/rumors.json (RUMOR-001): lines told by "Hear rumors" that depend on
## the region, the player's realm and world flags. Deterministic: rotated by the day, no rng.


## Ids (sorted) of the rumors the character can hear in `region_id`.
static func eligible(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> Array[String]:
	var ids: Array[String] = []
	for r: Dictionary in data.rumors.values():
		if r.has("region") and String(r["region"]) != region_id:
			continue
		if r.has("min_realm") and c.realm_index < data.realm_index_of(String(r["min_realm"])):
			continue
		if r.has("requires_flag") and not flags.get(String(r["requires_flag"]), false):
			continue
		if r.has("blocked_by_flag") and flags.get(String(r["blocked_by_flag"]), false):
			continue
		ids.append(String(r["id"]))
	ids.sort()
	return ids


## Up to max_per_visit rumor texts, starting at day mod count and wrapping round.
static func lines(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, day: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var ids := eligible(c, data, flags, region_id)
	if ids.is_empty():
		return out
	var count := mini(int(data.rumor_rules["max_per_visit"]), ids.size())
	var start := posmod(day, ids.size())
	for i in count:
		out.append(String(data.rumors[ids[(start + i) % ids.size()]]["text"]))
	return out
