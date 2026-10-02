class_name SpiritualRoots
extends RefCounted
## Spiritual root generation and the cultivation-speed multiplier they grant.
## Roots are stored as {element_id: purity}.


static func roll(data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var weights := PackedFloat32Array()
	for g in data.root_grades:
		weights.append(float(g["weight"]))
	var grade: Dictionary = data.root_grades[rng.rand_weighted(weights)]
	var ids: Array = data.root_elements.map(func(e): return e["id"])
	# Fisher-Yates with our own rng so rolls are reproducible from a seed.
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var roots := {}
	for i in mini(int(grade["element_count"]), ids.size()):
		roots[ids[i]] = rng.randi_range(data.root_purity_min, data.root_purity_max)
	return roots


static func grade_for(roots: Dictionary, data: GameData) -> Dictionary:
	for g in data.root_grades:
		if int(g["element_count"]) == roots.size():
			return g
	return {}


static func average_purity(roots: Dictionary) -> float:
	if roots.is_empty():
		return 0.0
	var total := 0.0
	for p in roots.values():
		total += p
	return total / roots.size()


## 0.0 means the character cannot cultivate at all.
static func cultivation_multiplier(roots: Dictionary, data: GameData) -> float:
	var grade := grade_for(roots, data)
	if grade.is_empty():
		return 0.0
	return float(grade["cultivation_multiplier"]) * (0.5 + average_purity(roots) / 100.0)


static func describe(roots: Dictionary, data: GameData) -> String:
	if roots.is_empty():
		return "No Spiritual Root"
	var names := {}
	for e in data.root_elements:
		names[e["id"]] = e["name"]
	var parts: PackedStringArray = []
	for element_id in roots:
		parts.append("%s %d" % [names.get(element_id, element_id), roots[element_id]])
	return "%s (%s)" % [grade_for(roots, data).get("name", "Unknown Root"), ", ".join(parts)]
