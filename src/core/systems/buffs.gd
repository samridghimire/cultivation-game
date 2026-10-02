class_name Buffs
extends RefCounted
## Temporary combat buffs (e.g. from forbidden secret arts). Stored on
## CharacterData.buffs as {buff_id: {"name", "days", "mults": {stat: fraction}}};
## each mult adds that fraction to a combat stat (attack 0.5 = +50% attack).
## Re-applying a buff refreshes it instead of stacking.

const STAT_KEYS: PackedStringArray = ["attack", "defense", "max_hp", "speed"]


## Adds or refreshes buff `id` for `days`. Returns false for a non-positive duration.
static func add(c: CharacterData, id: String, buff_name: String, days: int, mults: Dictionary) -> bool:
	if days <= 0:
		return false
	var clean := {}
	for key in mults:
		clean[String(key)] = float(mults[key])
	c.buffs[id] = {"name": buff_name, "days": days, "mults": clean}
	return true


static func has_any(c: CharacterData) -> bool:
	return not c.buffs.is_empty()


## Combat multiplier on `key` from every active buff (1.0 = none).
static func multiplier(c: CharacterData, key: String) -> float:
	var total := 1.0
	for buff: Dictionary in c.buffs.values():
		total += float(buff.get("mults", {}).get(key, 0.0))
	return maxf(total, 0.0)


## Counts buffs down by `days`. Returns the names of buffs that wore off.
static func pass_days(c: CharacterData, days: int) -> PackedStringArray:
	var expired: PackedStringArray = []
	for id in c.buffs.keys():
		var buff: Dictionary = c.buffs[id]
		buff["days"] = int(buff["days"]) - days
		if int(buff["days"]) <= 0:
			expired.append(String(buff.get("name", id)))
			c.buffs.erase(id)
	return expired


## "+80% attack, +30% speed" for a mults dictionary.
static func describe_mults(mults: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in STAT_KEYS:
		if mults.has(key):
			parts.append("%+d%% %s" % [roundi(float(mults[key]) * 100), key.replace("max_hp", "health")])
	return ", ".join(parts)


## One line per active buff: "Blood Demon Rage: +80% attack (12 days left)".
static func describe(c: CharacterData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for buff: Dictionary in c.buffs.values():
		lines.append("%s: %s (%s left)" % [buff.get("name", ""), describe_mults(buff.get("mults", {})), Calendar.format_duration(int(buff["days"]))])
	return lines
