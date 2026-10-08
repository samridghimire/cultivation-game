class_name SectFactions
extends RefCounted
## NPC sects as living factions (LW-002, part 1). A sect's strength is the sum
## of its living NPC members' realm weights (sects.json `factions.strength_base`
## ^ realm index), so it grows as members break through and shrinks as they
## die. Each month every sect may recruit one rogue generated NPC it would
## accept (Sects.check_join). Membership lives on CharacterData.sect, so
## nothing new is saved. Righteous and demonic sects clash monthly (LW-002b).


static func rules(data: GameData) -> Dictionary:
	return data.sect_factions


## Days a sect's call for its disciples stays open (LW-002c).
const CALL_DAYS := 30


## Living NPC members of `sect_id`, sorted by id.
static func members(npcs: Dictionary, sect_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	var ids := npcs.keys()
	ids.sort()
	for npc_id in ids:
		var c: CharacterData = npcs[npc_id]
		if c.alive and not c.is_rogue() and String(c.sect.get("id", "")) == sect_id:
			out.append(c)
	return out


## Strength one member of realm `realm_index` adds.
static func realm_weight(data: GameData, realm_index: int) -> int:
	return int(pow(float(rules(data).get("strength_base", 3)), maxi(0, realm_index)))


## Sum of the realm weights of `sect_id`'s living NPC members.
static func strength(data: GameData, npcs: Dictionary, sect_id: String) -> int:
	var total := 0
	for c in members(npcs, sect_id):
		total += realm_weight(data, c.realm_index)
	return total


## Every sect as {id, name, strength, members}, strongest first (ties by id).
static func standings(data: GameData, npcs: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sect_id: String in data.sects:
		out.append({"id": sect_id, "name": (data.sects[sect_id] as SectDef).name, "strength": strength(data, npcs, sect_id), "members": members(npcs, sect_id).size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["strength"] > b["strength"] or (a["strength"] == b["strength"] and String(a["id"]) < String(b["id"])))
	return out


## Whether `c` is a rogue generated NPC a sect may recruit: alive, cultivating,
## of recruiting age and not in `reserved` (the player's spouses and
## descendants, whose sect the player decides).
static func is_recruitable(c: CharacterData, data: GameData, reserved: Dictionary) -> bool:
	var recruit: Dictionary = rules(data).get("recruit", {})
	var age := c.age_years()
	return c.alive and c.cultivates and c.is_rogue() and c.id.begins_with(Npcs.SPAWN_PREFIX) and not reserved.has(c.id) \
		and age >= int(recruit.get("min_age_years", 16)) and age <= int(recruit.get("max_age_years", 40))


## Monthly recruitment: each sect (in id order) recruits, with
## `recruit.monthly_chance`, one random recruitable NPC it would accept.
## Returns news events [{npc_id, sect_id, text, category}].
static func recruit(data: GameData, npcs: Dictionary, rng: RandomNumberGenerator, reserved: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var chance := float(rules(data).get("recruit", {}).get("monthly_chance", 0.0))
	var sect_ids := data.sects.keys()
	sect_ids.sort()
	var ids := npcs.keys()
	ids.sort()
	for sect_id: String in sect_ids:
		if chance <= 0.0 or rng.randf() >= chance:
			continue
		var candidates: Array[CharacterData] = []
		for npc_id in ids:
			var c: CharacterData = npcs[npc_id]
			if is_recruitable(c, data, reserved) and Sects.check_join(c, data, sect_id)["ok"]:
				candidates.append(c)
		if candidates.is_empty():
			continue
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		Sects.npc_join(chosen, data, sect_id)
		events.append({"npc_id": chosen.id, "sect_id": sect_id, "text": "%s has joined the %s as %s." % [chosen.name, (data.sects[sect_id] as SectDef).name, Text.a((data.sects[sect_id] as SectDef).rank_name(int(chosen.sect["rank"])))], "category": "info"})
	return events


## Every [righteous_id, demonic_id] sect pair (sects.json `alignment` tags;
## neutral sects never clash), sorted for determinism.
static func hostile_pairs(data: GameData) -> Array:
	var righteous: Array[String] = []
	var demonic: Array[String] = []
	for sect_id: String in data.sects:
		match (data.sects[sect_id] as SectDef).alignment_tag:
			"righteous":
				righteous.append(sect_id)
			"demonic":
				demonic.append(sect_id)
	righteous.sort()
	demonic.sort()
	var pairs: Array = []
	for a in righteous:
		for b in demonic:
			pairs.append([a, b])
	return pairs


## Monthly sect clashes: each hostile pair clashes with `clash.monthly_chance`.
## The winner is rolled by relative strength; the loser loses `clash.casualties`
## random living NPC members. Returns [{winner, loser, dead_ids, text, category}].
static func clash(data: GameData, npcs: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var rule: Dictionary = rules(data).get("clash", {})
	var chance := float(rule.get("monthly_chance", 0.0))
	if chance <= 0.0:
		return events
	for pair: Array in hostile_pairs(data):
		if rng.randf() >= chance:
			continue
		var strength_a: int = strength(data, npcs, pair[0])
		var strength_b: int = strength(data, npcs, pair[1])
		if strength_a + strength_b <= 0:
			continue
		var a_wins := rng.randf() < strength_a / float(strength_a + strength_b)
		var winner: String = pair[0] if a_wins else pair[1]
		var loser: String = pair[1] if a_wins else pair[0]
		var winner_name := (data.sects[winner] as SectDef).name
		var loser_name := (data.sects[loser] as SectDef).name
		var pool := members(npcs, loser)
		var dead_ids: Array = []
		for i in int(rule.get("casualties", 1)):
			if pool.is_empty():
				break
			var victim: CharacterData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			Npcs.die(victim, "fell in battle against the %s" % winner_name)
			dead_ids.append(victim.id)
		events.append({"winner": winner, "loser": loser, "dead_ids": dead_ids, "category": "danger",
			"text": "The %s and the %s clashed at the border. The %s lost %s." % [(data.sects[pair[0]] as SectDef).name, (data.sects[pair[1]] as SectDef).name, loser_name, "%d disciple%s" % [dead_ids.size(), "" if dead_ids.size() == 1 else "s"]]})
	return events


## Gossip about the balance of power, for a merchant's rumors.
static func rumors(data: GameData, npcs: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ranked := standings(data, npcs)
	if ranked.is_empty() or int(ranked[0]["strength"]) <= 0:
		return lines
	lines.append("They say the %s is the mightiest sect of the region, with %d known disciples." % [ranked[0]["name"], ranked[0]["members"]])
	if ranked.size() > 1 and int(ranked[-1]["strength"]) * 2 < int(ranked[0]["strength"]):
		lines.append("The %s has fallen far behind; its elders fret over every recruit." % ranked[-1]["name"])
	return lines


## Load errors for the sects.json `factions` block.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	if float(r.get("strength_base", 3)) < 1.0:
		errors.append("sects.json factions.strength_base must be >= 1")
	var recruit: Dictionary = r.get("recruit", {})
	var chance := float(recruit.get("monthly_chance", 0.0))
	if chance < 0.0 or chance > 1.0:
		errors.append("sects.json factions.recruit.monthly_chance must be in 0..1")
	if int(recruit.get("min_age_years", 16)) > int(recruit.get("max_age_years", 40)):
		errors.append("sects.json factions.recruit needs min_age_years <= max_age_years")
	var clash_rule: Dictionary = r.get("clash", {})
	if not clash_rule.is_empty():
		var clash_chance := float(clash_rule.get("monthly_chance", 0.0))
		if clash_chance < 0.0 or clash_chance > 1.0:
			errors.append("sects.json factions.clash.monthly_chance must be in 0..1")
		if int(clash_rule.get("casualties", 1)) < 1:
			errors.append("sects.json factions.clash.casualties must be >= 1")
	return errors


## "1st", "2nd", "3rd", "4th", "11th"...
static func ordinal(n: int) -> String:
	var tail := n % 100
	if tail >= 11 and tail <= 13:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
	return "%dth" % n


## "Your sect ranks 2nd of 3 in strength." for a sect member, "" for a rogue.
static func rank_line(c: CharacterData, standings: Array[Dictionary]) -> String:
	if c.is_rogue():
		return ""
	for i in standings.size():
		if String(standings[i]["id"]) == String(c.sect.get("id", "")):
			return "Your sect ranks %s of %d in strength." % [ordinal(i + 1), standings.size()]
	return ""


## Days left on `sect_id`'s call (it lapses CALL_DAYS after `sect_call_day_<sect>`), -1 if there is none.
static func call_days_left(flags: Dictionary, sect_id: String, today: int) -> int:
	if sect_id == "" or not flags.get("sect_call_" + sect_id, false) or not flags.has("sect_call_day_" + sect_id):
		return -1
	return maxi(0, CALL_DAYS - (today - int(flags["sect_call_day_" + sect_id])))


## The id of the sect mission that answers `sect_id`'s call (requires_flag sect_call_<sect>), "" if none.
static func call_mission_id(data: GameData, sect_id: String) -> String:
	for mission_id: String in data.sect_missions:
		if String(data.sect_missions[mission_id].get("requires_flag", "")) == "sect_call_" + sect_id:
			return mission_id
	return ""


## Sect calls (LW-002b) lapse CALL_DAYS after they were made, or as soon as the call mission
## clears the flag. Tidies the `sect_call_*` / `sect_call_day_*` keys in `flags` and returns the
## ids of the sects whose call lapsed at the deadline.
static func expire_calls(flags: Dictionary, today: int) -> Array[String]:
	var lapsed: Array[String] = []
	for key: String in flags.keys():
		if key.begins_with("sect_call_day_") and not flags.has("sect_call_" + key.trim_prefix("sect_call_day_")):
			flags.erase(key)  # the call mission cleared its flag
			continue
		if not key.begins_with("sect_call_") or key.begins_with("sect_call_day_"):
			continue
		var sect_id := key.trim_prefix("sect_call_")
		var day_key := "sect_call_day_" + sect_id
		if not flags.get(key, false):
			flags.erase(day_key)
			continue
		if not flags.has(day_key):
			flags[day_key] = today  # a call from an older save starts counting now
			continue
		if today - int(flags[day_key]) > CALL_DAYS:
			flags.erase(key)
			flags.erase(day_key)
			lapsed.append(sect_id)
	return lapsed
