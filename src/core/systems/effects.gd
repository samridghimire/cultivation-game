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
##   burn_lifespan: int         spend years of lifespan (refused if it would kill outright)
##   extend_lifespan: int       gain years of lifespan
##   learn_recipe: String       learn a crafting recipe (see alchemy.gd)
##   buff: {id, name, days, mults: {stat: fraction}}  temporary combat buff (see buffs.gd),
##                              e.g. from a talisman; re-using it refreshes the duration
##   reputation: {sect_id: int} change reputation with sects (see reputation.gd)
##   witnessed: bool            the alignment change was seen: every sect's reputation
##                              moves by alignment * its deed_scale (data/sects.json)
##   bloodline: String          grant a bloodline (data/bloodlines.json) to someone who has
##                              none; it awakens at once if they are past its awaken_realm


## Returns "" if the effects can be applied, otherwise a reason they cannot.
static func check(c: CharacterData, data: GameData, effects: Dictionary) -> String:
	var item_changes: Dictionary = effects.get("items", {})
	for item_id in item_changes:
		var delta := int(item_changes[item_id])
		if delta < 0 and c.item_count(item_id) < -delta:
			return "You need %d %s." % [-delta, data.items.get(item_id, {}).get("name", item_id)]
	if effects.has("burn_lifespan") and int(effects["burn_lifespan"]) >= Cultivation.years_left(c, data):
		return "Burning %d years of life would kill you." % int(effects["burn_lifespan"])
	if effects.has("heal_injury") and not _has_healable(c, effects["heal_injury"]):
		return "You have no injury that this would heal."
	if effects.has("bloodline") and c.bloodline != "":
		return "Your blood already carries the %s." % Bloodlines.bloodline_name(data, c.bloodline)
	if effects.has("learn_technique"):
		var reason := Techniques.can_learn(c, data, effects["learn_technique"])
		if reason != "":
			return reason
	if effects.has("learn_recipe"):
		var reason := Alchemy.can_learn(c, data, effects["learn_recipe"])
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
		if effects.get("witnessed", false):
			notes.append_array(Reputation.on_witnessed(c, data, delta))
	if effects.has("reputation"):
		notes.append_array(Reputation.apply_changes(c, data, effects["reputation"]))
	if effects.has("items"):
		for item_id in effects["items"]:
			var delta := int(effects["items"][item_id])
			c.add_item(item_id, delta)
			notes.append("%+d %s" % [delta, data.items.get(item_id, {}).get("name", item_id)])
	if effects.has("qi"):
		var result := Cultivation.add_qi(c, data, float(effects["qi"]))
		notes.append("+%d qi" % int(result["qi_gained"]))
	if effects.has("burn_lifespan") and Cultivation.burn_lifespan(c, int(effects["burn_lifespan"])):
		notes.append("-%d years of lifespan" % int(effects["burn_lifespan"]))
	if effects.has("extend_lifespan") and Cultivation.extend_lifespan(c, int(effects["extend_lifespan"])):
		notes.append("+%d years of lifespan" % int(effects["extend_lifespan"]))
	if effects.has("breakthrough_bonus"):
		c.breakthrough_bonus += float(effects["breakthrough_bonus"])
		notes.append("Next breakthrough +%d%%" % int(float(effects["breakthrough_bonus"]) * 100))
	if effects.has("learn_technique") and Techniques.learn(c, data, effects["learn_technique"])["ok"]:
		notes.append("Learned %s" % data.techniques[effects["learn_technique"]].name)
	if effects.has("learn_recipe") and Alchemy.learn(c, data, effects["learn_recipe"]):
		notes.append("Learned the %s recipe" % data.recipes[effects["learn_recipe"]].get("name", effects["learn_recipe"]))
	if effects.has("heal_injury"):
		for injury_id in Injuries.heal(c, effects["heal_injury"]):
			notes.append("%s healed" % Injuries.injury_name(data, injury_id))
	if effects.has("buff"):
		var note := Buffs.add_from_effect(c, effects["buff"])
		if note != "":
			notes.append(note)
	if effects.has("bloodline") and Bloodlines.grant(c, data, String(effects["bloodline"])):
		notes.append("Your blood now carries the %s%s" % [Bloodlines.bloodline_name(data, c.bloodline), ", and it awakens" if c.bloodline_awakened else ""])
	if effects.has("set_flag"):
		flags[effects["set_flag"]] = true
	return notes


static func _has_healable(c: CharacterData, injury_id: String) -> bool:
	return c.injuries.has(injury_id) or (injury_id == "all" and Injuries.has_any(c))
