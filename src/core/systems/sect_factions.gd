class_name SectFactions
extends RefCounted
## NPC sects as living factions (LW-002, part 1). A sect's strength is the sum
## of its living NPC members' realm weights (sects.json `factions.strength_base`
## ^ realm index), so it grows as members break through and shrinks as they
## die. Each month every sect may recruit one rogue generated NPC it would
## accept (Sects.check_join). Membership lives on CharacterData.sect, so
## nothing new is saved. Clashes and help missions build on this (LW-002b/c).


static func rules(data: GameData) -> Dictionary:
	return data.sect_factions


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
	return errors
