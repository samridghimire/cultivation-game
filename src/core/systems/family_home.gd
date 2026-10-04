class_name FamilyHome
extends RefCounted
## The Family Home (FAM-011, data/family.json "home"): a house drawn in every
## region where the player's living spouses or children live (regions.json
## "family_home"), with the family standing at the NPC spots nearest to it.
## Spending time there raises their favor; the household can be gathered under
## one roof by moving spouses and minor children there.


static func _rules(data: GameData) -> Dictionary:
	return data.family.get("home", {})


## The player's living spouses and children (ids in that order).
static func household(c: CharacterData, people: Dictionary) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in c.spouses + c.children:
		var person: CharacterData = people.get(id)
		if person != null and person.alive and not out.has(person):
			out.append(person)
	return out


## Region ids (sorted) where at least one of `c`'s living spouses or children lives.
static func regions(c: CharacterData, people: Dictionary, data: GameData) -> Array[String]:
	var out: Array[String] = []
	for person in household(c, people):
		var region := Npcs.region_of(person, data)
		if region != "" and not out.has(region):
			out.append(region)
	out.sort()
	return out


## `c`'s living spouses and children who live in `region_id`.
static func at_home(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	out.assign(household(c, people).filter(func(p: CharacterData) -> bool: return Npcs.region_of(p, data) == region_id))
	return out


## Whether a Family Home stands in `region_id` for `c`.
static func has_home(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> bool:
	return data.regions.get(region_id, {}).has("family_home") and not at_home(c, people, data, region_id).is_empty()


## Why `c` cannot spend time at home in `region_id`, or "".
static func check_visit(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> String:
	if at_home(c, people, data, region_id).is_empty():
		return "None of your family lives here."
	return ""


## Spend home.visit_days with the family in `region_id`: each of them gains
## home.visit_favor (spouses up to dual_cultivation.max_favor, children up to
## home.max_child_favor). `favor` (npc id -> favor) is updated in place.
## Returns {ok, reason, days, gains: {id: favor gained}}.
static func visit(c: CharacterData, people: Dictionary, favor: Dictionary, data: GameData, region_id: String) -> Dictionary:
	var reason := check_visit(c, people, data, region_id)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0, "gains": {}}
	var gain := int(_rules(data).get("visit_favor", 0))
	var child_cap := int(_rules(data).get("max_child_favor", 100))
	var gains := {}
	for person in at_home(c, people, data, region_id):
		var before := int(favor.get(person.id, 0))
		var after := Family.add_spouse_favor(data, before, gain) if c.spouses.has(person.id) else maxi(before, mini(child_cap, before + gain))
		favor[person.id] = after
		gains[person.id] = after - before
	return {"ok": true, "reason": "", "days": int(_rules(data).get("visit_days", 1)), "gains": gains}


## Family who would move to `region_id`: living spouses and children under
## family.json adult_age whose home is elsewhere.
static func movers(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var adult := int(data.family.get("adult_age", 16))
	var out: Array[CharacterData] = []
	out.assign(household(c, people).filter(func(p: CharacterData) -> bool:
		return Npcs.region_of(p, data) != region_id and (c.spouses.has(p.id) or p.age_years() < adult)))
	return out


## Why `c` cannot bring the household to the home in `region_id`, or "".
static func check_move(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> String:
	if not data.regions.has(region_id):
		return "No such place."
	if not has_home(c, people, data, region_id):
		return "Your family has no home here."
	if movers(c, people, data, region_id).is_empty():
		return "Your whole household already lives here."
	return ""


## Moves every mover home to `region_id`. Returns {ok, reason, days, moved: [ids]}.
static func move_household(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> Dictionary:
	var reason := check_move(c, people, data, region_id)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0, "moved": []}
	var moved: Array[String] = []
	for person in movers(c, people, data, region_id):
		person.home_region = region_id
		moved.append(person.id)
	return {"ok": true, "reason": "", "days": int(_rules(data).get("move_days", 1)), "moved": moved}


## Splits NPC `positions` between the player's family (the `family_count`
## positions nearest `home_pos`) and everyone else (the rest, in order).
## Returns [family positions, other positions].
static func split_spots(positions: Array[Vector2], family_count: int, home_pos: Vector2) -> Array:
	var order: Array = range(positions.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := positions[a].distance_squared_to(home_pos)
		var db := positions[b].distance_squared_to(home_pos)
		return da < db if da != db else a < b)
	var family_idx: Array = order.slice(0, family_count)
	var family: Array[Vector2] = []
	for i in family_idx:
		family.append(positions[i])
	var others: Array[Vector2] = []
	for i in positions.size():
		if not family_idx.has(i):
			others.append(positions[i])
	return [family, others]


## Load errors for family.json "home" and regions.json "family_home".
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var rules := _rules(data)
	if not rules.is_empty():
		for key in ["visit_days", "move_days"]:
			if int(rules.get(key, 0)) < 1:
				errors.append("family.json home.%s must be at least 1" % key)
		if int(rules.get("visit_favor", 0)) < 0 or int(rules.get("max_child_favor", 0)) < 1:
			errors.append("family.json home needs visit_favor >= 0 and max_child_favor >= 1")
	for region_id in data.regions:
		var home: Variant = data.regions[region_id].get("family_home")
		if home == null:
			continue
		if not (home is Dictionary) or (home as Dictionary).get("pos", []).size() != 2 or (home as Dictionary).get("size", [90, 64]).size() != 2:
			errors.append("regions.json region '%s' family_home needs pos [x, y] and size [w, h]" % region_id)
	return errors
