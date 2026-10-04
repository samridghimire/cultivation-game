class_name NpcFamilies
extends RefCounted
## Off-screen family life of NPCs (FAM-003d), tuned by data/family.json
## "npc_families". Each month, unmarried generated NPCs may marry an unrelated
## eligible NPC of their region, married NPC couples may try for a child
## (Children.try_conceive) and due NPC pregnancies give birth
## (Children.give_birth). Conception and marriage stop while the living NPC
## population is at `population_cap`. Couples involving the player are left to GameState.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("npc_families", {})


## Living NPCs in `npcs`.
static func population(npcs: Dictionary) -> int:
	var count := 0
	for c: CharacterData in npcs.values():
		if c.alive:
			count += 1
	return count


## Whether `a` and `b` are parent and child or share a parent.
static func are_related(a: CharacterData, b: CharacterData) -> bool:
	if a.parents.has(b.id) or b.parents.has(a.id):
		return true
	for parent_id in a.parents:
		if b.parents.has(parent_id):
			return true
	return false


## Whether `a` and `b` may marry off-screen: both eligible generated NPCs
## (Npcs.is_eligible), neither `reserved` (e.g. NPCs the player knows), of
## partner genders and unrelated.
static func can_match(a: CharacterData, b: CharacterData, data: GameData, reserved: Dictionary) -> bool:
	if a == b or reserved.has(a.id) or reserved.has(b.id):
		return false
	if not Npcs.is_eligible(a, data) or not Npcs.is_eligible(b, data):
		return false
	if not (Family.gender_rules(data, a.gender).get("partner_genders", []) as Array).has(b.gender):
		return false
	return not are_related(a, b)


## The rank an off-screen marriage gets: the first rank of the partner who
## does not carry children (e.g. "wife"), else `a`'s first rank.
static func marriage_rank(a: CharacterData, b: CharacterData, data: GameData) -> String:
	var carrier := Children.carrier_of(a, b, data)
	var giver := b if carrier == a else a
	var ranks := Family.ranks(data, giver.gender)
	return ranks[0] if not ranks.is_empty() else ""


## Lives `days` of family life for every NPC, a month at a time. NPCs in
## `reserved` (id -> anything) never marry off-screen. Returns events as
## [{npc_id, text, category, kind}] with kind "marriage" or "birth".
static func simulate(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator, reserved: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if rules(data).is_empty():
		return events
	var remaining := days
	while remaining > 0:
		var step := mini(remaining, Npcs.STEP_DAYS)
		remaining -= step
		_births(npcs, data, step, remaining, rng, events)
		_conceptions(npcs, data, step, rng)
		_marriages(npcs, data, step, rng, reserved, events)
	return events


static func _marriages(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator, reserved: Dictionary, events: Array[Dictionary]) -> void:
	var chance := float(rules(data).get("marriage_chance_per_year", 0.0)) * days / Calendar.DAYS_PER_YEAR
	# Each off-screen marriage makes GameState spawn new courtship candidates
	# (Npcs.ensure_eligible), so a full world must not marry either (FAM-013).
	if chance <= 0.0 or population(npcs) >= int(rules(data).get("population_cap", 0)):
		return
	var by_region := {}
	for c: CharacterData in npcs.values():
		if Npcs.is_eligible(c, data) and not reserved.has(c.id):
			var region := Npcs.region_of(c, data)
			if not by_region.has(region):
				by_region[region] = []
			by_region[region].append(c)
	for region in by_region:
		var singles: Array = by_region[region]
		for a: CharacterData in singles:
			if not Npcs.is_eligible(a, data) or rng.randf() >= chance:
				continue
			var partners := singles.filter(func(b: CharacterData) -> bool: return can_match(a, b, data, reserved))
			if partners.is_empty():
				continue
			var b: CharacterData = partners[rng.randi_range(0, partners.size() - 1)]
			Family.marry(a, b, marriage_rank(a, b, data))
			events.append({"npc_id": a.id, "text": "%s and %s are married." % [a.name, b.name], "category": "info", "kind": "marriage"})


static func _conceptions(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator) -> void:
	var r := rules(data)
	var chance := float(r.get("attempt_chance_per_month", 0.0)) * days / Calendar.DAYS_PER_MONTH
	if chance <= 0.0 or population(npcs) >= int(r.get("population_cap", 0)):
		return
	var carrier_gender := String(Children.rules(data).get("carrier_gender", ""))
	for mother: CharacterData in npcs.values():
		if not mother.alive or mother.gender != carrier_gender or Children.is_pregnant(mother):
			continue
		if mother.children.size() >= int(r.get("max_children", 0)):
			continue
		for spouse_id in Family.living_spouses(mother, npcs):
			var father: CharacterData = npcs.get(spouse_id)
			if father == null or rng.randf() >= chance:
				continue  # the player's own marriages are GameState's business
			Children.try_conceive(mother, father, data, rng)
			break


## Due NPC pregnancies give birth. A child born with `left` days of the
## simulated span remaining has already lived those days.
static func _births(npcs: Dictionary, data: GameData, days: int, left: int, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
	var due: Array[CharacterData] = []
	for mother: CharacterData in npcs.values():
		var father: CharacterData = npcs.get(String(mother.pregnancy.get("partner", "")))
		if mother.alive and father != null and Children.advance_pregnancy(mother, days):
			due.append(mother)
	for mother in due:
		var father: CharacterData = npcs[String(mother.pregnancy["partner"])]
		var child := Children.give_birth(mother, father, npcs, data, rng, Npcs.region_of(mother, data))
		child.age_days = left
		events.append({"npc_id": mother.id, "text": "%s gives birth to %s." % [mother.name, child.name], "category": "info", "kind": "birth"})


## Load errors for data/family.json "npc_families" (optional block).
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	for key in ["marriage_chance_per_year", "attempt_chance_per_month"]:
		var chance := float(r.get(key, -1.0))
		if chance < 0.0 or chance > 1.0:
			errors.append("family.json npc_families.%s must be within 0..1" % key)
	if int(r.get("max_children", -1)) < 0 or int(r.get("population_cap", -1)) < 0:
		errors.append("family.json npc_families needs max_children and population_cap >= 0")
	return errors
