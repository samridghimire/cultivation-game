class_name Dao
extends RefCounted
## Dao insights (data/dao.json): comprehension of the laws behind techniques.
## Stored as CharacterData.dao {insight_id: {"level": int, "progress": float}}.
## Each level strengthens matching techniques and every breakthrough attempt.


static func def_of(data: GameData, insight_id: String) -> Dictionary:
	return data.dao_insights.get(insight_id, {})


static func level(c: CharacterData, insight_id: String) -> int:
	return int(c.dao.get(insight_id, {}).get("level", 0))


static func progress(c: CharacterData, insight_id: String) -> float:
	return float(c.dao.get(insight_id, {}).get("progress", 0.0))


static func max_level(data: GameData) -> int:
	return int(data.dao.get("max_level", 5))


## Progress needed to go from the current level to the next (0 at max level).
static func progress_needed(c: CharacterData, data: GameData, insight_id: String) -> float:
	var lvl := level(c, insight_id)
	var table: Array = data.dao.get("progress_needed", [])
	if lvl >= max_level(data) or table.is_empty():
		return 0.0
	return float(table[mini(lvl, table.size() - 1)])


## Chance that a Comprehension check succeeds.
static func check_chance(c: CharacterData, data: GameData) -> float:
	var check: Dictionary = data.dao.get("check", {})
	var chance := float(check.get("base", 0.4)) + (c.attribute("comprehension") - 10) * float(check.get("per_comprehension", 0.03))
	return clampf(chance, float(check.get("min", 0.05)), float(check.get("max", 0.95)))


## True if the insight strengthens the technique (shared element or listed id).
static func matches(insight: Dictionary, tech: TechniqueDef) -> bool:
	if tech == null:
		return false
	if insight.get("techniques", []).has(tech.id):
		return true
	return tech.element != "" and insight.get("elements", []).has(tech.element)


## Multiplier on a technique's bonuses from insights ({insight_id: level} or CharacterData.dao).
static func technique_multiplier(dao: Dictionary, data: GameData, tech: TechniqueDef) -> float:
	var mult := 1.0
	for insight_id in dao:
		var insight := def_of(data, insight_id)
		if matches(insight, tech):
			mult += float(insight.get("technique_bonus", 0.0)) * int(dao[insight_id].get("level", 0))
	return mult


## Added to every breakthrough chance.
static func breakthrough_bonus(c: CharacterData, data: GameData) -> float:
	var total := 0.0
	for insight_id in c.dao:
		total += float(def_of(data, insight_id).get("breakthrough_bonus", 0.0)) * level(c, insight_id)
	return total


## Grants `levels` insight levels at once (sudden enlightenment), keeping progress.
## Returns the levels actually gained (capped at max level, 0 for unknown ids).
static func gain_levels(c: CharacterData, data: GameData, insight_id: String, levels: int = 1) -> int:
	if def_of(data, insight_id).is_empty() or levels <= 0:
		return 0
	var gained := mini(levels, max_level(data) - level(c, insight_id))
	if gained <= 0:
		return 0
	_entry(c, insight_id)["level"] = level(c, insight_id) + gained
	if level(c, insight_id) >= max_level(data):
		c.dao[insight_id]["progress"] = 0.0
	return gained


## Adds progress and rolls Comprehension checks while enough has built up.
## Returns the levels gained.
static func add_progress(c: CharacterData, data: GameData, insight_id: String, amount: float, rng: RandomNumberGenerator) -> int:
	if def_of(data, insight_id).is_empty() or amount <= 0.0 or level(c, insight_id) >= max_level(data):
		return 0
	var entry := _entry(c, insight_id)
	entry["progress"] = float(entry["progress"]) + amount
	var gained := 0
	while level(c, insight_id) < max_level(data) and float(entry["progress"]) >= progress_needed(c, data, insight_id):
		var needed := progress_needed(c, data, insight_id)
		if rng.randf() < check_chance(c, data):
			entry["progress"] = float(entry["progress"]) - needed
			entry["level"] = int(entry["level"]) + 1
			gained += 1
		else:
			entry["progress"] = float(entry["progress"]) * float(data.dao.get("failure_keep", 0.5))
			break
	if level(c, insight_id) >= max_level(data):
		entry["progress"] = 0.0
	return gained


## Practicing a technique for `days` builds progress toward every matching insight.
## Returns {insight_id: levels gained} for insights that gained a level.
static func on_practice(c: CharacterData, data: GameData, tech_id: String, days: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var tech: TechniqueDef = data.techniques.get(tech_id)
	for insight_id in data.dao_insights:
		if matches(data.dao_insights[insight_id], tech):
			var gained := add_progress(c, data, insight_id, float(days), rng)
			if gained > 0:
				out[insight_id] = gained
	return out


## Returns "" if `c` can contemplate the insight in seclusion, otherwise the reason not.
static func check_contemplate(c: CharacterData, data: GameData, insight_id: String) -> String:
	var insight := def_of(data, insight_id)
	if insight.is_empty():
		return "There is no such Dao."
	if level(c, insight_id) <= 0:
		return "You have not yet glimpsed the %s." % insight["name"]
	if level(c, insight_id) >= max_level(data):
		return "You have fully comprehended the %s." % insight["name"]
	return ""


## Contemplates an insight in seclusion for `days`. Returns {ok, reason, levels}.
static func contemplate(c: CharacterData, data: GameData, insight_id: String, days: int, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check_contemplate(c, data, insight_id)
	if reason != "":
		return {"ok": false, "reason": reason, "levels": 0}
	var amount := days * float(data.dao.get("seclusion_mult", 2.0))
	return {"ok": true, "reason": "", "levels": add_progress(c, data, insight_id, amount, rng)}


## e.g. ["Sword Dao 2/5 (+24% metal arts)"] for the character sheet.
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for insight_id in c.dao:
		var insight := def_of(data, insight_id)
		if insight.is_empty() or level(c, insight_id) <= 0:
			continue
		lines.append("%s %d/%d (+%d%% to its arts)" % [insight["name"], level(c, insight_id), max_level(data), roundi(float(insight.get("technique_bonus", 0.0)) * level(c, insight_id) * 100)])
	return lines


## Insight ids the character has glimpsed (level >= 1), in data order.
static func known_ids(c: CharacterData, data: GameData) -> Array[String]:
	var ids: Array[String] = []
	for insight_id in data.dao_insights:
		if level(c, insight_id) > 0:
			ids.append(String(insight_id))
	return ids


## e.g. "34/120 toward level 3", or "fully comprehended" at max level.
static func progress_text(c: CharacterData, data: GameData, insight_id: String) -> String:
	var needed := progress_needed(c, data, insight_id)
	if needed <= 0.0:
		return "fully comprehended"
	return "%d/%d toward level %d" % [int(progress(c, insight_id)), int(needed), level(c, insight_id) + 1]


## Load errors for data/dao.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.dao_insights.is_empty():
		return errors
	var table: Array = data.dao.get("progress_needed", [])
	if max_level(data) < 1 or table.is_empty() or table.any(func(v) -> bool: return float(v) <= 0.0):
		errors.append("dao.json needs max_level >= 1 and positive progress_needed")
	var element_ids: Array = data.root_elements.map(func(e): return e["id"])
	for insight: Dictionary in data.dao_insights.values():
		for element in insight.get("elements", []):
			if not element_ids.has(element):
				errors.append("Dao insight '%s' has unknown element '%s'" % [insight["id"], element])
		for tech_id in insight.get("techniques", []):
			if not data.techniques.has(tech_id):
				errors.append("Dao insight '%s' has unknown technique '%s'" % [insight["id"], tech_id])
	var effect_lists: Array = []
	for item: Dictionary in data.items.values():
		effect_lists.append(["Item '%s'" % item["id"], item.get("effects", {})])
	for enc: Dictionary in data.encounters.values():
		effect_lists.append(["Encounter '%s'" % enc["id"], enc.get("effects", {})])
		for choice: Dictionary in enc.get("choices", []):
			effect_lists.append(["Encounter '%s' choice" % enc["id"], choice.get("effects", {})])
	for pair in effect_lists:
		var insight_id: String = pair[1].get("dao_insight", "")
		if insight_id != "" and not data.dao_insights.has(insight_id):
			errors.append("%s grants unknown dao_insight '%s'" % [pair[0], insight_id])
	return errors


static func _entry(c: CharacterData, insight_id: String) -> Dictionary:
	if not c.dao.has(insight_id):
		c.dao[insight_id] = {"level": 0, "progress": 0.0}
	return c.dao[insight_id]
