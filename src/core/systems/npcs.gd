class_name Npcs
extends RefCounted
## Named NPCs from data/npcs.json. They reuse CharacterData and live their own
## lives off-screen: aging, cultivating and breaking through month by month.

## NPCs are simulated in steps of at most this many days, so a year of
## seclusion gives them twelve chances to break through, not one.
const STEP_DAYS := Calendar.DAYS_PER_MONTH
## Fraction of their days NPCs spend cultivating, unless their data sets
## "diligence". They have lives, duties and bad habits.
const DEFAULT_DILIGENCE := 0.3


static func create(def: Dictionary, data: GameData, rng: RandomNumberGenerator) -> CharacterData:
	var c := CharacterData.new()
	c.id = def["id"]
	c.name = def.get("name", c.id)
	c.age_days = int(def.get("age_years", 20)) * Calendar.DAYS_PER_YEAR
	for attr_id in data.attribute_ids():
		c.attributes[attr_id] = int(def.get("attributes", {}).get(attr_id, 10))
	if def.has("roots"):
		for element in def["roots"]:
			c.spiritual_roots[element] = int(def["roots"][element])
	else:
		c.spiritual_roots = SpiritualRoots.roll(data, rng)
	c.realm_index = maxi(0, data.realm_index_of(def.get("realm", "mortal")))
	c.stage = clampi(int(def.get("stage", 0)), 0, data.realms[c.realm_index].stage_count() - 1)
	c.alignment = int(def.get("alignment", 0))
	return c


## Creates any NPC in data that `npcs` (id -> CharacterData) does not have yet,
## so old saves pick up newly added NPCs.
static func ensure_all(npcs: Dictionary, data: GameData, rng: RandomNumberGenerator) -> void:
	for def: Dictionary in data.npcs.values():
		if not npcs.has(def["id"]):
			npcs[def["id"]] = create(def, data, rng)


## Lives `days` for every NPC. Returns notable events as [{npc_id, text, category}].
static func simulate(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for npc_id in npcs:
		var c: CharacterData = npcs[npc_id]
		var def: Dictionary = data.npcs.get(npc_id, {})
		var remaining := days
		while remaining > 0 and c.alive:
			var step := mini(remaining, STEP_DAYS)
			remaining -= step
			_live(c, def, data, step, rng, events)
	return events


static func _live(c: CharacterData, def: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
	c.age_days += days
	if c.age_years() >= Cultivation.lifespan_years(c, data):
		c.alive = false
		c.cause_of_death = "old age"
		events.append({"npc_id": c.id, "text": "News arrives: %s has died of old age at %d." % [c.name, c.age_years()], "category": "warning"})
		return
	if not def.get("cultivates", false):
		return
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return
	var diligence := float(def.get("diligence", DEFAULT_DILIGENCE))
	Cultivation.cultivate(c, data, days, Exploration.qi_density(data, def.get("region", "")) * diligence)
	if Cultivation.can_attempt_breakthrough(c, data):
		var result := Cultivation.attempt_breakthrough(c, data, rng)
		# Mortal to Qi Refining is routine; only report real breakthroughs.
		if result["success"] and c.realm_index > 1:
			events.append({"npc_id": c.id, "text": "Rumours spread: %s has broken through to %s!" % [c.name, result["realm_name"]], "category": "info"})
		elif result["success"] and c.realm_index == 1:
			events.append({"npc_id": c.id, "text": "%s has begun Qi Refining." % c.name, "category": "info"})


## NPCs whose home is `region_id` and who are still alive.
static func in_region(npcs: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for npc_id in npcs:
		var c: CharacterData = npcs[npc_id]
		if c.alive and data.npcs.get(npc_id, {}).get("region", "") == region_id:
			result.append(c)
	return result


static func to_dict(npcs: Dictionary) -> Dictionary:
	var out := {}
	for npc_id in npcs:
		out[npc_id] = (npcs[npc_id] as CharacterData).to_dict()
	return out


static func from_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for npc_id in d:
		out[npc_id] = CharacterData.from_dict(d[npc_id])
	return out
