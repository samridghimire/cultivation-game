class_name Reputation
extends RefCounted
## Standing with each sect, separate from alignment (G-009). Rules live in
## data/sects.json: the top-level "reputation" block holds the range and tiers
## (with shop price multipliers), and each sect's "reputation" block holds
## min_join (reputation needed to join) and deed_scale (how a witnessed
## alignment change moves that sect's opinion: righteous sects scale it up,
## demonic sects invert it). Stored in CharacterData.reputation (sect id -> int).


## Current reputation of `c` with `sect_id` (unknown sects read as the start value).
static func value(c: CharacterData, data: GameData, sect_id: String) -> int:
	return int(c.reputation.get(sect_id, int(data.sect_reputation.get("start", 0))))


## Changes reputation, clamped to the data range. Returns the actual change.
static func change(c: CharacterData, data: GameData, sect_id: String, delta: int) -> int:
	if not data.sects.has(sect_id) or delta == 0:
		return 0
	var old := value(c, data, sect_id)
	var new_value := clampi(old + delta, int(data.sect_reputation.get("min", -1000)), int(data.sect_reputation.get("max", 1000)))
	c.reputation[sect_id] = new_value
	return new_value - old


## Applies an explicit {sect_id: delta} effect. Returns notes like "Azure Cloud Sect reputation +20".
static func apply_changes(c: CharacterData, data: GameData, changes: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	for sect_id in changes:
		_note(notes, data, String(sect_id), change(c, data, String(sect_id), int(changes[sect_id])))
	return notes


## A witnessed deed that shifted alignment by `alignment_delta`: every sect
## reacts according to its deed_scale. Returns notes for the sects that moved.
static func on_witnessed(c: CharacterData, data: GameData, alignment_delta: int) -> PackedStringArray:
	var notes: PackedStringArray = []
	for sect: SectDef in data.sects.values():
		var delta := roundi(alignment_delta * sect.reputation_deed_scale)
		_note(notes, data, sect.id, change(c, data, sect.id, delta))
	return notes


## Leaving a sect offends it. Returns the change applied.
static func on_leave(c: CharacterData, data: GameData, sect_id: String) -> int:
	return change(c, data, sect_id, -int(data.sect_reputation.get("leave_penalty", 0)))


## Reputation earned with `c`'s own sect for `contribution` mission contribution.
static func mission_gain(data: GameData, contribution: int) -> int:
	return int(contribution * float(data.sect_reputation.get("mission_rate", 0.0)))


## The tier dictionary ({min, name, price_mult}) for a reputation value.
static func tier(data: GameData, rep: int) -> Dictionary:
	var tiers: Array = data.sect_reputation.get("tiers", [])
	var result: Dictionary = tiers[0] if not tiers.is_empty() else {}
	for t: Dictionary in tiers:
		if rep >= int(t["min"]):
			result = t
	return result


static func tier_name(c: CharacterData, data: GameData, sect_id: String) -> String:
	return String(tier(data, value(c, data, sect_id)).get("name", "Unknown"))


## Price multiplier at a merchant affiliated with `sect_id` ("" = unaffiliated, 1.0).
static func price_multiplier(c: CharacterData, data: GameData, sect_id: String) -> float:
	if sect_id == "" or not data.sects.has(sect_id):
		return 1.0
	return float(tier(data, value(c, data, sect_id)).get("price_mult", 1.0))


## What `item_id` costs `c` at a merchant affiliated with `sect_id` (never below 1).
static func buy_price(c: CharacterData, data: GameData, item_id: String, sect_id: String) -> int:
	var base := int(data.items.get(item_id, {}).get("price", 0))
	if base <= 0:
		return 0
	return maxi(1, roundi(base * price_multiplier(c, data, sect_id)))


## Why `sect_id` refuses `c` on reputation grounds, or "".
static func check_join(c: CharacterData, data: GameData, sect_id: String) -> String:
	var sect: SectDef = data.sects[sect_id]
	if value(c, data, sect_id) < sect.reputation_min_join:
		return "%s will not accept you: your name is %s among them." % [sect.name, tier_name(c, data, sect_id).to_lower()]
	return ""


## One line per sect, e.g. "Azure Cloud Sect: Friendly (120)", for the UI.
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for sect: SectDef in data.sects.values():
		lines.append("%s: %s (%d)" % [sect.name, tier_name(c, data, sect.id), value(c, data, sect.id)])
	return lines


## Load errors for the reputation rules and every `reputation` effect in content.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var rules := data.sect_reputation
	if int(rules.get("min", -1000)) >= int(rules.get("max", 1000)):
		errors.append("sects.json reputation needs min < max")
	var tiers: Array = rules.get("tiers", [])
	if tiers.is_empty():
		errors.append("sects.json reputation needs tiers")
	var last: int = -(1 << 62)
	for t: Dictionary in tiers:
		if not t.has("min") or not t.has("name") or float(t.get("price_mult", 1.0)) <= 0.0:
			errors.append("sects.json reputation tier needs min, name and a positive price_mult")
		elif int(t["min"]) <= last:
			errors.append("sects.json reputation tiers must be in ascending min order")
		else:
			last = int(t["min"])
	var sources := {"deed": data.deeds, "item": data.items, "encounter": data.encounters, "mission": data.sect_missions}
	for kind: String in sources:
		for entry: Dictionary in sources[kind].values():
			_check_effects(entry, data, "%s '%s'" % [kind, entry.get("id", "?")], errors)
	return errors


static func _check_effects(node: Variant, data: GameData, where: String, errors: PackedStringArray) -> void:
	if node is Array:
		for v: Variant in node:
			_check_effects(v, data, where, errors)
	elif node is Dictionary:
		var changes: Variant = node.get("reputation", null)
		if changes is Dictionary:
			for sect_id in changes:
				if not data.sects.has(sect_id):
					errors.append("%s changes reputation with unknown sect '%s'" % [where, sect_id])
		for v: Variant in node.values():
			_check_effects(v, data, where, errors)


static func _note(notes: PackedStringArray, data: GameData, sect_id: String, delta: int) -> void:
	if delta != 0:
		notes.append("%s reputation %+d" % [data.sects[sect_id].name, delta])
