class_name Effects
extends RefCounted
## Shared effect application used by items, deeds and (later) events/quests.
## Supported keys:
##   qi: float                  add qi (may advance stages)
##   alignment: int             shift alignment
##   items: {item_id: int}      add (or remove, if negative) items
##   breakthrough_bonus: float  bonus to next breakthrough attempt
##   breakthrough_realm: String realm id this breakthrough_bonus is meant for; refused
##                              for any other next realm, and while a bonus is already waiting
##   set_flag: String | [String]    set a world flag (or each flag of a list)
##   clear_flag: String | [String]  clear a world flag (or each flag of a list)
##   learn_technique: String    learn a technique (see techniques.gd)
##   heal_injury: String        heal one injury id, or "all" (see injuries.gd)
##   burn_lifespan: int         spend years of lifespan (refused if it would kill outright)
##   extend_lifespan: int       gain years of lifespan
##   learn_recipe: String       learn a crafting recipe (see alchemy.gd)
##   dao_insight: String        gain one level of a Dao insight (see dao.gd), e.g. a sudden enlightenment
##   buff: {id, name, days, mults: {stat: fraction}}  temporary combat buff (see buffs.gd),
##                              e.g. from a talisman; re-using it refreshes the duration
##   reputation: {sect_id: int} change reputation with sects (see reputation.gd)
##   witnessed: bool            the alignment change was seen: every sect's reputation
##                              moves by alignment * its deed_scale (data/sects.json)
##   attributes: {attr_id: int} raise (or lower) attributes (data/attributes.json ids)
##   bloodline: String          grant a bloodline (data/bloodlines.json) to someone who has
##                              none; it awakens at once if they are past its awaken_realm


## Returns "" if the effects can be applied, otherwise a reason they cannot.
static func check(c: CharacterData, data: GameData, effects: Dictionary) -> String:
	var item_changes: Dictionary = effects.get("items", {})
	for item_id in item_changes:
		var delta := int(item_changes[item_id])
		if delta < 0 and c.item_count(item_id) < -delta:
			return "You need %d %s." % [-delta, data.items.get(item_id, {}).get("name", item_id)]
	if effects.has("breakthrough_realm"):
		var realm_reason := _check_breakthrough_realm(c, data, String(effects["breakthrough_realm"]))
		if realm_reason != "":
			return realm_reason
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


static func _check_breakthrough_realm(c: CharacterData, data: GameData, realm_id: String) -> String:
	var target := ""
	if c.realm_index + 1 < data.realms.size():
		target = data.realms[c.realm_index + 1].id
	if target != realm_id:
		var idx := data.realm_index_of(realm_id)
		var realm_name := data.realms[idx].name if idx >= 0 else realm_id
		return "This pill is meant for the breakthrough into %s." % realm_name
	if c.breakthrough_pill != "":
		return "A breakthrough boost already steadies you; one pill per attempt."
	return ""


## Applies effects. `flags` is the world flag dictionary (mutated by set_flag).
## Returns a list of human-readable outcome strings.
static func apply(c: CharacterData, data: GameData, effects: Dictionary, flags: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	if effects.has("alignment"):
		var delta := int(effects["alignment"])
		Alignment.shift(c, data, delta)
		notes.append("Alignment %+d, now %s" % [delta, Alignment.tier_name(c.alignment, data)])
		if effects.get("witnessed", false):
			notes.append_array(Reputation.on_witnessed(c, data, delta))
	if effects.has("reputation"):
		notes.append_array(Reputation.apply_changes(c, data, effects["reputation"]))
	if effects.has("items"):
		for item_id in effects["items"]:
			var delta := int(effects["items"][item_id])
			c.add_item(item_id, delta)
			if item_id == "spirit_stone":
				LifeStats.record_stones(c, delta)
			notes.append("%+d %s" % [delta, data.items.get(item_id, {}).get("name", item_id)])
	if effects.has("qi"):
		var result := Cultivation.add_qi(c, data, float(effects["qi"]))
		LifeStats.add(c, "qi_gathered", int(result["qi_gained"]))
		notes.append("+%d qi" % int(result["qi_gained"]))
	if effects.has("burn_lifespan") and Cultivation.burn_lifespan(c, int(effects["burn_lifespan"])):
		notes.append("-%d years of lifespan" % int(effects["burn_lifespan"]))
	if effects.has("extend_lifespan") and Cultivation.extend_lifespan(c, int(effects["extend_lifespan"])):
		notes.append("+%d years of lifespan" % int(effects["extend_lifespan"]))
	if effects.has("breakthrough_bonus"):
		c.breakthrough_bonus += float(effects["breakthrough_bonus"])
		if effects.has("breakthrough_realm"):
			c.breakthrough_pill = String(effects["breakthrough_realm"])
		notes.append("Next breakthrough +%d%%" % int(float(effects["breakthrough_bonus"]) * 100))
	if effects.has("learn_technique") and Techniques.learn(c, data, effects["learn_technique"])["ok"]:
		notes.append("Learned %s" % data.techniques[effects["learn_technique"]].name)
	if effects.has("learn_recipe") and Alchemy.learn(c, data, effects["learn_recipe"]):
		notes.append("Learned the %s recipe" % data.recipes[effects["learn_recipe"]].get("name", effects["learn_recipe"]))
	if effects.has("heal_injury"):
		for injury_id in Injuries.heal(c, effects["heal_injury"]):
			notes.append("%s healed" % Injuries.injury_name(data, injury_id))
	if effects.has("dao_insight") and Dao.gain_levels(c, data, effects["dao_insight"]) > 0:
		notes.append("Insight into the %s (level %d)" % [Dao.def_of(data, effects["dao_insight"])["name"], Dao.level(c, effects["dao_insight"])])
	if effects.has("buff"):
		var note := Buffs.add_from_effect(c, effects["buff"])
		if note != "":
			notes.append(note)
	if effects.has("bloodline") and Bloodlines.grant(c, data, String(effects["bloodline"])):
		notes.append("Your blood now carries the %s%s" % [Bloodlines.bloodline_name(data, c.bloodline), ", and it awakens" if c.bloodline_awakened else ""])
	var attribute_changes: Dictionary = effects.get("attributes", {})
	for attr_id in attribute_changes:
		var delta := int(attribute_changes[attr_id])
		c.attributes[attr_id] = c.attribute(attr_id) + delta
		notes.append("%s %+d" % [String(attr_id).capitalize(), delta])
	for flag in flag_list(effects.get("set_flag", "")):
		flags[flag] = true
	for flag in flag_list(effects.get("clear_flag", "")):
		flags.erase(flag)
	return notes


## A set_flag/clear_flag value (a String or an Array of Strings) as a list.
static func flag_list(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if value is Array:
		for flag: Variant in value:
			out.append(String(flag))
	elif String(value) != "":
		out.append(String(value))
	return out


const KEYS: Array[String] = [
	"qi", "alignment", "items", "breakthrough_bonus", "breakthrough_realm", "set_flag", "clear_flag",
	"learn_technique", "heal_injury", "burn_lifespan", "extend_lifespan", "learn_recipe", "dao_insight",
	"buff", "reputation", "witnessed", "attributes", "bloodline",
]


## Problems with an effects block from data: unknown keys and unknown ids.
## `where` names the block in each message.
static func validate(data: GameData, effects: Dictionary, where: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key: Variant in effects:
		if not KEYS.has(String(key)):
			errors.append("%s: unknown effect key '%s'" % [where, key])
	for item_id: Variant in effects.get("items", {}):
		if not data.items.has(String(item_id)):
			errors.append("%s: unknown item '%s'" % [where, item_id])
	if effects.has("learn_technique") and not data.techniques.has(String(effects["learn_technique"])):
		errors.append("%s: unknown technique '%s'" % [where, effects["learn_technique"]])
	if effects.has("learn_recipe") and not data.recipes.has(String(effects["learn_recipe"])):
		errors.append("%s: unknown recipe '%s'" % [where, effects["learn_recipe"]])
	if effects.has("heal_injury"):
		var injury := String(effects["heal_injury"])
		if injury != "all" and not data.injuries.has(injury):
			errors.append("%s: unknown injury '%s'" % [where, injury])
	if effects.has("dao_insight") and not data.dao_insights.has(String(effects["dao_insight"])):
		errors.append("%s: unknown dao insight '%s'" % [where, effects["dao_insight"]])
	if effects.has("bloodline") and not data.bloodlines.has(String(effects["bloodline"])):
		errors.append("%s: unknown bloodline '%s'" % [where, effects["bloodline"]])
	if effects.has("breakthrough_realm") and data.realm_index_of(String(effects["breakthrough_realm"])) < 0:
		errors.append("%s: unknown realm '%s'" % [where, effects["breakthrough_realm"]])
	for sect_id: Variant in effects.get("reputation", {}):
		if not data.sects.has(String(sect_id)):
			errors.append("%s: unknown sect '%s' in reputation" % [where, sect_id])
	var attribute_ids: Array[String] = []
	for attr: Dictionary in data.attributes:
		attribute_ids.append(String(attr.get("id", "")))
	for attr_id: Variant in effects.get("attributes", {}):
		if not attribute_ids.has(String(attr_id)):
			errors.append("%s: unknown attribute '%s'" % [where, attr_id])
	for key in ["set_flag", "clear_flag"]:
		if not effects.has(key):
			continue
		var value: Variant = effects[key]
		var names: Array = value if value is Array else [value]
		var ok := not names.is_empty()
		for flag: Variant in names:
			if not (flag is String) or String(flag) == "":
				ok = false
		if not ok:
			errors.append("%s: %s must be a non-empty String or an Array of non-empty Strings" % [where, key])
	return errors


static func _has_healable(c: CharacterData, injury_id: String) -> bool:
	return c.injuries.has(injury_id) or (injury_id == "all" and Injuries.has_any(c))
