class_name Bloodlines
extends RefCounted
## Bloodlines (FAM-007), defined in data/bloodlines.json: rare traits passed
## from parents to children. A bloodline lies dormant until its bearer reaches
## the bloodline's awaken_realm, then grants its bonuses (cultivation speed,
## breakthrough chance, combat stats). Attribute bonuses (an attribute id as the
## bonus key, in points, FAM-007d) are added to the bearer's attributes once,
## when the bloodline awakens; `alignment_drift` shifts an awakened bearer's
## alignment by that much each year. Stored as CharacterData.bloodline (id)
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


## A random bloodline weighted by rarity (rarer ones come up less often), for
## generated NPCs that roll family.json eligible_npcs.bloodline_chance.
static func roll_any(data: GameData, rng: RandomNumberGenerator) -> String:
	var ids: Array = data.bloodlines.keys()
	ids.sort()
	var total := 0.0
	for id in ids:
		total += float(data.bloodlines[id].get("rarity", 0.0))
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for id in ids:
		roll -= float(data.bloodlines[id].get("rarity", 0.0))
		if roll < 0.0:
			return String(id)
	return String(ids.back())


## Gives `c` bloodline `id` if they have none (the `bloodline` effect), awakening
## it at once if they already stand at its realm. Returns true if granted.
static func grant(c: CharacterData, data: GameData, id: String) -> bool:
	if c.bloodline != "" or not data.bloodlines.has(id):
		return false
	c.bloodline = id
	c.bloodline_awakened = false
	update(c, data)
	return true


## Awakens `c`'s dormant bloodline once they reach its realm. Returns true if it awoke now.
static func update(c: CharacterData, data: GameData) -> bool:
	if c.bloodline == "" or c.bloodline_awakened or not data.bloodlines.has(c.bloodline):
		return false
	if c.realm_index < data.realm_index_of(String(def(data, c.bloodline).get("awaken_realm", "mortal"))):
		return false
	c.bloodline_awakened = true
	for key in def(data, c.bloodline).get("bonuses", {}):
		if data.attribute_ids().has(String(key)):
			c.attributes[key] = c.attribute(String(key)) + int(def(data, c.bloodline)["bonuses"][key])
	return true


## Attribute points `id`'s bonuses add on awakening: {attribute id: points}.
static func attribute_bonuses(data: GameData, id: String) -> Dictionary:
	var out := {}
	var bonuses: Dictionary = def(data, id).get("bonuses", {})
	for key in bonuses:
		if data.attribute_ids().has(String(key)):
			out[String(key)] = int(bonuses[key])
	return out


## Alignment shift an awakened bloodline applies to `c` between two ages
## (in days): alignment_drift per whole year crossed.
@warning_ignore("integer_division")
static func drift_amount(c: CharacterData, data: GameData, age_days_before: int, age_days_after: int) -> int:
	if c.bloodline == "" or not c.bloodline_awakened:
		return 0
	var drift := int(def(data, c.bloodline).get("alignment_drift", 0))
	var years := age_days_after / Calendar.DAYS_PER_YEAR - age_days_before / Calendar.DAYS_PER_YEAR
	return drift * maxi(0, years)


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
			if not BONUS_KEYS.has(String(key)) and not data.attribute_ids().has(String(key)):
				errors.append("Bloodline '%s' has unknown bonus '%s'" % [id, key])
			elif data.attribute_ids().has(String(key)) and float(b["bonuses"][key]) != floorf(float(b["bonuses"][key])):
				errors.append("Bloodline '%s' attribute bonus '%s' must be whole points" % [id, key])
		if b.has("alignment_drift") and absi(int(b["alignment_drift"])) > 200:
			errors.append("Bloodline '%s' alignment_drift must be within -200..200 per year" % id)
	for npc: Dictionary in data.npcs.values():
		if npc.has("bloodline") and not data.bloodlines.has(String(npc["bloodline"])):
			errors.append("NPC '%s' has unknown bloodline '%s'" % [npc["id"], npc["bloodline"]])
	var eligible_chance := float(data.family.get("eligible_npcs", {}).get("bloodline_chance", 0.0))
	if eligible_chance < 0.0 or eligible_chance > 1.0:
		errors.append("family.json eligible_npcs bloodline_chance must be within 0..1")
	var sources := {}
	for item: Dictionary in data.items.values():
		sources["Item '%s'" % item["id"]] = item.get("effects", {})
	for e: Dictionary in data.encounters.values():
		sources["Encounter '%s'" % e["id"]] = e.get("effects", {})
		for choice: Dictionary in e.get("choices", []):
			sources["Encounter '%s' choice '%s'" % [e["id"], choice.get("label", "")]] = choice.get("effects", {})
	for source: String in sources:
		var effects: Dictionary = sources[source]
		if effects.has("bloodline") and not data.bloodlines.has(String(effects["bloodline"])):
			errors.append("%s grants unknown bloodline '%s'" % [source, effects["bloodline"]])
	return errors
