class_name HeartVision
extends RefCounted
## HEART-001: the still-heart vision offered before a major breakthrough. A short
## inner scene with a few choices (optionally an attribute check) that leaves a
## one-shot bonus on CharacterData.heart_bonus, spent by the next attempt.
## One vision per realm per life (heart_seen_realm). Content: realms.json heart_vision.

const MAX_BONUS := 0.15
const MAX_CHOICES := 6
const NO_FIGURE := "a faceless figure"


## The pending vision {text, choices} (text filled in), or {} when none is due.
## `people` lets {rival_or_parent} name the player's rival.
static func vision(c: CharacterData, data: GameData, people: Dictionary = {}) -> Dictionary:
	if not Cultivation.can_attempt_breakthrough(c, data) or c.heart_seen_realm == c.realm_index + 1:
		return {}
	var def: Dictionary = data.realms[c.realm_index + 1].heart_vision
	if def.is_empty():
		return {}
	var rival := Rivals.rival_of(c, people)
	var out := def.duplicate(true)
	out["choices"] = visible_choices(def.get("choices", []), c.alignment)
	if (out["choices"] as Array).is_empty():
		return {}
	out["text"] = String(def["text"]).replace("{rival_or_parent}", rival.name if rival != null else NO_FIGURE)
	return out


## The choices whose optional min_alignment / max_alignment admit `alignment`.
static func visible_choices(choices: Array, alignment: int) -> Array:
	var out: Array = []
	for choice: Dictionary in choices:
		if alignment >= int(choice.get("min_alignment", -1000000)) and alignment <= int(choice.get("max_alignment", 1000000)):
			out.append(choice)
	return out


## Faces choice `index` of the pending vision: rolls its check, stores the bonus
## and marks the vision seen. Returns {text, bonus, passed}; {} (nothing changes)
## when there is no vision or the index is invalid.
static func choose(c: CharacterData, data: GameData, index: int, rng: RandomNumberGenerator) -> Dictionary:
	var pending := vision(c, data)
	var choices: Array = pending.get("choices", [])
	if index < 0 or index >= choices.size():
		return {}
	var choice: Dictionary = choices[index]
	var chance := Exploration.check_chance(c, choice)
	var passed := chance < 0.0 or rng.randf() < chance
	var bonus := float(choice.get("bonus", 0.0)) if passed else float(choice.get("fail_bonus", 0.0))
	c.heart_bonus = bonus
	c.heart_seen_realm = c.realm_index + 1
	if choice.has("alignment"):
		Alignment.shift(c, data, int(choice["alignment"]))
	return {"text": String(choice["text"] if passed else choice.get("fail_text", choice["text"])), "bonus": bonus, "passed": passed}


## Content errors in realms.json heart_vision blocks.
static func validate(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	var attr_ids := data.attribute_ids()
	for realm in data.realms:
		var v: Dictionary = realm.heart_vision
		if v.is_empty():
			continue
		var where := "Realm '%s' heart_vision" % realm.id
		if String(v.get("text", "")).strip_edges() == "":
			errors.append("%s needs text" % where)
		var choices: Array = v.get("choices", [])
		if choices.size() < 2 or choices.size() > MAX_CHOICES:
			errors.append("%s needs 2-%d choices" % [where, MAX_CHOICES])
		for a in [data.alignment_min, 0, data.alignment_max]:
			var shown := visible_choices(choices, a).size()
			if shown < 2 or shown > 4:
				errors.append("%s shows %d choices at alignment %d (needs 2-4)" % [where, shown, a])
		for choice: Dictionary in choices:
			if String(choice.get("label", "")).strip_edges() == "" or String(choice.get("text", "")).strip_edges() == "":
				errors.append("%s choice needs label and text" % where)
			for key: String in ["min_alignment", "max_alignment"]:
				if choice.has(key) and (int(choice[key]) < data.alignment_min or int(choice[key]) > data.alignment_max):
					errors.append("%s %s is outside the alignment range" % [where, key])
			if int(choice.get("min_alignment", data.alignment_min)) > int(choice.get("max_alignment", data.alignment_max)):
				errors.append("%s choice has min_alignment above max_alignment" % where)
			for key: String in ["bonus", "fail_bonus"]:
				if choice.has(key) and absf(float(choice[key])) > MAX_BONUS:
					errors.append("%s %s must be within +-%s" % [where, key, MAX_BONUS])
			if choice.has("check"):
				var check: Dictionary = choice["check"]
				if not attr_ids.has(String(check.get("attribute", ""))):
					errors.append("%s check has unknown attribute" % where)
				if int(check.get("target", 0)) < 1 or int(check.get("target", 0)) > 30:
					errors.append("%s check target must be 1-30" % where)
			elif choice.has("fail_bonus") or choice.has("fail_text"):
				errors.append("%s fail_bonus/fail_text need a check" % where)
	return errors
