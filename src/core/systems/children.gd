class_name Children
extends RefCounted
## Children and inheritance (FAM-003), tuned by data/family.json "children".
## Married couples try for a child; on conception the carrying partner (the
## `carrier_gender` one) tracks the pregnancy on their own CharacterData, so
## several spouses can be pregnant at once. At birth a new NPC is created whose
## spiritual roots and attributes mix both parents' with random variation
## (rarely a genius). Children cannot cultivate before `cultivation_start_age`.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("children", {})


static func is_pregnant(c: CharacterData) -> bool:
	return not c.pregnancy.is_empty()


## Of a couple, the partner who would carry the child (null if neither can).
static func carrier_of(a: CharacterData, b: CharacterData, data: GameData) -> CharacterData:
	var gender := String(rules(data).get("carrier_gender", ""))
	if a.gender == gender and b.gender != gender:
		return a
	if b.gender == gender and a.gender != gender:
		return b
	return null


static func cultivation_start_age(data: GameData) -> int:
	return int(rules(data).get("cultivation_start_age", 6))


## Ids of `c`'s children, grandchildren and so on (looked up in `people`).
static func descendants(c: CharacterData, people: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var queue: Array[String] = c.children.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if out.has(id):
			continue
		out.append(id)
		var descendant: CharacterData = people.get(id)
		if descendant != null:
			queue.append_array(descendant.children)
	return out


## Whether `c` is old enough to start cultivating.
static func can_cultivate_yet(c: CharacterData, data: GameData) -> bool:
	return c.age_years() >= cultivation_start_age(data)


## Why `c` and `spouse` cannot try for a child now, or "" if they can.
static func check_conception(c: CharacterData, spouse: CharacterData, data: GameData) -> String:
	if spouse == null or not spouse.alive:
		return "There is no one to start a family with."
	if not Family.is_married_to(c, spouse):
		return "Only married couples may try for a child."
	var carrier := carrier_of(c, spouse, data)
	if carrier == null:
		return "You and %s cannot have a child together. Perhaps adopt." % spouse.name
	if is_pregnant(carrier):
		return "%s already with child." % _subject(c, carrier)
	if carrier.age_years() > int(rules(data).get("max_mortal_carrier_age", 999)) and carrier.realm_index == 0:
		return "%s past the age of bearing children." % _subject(c, carrier)
	return ""


## Spend `conception_days` trying for a child. Returns {ok, reason, conceived, days}.
## On conception the carrier's pregnancy starts.
static func try_conceive(c: CharacterData, spouse: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check_conception(c, spouse, data)
	if reason != "":
		return {"ok": false, "reason": reason, "conceived": false, "days": 0}
	var conceived := rng.randf() < float(rules(data).get("conception_chance", 0.0))
	if conceived:
		var carrier := carrier_of(c, spouse, data)
		var partner := spouse if carrier == c else c
		carrier.pregnancy = {"partner": partner.id, "days_left": int(rules(data).get("pregnancy_days", 300))}
	return {"ok": true, "reason": "", "conceived": conceived, "days": int(rules(data).get("conception_days", 30))}


## Advances `c`'s pregnancy by `days`. Returns true when the child is due.
static func advance_pregnancy(c: CharacterData, days: int) -> bool:
	if not is_pregnant(c):
		return false
	c.pregnancy["days_left"] = int(c.pregnancy.get("days_left", 0)) - days
	return int(c.pregnancy["days_left"]) <= 0


## Spiritual roots for a child of `mother` and `father`. Usually the child takes
## as many elements as one parent (randomly chosen) has, drawn from the
## parents' elements with purities near theirs; mutation_chance shifts the
## count by one and per element can swap in a new element; genius_chance gives
## a single high-purity Heavenly Root regardless of the parents.
static func inherit_roots(mother: CharacterData, father: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var r := rules(data)
	var all_elements: Array = data.root_elements.map(func(e): return String(e["id"]))
	var pool: Array = []
	for parent: CharacterData in [mother, father]:
		for element in parent.spiritual_roots:
			if not pool.has(String(element)):
				pool.append(String(element))
	if rng.randf() < float(r.get("genius_chance", 0.0)):
		var source: Array = pool if not pool.is_empty() else all_elements
		var element: String = source[rng.randi_range(0, source.size() - 1)]
		return {element: rng.randi_range(int(r.get("genius_purity_min", 80)), data.root_purity_max)}
	var count := (mother if rng.randf() < 0.5 else father).spiritual_roots.size()
	var mutation := float(r.get("mutation_chance", 0.0))
	if rng.randf() < mutation:
		count += 1 if rng.randf() < 0.5 else -1
	count = clampi(count, 0, all_elements.size())
	_shuffle(pool, rng)
	var picked: Array = []
	for element in pool:
		if picked.size() >= count:
			break
		if rng.randf() < mutation:
			continue  # this parent element is lost; a new one may take its place
		picked.append(element)
	var others := all_elements.filter(func(e): return not picked.has(e))
	_shuffle(others, rng)
	while picked.size() < count and not others.is_empty():
		picked.append(others.pop_back())
	var variance := int(r.get("purity_variance", 0))
	var roots := {}
	for element in picked:
		var purity := _parent_purity(mother, father, element, data, rng) + rng.randi_range(-variance, variance)
		roots[element] = clampi(purity, data.root_purity_min, data.root_purity_max)
	return roots


## Attributes for a child: the parents' average plus or minus attribute_variance,
## clamped to data/attributes.json roll_min..roll_max widened by the variance.
static func inherit_attributes(mother: CharacterData, father: CharacterData, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var variance := int(rules(data).get("attribute_variance", 0))
	var out := {}
	for attr in data.attributes:
		var attr_id := String(attr["id"])
		var average := roundi((mother.attribute(attr_id) + father.attribute(attr_id)) / 2.0)
		out[attr_id] = clampi(average + rng.randi_range(-variance, variance), maxi(1, int(attr["roll_min"]) - variance), int(attr["roll_max"]) + variance)
	return out


## The pregnant `mother` gives birth to `father`'s child: a new NPC in `npcs`
## (age 0, the father's surname unless he has none, inherited roots and
## attributes) linked to both parents. `birth_rank` records the mother's
## spousal rank, for heir priority. Clears the pregnancy and returns the child.
static func give_birth(mother: CharacterData, father: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region: String) -> CharacterData:
	var surname := father.surname if father.surname != "" else mother.surname
	var child := Npcs.spawn(npcs, data, rng, {
		"surname": surname,
		"age_years": 0,
		"region": region,
		"roots": inherit_roots(mother, father, data, rng),
		"attributes": inherit_attributes(mother, father, data, rng),
		"alignment": 0,
		"cultivates": true,
	})
	child.age_days = 0
	child.parents = [mother.id, father.id]
	child.birth_rank = String(mother.spouse_ranks.get(father.id, ""))
	for parent: CharacterData in [mother, father]:
		if not parent.children.has(child.id):
			parent.children.append(child.id)
	mother.pregnancy = {}
	return child


## Display lines for pregnancies in `c`'s family: `c`'s own and each living
## spouse's (looked up in `people`) where `c` is the other parent, e.g.
## "Mei Lin is with your child (3 months to the birth)".
static func describe_pregnancies(c: CharacterData, people: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if is_pregnant(c):
		var partner: CharacterData = people.get(String(c.pregnancy.get("partner", "")))
		var by := " by %s" % partner.name if partner != null else ""
		out.append("You are with child%s (%s)" % [by, _due_in(c)])
	for spouse_id in Family.living_spouses(c, people):
		var spouse: CharacterData = people.get(spouse_id)
		if spouse != null and is_pregnant(spouse) and String(spouse.pregnancy.get("partner", "")) == c.id:
			out.append("%s is with your child (%s)" % [spouse.name, _due_in(spouse)])
	return out


static func _due_in(carrier: CharacterData) -> String:
	var days := int(carrier.pregnancy.get("days_left", 0))
	return "due any day" if days <= 0 else "%s to the birth" % Calendar.format_duration(days)


## "You are" when `who` is `c`, else "<name> is".
static func _subject(c: CharacterData, who: CharacterData) -> String:
	return "You are" if who == c else who.name + " is"


static func _parent_purity(mother: CharacterData, father: CharacterData, element: String, data: GameData, rng: RandomNumberGenerator) -> int:
	var values: Array[int] = []
	for parent: CharacterData in [mother, father]:
		if parent.spiritual_roots.has(element):
			values.append(int(parent.spiritual_roots[element]))
	if values.is_empty():
		return rng.randi_range(data.root_purity_min, data.root_purity_max)
	var total := 0
	for v in values:
		total += v
	return roundi(float(total) / values.size())


## Fisher-Yates with our own rng so births are reproducible from a seed.
static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


## Load errors for data/family.json "children" (optional block).
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	if not Names.is_gender(data, String(r.get("carrier_gender", ""))):
		errors.append("family.json children.carrier_gender must be a names.json gender")
	if int(r.get("pregnancy_days", 0)) < 1 or int(r.get("conception_days", 0)) < 1:
		errors.append("family.json children needs pregnancy_days >= 1 and conception_days >= 1")
	for key in ["conception_chance", "mutation_chance", "genius_chance"]:
		var chance := float(r.get(key, 0.0))
		if chance < 0.0 or chance > 1.0:
			errors.append("family.json children.%s must be within 0..1" % key)
	if int(r.get("purity_variance", 0)) < 0 or int(r.get("attribute_variance", 0)) < 0 or int(r.get("cultivation_start_age", 0)) < 0:
		errors.append("family.json children variances and cultivation_start_age must be >= 0")
	return errors
