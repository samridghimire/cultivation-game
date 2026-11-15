class_name Mentorship
extends RefCounted
## MENTOR-001: a stronger NPC who likes you points out a flaw in one of your
## techniques. Tunables live in data/family.json `mentorship`.


static func _rules(data: GameData, kind: String) -> Dictionary:
	return data.family.get("mentorship", {}).get(kind, {})


## What a friendly bout costs and is worth, straight from data/family.json (hints quote it).
static func spar_terms(data: GameData) -> Dictionary:
	var rules := _rules(data, "spar")
	return {"days": int(rules.get("days", 1)), "practice_days": int(rules.get("practice_days", 0)), "cooldown_days": int(rules.get("cooldown_days", 0))}


## Friendly bouts with the villager who taught you a fighting style (SPAR-001): rules in `mentorship.teacher_bout`.
static func teacher_bout_terms(data: GameData) -> Dictionary:
	var rules := _rules(data, "teacher_bout")
	return {"days": int(rules.get("days", 1)), "practice_days": int(rules.get("practice_days", 0)), "cooldown_days": int(rules.get("cooldown_days", 0)),
		"win_favor": int(rules.get("win_favor", 0)), "min_favor": int(rules.get("min_favor", 0)), "power_mult": float(rules.get("power_mult", 1.0)),
		"graduation_favor": int(rules.get("graduation_favor", 5))}


## World flag set once a teacher has nothing left to show you in a style (SPAR-002).
static func graduation_flag(npc_id: String, tech_id: String) -> String:
	return "teacher_graduated_%s_%s" % [npc_id, tech_id]


## The teacher's farewell for a mastered style: the npc's own `graduation_line` or a generic one.
static func graduation_line(data: GameData, npc_id: String, npc_name: String, tech_name: String) -> String:
	var own := String(data.npcs.get(npc_id, {}).get("graduation_line", ""))
	if own != "":
		return own
	return "%s lowers their hands. \"Nothing left I can show you of %s.\"" % [npc_name, tech_name]


## The first technique id `c` knows, has not mastered, and villager `npc_id` teaches (a non-method style), else "".
## With every taught style mastered it is "" and the normal spar rules apply (SPAR-002).
static func teacher_bout_style(c: CharacterData, npc_id: String, data: GameData) -> String:
	if _rules(data, "teacher_bout").is_empty() or c == null:
		return ""
	for tech_id: String in taught_styles(npc_id, data):
		if Techniques.knows(c, tech_id) and not Techniques.is_mastered(c, data, tech_id):
			return tech_id
	return ""


## Days until the teacher-bout cooldown with `npc_id` ends (0 = ready); the same key and rule `check_spar` uses.
static func teacher_bout_cooldown_left(c: CharacterData, npc_id: String, data: GameData, today: int) -> int:
	return cooldown_left(c, "spar:" + npc_id, int(_rules(data, "teacher_bout").get("cooldown_days", 0)), today)


## WU-542: where villager `npc_id`'s bouts for style `tech_id` stand: {state: "ready"|"wait"|"graduated"|"", days}.
## "" when the villager does not teach the style or the player has not learned it.
static func bout_status(c: CharacterData, npc_id: String, tech_id: String, data: GameData, flags: Dictionary, today: int) -> Dictionary:
	var none := {"state": "", "days": 0}
	if c == null or not taught_styles(npc_id, data).has(tech_id) or not Techniques.knows(c, tech_id):
		return none
	if bool(flags.get(graduation_flag(npc_id, tech_id), false)) or Techniques.is_mastered(c, data, tech_id):
		return {"state": "graduated", "days": 0}
	var left := teacher_bout_cooldown_left(c, npc_id, data, today)
	if left > 0:
		return {"state": "wait", "days": left}
	return {"state": "ready", "days": 0}


## WU-542: the suffix a bout state adds to a style line ("practice day ready", "next practice in 3 days", "graduated"); "" for none.
static func bout_status_text(status: Dictionary) -> String:
	match String(status.get("state", "")):
		"ready":
			return "practice day ready"
		"wait":
			var d := int(status.get("days", 0))
			return "next practice in %d day%s" % [d, "" if d == 1 else "s"]
		"graduated":
			return "graduated"
	return ""


## WU-542: "Taught by Hunter Ma · practice day ready" lines for a learned style, one per villager who teaches it.
static func taught_by_lines(c: CharacterData, tech_id: String, data: GameData, flags: Dictionary, today: int) -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Array = data.npcs.keys()
	ids.sort()
	for npc_id: String in ids:
		var text := bout_status_text(bout_status(c, npc_id, tech_id, data, flags, today))
		if text != "":
			out.append("Taught by %s \u00b7 %s" % [String(data.npcs[npc_id].get("name", npc_id)), text])
	return out


## Sorted ids of the non-method techniques villager `npc_id` teaches through dialogue choices.
static func taught_styles(npc_id: String, data: GameData) -> Array:
	var def: Dictionary = data.npcs.get(npc_id, {})
	var nodes: Dictionary = data.dialogues.get(String(def.get("dialogue", "")), {}).get("nodes", {})
	var ids: Array = []
	for node_id: String in nodes:
		for choice: Dictionary in nodes[node_id].get("choices", []):
			var tech_id := String(choice.get("effects", {}).get("learn_technique", ""))
			if tech_id != "" and data.techniques.has(tech_id) and not (data.techniques[tech_id] as TechniqueDef).is_method() and not ids.has(tech_id):
				ids.append(tech_id)
	ids.sort()
	return ids


## TEACH-003: tunables of `mentorship.teacher_pride` {favor_per_level, max_per_month}.
static func teacher_pride_terms(data: GameData) -> Dictionary:
	var rules := _rules(data, "teacher_pride")
	return {"favor_per_level": int(rules.get("favor_per_level", 0)), "max_per_month": int(rules.get("max_per_month", 0))}


## Favor a villager grants when `tech_id` rises from `old_level` to `new_level`; 0 when they did not teach it.
static func teacher_pride(_c: CharacterData, data: GameData, npc_id: String, tech_id: String, old_level: int, new_level: int) -> int:
	if new_level <= old_level or not taught_styles(npc_id, data).has(tech_id):
		return 0
	return (new_level - old_level) * int(teacher_pride_terms(data)["favor_per_level"])


## World-flag key counting favor a teacher gave this calendar month.
static func pride_month_key(npc_id: String, total_days: int) -> String:
	return "teacher_pride_%s_%d_%d" % [npc_id, Calendar.year_of(total_days), Calendar.month_of(total_days)]


## World-flag key holding the style id whose new level the teacher has yet to remark on.
static func pride_note_key(npc_id: String) -> String:
	return "teacher_pride_note_" + npc_id


static func pride_line(npc_name: String, tech_name: String, level: int) -> String:
	return "%s eyes your stance. \"%s %d already? Good.\"" % [npc_name, tech_name, level]


static func is_senior(c: CharacterData, npc: CharacterData) -> bool:
	return npc.realm_index > c.realm_index or (npc.realm_index == c.realm_index and npc.stage > c.stage)


## True when `npc` knows the technique at a higher level than `c` (RV-014): only
## then does their pointer count as shared.
static func knows_better(c: CharacterData, npc: CharacterData, tech_id: String) -> bool:
	return Techniques.knows(npc, tech_id) and Techniques.level(npc, tech_id) > Techniques.level(c, tech_id)


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
		var shared := knows_better(c, npc, tech_id)
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


## The line posted when a master points out a flaw (MENTOR-005): `lines[day % size]` from
## data/family.json, no RNG so sim streams do not move.
static func pointer_line(data: GameData, npc_name: String, tech_name: String, day: int) -> String:
	var lines: Array = _rules(data, "pointers").get("lines", [])
	if lines.is_empty():
		return "%s watches your %s and points out a flaw." % [npc_name, tech_name]
	return String(lines[posmod(day, lines.size())]).replace("{npc}", npc_name).replace("{tech}", tech_name)


## Days until `key` may be used again (0 = ready, also when never used).
static func cooldown_left(c: CharacterData, key: String, cooldown: int, today: int) -> int:
	if not c.npc_action_days.has(key):
		return 0
	return maxi(0, int(c.npc_action_days[key]) + cooldown - today)


## `region_id` and `flags` (world flags) only enrich the refusal texts with where to find a
## fighting manual and what the NPC likes.
static func check_pointers(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int, region_id: String = "", flags: Dictionary = {}) -> String:
	if npc == null or not npc.alive:
		return "They are not here."
	var rules := _rules(data, "pointers")
	if rules.is_empty():
		return "Nobody is offering pointers."
	if npc.age_years() < int(data.family.get("adult_age", 16)):
		return "%s is too young to teach anyone." % npc.name
	if not is_senior(c, npc):
		return "%s is no stronger than you; there is nothing to learn from them yet." % npc.name
	var min_favor := _min_favor(c, npc, rules)
	if favor < min_favor:
		return "%s does not know you well enough (favor %d/%d). Chats and gifts raise it.%s" % [npc.name, favor, min_favor, _taste_note(data, flags, npc)]
	var left := cooldown_left(c, "pointers:" + npc.id, int(rules.get("cooldown_days", 0)), today)
	if left > 0:
		return "%s already pointed out your flaws recently (%d days)." % [npc.name, left]
	if pointer_technique(c, npc, data) == "":
		var hint := Guidance.first_combat_hint(c, data, region_id)
		return "You have no technique they could correct yet. " + hint if hint != "" else "You have no technique they could correct yet; find a technique manual first."
	return ""


## " They are fond of <item>." for the first liked item the player has learned, else
## the told hint sentence, else "".
static func _taste_note(data: GameData, flags: Dictionary, npc: CharacterData) -> String:
	var likes: Array[String] = []
	var tastes := Family.known_tastes(flags, data, npc.id)
	for item_id: String in tastes:
		if int(tastes[item_id]) > 0:
			likes.append(String(data.items[item_id].get("name", item_id)))
	if not likes.is_empty():
		likes.sort()
		return " They are fond of %s." % likes[0]
	if flags.has("taste_told_" + npc.id):
		var hint := Family.taste_hint(data, npc.id, npc.name)
		if hint != "":
			return " " + hint
	return ""


## Returns {ok, reason, tech_id, tech_name, shared, days, levels_gained}.
static func give_pointers(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int) -> Dictionary:
	var result := {"ok": false, "reason": "", "tech_id": "", "tech_name": "", "shared": false, "days": 0, "levels_gained": 0}
	result["reason"] = check_pointers(c, npc, favor, data, today)
	if result["reason"] != "":
		return result
	var rules := _rules(data, "pointers")
	var tech_id := pointer_technique(c, npc, data)
	var shared := knows_better(c, npc, tech_id)
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


static func check_spar(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int) -> String:
	if npc == null or not npc.alive:
		return "They are not here."
	var rules := _rules(data, "spar")
	if rules.is_empty():
		return "Nobody is offering to spar."
	if npc.age_years() < int(data.family.get("adult_age", 16)):
		return "%s is too young." % npc.name
	var teacher_style := teacher_bout_style(c, npc.id, data)
	if teacher_style != "":
		rules = rules.duplicate()
		var bout := _rules(data, "teacher_bout")
		rules["min_favor"] = int(bout.get("min_favor", 0))
		rules["same_sect_min_favor"] = int(bout.get("min_favor", 0))
		rules["cooldown_days"] = int(bout.get("cooldown_days", 0))
	else:
		if c.realm_index < 1:
			return "You need to cultivate before you can spar."
		if npc.realm_index < 1:
			return "%s does not cultivate." % npc.name
		if absi(npc.realm_index - c.realm_index) > int(rules.get("max_realm_gap", 1)):
			return "%s would not cross hands with someone so far from their own realm." % npc.name
	if npc.id == c.rival:
		# RIVAL-012: a rival answers any challenge, unless they are too bitter for a bout.
		if Rivals.attitude(c, npc, favor, data) == "bitter":
			return "%s will not spar with you. They want a real fight." % npc.name
	else:
		var min_favor := _min_favor(c, npc, rules)
		if favor < min_favor:
			return "%s does not know you well enough (favor %d/%d)." % [npc.name, favor, min_favor]
	var left := cooldown_left(c, "spar:" + npc.id, int(rules.get("cooldown_days", 0)), today)
	if left > 0:
		return "You sparred with %s recently (%d days)." % [npc.name, left]
	return ""


## The opponent for a friendly bout: no stones taken, no injury, never lethal.
static func spar_enemy(npc: CharacterData, data: GameData, player: CharacterData = null) -> Dictionary:
	var enemy := Karma.npc_enemy(npc, data, player)
	enemy["spar"] = true
	enemy["friendly"] = true
	if player != null and teacher_bout_style(player, npc.id, data) != "":
		enemy["power_mult"] = float(teacher_bout_terms(data)["power_mult"])
	return enemy


## After the bout: practice xp for every unmastered non-method technique, the
## cooldown, and favor on a win. Returns {favor, practiced, levels, days}.
static func after_spar(c: CharacterData, npc: CharacterData, data: GameData, won: bool, today: int, style: String = "") -> Dictionary:
	var rules := _rules(data, "spar")
	var terms := spar_terms(data)
	var practiced: PackedStringArray = []
	var levels: PackedStringArray = []
	var ids: Array = c.techniques.keys()
	ids.sort()
	if style != "":
		# A teacher bout: only the style they taught, on the teacher_bout terms.
		var bout := teacher_bout_terms(data)
		rules = {"win_favor": bout["win_favor"]}
		terms = {"days": bout["days"], "practice_days": bout["practice_days"]}
		ids = [style]
	for tech_id: String in ids:
		var def: TechniqueDef = data.techniques.get(tech_id)
		if def == null or def.is_method() or Techniques.is_mastered(c, data, tech_id):
			continue
		var r := Techniques.practice(c, data, tech_id, int(terms["practice_days"]))
		if not r["ok"]:
			continue
		practiced.append(def.name)
		if int(r["levels_gained"]) > 0:
			levels.append("%s reaches level %d" % [def.name, Techniques.level(c, tech_id)])
	c.npc_action_days["spar:" + npc.id] = today
	return {"favor": int(rules.get("win_favor", 0)) if won else 0, "practiced": practiced, "levels": levels, "days": int(terms["days"])}


## Favor `npc` needs to teach or spar with `c`: `same_sect_min_favor` for a fellow sect member.
static func _min_favor(c: CharacterData, npc: CharacterData, rules: Dictionary) -> int:
	var base := int(rules.get("min_favor", 0))
	if c.is_rogue() or npc.is_rogue() or npc.sect.get("id") != c.sect.get("id"):
		return base
	return int(rules.get("same_sect_min_favor", base))


## Load errors for data/family.json `mentorship`.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var block: Dictionary = data.family.get("mentorship", {})
	for kind in block:
		var rules: Dictionary = block[kind]
		for key in rules:
			if key == "lines":
				continue
			if float(rules[key]) < 0.0:
				errors.append("family.json mentorship.%s.%s must be >= 0" % [kind, key])
		if int(rules.get("min_favor", 0)) > 100:
			errors.append("family.json mentorship.%s.min_favor must be <= 100" % kind)
		if int(rules.get("same_sect_min_favor", 0)) > int(rules.get("min_favor", 0)):
			errors.append("family.json mentorship.%s.same_sect_min_favor must be <= min_favor" % kind)
	if block.has("teacher_pride"):
		for key: String in ["favor_per_level", "max_per_month"]:
			if float(block["teacher_pride"].get(key, 0)) != float(int(block["teacher_pride"].get(key, 0))):
				errors.append("family.json mentorship.teacher_pride.%s must be an integer" % key)
	if block.has("teacher_bout"):
		if block["teacher_bout"].has("graduation_favor") and float(block["teacher_bout"]["graduation_favor"]) != float(int(block["teacher_bout"]["graduation_favor"])):
			errors.append("family.json mentorship.teacher_bout.graduation_favor must be an integer")
		var days := int(block["teacher_bout"].get("days", 1))
		if days < 1 or days > 3:
			errors.append("family.json mentorship.teacher_bout.days must be 1..3")
	if block.has("pointers") and float(block["pointers"].get("shared_multiplier", 1.0)) < 1.0:
		errors.append("family.json mentorship.pointers.shared_multiplier must be >= 1")
	var lines: Array = block.get("pointers", {}).get("lines", [])
	for line in lines:
		if not String(line).contains("{npc}") or not String(line).contains("{tech}"):
			errors.append("family.json mentorship.pointers.lines entry needs {npc} and {tech}: %s" % line)
	return errors
