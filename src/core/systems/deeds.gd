class_name Deeds
extends RefCounted
## Moral choices (helping, robbing, killing...). Definitions in data/deeds.json.


static func available(data: GameData, context: String, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deed: Dictionary in data.deeds.values():
		if deed.get("context", "") != context:
			continue
		var blocker: String = deed.get("blocked_by_flag", "")
		if blocker != "" and flags.get(blocker, false):
			continue
		result.append(deed)
	return result


## Why `c` cannot perform `deed` right now, or "". Optional `requires`
## ({min_realm, min_alignment, max_alignment, flag}, like encounter choices),
## and the deed's effects must be payable.
static func check(c: CharacterData, data: GameData, deed: Dictionary, flags: Dictionary) -> String:
	return Exploration.check_choice(c, data, deed, flags)


## The deeds offered at `context` for `c`:
## [{deed, disabled, reason, danger}]; `danger` is Combat.danger_label of the
## deed's `enemy` ("" if the deed has no fight).
static func options(c: CharacterData, data: GameData, context: String, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for deed in available(data, context, flags):
		var reason := check(c, data, deed, flags)
		var enemy_id := String(deed.get("enemy", ""))
		var danger := Combat.danger_label(c, data, data.enemies[enemy_id]) if data.enemies.has(enemy_id) else ""
		out.append({"deed": deed, "disabled": reason != "", "reason": reason, "danger": danger})
	return out


## Load errors for deeds.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for deed: Dictionary in data.deeds.values():
		for item_id in deed.get("effects", {}).get("items", {}):
			if not data.items.has(item_id):
				errors.append("Deed '%s' references unknown item '%s'" % [deed["id"], item_id])
		if deed.has("enemy") and not data.enemies.has(String(deed["enemy"])):
			errors.append("Deed '%s' references unknown enemy '%s'" % [deed["id"], deed["enemy"]])
		var req: Dictionary = deed.get("requires", {})
		for key in req:
			if not key in ["min_realm", "min_alignment", "max_alignment", "flag"]:
				errors.append("Deed '%s' has unknown requirement '%s'" % [deed["id"], key])
		if req.has("min_realm") and data.realm_index_of(String(req["min_realm"])) < 0:
			errors.append("Deed '%s' has unknown min_realm '%s'" % [deed["id"], req["min_realm"]])
	return errors


## Applies the deed's effects. The caller fights the deed's `enemy` first
## (and only calls this on a win). Returns {ok, reason, notes, days}.
static func perform(c: CharacterData, data: GameData, deed_id: String, flags: Dictionary) -> Dictionary:
	var deed: Dictionary = data.deeds.get(deed_id, {})
	if deed.is_empty():
		return {"ok": false, "reason": "Unknown deed.", "notes": PackedStringArray(), "days": 0}
	var effects: Dictionary = deed.get("effects", {})
	var reason := check(c, data, deed, flags)
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray(), "days": 0}
	return {"ok": true, "reason": "", "notes": Effects.apply(c, data, effects, flags), "days": int(deed.get("days", 0))}
