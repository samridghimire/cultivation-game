class_name Exploration
extends RefCounted
## Pure rules for regions, travel and random encounters. Definitions live in
## data/regions.json and data/encounters.json. GameState calls these, applies
## time and fights, and emits events.

## How strongly Fortune shifts the odds of good vs bad encounters (per point
## above or below the average of 10).
const FORTUNE_WEIGHT_PER_POINT := 0.05


static func region_name(data: GameData, region_id: String) -> String:
	return data.regions.get(region_id, {}).get("name", region_id)


static func qi_density(data: GameData, region_id: String) -> float:
	return float(data.regions.get(region_id, {}).get("qi_density", 1.0))


## Routes out of a region, each {to, name, days, ok, reason}.
static func routes(c: CharacterData, data: GameData, region_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route: Dictionary in data.regions.get(region_id, {}).get("routes", []):
		var check := check_travel(c, data, region_id, route["to"])
		result.append({"to": route["to"], "name": region_name(data, route["to"]), "days": int(route.get("days", 1)), "ok": check["ok"], "reason": check["reason"]})
	return result


## Returns {ok, reason, days}.
static func check_travel(c: CharacterData, data: GameData, from_id: String, to_id: String) -> Dictionary:
	for route: Dictionary in data.regions.get(from_id, {}).get("routes", []):
		if route.get("to", "") != to_id:
			continue
		var min_realm: String = route.get("min_realm", "")
		if min_realm != "" and c.realm_index < data.realm_index_of(min_realm):
			var realm_name := data.realms[data.realm_index_of(min_realm)].name
			return {"ok": false, "reason": "The way to %s is too perilous before %s." % [region_name(data, to_id), realm_name], "days": 0}
		return {"ok": true, "reason": "", "days": int(route.get("days", 1))}
	return {"ok": false, "reason": "There is no road from here to %s." % region_name(data, to_id), "days": 0}


## Encounters that can happen for a place with `tags`, each paired with its
## Fortune-adjusted weight: [{encounter, weight}].
static func eligible_encounters(c: CharacterData, data: GameData, tags: Array, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var fortune_shift := (c.attribute("fortune") - 10) * FORTUNE_WEIGHT_PER_POINT
	for e: Dictionary in data.encounters.values():
		if not _shares_tag(e.get("tags", []), tags):
			continue
		if e.has("min_realm") and c.realm_index < data.realm_index_of(e["min_realm"]):
			continue
		if e.has("max_realm") and c.realm_index > data.realm_index_of(e["max_realm"]):
			continue
		var blocker: String = e.get("blocked_by_flag", "")
		if blocker != "" and flags.get(blocker, false):
			continue
		var weight := float(e.get("weight", 1))
		match e.get("kind", "neutral"):
			"fortune":
				weight *= maxf(0.1, 1.0 + fortune_shift)
			"misfortune":
				weight *= maxf(0.1, 1.0 - fortune_shift)
		result.append({"encounter": e, "weight": weight})
	return result


## Picks a weighted random encounter, or {} if none are eligible.
static func roll_encounter(c: CharacterData, data: GameData, tags: Array, flags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pool := eligible_encounters(c, data, tags, flags)
	var total := 0.0
	for entry in pool:
		total += entry["weight"]
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for entry in pool:
		roll -= entry["weight"]
		if roll < 0.0:
			return entry["encounter"]
	return pool.back()["encounter"]


## Applies an encounter's non-combat part. Returns {ok, reason, notes, days, enemy}.
## `enemy` is an enemy id the caller must fight ("" = none).
static func resolve(c: CharacterData, data: GameData, encounter: Dictionary, flags: Dictionary) -> Dictionary:
	var effects: Dictionary = encounter.get("effects", {})
	var notes: PackedStringArray = []
	# Losses the player cannot cover (e.g. a pickpocket finding an empty
	# pouch) are clamped instead of refusing the encounter.
	effects = _clamp_losses(c, effects)
	if not effects.is_empty():
		notes = Effects.apply(c, data, effects, flags)
	return {"ok": true, "reason": "", "notes": notes, "days": int(encounter.get("days", 0)), "enemy": encounter.get("enemy", "")}


## True if the player should sense `enemy_id` coming and avoid the fight:
## lethal foes rated Deadly are never forced on the player by exploring.
static func should_evade(c: CharacterData, data: GameData, enemy_id: String) -> bool:
	var enemy: Dictionary = data.enemies.get(enemy_id, {})
	return bool(enemy.get("lethal", false)) and Combat.danger_label(c, data, enemy) == "Deadly"


static func _clamp_losses(c: CharacterData, effects: Dictionary) -> Dictionary:
	if not effects.has("items"):
		return effects
	var clamped := effects.duplicate(true)
	var item_changes: Dictionary = clamped["items"]
	for item_id in item_changes.keys():
		var delta := int(item_changes[item_id])
		if delta < 0:
			delta = -mini(-delta, c.item_count(item_id))
		if delta == 0:
			item_changes.erase(item_id)
		else:
			item_changes[item_id] = delta
	if item_changes.is_empty():
		clamped.erase("items")
	return clamped


static func _shares_tag(a: Array, b: Array) -> bool:
	for tag in a:
		if b.has(tag):
			return true
	return false
