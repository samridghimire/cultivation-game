class_name Mentorship
extends RefCounted
## MENTOR-001: a stronger NPC who likes you points out a flaw in one of your
## techniques. Tunables live in data/family.json `mentorship`.


static func _rules(data: GameData, kind: String) -> Dictionary:
	return data.family.get("mentorship", {}).get(kind, {})


static func is_senior(c: CharacterData, npc: CharacterData) -> bool:
	return npc.realm_index > c.realm_index or (npc.realm_index == c.realm_index and npc.stage > c.stage)


## The technique `npc` would correct: one you both know (the NPC's highest
## level first), else your lowest-level unmastered one. "" when none.
static func pointer_technique(c: CharacterData, npc: CharacterData, data: GameData) -> String:
	var ids: Array = c.techniques.keys()
	ids.sort()
	var best := ""
	var best_shared := false
	var best_level := 0
	for tech_id: String in ids:
		if Techniques.is_mastered(c, data, tech_id):
			continue
		var shared := Techniques.knows(npc, tech_id)
		var lvl := Techniques.level(npc, tech_id) if shared else Techniques.level(c, tech_id)
		var better := best == ""
		if not better:
			if shared != best_shared:
				better = shared
			elif shared:
				better = lvl > best_level
			else:
				better = lvl < best_level
		if better:
			best = tech_id
			best_shared = shared
			best_level = lvl
	return best


## Days until `key` may be used again (0 = ready, also when never used).
static func cooldown_left(c: CharacterData, key: String, cooldown: int, today: int) -> int:
	if not c.npc_action_days.has(key):
		return 0
	return maxi(0, int(c.npc_action_days[key]) + cooldown - today)


static func check_pointers(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int) -> String:
	if npc == null or not npc.alive:
		return "They are not here."
	var rules := _rules(data, "pointers")
	if rules.is_empty():
		return "Nobody is offering pointers."
	if npc.age_years() < int(data.family.get("adult_age", 16)):
		return "%s is too young to teach anyone." % npc.name
	if not is_senior(c, npc):
		return "%s is no stronger than you; there is nothing to learn from them yet." % npc.name
	var min_favor := int(rules.get("min_favor", 0))
	if favor < min_favor:
		return "%s does not know you well enough (favor %d/%d)." % [npc.name, favor, min_favor]
	var left := cooldown_left(c, "pointers:" + npc.id, int(rules.get("cooldown_days", 0)), today)
	if left > 0:
		return "%s already pointed out your flaws recently (%d days)." % [npc.name, left]
	if pointer_technique(c, npc, data) == "":
		return "You have no technique they could correct."
	return ""


## Returns {ok, reason, tech_id, tech_name, shared, days, levels_gained}.
static func give_pointers(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int) -> Dictionary:
	var result := {"ok": false, "reason": "", "tech_id": "", "tech_name": "", "shared": false, "days": 0, "levels_gained": 0}
	result["reason"] = check_pointers(c, npc, favor, data, today)
	if result["reason"] != "":
		return result
	var rules := _rules(data, "pointers")
	var tech_id := pointer_technique(c, npc, data)
	var shared := Techniques.knows(npc, tech_id)
	var practice_days := int(float(rules.get("practice_days", 0)) * (float(rules.get("shared_multiplier", 1.0)) if shared else 1.0))
	var practiced := Techniques.practice(c, data, tech_id, practice_days)
	c.npc_action_days["pointers:" + npc.id] = today
	result["ok"] = true
	result["tech_id"] = tech_id
	result["tech_name"] = (data.techniques[tech_id] as TechniqueDef).name
	result["shared"] = shared
	result["days"] = int(rules.get("days", 1))
	result["levels_gained"] = int(practiced["levels_gained"])
	return result


## Load errors for data/family.json `mentorship`.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var block: Dictionary = data.family.get("mentorship", {})
	for kind in block:
		var rules: Dictionary = block[kind]
		for key in rules:
			if float(rules[key]) < 0.0:
				errors.append("family.json mentorship.%s.%s must be >= 0" % [kind, key])
		if int(rules.get("min_favor", 0)) > 100:
			errors.append("family.json mentorship.%s.min_favor must be <= 100" % kind)
	if block.has("pointers") and float(block["pointers"].get("shared_multiplier", 1.0)) < 1.0:
		errors.append("family.json mentorship.pointers.shared_multiplier must be >= 1")
	return errors
