class_name Effects
extends RefCounted
## Shared effect application used by items, deeds and (later) events/quests.
## Supported keys:
##   qi: float                  add qi (may advance stages)
##   alignment: int             shift alignment
##   items: {item_id: int}      add (or remove, if negative) items
##   breakthrough_bonus: float  bonus to next breakthrough attempt
##   set_flag: String           set a world flag
##   learn_technique: String    learn a technique (see techniques.gd)
##   heal_injury: String        heal one injury id, or "all" (see injuries.gd)


## Returns "" if the effects can be applied, otherwise a reason they cannot.
static func check(c: CharacterData, data: GameData, effects: Dictionary) -> String:
	var item_changes: Dictionary = effects.get("items", {})
	for item_id in item_changes:
		var delta := int(item_changes[item_id])
		if delta < 0 and c.item_count(item_id) < -delta:
			return "You need %d %s." % [-delta, data.items.get(item_id, {}).get("name", item_id)]
	if effects.has("heal_injury") and not _has_healable(c, effects["heal_injury"]):
		return "You have no injury that this would heal."
	if effects.has("learn_technique"):
		var reason := Techniques.can_learn(c, data, effects["learn_technique"])
		if reason != "":
			return reason
	return ""


## Applies effects. `flags` is the world flag dictionary (mutated by set_flag).
## Returns a list of human-readable outcome strings.
static func apply(c: CharacterData, data: GameData, effects: Dictionary, flags: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	if effects.has("alignment"):
		var delta := int(effects["alignment"])
		Alignment.shift(c, data, delta)
		notes.append("Alignment %+d" % delta)
	if effects.has("items"):
		for item_id in effects["items"]:
			var delta := int(effects["items"][item_id])
			c.add_item(item_id, delta)
			notes.append("%+d %s" % [delta, data.items.get(item_id, {}).get("name", item_id)])
	if effects.has("qi"):
		var result := Cultivation.add_qi(c, data, float(effects["qi"]))
		notes.append("+%d qi" % int(result["qi_gained"]))
	if effects.has("breakthrough_bonus"):
		c.breakthrough_bonus += float(effects["breakthrough_bonus"])
		notes.append("Next breakthrough +%d%%" % int(float(effects["breakthrough_bonus"]) * 100))
	if effects.has("learn_technique") and Techniques.learn(c, data, effects["learn_technique"])["ok"]:
		notes.append("Learned %s" % data.techniques[effects["learn_technique"]].name)
	if effects.has("heal_injury"):
		for injury_id in Injuries.heal(c, effects["heal_injury"]):
			notes.append("%s healed" % Injuries.injury_name(data, injury_id))
	if effects.has("set_flag"):
		flags[effects["set_flag"]] = true
	return notes


static func _has_healable(c: CharacterData, injury_id: String) -> bool:
	return c.injuries.has(injury_id) or (injury_id == "all" and Injuries.has_any(c))
