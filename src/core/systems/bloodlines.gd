class_name Bloodlines
extends RefCounted
## Bloodlines (FAM-007), defined in data/bloodlines.json: rare traits passed
## from parents to children. A bloodline lies dormant until its bearer reaches
## the bloodline's awaken_realm, then grants its bonuses (cultivation speed,
## breakthrough chance, combat stats). Stored as CharacterData.bloodline (id)
## and CharacterData.bloodline_awakened.

const BONUS_KEYS := ["qi_mult", "breakthrough", "max_hp", "attack", "defense", "speed"]


static func def(data: GameData, id: String) -> Dictionary:
	return data.bloodlines.get(id, {})


static func bloodline_name(data: GameData, id: String) -> String:
	return String(def(data, id).get("name", id))


## The bonus `key` that `c`'s awakened bloodline grants (0 if none or dormant).
static func bonus(c: CharacterData, data: GameData, key: String) -> float:
	if c.bloodline == "" or not c.bloodline_awakened:
		return 0.0
	return float(def(data, c.bloodline).get("bonuses", {}).get(key, 0.0))


## The bloodline a child of `mother` and `father` is born with ("" = none).
static func inherit(mother: CharacterData, father: CharacterData, data: GameData, rng: RandomNumberGenerator) -> String:
	var carried: Array[String] = []
	for parent: CharacterData in [mother, father]:
		if parent.bloodline != "" and data.bloodlines.has(parent.bloodline) and not carried.has(parent.bloodline):
			carried.append(parent.bloodline)
	var both := carried.size() == 1 and mother.bloodline == father.bloodline
	var chance := float(data.bloodline_rules.get("inherit_chance_both" if both else "inherit_chance_one", 0.0))
	if carried.size() == 2 and rng.randf() < 0.5:
		carried.reverse()
	for id in carried:
		if rng.randf() < chance:
			return id
	var ids: Array = data.bloodlines.keys()
	ids.sort()
	for id in ids:
		if rng.randf() < float(data.bloodlines[id].get("rarity", 0.0)):
			return String(id)
	return ""


## Awakens `c`'s dormant bloodline once they reach its realm. Returns true if it awoke now.
static func update(c: CharacterData, data: GameData) -> bool:
	if c.bloodline == "" or c.bloodline_awakened or not data.bloodlines.has(c.bloodline):
		return false
	if c.realm_index < data.realm_index_of(String(def(data, c.bloodline).get("awaken_realm", "mortal"))):
		return false
	c.bloodline_awakened = true
	return true


## e.g. "Azure Dragon Bloodline (dormant until Foundation Establishment)", or "" without one.
static func describe(c: CharacterData, data: GameData) -> String:
	if c.bloodline == "" or not data.bloodlines.has(c.bloodline):
		return ""
	if c.bloodline_awakened:
		return "%s (awakened)" % bloodline_name(data, c.bloodline)
	var realm := data.realm_index_of(String(def(data, c.bloodline).get("awaken_realm", "mortal")))
	return "%s (dormant until %s)" % [bloodline_name(data, c.bloodline), data.realms[realm].name]


## Load errors for data/bloodlines.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key in ["inherit_chance_one", "inherit_chance_both"]:
		var chance := float(data.bloodline_rules.get(key, 0.0))
		if chance < 0.0 or chance > 1.0:
			errors.append("bloodlines.json %s must be within 0..1" % key)
	for id in data.bloodlines:
		var b: Dictionary = data.bloodlines[id]
		if String(b.get("name", "")) == "":
			errors.append("Bloodline '%s' needs a name" % id)
		if data.realm_index_of(String(b.get("awaken_realm", ""))) < 0:
			errors.append("Bloodline '%s' has unknown awaken_realm" % id)
		var rarity := float(b.get("rarity", 0.0))
		if rarity < 0.0 or rarity > 1.0:
			errors.append("Bloodline '%s' rarity must be within 0..1" % id)
		for key in b.get("bonuses", {}):
			if not BONUS_KEYS.has(String(key)):
				errors.append("Bloodline '%s' has unknown bonus '%s'" % [id, key])
	for npc: Dictionary in data.npcs.values():
		if npc.has("bloodline") and not data.bloodlines.has(String(npc["bloodline"])):
			errors.append("NPC '%s' has unknown bloodline '%s'" % [npc["id"], npc["bloodline"]])
	return errors
