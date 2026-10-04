class_name Rivals
extends RefCounted
## The player's named rival (RIV-002): a generated NPC of the player's age with
## a strong root and high diligence, so it climbs the realms faster than most.
## CharacterData.rival holds its id. Encounters with a `rival` condition
## ("any", "stronger", "equal", "weaker": the rival's major realm compared to
## the player's) only happen while the rival lives; their text may use
## {rival} and {rival_realm}. Rules live in data/karma.json "rival".

const RELATIONS: Array[String] = ["any", "stronger", "equal", "weaker"]


static func rules(data: GameData) -> Dictionary:
	return data.karma.get("rival", {})


## Spawns `c`'s rival in `region_id` and remembers it. Returns the rival.
static func spawn(c: CharacterData, people: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String) -> CharacterData:
	var r := rules(data)
	var purity: Array = r.get("root_purity", [70, 90])
	var elements: Array = data.root_elements.map(func(e: Dictionary) -> String: return String(e["id"]))
	var element := String(elements[rng.randi_range(0, elements.size() - 1)]) if not elements.is_empty() else "fire"
	var rival := Npcs.spawn(people, data, rng, {
		"age_years": maxi(c.age_years(), 1),
		"roots": {element: rng.randi_range(int(purity[0]), int(purity[1]))},
		"realm": data.realms[c.realm_index].id,
		"stage": c.stage,
		"region": region_id,
		"diligence": float(r.get("diligence", 0.6)),
		"proud": bool(r.get("proud", true)),
	})
	c.rival = rival.id
	return rival


## `c`'s living rival, or null.
static func rival_of(c: CharacterData, people: Dictionary) -> CharacterData:
	if c == null or c.rival == "":
		return null
	var rival: CharacterData = people.get(c.rival)
	return rival if rival != null and rival.alive else null


## "stronger", "equal" or "weaker": the rival's major realm against `c`'s.
static func relation(c: CharacterData, rival: CharacterData) -> String:
	if rival.realm_index > c.realm_index:
		return "stronger"
	if rival.realm_index < c.realm_index:
		return "weaker"
	return "equal"


## Whether an encounter's `rival` condition holds (no condition = always).
static func allows(c: CharacterData, rival: CharacterData, condition: String) -> bool:
	if condition == "":
		return true
	if rival == null:
		return false
	return condition == "any" or relation(c, rival) == condition


## Fills {rival} and {rival_realm} in encounter text.
static func fill(text: String, rival: CharacterData, data: GameData) -> String:
	if rival == null or not text.contains("{rival"):
		return text
	return text.replace("{rival_realm}", Cultivation.realm_label(rival, data)).replace("{rival}", rival.name)


## Load errors for the rival rules and encounter rival fields.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if not r.is_empty():
		var purity: Array = r.get("root_purity", [])
		if purity.size() != 2 or int(purity[0]) > int(purity[1]) or int(purity[0]) < 1:
			errors.append("karma.json rival root_purity must be [min, max] with 1 <= min <= max")
		if float(r.get("diligence", 0.0)) <= 0.0 or float(r.get("diligence", 0.0)) > 1.0:
			errors.append("karma.json rival diligence must be in (0, 1]")
	for e: Dictionary in data.encounters.values():
		if e.has("rival") and not RELATIONS.has(String(e["rival"])):
			errors.append("Encounter '%s' has unknown rival condition '%s'" % [e["id"], e["rival"]])
		var uses_rival := e.has("fight_rival") or e.has("rival_grudge") or e.has("rival_favor") or String(e.get("text", "")).contains("{rival")
		for choice: Dictionary in e.get("choices", []):
			uses_rival = uses_rival or choice.has("fight_rival") or choice.has("rival_grudge") or choice.has("rival_favor") or String(choice.get("text", "")).contains("{rival") or String(choice.get("label", "")).contains("{rival")
			if choice.has("fight_rival") and choice.has("enemy"):
				errors.append("Encounter '%s' choice '%s' cannot fight both an enemy and the rival" % [e["id"], choice.get("label", "")])
		if uses_rival and not e.has("rival"):
			errors.append("Encounter '%s' involves the rival but has no rival condition" % e["id"])
		if e.has("fight_rival") and e.has("enemy"):
			errors.append("Encounter '%s' cannot fight both an enemy and the rival" % e["id"])
	return errors
