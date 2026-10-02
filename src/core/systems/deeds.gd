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


## Returns {ok, reason, notes, days}.
static func perform(c: CharacterData, data: GameData, deed_id: String, flags: Dictionary) -> Dictionary:
	var deed: Dictionary = data.deeds.get(deed_id, {})
	if deed.is_empty():
		return {"ok": false, "reason": "Unknown deed.", "notes": PackedStringArray(), "days": 0}
	var effects: Dictionary = deed.get("effects", {})
	var reason := Effects.check(c, data, effects)
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray(), "days": 0}
	return {"ok": true, "reason": "", "notes": Effects.apply(c, data, effects, flags), "days": int(deed.get("days", 0))}
