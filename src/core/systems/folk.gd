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


static func request_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_requests", {})


## FOLK-001: this month's favour a villager of `region_id` asks of the player, stored as a letter request with
## source "folk" and returned ({} when nobody asks). The chance is rolled first, so a closed door costs one draw.
static func monthly_request(c: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String, favor: Dictionary, today: int) -> Dictionary:
	var r := request_rules(data)
	if r.is_empty() or rng.randf() >= float(r.get("monthly_chance", 0.0)):
		return {}
	var open := 0
	for req: Dictionary in c.letter_requests:
		if String(req.get("source", "letter")) == "folk" and int(req["until"]) >= today:
			open += 1
	if open >= int(r.get("max_open", 1)):
		return {}
	var min_favor := int(r.get("min_favor", 0))
	var villagers: Array[CharacterData] = []
	for npc in candidates(npcs, data, c, region_id):
		if int(favor.get(npc.id, 0)) >= min_favor and Letters.open_request(c, npc.id, today).is_empty():
			villagers.append(npc)
	var season := Calendar.season_of(today).to_lower()
	var asks: Array[Dictionary] = []
	for ask: Dictionary in r.get("asks", []):
		if ask.has("regions") and not (ask["regions"] as Array).has(region_id):
			continue
		if ask.has("seasons") and not (ask["seasons"] as Array).has(season):
			continue
		asks.append(ask)
	if villagers.is_empty() or asks.is_empty():
		return {}
	villagers.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.id < b.id)
	var npc: CharacterData = villagers[rng.randi_range(0, villagers.size() - 1)]
	var ask: Dictionary = asks[rng.randi_range(0, asks.size() - 1)]
	var count := rng.randi_range(int(ask["count"][0]), int(ask["count"][1]))
	var stones := rng.randi_range(int(ask["stones"][0]), int(ask["stones"][1]))
	var text := String(ask["text"]).replace(VILLAGER, npc.name).replace("{count}", str(count)).replace("{item}", Items.item_plural(data, String(ask["item"]), count))
	var entry := {"npc_id": npc.id, "item": String(ask["item"]), "count": count, "until": today + int(r.get("days", 20)),
		"favor": int(ask["favor"]), "effects": {"items": {"spirit_stone": stones}} if stones > 0 else {}, "source": "folk", "text": text}
	c.letter_requests.append(entry)
	return entry


static func validate_requests(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := request_rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("monthly_chance", 0.0))
	if chance < 0.0 or chance > 1.0 or absi(int(r.get("min_favor", 0))) > 100 or int(r.get("days", 0)) < 1 or int(r.get("max_open", 0)) < 1:
		errors.append("family.json folk_requests needs monthly_chance 0..1, min_favor -100..100, days >= 1, max_open >= 1")
	if not (r.get("asks") is Array) or r["asks"].is_empty():
		errors.append("family.json folk_requests.asks must be a non-empty list")
		return errors
	for i in r["asks"].size():
		var ask: Dictionary = r["asks"][i]
		var where := "family.json folk_requests ask %d" % i
		if not data.items.is_empty() and not data.items.has(String(ask.get("item", ""))):
			errors.append("%s names unknown item %s" % [where, ask.get("item", "?")])
		for key: String in ["count", "stones"]:
			var range_v: Variant = ask.get(key)
			var low := 1 if key == "count" else 0
			if not (range_v is Array) or range_v.size() != 2 or int(range_v[0]) < low or int(range_v[0]) > int(range_v[1]):
				errors.append("%s %s must be [min, max] with %d <= min <= max" % [where, key, low])
		if int(ask.get("favor", 0)) < 1 or int(ask.get("favor", 0)) > 15:
			errors.append("%s favor must be 1..15" % where)
		var text := String(ask.get("text", ""))
		for token: String in [VILLAGER, "{count}", "{item}"]:
			if not text.contains(token):
				errors.append("%s text needs %s" % [where, token])
		for key: String in ["regions", "seasons"]:
			if ask.has(key) and (not (ask[key] is Array) or ask[key].is_empty()):
				errors.append("%s %s must be a non-empty list" % [where, key])
		for region_id: String in ask.get("regions", []):
			if not data.regions.is_empty() and not data.regions.has(region_id):
				errors.append("%s names unknown region %s" % [where, region_id])
	return errors


## Load errors: favor effects are ints within +-FAVOR_LIMIT and need their placeholder in the encounter's texts.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = validate_greetings(data)
	errors.append_array(validate_requests(data))
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
