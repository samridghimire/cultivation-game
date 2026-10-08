class_name Exploration
extends RefCounted
## Pure rules for regions, travel and random encounters. Definitions live in
## data/regions.json and data/encounters.json. GameState calls these, applies
## time and fights, and emits events.

## How strongly Fortune shifts the odds of good vs bad encounters (per point
## above or below the average of 10).
const FORTUNE_WEIGHT_PER_POINT := 0.05
## Draws per gathering trip before the Fortune bonus.
const GATHER_ROLLS := 3


static func region_name(data: GameData, region_id: String) -> String:
	return data.regions.get(region_id, {}).get("name", region_id)


static func qi_density(data: GameData, region_id: String) -> float:
	return float(data.regions.get(region_id, {}).get("qi_density", 1.0))


## True if region_id is the region you are in or a direct route target of it.
## An empty region_id (a realm-wide matter) counts as nearby.
static func is_nearby(data: GameData, from_region: String, region_id: String) -> bool:
	if region_id == "" or region_id == from_region:
		return true
	for route: Dictionary in data.regions.get(from_region, {}).get("routes", []):
		if route.get("to", "") == region_id:
			return true
	return false


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


## True when `c`'s realm (and, inside min_realm, stage) fits the encounter's
## min_realm / min_stage / max_realm.
static func realm_allows(c: CharacterData, data: GameData, e: Dictionary) -> bool:
	if e.has("min_realm"):
		var min_index := data.realm_index_of(e["min_realm"])
		if c.realm_index < min_index:
			return false
		if e.has("min_stage") and c.realm_index == min_index and c.stage < int(e["min_stage"]):
			return false
	if e.has("max_realm") and c.realm_index > data.realm_index_of(e["max_realm"]):
		return false
	return true


## Encounters that can happen for a place with `tags`, each paired with its
## Fortune-adjusted weight: [{encounter, weight}]. `rival` is `c`'s living
## rival (Rivals) or null; encounters with a `rival` condition need one.
## `misfortune_scale` multiplies misfortune weights (a clan estate's ward).
static func eligible_encounters(c: CharacterData, data: GameData, tags: Array, flags: Dictionary, rival: CharacterData = null, misfortune_scale: float = 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var fortune_shift := (c.attribute("fortune") - 10) * FORTUNE_WEIGHT_PER_POINT
	for e: Dictionary in data.encounters.values():
		if not _shares_tag(e.get("tags", []), tags):
			continue
		if not realm_allows(c, data, e):
			continue
		if not alignment_allows(c, e):
			continue
		if not Rivals.allows(c, rival, String(e.get("rival", ""))):
			continue
		var blocker: String = e.get("blocked_by_flag", "")
		if blocker != "" and flags.get(blocker, false):
			continue
		var needed_flag: String = e.get("requires_flag", "")
		if needed_flag != "" and not flags.get(needed_flag, false):
			continue
		if e.get("only_if_applicable", false) and Effects.check(c, data, e.get("effects", {})) != "":
			continue
		var weight := float(e.get("weight", 1))
		match e.get("kind", "neutral"):
			"fortune":
				weight *= maxf(0.1, 1.0 + fortune_shift)
			"misfortune":
				weight *= maxf(0.1, 1.0 - fortune_shift) * misfortune_scale
		result.append({"encounter": e, "weight": weight})
	return result


## What exploring a place with `tags` might bring, from the eligible encounters (no rival):
## {fight, choice, fortune, misfortune, other: shares 0..1 summing to 1,
## foes: [{name, danger, lethal}] most dangerous first, at most 4}. Encounters with an
## enemy count as `fight`, those with choices as `choice`, the rest by their kind.
static func outlook(c: CharacterData, data: GameData, tags: Array, flags: Dictionary) -> Dictionary:
	var sums := {"fight": 0.0, "choice": 0.0, "fortune": 0.0, "misfortune": 0.0, "other": 0.0}
	var foes: Array[Dictionary] = []
	var seen := {}
	var total := 0.0
	for entry in eligible_encounters(c, data, tags, flags):
		var e: Dictionary = entry["encounter"]
		var weight: float = entry["weight"]
		var bucket := "other"
		if String(e.get("enemy", "")) != "":
			bucket = "fight"
			var enemy_id := String(e["enemy"])
			if not seen.has(enemy_id) and data.enemies.has(enemy_id):
				seen[enemy_id] = true
				var enemy: Dictionary = data.enemies[enemy_id]
				foes.append({"name": String(enemy.get("name", enemy_id)), "danger": Combat.danger_label(c, data, enemy), "lethal": bool(enemy.get("lethal", false))})
		elif e.has("choices"):
			bucket = "choice"
		elif e.get("kind", "neutral") in ["fortune", "misfortune"]:
			bucket = String(e["kind"])
		sums[bucket] += weight
		total += weight
	var out := {"foes": []}
	for key: String in sums:
		out[key] = sums[key] / total if total > 0.0 else (1.0 if key == "other" else 0.0)
	var rank := {"Deadly": 0, "Dangerous": 1, "Even": 2, "Weak": 3}
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return rank.get(a["danger"], 4) < rank.get(b["danger"], 4))
	out["foes"] = foes.slice(0, 4)
	return out


## Picks a weighted random encounter, or {} if none are eligible.
static func roll_encounter(c: CharacterData, data: GameData, tags: Array, flags: Dictionary, rng: RandomNumberGenerator, rival: CharacterData = null, misfortune_scale: float = 1.0) -> Dictionary:
	var pool := eligible_encounters(c, data, tags, flags, rival, misfortune_scale)
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


## Whether `c`'s alignment is within `entry`'s optional `min_alignment` /
## `max_alignment` (inclusive), e.g. righteous enforcers only hunt the wicked.
static func alignment_allows(c: CharacterData, entry: Dictionary) -> bool:
	if entry.has("min_alignment") and c.alignment < int(entry["min_alignment"]):
		return false
	if entry.has("max_alignment") and c.alignment > int(entry["max_alignment"]):
		return false
	return true


# --- Choices (W-004c) ----------------------------------------------------------

## Why `c` cannot pick `choice` (an entry of an encounter's `choices`), or ""
## if they can. `requires`: {min_realm, min_alignment, max_alignment, flag};
## the choice's effects must also be payable (e.g. items it costs).
static func check_choice(c: CharacterData, data: GameData, choice: Dictionary, flags: Dictionary) -> String:
	var req: Dictionary = choice.get("requires", {})
	if req.has("min_realm") and c.realm_index < data.realm_index_of(req["min_realm"]):
		return "Only a cultivator of %s or above could do that." % data.realms[data.realm_index_of(req["min_realm"])].name
	if req.has("min_alignment") and c.alignment < int(req["min_alignment"]):
		return "Your heart is too dark for that."
	if req.has("max_alignment") and c.alignment > int(req["max_alignment"]):
		return "You are too soft-hearted for that."
	if req.has("flag") and not flags.get(req["flag"], false):
		return "You lack the knowledge for that."
	return Effects.check(c, data, choice.get("effects", {}))


## The choices of `encounter` for `c`: [{index, label, disabled, reason}].
static func choices(c: CharacterData, data: GameData, encounter: Dictionary, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = encounter.get("choices", [])
	for i in list.size():
		var reason := check_choice(c, data, list[i], flags)
		out.append({"index": i, "label": String(list[i].get("label", "")), "disabled": reason != "", "reason": reason})
	return out


## Applies choice `index` of `encounter`. Returns {ok, reason, text, notes,
## days, enemy, karma}; `enemy` is an enemy id the caller must fight ("" = none)
## and `karma` is true when the choice shifted alignment.
static func resolve_choice(c: CharacterData, data: GameData, encounter: Dictionary, index: int, flags: Dictionary) -> Dictionary:
	var list: Array = encounter.get("choices", [])
	if index < 0 or index >= list.size():
		return {"ok": false, "reason": "That is not a choice here.", "text": "", "notes": PackedStringArray(), "days": 0, "enemy": "", "karma": false}
	var choice: Dictionary = list[index]
	var reason := check_choice(c, data, choice, flags)
	if reason != "":
		return {"ok": false, "reason": reason, "text": "", "notes": PackedStringArray(), "days": 0, "enemy": "", "karma": false}
	var effects: Dictionary = choice.get("effects", {})
	var notes := Effects.apply(c, data, effects, flags) if not effects.is_empty() else PackedStringArray()
	return {"ok": true, "reason": "", "text": String(choice.get("text", "")), "notes": notes, "days": int(choice.get("days", 0)), "enemy": String(choice.get("enemy", "")), "karma": effects.has("alignment")}


## Load errors for encounter `choices`, `requires_flag` and alignment bounds.
static func validate_choices(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for e: Dictionary in data.encounters.values():
		if e.has("requires_flag") and String(e["requires_flag"]) == "":
			errors.append("Encounter '%s' has an empty requires_flag" % e["id"])
		errors.append_array(_validate_alignment_bounds(data, e, "Encounter '%s'" % e["id"]))
		if not e.has("choices"):
			continue
		var list: Array = e["choices"]
		if list.size() < 2:
			errors.append("Encounter '%s' needs at least 2 choices" % e["id"])
		if e.has("enemy"):
			errors.append("Encounter '%s' with choices must put its enemy in a choice" % e["id"])
		for choice: Dictionary in list:
			var label := String(choice.get("label", ""))
			if label == "":
				errors.append("Encounter '%s' has a choice without a label" % e["id"])
			if choice.has("enemy") and not data.enemies.has(choice["enemy"]):
				errors.append("Encounter '%s' choice '%s' has unknown enemy '%s'" % [e["id"], label, choice["enemy"]])
			for item_id in choice.get("effects", {}).get("items", {}):
				if not data.items.has(item_id):
					errors.append("Encounter '%s' choice '%s' references unknown item '%s'" % [e["id"], label, item_id])
			var req: Dictionary = choice.get("requires", {})
			if req.has("min_realm") and data.realm_index_of(String(req["min_realm"])) < 0:
				errors.append("Encounter '%s' choice '%s' has unknown min_realm '%s'" % [e["id"], label, req["min_realm"]])
			errors.append_array(_validate_alignment_bounds(data, req, "Encounter '%s' choice '%s'" % [e["id"], label]))
			if int(choice.get("days", 0)) < 0:
				errors.append("Encounter '%s' choice '%s' needs days >= 0" % [e["id"], label])
			if choice.has("grateful_npc"):
				errors.append_array(_validate_grateful(data, choice["grateful_npc"], "Encounter '%s' choice '%s'" % [e["id"], label]))
	return errors


## Load errors for a choice's grateful_npc (RIV-001f).
static func _validate_grateful(data: GameData, def: Dictionary, where: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	if int(def.get("amount", 0)) <= 0:
		errors.append("%s grateful_npc needs amount > 0" % where)
	if data.realm_index_of(String(def.get("realm", "mortal"))) < 0:
		errors.append("%s grateful_npc has unknown realm '%s'" % [where, def.get("realm", "")])
	var ages: Array = def.get("age_years", [18, 40])
	if ages.size() != 2 or int(ages[0]) < 0 or int(ages[0]) > int(ages[1]):
		errors.append("%s grateful_npc age_years must be [min, max]" % where)
	if def.has("gender") and not Names.is_gender(data, String(def["gender"])):
		errors.append("%s grateful_npc has unknown gender '%s'" % [where, def["gender"]])
	return errors


## The gathering table `c` can actually draw from: entries whose optional
## `min_realm` is above the character's realm become "nothing found" (same
## weight), so the odds of the common finds stay the same.
static func gather_table_for(c: CharacterData, data: GameData, table: Array) -> Array:
	var result: Array = []
	for entry: Dictionary in table:
		if _gather_entry_locked(c, data, entry):
			result.append({"item": "", "weight": entry.get("weight", 1)})
		else:
			result.append(entry)
	return result


## Number of gathering entries at `table` hidden from `c` by their min_realm.
static func locked_gather_count(c: CharacterData, data: GameData, table: Array) -> int:
	var count := 0
	for entry: Dictionary in table:
		if _gather_entry_locked(c, data, entry):
			count += 1
	return count


static func _gather_entry_locked(c: CharacterData, data: GameData, entry: Dictionary) -> bool:
	var min_realm: String = entry.get("min_realm", "")
	return min_realm != "" and String(entry.get("item", "")) != "" and c.realm_index < data.realm_index_of(min_realm)


## Draws from a gathering table [{item, weight, min, max}] ("" item = nothing).
## Ignores `min_realm`: filter with gather_table_for first.
## Rolls GATHER_ROLLS times, plus one more per 5 Fortune above 10.
## Returns {item_id: count}.
@warning_ignore("integer_division")
static func gather(c: CharacterData, table: Array, rng: RandomNumberGenerator) -> Dictionary:
	var found := {}
	var total := 0.0
	for entry: Dictionary in table:
		total += float(entry.get("weight", 1))
	if total <= 0.0:
		return found
	var rolls := GATHER_ROLLS + maxi(0, (c.attribute("fortune") - 10) / 5)
	for i in rolls:
		var roll := rng.randf() * total
		for entry: Dictionary in table:
			roll -= float(entry.get("weight", 1))
			if roll < 0.0:
				var item_id: String = entry.get("item", "")
				if item_id != "":
					var count := rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
					found[item_id] = int(found.get(item_id, 0)) + count
				break
	return found


## True if the player should sense `enemy_id` coming and avoid the fight:
## lethal foes rated Deadly are never forced on the player by exploring.
static func should_evade(c: CharacterData, data: GameData, enemy_id: String) -> bool:
	var enemy: Dictionary = data.enemies.get(enemy_id, {})
	return bool(enemy.get("lethal", false)) and Combat.danger_label(c, data, enemy) == "Deadly"


## True if a lethal foe rated Dangerous (not Deadly) is met: the player is
## told and chooses whether to fight or flee instead of being forced.
static func should_offer_flee(c: CharacterData, data: GameData, enemy_id: String) -> bool:
	var enemy: Dictionary = data.enemies.get(enemy_id, {})
	return bool(enemy.get("lethal", false)) and Combat.danger_label(c, data, enemy) == "Dangerous"


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


## Load errors for optional `min_alignment`/`max_alignment` in `entry`: whole
## numbers on the alignment axis, min <= max. `what` prefixes each message.
static func _validate_alignment_bounds(data: GameData, entry: Dictionary, what: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var lo := data.alignment_min
	var hi := data.alignment_max
	for key in ["min_alignment", "max_alignment"]:
		if not entry.has(key):
			continue
		var value: Variant = entry[key]
		if not (value is int or value is float) or float(value) != floorf(float(value)) or int(value) < lo or int(value) > hi:
			errors.append("%s has %s '%s' outside %d..%d" % [what, key, value, lo, hi])
	if entry.has("min_alignment") and entry.has("max_alignment") and int(entry["min_alignment"]) > int(entry["max_alignment"]):
		errors.append("%s has min_alignment above max_alignment" % what)
	return errors


static func _shares_tag(a: Array, b: Array) -> bool:
	for tag in a:
		if b.has(tag):
			return true
	return false
