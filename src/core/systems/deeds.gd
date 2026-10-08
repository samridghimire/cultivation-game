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
## the deed's effects must be payable, and `cooldown_days` / `once` (see
## data/deeds.json) block repeats; `today` is the GameClock day.
static func check(c: CharacterData, data: GameData, deed: Dictionary, flags: Dictionary, today: int = 0) -> String:
	var id := String(deed.get("id", ""))
	if c.deed_days.has(id):
		if bool(deed.get("once", false)):
			return "You have already done this."
		var cooldown := int(deed.get("cooldown_days", 0))
		var left := int(c.deed_days[id]) + cooldown - today
		if cooldown > 0 and left > 0:
			return "You did this recently. Try again in %d days." % left
	return Exploration.check_choice(c, data, deed, flags)


## The deeds offered at `context` for `c`:
## [{deed, disabled, reason, danger, lethal}]; `danger` is Combat.danger_label of the
## deed's `enemy` ("" if the deed has no fight).
static func options(c: CharacterData, data: GameData, context: String, flags: Dictionary, today: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for deed in available(data, context, flags):
		var reason := check(c, data, deed, flags, today)
		var enemy_id := String(deed.get("enemy", ""))
		var danger := Combat.danger_label(c, data, data.enemies[enemy_id]) if data.enemies.has(enemy_id) else ""
		var lethal := data.enemies.has(enemy_id) and bool(data.enemies[enemy_id].get("lethal", false))
		out.append({"deed": deed, "disabled": reason != "", "reason": reason, "danger": danger, "lethal": lethal})
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
		if deed.has("cooldown_days") and int(deed["cooldown_days"]) < 1:
			errors.append("Deed '%s' needs cooldown_days >= 1" % deed["id"])
		var req: Dictionary = deed.get("requires", {})
		for key in req:
			if not key in ["min_realm", "min_alignment", "max_alignment", "flag"]:
				errors.append("Deed '%s' has unknown requirement '%s'" % [deed["id"], key])
		if req.has("min_realm") and data.realm_index_of(String(req["min_realm"])) < 0:
			errors.append("Deed '%s' has unknown min_realm '%s'" % [deed["id"], req["min_realm"]])
	return errors


## Applies the deed's effects. The caller fights the deed's `enemy` first
## (and only calls this on a win). Returns {ok, reason, notes, days}.
static func perform(c: CharacterData, data: GameData, deed_id: String, flags: Dictionary, today: int = 0) -> Dictionary:
	var deed: Dictionary = data.deeds.get(deed_id, {})
	if deed.is_empty():
		return {"ok": false, "reason": "Unknown deed.", "notes": PackedStringArray(), "days": 0}
	var effects: Dictionary = deed.get("effects", {})
	var reason := check(c, data, deed, flags, today)
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray(), "days": 0}
	var notes := Effects.apply(c, data, effects, flags)
	if deed.has("cooldown_days") or bool(deed.get("once", false)):
		c.deed_days[deed_id] = today
	return {"ok": true, "reason": "", "notes": notes, "days": int(deed.get("days", 0))}
