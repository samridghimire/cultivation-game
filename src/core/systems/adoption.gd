class_name Adoption
extends RefCounted
## Adoption (FAM-003b), tuned by data/family.json "adoption". An adult can take
## in an orphaned child NPC (no living parents) or a foundling from an
## orphanage/temple (a newly generated child, for a donation). Adopted children
## join the adopter's `children`, list the adopter among their `parents` (after
## any late birth parents) and get birth_rank "" (adopted, see CharacterData).
## This lets couples who cannot conceive (Children.carrier_of) grow a family.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("adoption", {})


static func is_adopted(child: CharacterData) -> bool:
	return child.birth_rank == ""


## Whether none of `child`'s parents are alive. `c` (the would-be adopter) is
## looked up directly since the player is not in `npcs`.
static func is_orphan(child: CharacterData, npcs: Dictionary) -> bool:
	for parent_id in child.parents:
		var parent: CharacterData = npcs.get(parent_id)
		if parent != null and parent.alive:
			return false
	return true


## How many of `c`'s children are adopted.
static func adopted_count(c: CharacterData, npcs: Dictionary) -> int:
	var count := 0
	for child_id in c.children:
		var child: CharacterData = npcs.get(child_id)
		if child != null and is_adopted(child):
			count += 1
	return count


## Why `c` cannot adopt anyone right now ("" if they can, as far as `c` goes).
static func check_adopter(c: CharacterData, npcs: Dictionary, data: GameData) -> String:
	if rules(data).is_empty():
		return "Adoption is not possible here."
	if c.age_years() < int(data.family.get("adult_age", 16)):
		return "You are too young to raise a child."
	if adopted_count(c, npcs) >= int(rules(data).get("max_adopted", 0)):
		return "You cannot take in any more children."
	return ""


## Why `c` cannot adopt `child`, or "" if they can.
static func check_adoption(c: CharacterData, child: CharacterData, npcs: Dictionary, data: GameData) -> String:
	if child == null or not child.alive or child == c:
		return "There is no child to adopt."
	var reason := check_adopter(c, npcs, data)
	if reason != "":
		return reason
	if child.parents.has(c.id) or c.children.has(child.id):
		return "%s is already your child." % child.name
	if child.age_years() > int(rules(data).get("max_age", 12)):
		return "%s is too old to be adopted." % child.name
	if not is_orphan(child, npcs):
		return "%s already has a family." % child.name
	return ""


## `c` adopts the orphan `child`. Returns {ok, reason, days, alignment, favor}:
## alignment is the shift applied to `c`, favor the child's starting favor.
static func adopt(c: CharacterData, child: CharacterData, npcs: Dictionary, data: GameData) -> Dictionary:
	var reason := check_adoption(c, child, npcs, data)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0, "alignment": 0, "favor": 0}
	return _take_in(c, child, data)


## Why `c` cannot adopt a foundling now, or "" if they can.
static func check_foundling(c: CharacterData, npcs: Dictionary, data: GameData) -> String:
	var reason := check_adopter(c, npcs, data)
	if reason != "":
		return reason
	var donation := foundling_donation(data)
	if c.item_count("spirit_stone") < donation:
		return "The caretakers ask a donation of %d spirit stones for the child's upkeep." % donation
	return ""


static func foundling_donation(data: GameData) -> int:
	return int(rules(data).get("foundling_donation", 0))


## `c` adopts a newly generated foundling in `region` for the donation.
## Returns {ok, reason, child, days, alignment, favor, donation}.
static func adopt_foundling(c: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region: String) -> Dictionary:
	var reason := check_foundling(c, npcs, data)
	if reason != "":
		return {"ok": false, "reason": reason, "child": null, "days": 0, "alignment": 0, "favor": 0, "donation": 0}
	var r := rules(data)
	var child := Npcs.spawn(npcs, data, rng, {
		"age_years": rng.randi_range(int(r.get("foundling_age_min", 0)), int(r.get("foundling_age_max", 6))),
		"region": region,
		"alignment": 0,
		"cultivates": true,
	})
	var donation := foundling_donation(data)
	c.add_item("spirit_stone", -donation)
	var result := _take_in(c, child, data)
	result["child"] = child
	result["donation"] = donation
	return result


static func _take_in(c: CharacterData, child: CharacterData, data: GameData) -> Dictionary:
	var r := rules(data)
	child.parents.append(c.id)
	if not c.children.has(child.id):
		c.children.append(child.id)
	child.birth_rank = ""
	if bool(r.get("take_surname", false)) and c.surname != "":
		Names.apply(child, c.surname, child.given_name)
	var shift := int(r.get("alignment", 0))
	Alignment.shift(c, data, shift)
	return {"ok": true, "reason": "", "days": int(r.get("days", 1)), "alignment": shift, "favor": int(r.get("favor", 0))}


## Load errors for data/family.json "adoption" (optional block).
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	if int(r.get("days", 0)) < 1:
		errors.append("family.json adoption.days must be >= 1")
	if int(r.get("max_adopted", 0)) < 1:
		errors.append("family.json adoption.max_adopted must be >= 1")
	var max_age := int(r.get("max_age", -1))
	if max_age < 0 or max_age >= int(data.family.get("adult_age", 16)):
		errors.append("family.json adoption.max_age must be within 0..adult_age-1")
	var age_min := int(r.get("foundling_age_min", -1))
	var age_max := int(r.get("foundling_age_max", -1))
	if age_min < 0 or age_max < age_min or age_max > max_age:
		errors.append("family.json adoption needs 0 <= foundling_age_min <= foundling_age_max <= max_age")
	if foundling_donation(data) < 0 or int(r.get("favor", 0)) < 0:
		errors.append("family.json adoption.foundling_donation and favor must be >= 0")
	return errors
