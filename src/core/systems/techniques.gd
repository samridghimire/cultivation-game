class_name Techniques
extends RefCounted
## Learning, practicing and the stat bonuses of techniques.
## Known techniques are stored as CharacterData.techniques {id: {"level", "xp"}}.


static func level(c: CharacterData, tech_id: String) -> int:
	return int(c.techniques.get(tech_id, {}).get("level", 0))


static func knows(c: CharacterData, tech_id: String) -> bool:
	return c.techniques.has(tech_id)


## Returns "" if `c` can learn the technique, otherwise the reason not.
static func can_learn(c: CharacterData, data: GameData, tech_id: String) -> String:
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def == null:
		return "There is no such technique."
	if knows(c, tech_id):
		return "You already know the %s." % def.name
	var min_index := data.realm_index_of(def.min_realm)
	if c.realm_index < min_index:
		return "The %s requires the %s realm." % [def.name, data.realms[min_index].name]
	return ""


## Returns {ok, reason}.
static func learn(c: CharacterData, data: GameData, tech_id: String) -> Dictionary:
	var reason := can_learn(c, data, tech_id)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.techniques[tech_id] = {"level": 1, "xp": 0.0}
	return {"ok": true, "reason": ""}


static func xp_per_day(c: CharacterData) -> float:
	return 0.5 + c.attribute("comprehension") / 20.0


## Practice xp still needed for the next level (0 at max level or unknown).
static func xp_to_next(c: CharacterData, data: GameData, tech_id: String) -> float:
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def == null or not knows(c, tech_id) or level(c, tech_id) >= def.max_level:
		return 0.0
	return def.xp_to_next(level(c, tech_id)) - float(c.techniques[tech_id]["xp"])


static func is_mastered(c: CharacterData, data: GameData, tech_id: String) -> bool:
	var def: TechniqueDef = data.techniques.get(tech_id)
	return def != null and level(c, tech_id) >= def.max_level


## Practice for `days`. Returns {ok, reason, xp, levels_gained}.
static func practice(c: CharacterData, data: GameData, tech_id: String, days: int) -> Dictionary:
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def == null or not knows(c, tech_id):
		return {"ok": false, "reason": "You do not know that technique.", "xp": 0.0, "levels_gained": 0}
	if is_mastered(c, data, tech_id):
		return {"ok": false, "reason": "You have already mastered the %s." % def.name, "xp": 0.0, "levels_gained": 0}
	var entry: Dictionary = c.techniques[tech_id]
	var gained := xp_per_day(c) * days
	entry["xp"] = float(entry["xp"]) + gained
	var levels := 0
	while int(entry["level"]) < def.max_level and float(entry["xp"]) >= def.xp_to_next(int(entry["level"])):
		entry["xp"] = float(entry["xp"]) - def.xp_to_next(int(entry["level"]))
		entry["level"] = int(entry["level"]) + 1
		levels += 1
	if int(entry["level"]) >= def.max_level:
		entry["xp"] = 0.0
	return {"ok": true, "reason": "", "xp": gained, "levels_gained": levels}


## How strongly a technique works for someone with these roots. Techniques
## without an element, and characters without roots data (enemies), get 1.0.
static func element_factor(def: TechniqueDef, roots: Dictionary, data: GameData) -> float:
	if def.element == "" or roots.is_empty():
		return 1.0
	if roots.has(def.element):
		return 1.0 + data.technique_affinity_bonus
	return 1.0 - data.technique_mismatch_penalty


## Total of one bonus key over `levels` ({tech_id: level}).
static func bonus_from(levels: Dictionary, roots: Dictionary, data: GameData, key: String) -> float:
	var total := 0.0
	for tech_id in levels:
		var def: TechniqueDef = data.techniques.get(tech_id)
		if def == null:
			continue
		total += float(def.bonuses.get(key, 0.0)) * int(levels[tech_id]) * element_factor(def, roots, data)
	return total


## Total of one bonus key (qi_mult, attack, defense, max_hp, speed) over everything `c` knows.
static func bonus(c: CharacterData, data: GameData, key: String) -> float:
	return bonus_from(levels_of(c), c.spiritual_roots, data, key)


static func levels_of(c: CharacterData) -> Dictionary:
	var out := {}
	for tech_id in c.techniques:
		out[tech_id] = level(c, tech_id)
	return out


## Multiplier on qi gathered while cultivating.
static func cultivation_multiplier(c: CharacterData, data: GameData) -> float:
	return 1.0 + bonus(c, data, "qi_mult")


## e.g. "+12% cultivation speed, +6 attack" at the character's current level
## (or level 1 if the technique is not known yet).
static func describe_bonuses(c: CharacterData, data: GameData, tech_id: String) -> String:
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def == null:
		return ""
	var lvl := maxi(level(c, tech_id), 1)
	var factor := element_factor(def, c.spiritual_roots, data)
	var parts: PackedStringArray = []
	for key in TechniqueDef.BONUS_KEYS:
		if not def.bonuses.has(key):
			continue
		var value: float = def.bonuses[key] * lvl * factor
		if key == "qi_mult":
			parts.append("%+d%% cultivation speed" % roundi(value * 100))
		else:
			parts.append("%+d %s" % [roundi(value), key.replace("max_hp", "health")])
	return ", ".join(parts)
