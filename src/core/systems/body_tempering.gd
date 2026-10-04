class_name BodyTempering
extends RefCounted
## Body cultivation (BODY-001): stages of tempering from data/body_tempering.json
## (Copper Skin, Iron Bone, ...) reached in order alongside qi cultivation.
## CharacterData.body_stage counts the stages reached. Reached stages add
## combat stat fractions (Combat.stats) and resistance to injuries (Injuries.roll).

const STAT_KEYS := ["max_hp", "attack", "defense", "speed"]


static func stages(data: GameData) -> Array:
	return data.body_tempering.get("stages", [])


## The stage def `c` would temper next, or {} at the last stage.
static func next_stage(c: CharacterData, data: GameData) -> Dictionary:
	var all := stages(data)
	return all[c.body_stage] if c.body_stage < all.size() else {}


## Name of the highest stage reached, or "Untempered".
static func stage_name(c: CharacterData, data: GameData) -> String:
	var all := stages(data)
	if c.body_stage <= 0 or all.is_empty():
		return "Untempered"
	return String(all[mini(c.body_stage, all.size()) - 1].get("name", "?"))


## Sum of the reached stages' `key` bonus (a fraction, e.g. 0.16 = +16%).
static func bonus(c: CharacterData, data: GameData, key: String) -> float:
	var total := 0.0
	var all := stages(data)
	for i in mini(c.body_stage, all.size()):
		total += float(all[i].get("bonuses", {}).get(key, 0.0))
	return total


## Fraction by which every injury-source chance is reduced.
static func injury_resistance(c: CharacterData, data: GameData) -> float:
	var total := 0.0
	var all := stages(data)
	for i in mini(c.body_stage, all.size()):
		total += float(all[i].get("injury_resist", 0.0))
	return clampf(total, 0.0, float(data.body_tempering.get("max_injury_resist", 0.6)))


## Chance that tempering the next stage injures `c` (0 at the last stage).
static func risk(c: CharacterData, data: GameData) -> float:
	var stage := next_stage(c, data)
	if stage.is_empty():
		return 0.0
	var rules := data.body_tempering
	var chance := float(stage.get("risk", 0.0)) - (c.attribute("constitution") - 10) * float(rules.get("risk_per_constitution", 0.02))
	return clampf(chance, float(rules.get("min_risk", 0.02)), float(rules.get("max_risk", 0.9)))


## Why `c` cannot temper the next stage now, or "".
static func check_temper(c: CharacterData, data: GameData) -> String:
	var stage := next_stage(c, data)
	if stage.is_empty():
		return "Your body cannot be tempered further."
	var realm_id := String(stage.get("min_realm", ""))
	if realm_id != "" and c.realm_index < data.realm_index_of(realm_id):
		return "%s needs %s." % [stage["name"], data.realms[data.realm_index_of(realm_id)].name]
	if Injuries.has_any(c):
		return "Heal your injuries first."
	var missing: PackedStringArray = []
	var items: Dictionary = stage.get("items", {})
	for item_id in items:
		if c.item_count(item_id) < int(items[item_id]):
			missing.append(String(data.items.get(item_id, {}).get("name", item_id)))
	if not missing.is_empty():
		return "You lack %s." % ", ".join(missing)
	return ""


## Tempers the next stage: consumes its items, reaches the stage and maybe
## injures `c`. Returns {ok, reason, stage_id, name, days, injury ("" = unhurt)}.
static func temper(c: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check_temper(c, data)
	if reason != "":
		return {"ok": false, "reason": reason, "stage_id": "", "name": "", "days": 0, "injury": ""}
	var stage := next_stage(c, data)
	var chance := risk(c, data)
	var items: Dictionary = stage.get("items", {})
	for item_id in items:
		c.add_item(item_id, -int(items[item_id]))
	c.body_stage += 1
	var injury := ""
	if rng.randf() < chance:
		injury = _roll_injury(data, rng)
		Injuries.inflict(c, data, injury)
	return {"ok": true, "reason": "", "stage_id": String(stage["id"]), "name": String(stage["name"]), "days": int(stage.get("days", 0)), "injury": injury}


static func _roll_injury(data: GameData, rng: RandomNumberGenerator) -> String:
	var table: Array = data.body_tempering.get("injury_table", [])
	if table.is_empty():
		return ""
	var weights := PackedFloat32Array()
	for entry in table:
		weights.append(float(entry.get("weight", 1)))
	return String(table[rng.rand_weighted(weights)]["id"])


## Bonus summary, e.g. "+16% health, +18% defense, 15% injury resistance".
static func describe_bonuses(c: CharacterData, data: GameData) -> String:
	var parts: PackedStringArray = []
	var labels := {"max_hp": "health", "attack": "attack", "defense": "defense", "speed": "speed"}
	for key in STAT_KEYS:
		var value := bonus(c, data, key)
		if value != 0.0:
			parts.append("%+d%% %s" % [roundi(value * 100), labels[key]])
	var resist := injury_resistance(c, data)
	if resist > 0.0:
		parts.append("%d%% injury resistance" % roundi(resist * 100))
	return ", ".join(parts)


## Cost of the next stage, e.g. "2 months, Cold Iron 1/4, Iron Essence 6/6, 18% injury risk".
static func describe_next(c: CharacterData, data: GameData) -> String:
	var stage := next_stage(c, data)
	if stage.is_empty():
		return ""
	var parts: PackedStringArray = [Calendar.format_duration(int(stage.get("days", 0)))]
	var items: Dictionary = stage.get("items", {})
	for item_id in items:
		parts.append("%s %d/%d" % [data.items.get(item_id, {}).get("name", item_id), c.item_count(item_id), int(items[item_id])])
	parts.append("%d%% injury risk" % roundi(risk(c, data) * 100))
	return ", ".join(parts)


## Character sheet lines: current stage with bonuses, then the next stage and its cost.
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	var current := stage_name(c, data)
	var bonuses := describe_bonuses(c, data)
	lines.append(current + (" (%s)" % bonuses if bonuses != "" else ""))
	var stage := next_stage(c, data)
	if not stage.is_empty():
		var realm_id := String(stage.get("min_realm", ""))
		var gate := ""
		if realm_id != "" and c.realm_index < data.realm_index_of(realm_id):
			gate = ", needs %s" % data.realms[data.realm_index_of(realm_id)].name
		lines.append("Next: %s (%s%s)" % [stage["name"], describe_next(c, data), gate])
	return lines


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen := {}
	for stage: Dictionary in stages(data):
		var id := String(stage.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("Body tempering stage has a missing or duplicate id '%s'" % id)
		seen[id] = true
		if int(stage.get("days", 0)) <= 0:
			errors.append("Body tempering stage '%s' needs positive days" % id)
		if stage.has("min_realm") and data.realm_index_of(String(stage["min_realm"])) < 0:
			errors.append("Body tempering stage '%s' has unknown min_realm '%s'" % [id, stage["min_realm"]])
		for item_id in stage.get("items", {}):
			if not data.items.has(item_id):
				errors.append("Body tempering stage '%s' needs unknown item '%s'" % [id, item_id])
		for key in stage.get("bonuses", {}):
			if not STAT_KEYS.has(key):
				errors.append("Body tempering stage '%s' has unknown bonus '%s'" % [id, key])
	for entry: Dictionary in data.body_tempering.get("injury_table", []):
		if not data.injuries.has(String(entry.get("id", ""))):
			errors.append("Body tempering injury_table has unknown injury '%s'" % entry.get("id", ""))
	return errors
