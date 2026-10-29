class_name Folk
extends RefCounted
## Happenings that name the people who live there (ENC-011). Encounter text may use {villager} (a living
## generated adult of the current region, not family, not the rival) and {elder} (the oldest such person).
## `pick` chooses them when the encounter is rolled; `fill` writes their names into any text shown.

const VILLAGER := "{villager}"
const ELDER := "{elder}"
const FAVOR_LIMIT := 20


## The texts of `encounter` that may carry placeholders: its text and each choice's label, text and on_fail text.
static func texts(encounter: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = [String(encounter.get("text", ""))]
	for choice: Dictionary in encounter.get("choices", []):
		out.append(String(choice.get("label", "")))
		out.append(String(choice.get("text", "")))
		out.append(String(choice.get("on_fail", {}).get("text", "")))
	return out


## Whether any text of `encounter` names a villager or an elder.
static func uses(encounter: Dictionary) -> bool:
	for text in texts(encounter):
		if text.contains(VILLAGER) or text.contains(ELDER):
			return true
	return false


## Living generated adults of `region_id` who are neither the player's family nor their rival, by id.
static func candidates(npcs: Dictionary, data: GameData, player: CharacterData, region_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	if region_id == "":
		return out
	var adult := int(data.family.get("adult_age", 16))
	for c in Npcs.generated_in_region(npcs, data, region_id):
		if c.age_years() < adult or c.id == player.rival:
			continue
		if player.spouses.has(c.id) or player.children.has(c.id) or player.parents.has(c.id):
			continue
		out.append(c)
	return out


## Whether `encounter` can happen in `region_id`: one that names people needs someone there to name.
static func available(encounter: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, region_id: String) -> bool:
	return not uses(encounter) or not candidates(npcs, data, player, region_id).is_empty()


## Chooses the cast of `encounter`: {villager: id, elder: id}, or {} when it names nobody or nobody lives there.
## Half the time the villager is someone the player already knows (favor > 0), if anyone is. Uses `rng` only
## when the encounter names people.
static func pick(encounter: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, region_id: String, favor: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not uses(encounter):
		return {}
	var pool := candidates(npcs, data, player, region_id)
	if pool.is_empty():
		return {}
	var known: Array[CharacterData] = []
	for c in pool:
		if int(favor.get(c.id, 0)) > 0:
			known.append(c)
	var from: Array[CharacterData] = known if not known.is_empty() and rng.randf() < 0.5 else pool
	var villager := from[rng.randi_range(0, from.size() - 1)]
	var elder := pool[0]
	for c in pool:
		if c.age_days > elder.age_days:
			elder = c
	return {"villager": villager.id, "elder": elder.id}


## `text` with {villager} and {elder} replaced by the names in `cast` (left as is without a cast).
static func fill(text: String, cast: Dictionary, npcs: Dictionary) -> String:
	if cast.is_empty() or not (text.contains(VILLAGER) or text.contains(ELDER)):
		return text
	var villager: CharacterData = npcs.get(String(cast.get("villager", "")))
	var elder: CharacterData = npcs.get(String(cast.get("elder", "")))
	if villager != null:
		text = text.replace(VILLAGER, villager.name)
	if elder != null:
		text = text.replace(ELDER, elder.name)
	return text


## The favor changes an effects block asks for with the cast: {npc_id: delta} (the elder and villager may be one person).
static func favor_changes(effects: Dictionary, cast: Dictionary) -> Dictionary:
	var out := {}
	for pair: Array in [["villager_favor", "villager"], ["elder_favor", "elder"]]:
		var npc_id := String(cast.get(pair[1], ""))
		if effects.has(pair[0]) and npc_id != "":
			out[npc_id] = int(out.get(npc_id, 0)) + int(effects[pair[0]])
	return out


## What `npc` says in passing (WORLD-003) given the player's `favor` with them: a warm or cool line from
## data/family.json folk_greetings picked by hash(npc id + day), with {player} left for the caller. "" in between.
static func greeting(npc: CharacterData, favor: int, day: int, data: GameData) -> String:
	var bands: Dictionary = data.family.get("folk_greetings", {})
	var band: Dictionary = {}
	if favor >= int(bands.get("warm", {}).get("min_favor", 1000)):
		band = bands["warm"]
	elif favor <= int(bands.get("cool", {}).get("max_favor", -1000)):
		band = bands["cool"]
	var lines: Array = band.get("lines", [])
	if lines.is_empty():
		return ""
	return String(lines[absi(hash(npc.id + str(day))) % lines.size()])


## Load errors in folk_greetings: both bands, non-empty string lines, min_favor above max_favor.
static func validate_greetings(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var bands: Dictionary = data.family.get("folk_greetings", {})
	if bands.is_empty():
		return errors
	for key: String in ["warm", "cool"]:
		var band: Variant = bands.get(key)
		if not (band is Dictionary):
			errors.append("family.json folk_greetings: missing band %s" % key)
			continue
		var lines: Variant = band.get("lines")
		if not (lines is Array) or lines.is_empty():
			errors.append("family.json folk_greetings.%s: lines must be a non-empty array" % key)
		else:
			for line: Variant in lines:
				if not (line is String) or String(line) == "":
					errors.append("family.json folk_greetings.%s: lines must be non-empty strings" % key)
		if not band.has("min_favor" if key == "warm" else "max_favor"):
			errors.append("family.json folk_greetings.%s: needs %s" % [key, "min_favor" if key == "warm" else "max_favor"])
	if errors.is_empty() and int(bands["warm"]["min_favor"]) <= int(bands["cool"]["max_favor"]):
		errors.append("family.json folk_greetings: warm min_favor must be above cool max_favor")
	return errors


## Load errors: favor effects are ints within +-FAVOR_LIMIT and need their placeholder in the encounter's texts.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = validate_greetings(data)
	for e: Dictionary in data.encounters.values():
		var blocks: Array = [[String(e["id"]), e.get("effects", {})]]
		for i in e.get("choices", []).size():
			var choice: Dictionary = e["choices"][i]
			blocks.append(["%s choice %d" % [e["id"], i], choice.get("effects", {})])
			if choice.has("on_fail"):
				blocks.append(["%s choice %d on_fail" % [e["id"], i], choice["on_fail"].get("effects", {})])
		var joined := " ".join(texts(e))
		for block: Array in blocks:
			for pair: Array in [["villager_favor", VILLAGER], ["elder_favor", ELDER]]:
				if not block[1].has(pair[0]):
					continue
				var v: Variant = block[1][pair[0]]
				if not (v is int or (v is float and v == floorf(v))) or absi(int(v)) > FAVOR_LIMIT or int(v) == 0:
					errors.append("%s: %s must be a non-zero int within +-%d" % [block[0], pair[0], FAVOR_LIMIT])
				if not joined.contains(pair[1]):
					errors.append("%s: %s needs %s in the encounter's text" % [block[0], pair[0], pair[1]])
	return errors
