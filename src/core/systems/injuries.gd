class_name Injuries
extends RefCounted
## Injuries from failed breakthroughs and lost fights. They slow cultivation
## and weaken the character in combat until healed by time, a doctor or a pill.
## Stored as CharacterData.injuries {injury_id: days_left}; defined in data/injuries.json.


static func has_any(c: CharacterData) -> bool:
	return not c.injuries.is_empty()


## Inflicts an injury. Returns false if the id is unknown.
static func inflict(c: CharacterData, data: GameData, injury_id: String) -> bool:
	var def: Dictionary = data.injuries.get(injury_id, {})
	if def.is_empty():
		return false
	c.injuries[injury_id] = maxi(int(c.injuries.get(injury_id, 0)), int(def["heal_days"]))
	return true


## Maybe inflicts an injury from a source in injuries.json (e.g.
## "breakthrough_failure"). `scale` multiplies the base chance (e.g. the
## fraction of a month for per-month sources); a tempered body resists
## (BodyTempering.injury_resistance). Table entries with a min_realm only
## strike cultivators of that realm or above. Returns the injury id, or "" if spared.
static func roll(c: CharacterData, data: GameData, source: String, rng: RandomNumberGenerator, scale: float = 1.0) -> String:
	var src: Dictionary = data.injury_sources.get(source, {})
	# Entries with a min_realm above `c`'s realm are skipped (C-010).
	var table: Array = (src.get("table", []) as Array).filter(func(entry: Dictionary) -> bool:
		return not entry.has("min_realm") or c.realm_index >= data.realm_index_of(String(entry["min_realm"])))
	if table.is_empty():
		return ""
	var chance := (float(src.get("chance", 0.0)) - (c.attribute("fortune") - 10) * data.injury_fortune_step) * scale
	chance *= 1.0 - BodyTempering.injury_resistance(c, data)
	if rng.randf() >= chance:
		return ""
	var weights := PackedFloat32Array()
	for entry in table:
		weights.append(float(entry.get("weight", 1)))
	var injury_id: String = table[rng.rand_weighted(weights)]["id"]
	inflict(c, data, injury_id)
	return injury_id


## Removes one injury, or every injury with "all". Returns the ids healed.
static func heal(c: CharacterData, injury_id: String) -> PackedStringArray:
	var healed: PackedStringArray = []
	for id in c.injuries.keys():
		if injury_id == "all" or id == injury_id:
			healed.append(id)
			c.injuries.erase(id)
	return healed


## Lets `days` pass. Returns the ids that healed completely.
static func pass_days(c: CharacterData, days: int) -> PackedStringArray:
	var healed: PackedStringArray = []
	for id in c.injuries.keys():
		var left := int(c.injuries[id]) - days
		if left <= 0:
			c.injuries.erase(id)
			healed.append(id)
		else:
			c.injuries[id] = left
	return healed


static func cultivation_multiplier(c: CharacterData, data: GameData) -> float:
	return _product(c, data, "cultivation_mult")


static func combat_multiplier(c: CharacterData, data: GameData) -> float:
	return _product(c, data, "combat_mult")


static func _product(c: CharacterData, data: GameData, key: String) -> float:
	var mult := 1.0
	for id in c.injuries:
		mult *= float(data.injuries.get(id, {}).get(key, 1.0))
	return mult


static func injury_name(data: GameData, injury_id: String) -> String:
	return data.injuries.get(injury_id, {}).get("name", injury_id)


## One line per injury, e.g. "Broken Bones (heals in 1 month, 20 days)".
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for id in c.injuries:
		lines.append("%s (heals in %s)" % [injury_name(data, id), Calendar.format_duration(int(c.injuries[id]))])
	return lines
