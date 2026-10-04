class_name Appraisal
extends RefCounted
## Creation Artifact function: the Appraising Eye (ART-003a). While it is
## sealed, the player only sees what anyone would see; once unsealed, the
## artifact reads hidden detail for them: an NPC's spiritual root, talent,
## attributes, remaining lifespan and the colour of their heart, and an item's
## grade, power and worth. UI code asks these functions instead of reading the
## data itself, so hidden stats stay hidden until the function is unsealed.
##
## Talent tiers live in the function def in data/artifact.json
## ("talent_tiers": [{min_multiplier, name}], highest matching tier wins).

## The data/artifact.json function id this system implements.
const FUNCTION := "appraisal"


static func is_available(c: CharacterData) -> bool:
	return ArtifactFunctions.is_unlocked(c, FUNCTION)


## Why `c` cannot appraise anything, or "" if they can.
static func check(c: CharacterData, data: GameData) -> String:
	if ArtifactFunctions.get_def(data, FUNCTION).is_empty():
		return "The artifact holds no appraising eye."
	if not is_available(c):
		return "The artifact's appraising eye is still sealed."
	return ""


## Talent tiers of the appraisal function, in data order.
static func talent_tiers(data: GameData) -> Array:
	return ArtifactFunctions.get_def(data, FUNCTION).get("talent_tiers", [])


## Name of the talent tier for a cultivation-speed `multiplier`
## (SpiritualRoots.cultivation_multiplier), or "" if no tier matches.
static func talent_name(data: GameData, multiplier: float) -> String:
	var name := ""
	for tier: Dictionary in talent_tiers(data):
		if multiplier >= float(tier.get("min_multiplier", 0.0)):
			name = String(tier.get("name", ""))
	return name


## "Exceptional (x1.86 cultivation speed)" for `target`.
static func talent_label(target: CharacterData, data: GameData) -> String:
	var multiplier := SpiritualRoots.cultivation_multiplier(target.spiritual_roots, data)
	if multiplier <= 0.0:
		return "%s (cannot cultivate)" % talent_name(data, multiplier)
	return "%s (x%.2f cultivation speed)" % [talent_name(data, multiplier), multiplier]


## Hidden detail about `target` (an NPC or the player), or [] while the
## appraising eye is sealed.
static func describe_npc(c: CharacterData, target: CharacterData, data: GameData) -> Array[String]:
	if check(c, data) != "" or target == null:
		return []
	var lines: Array[String] = []
	lines.append("Realm: %s" % Cultivation.realm_label(target, data))
	lines.append("Spiritual Root: %s" % SpiritualRoots.describe(target.spiritual_roots, data))
	lines.append("Talent: %s" % talent_label(target, data))
	var years := Cultivation.years_left(target, data)
	lines.append("Age: %d (%d %s of life left)" % [target.age_years(), years, "year" if years == 1 else "years"])
	var attributes: PackedStringArray = []
	for attr: Dictionary in data.attributes:
		var attr_id := String(attr["id"])
		attributes.append("%s %d" % [attr.get("name", attr_id), int(target.attributes.get(attr_id, 0))])
	if not attributes.is_empty():
		lines.append("Attributes: %s" % ", ".join(attributes))
	lines.append("Heart: %s (%d)" % [Alignment.tier_name(target.alignment, data), target.alignment])
	return lines


## Hidden detail about `item_id`, or [] while the appraising eye is sealed.
static func describe_item(c: CharacterData, data: GameData, item_id: String) -> Array[String]:
	if check(c, data) != "" or not data.items.has(item_id):
		return []
	var item: Dictionary = data.items[item_id]
	var lines: Array[String] = []
	if Equipment.is_equipment(data, item_id):
		var equip: Dictionary = item["equip"]
		lines.append("Grade %d %s: %s" % [int(equip.get("grade", 1)), equip.get("slot", "artifact"), Equipment.describe_stats(data, item_id)])
	if CombatTalismans.is_combat_talisman(data, item_id):
		var kind := CombatTalismans.kind_of(data, item_id)
		var amount := CombatTalismans.amount(data, item_id)
		var power := "turns a defeat into an escape" if kind == "escape" else "%d at your realm" % amount
		lines.append("Grade %d %s talisman: %s" % [int(CombatTalismans.combat_def(data, item_id).get("grade", 1)), kind, power])
	var price := int(item.get("price", 0))
	lines.append("Worth: %d spirit stones" % price if price > 0 else "Worth: priceless, or worthless; no merchant will name a price")
	return lines


## Load errors for the appraisal function def in data/artifact.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var def := ArtifactFunctions.get_def(data, FUNCTION)
	if def.is_empty():
		return errors
	var tiers: Array = def.get("talent_tiers", [])
	if tiers.is_empty():
		errors.append("artifact.json appraisal needs talent_tiers")
	var previous := -INF
	for tier: Dictionary in tiers:
		if String(tier.get("name", "")) == "":
			errors.append("artifact.json appraisal has a talent tier without a name")
		var minimum := float(tier.get("min_multiplier", 0.0))
		if minimum < previous:
			errors.append("artifact.json appraisal talent_tiers must rise by min_multiplier")
		previous = minimum
	return errors
