class_name Training
extends RefCounted
## Training descendants (FAM-004), tuned by data/family.json "training".
## The player gives each of their children a monthly assignment (kept on the
## child as CharacterData.training = {"assignment": id, "profession": id}).
## Every month the player pays the assignment's spirit stones and the child
## trains: extra cultivation, profession xp, or technique practice. The player
## can also teach a child a technique they know, and give them pills to use.

## Assignment kinds (data/family.json training.assignments.<id>.kind).
const KINDS := ["cultivate", "profession", "technique"]


static func rules(data: GameData) -> Dictionary:
	return data.family.get("training", {})


## Assignment ids, in a stable order.
static func assignments(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for id in rules(data).get("assignments", {}):
		out.append(String(id))
	out.sort()
	return out


static func assignment(data: GameData, id: String) -> Dictionary:
	return rules(data).get("assignments", {}).get(id, {})


static func assignment_name(data: GameData, id: String) -> String:
	return String(assignment(data, id).get("name", id))


static func monthly_cost(data: GameData, id: String) -> int:
	return int(assignment(data, id).get("stones_per_month", 0))


## The child's current assignment id ("" = none).
static func current(child: CharacterData) -> String:
	return String(child.training.get("assignment", ""))


## Why `c` cannot direct `child`'s training at all, or "".
static func check_child(c: CharacterData, child: CharacterData) -> String:
	if child == null or not c.children.has(child.id):
		return "Only your own children can be trained by you."
	if not child.alive:
		return "%s has passed away." % child.name
	return ""


## Why `child` cannot take `assignment_id` (with `profession` for profession
## assignments), or "" if they can.
static func check_assign(c: CharacterData, child: CharacterData, assignment_id: String, profession: String, data: GameData) -> String:
	var reason := check_child(c, child)
	if reason != "":
		return reason
	var a := assignment(data, assignment_id)
	if a.is_empty():
		return "There is no such training."
	if child.age_years() < int(a.get("min_age", 0)):
		return "%s is too young for that (age %d)." % [child.name, int(a.get("min_age", 0))]
	match String(a.get("kind", "")):
		"cultivate":
			if SpiritualRoots.cultivation_multiplier(child.spiritual_roots, data) <= 0.0:
				return "%s has no spiritual roots to cultivate with." % child.name
		"profession":
			if not data.professions.has(profession):
				return "Choose a profession for %s to learn." % child.name
		"technique":
			if child.techniques.is_empty():
				return "%s knows no technique to practice. Teach one first." % child.name
	return ""


## Sets `child`'s assignment. Returns {ok, reason}.
static func assign(c: CharacterData, child: CharacterData, assignment_id: String, profession: String, data: GameData) -> Dictionary:
	var reason := check_assign(c, child, assignment_id, profession, data)
	if reason != "":
		return {"ok": false, "reason": reason}
	child.training = {"assignment": assignment_id}
	if String(assignment(data, assignment_id).get("kind", "")) == "profession":
		child.training["profession"] = profession
	return {"ok": true, "reason": ""}


static func clear(child: CharacterData) -> void:
	child.training = {}


## Why `c` cannot teach `child` the technique now, or "".
static func check_teach(c: CharacterData, child: CharacterData, tech_id: String, data: GameData) -> String:
	var reason := check_child(c, child)
	if reason != "":
		return reason
	if not Techniques.knows(c, tech_id):
		return "You do not know that technique."
	if child.age_years() < int(rules(data).get("teach_min_age", 0)):
		return "%s is too young to be taught techniques." % child.name
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def == null:
		return "There is no such technique."
	if Techniques.knows(child, tech_id):
		return "%s already knows the %s." % [child.name, def.name]
	var min_index := data.realm_index_of(def.min_realm)
	if child.realm_index < min_index:
		return "%s must reach %s to learn the %s." % [child.name, data.realms[min_index].name, def.name]
	return ""


## Teaches `child` a technique `c` knows. Returns {ok, reason, days}.
static func teach(c: CharacterData, child: CharacterData, tech_id: String, data: GameData) -> Dictionary:
	var reason := check_teach(c, child, tech_id, data)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0}
	Techniques.learn(child, data, tech_id)
	return {"ok": true, "reason": "", "days": int(rules(data).get("teach_days", 30))}


## Why `c` cannot give `child` a usable item (e.g. a pill), or "".
static func check_give(c: CharacterData, child: CharacterData, item_id: String, data: GameData) -> String:
	var reason := check_child(c, child)
	if reason != "":
		return reason
	var item: Dictionary = data.items.get(item_id, {})
	if item.is_empty() or not item.get("usable", false) or Equipment.is_equipment(data, item_id):
		return "That cannot be given to a child to use."
	if c.item_count(item_id) <= 0:
		return "You have none left."
	var effects_reason := Effects.check(child, data, item.get("effects", {}))
	if effects_reason != "":
		return "%s cannot use it: %s" % [child.name, effects_reason]
	return ""


## `c` hands one `item_id` to `child`, who uses it at once. Returns {ok, reason, notes}.
static func give(c: CharacterData, child: CharacterData, item_id: String, data: GameData, flags: Dictionary) -> Dictionary:
	var reason := check_give(c, child, item_id, data)
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray()}
	c.add_item(item_id, -1)
	return {"ok": true, "reason": "", "notes": Effects.apply(child, data, data.items[item_id].get("effects", {}), flags)}


## Runs `months` months of training for `c`'s children in `people`: each month
## and child, pay the assignment's stones (an unpaid month is skipped) and
## train; `speed` scales the training days (clan library, FAM-006). Returns
## notable events [{text, category}].
static func advance(c: CharacterData, people: Dictionary, data: GameData, months: int, speed: float = 1.0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in months:
		for child_id in c.children:
			var child: CharacterData = people.get(child_id)
			if child == null or not child.alive or current(child) == "":
				continue
			var assignment_id := current(child)
			if assignment(data, assignment_id).is_empty():
				clear(child)  # the assignment was removed from data
				continue
			var cost := monthly_cost(data, assignment_id)
			if c.item_count("spirit_stone") < cost:
				events.append({"text": "You cannot pay %d spirit stones for %s's training this month." % [cost, child.name], "category": "warning"})
				continue
			c.add_item("spirit_stone", -cost)
			var note := train_month(child, data, speed)
			if note != "":
				events.append({"text": note, "category": "progress"})
	return events


## One month of `child`'s assignment, its days scaled by `speed`. Returns a
## message for anything notable, else "".
static func train_month(child: CharacterData, data: GameData, speed: float = 1.0) -> String:
	var a := assignment(data, current(child))
	var days := roundi(int(a.get("days", 0)) * speed)
	match String(a.get("kind", "")):
		"cultivate":
			if Children.can_cultivate_yet(child, data):
				Cultivation.cultivate(child, data, days, Exploration.qi_density(data, Npcs.region_of(child, data)))
		"profession":
			var prof_id := String(child.training.get("profession", ""))
			if data.professions.has(prof_id):
				var def: ProfessionDef = data.professions[prof_id]
				if Professions.add_xp(child, data, prof_id, days * child.attribute(def.primary_attribute) / 10.0) > 0:
					return "%s's training pays off: now a %s." % [child.name, Professions.rank_title(child, data, prof_id)]
		"technique":
			var tech_id := _least_practiced(child, data)
			if tech_id != "":
				var result := Techniques.practice(child, data, tech_id, days)
				if int(result["levels_gained"]) > 0:
					return "%s's %s reaches level %d." % [child.name, data.techniques[tech_id].name, Techniques.level(child, tech_id)]
	return ""


## The unmastered technique of `child` with the lowest level ("" if none).
static func _least_practiced(child: CharacterData, data: GameData) -> String:
	var best := ""
	var ids: Array = child.techniques.keys()
	ids.sort()
	for tech_id in ids:
		if not data.techniques.has(tech_id) or Techniques.is_mastered(child, data, tech_id):
			continue
		if best == "" or Techniques.level(child, tech_id) < Techniques.level(child, best):
			best = tech_id
	return best


## Load errors for data/family.json "training" (optional block).
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id in assignments(data):
		var a := assignment(data, id)
		if not KINDS.has(String(a.get("kind", ""))):
			errors.append("family.json training assignment '%s' needs kind in %s" % [id, KINDS])
		if int(a.get("stones_per_month", -1)) < 0 or int(a.get("days", -1)) < 0 or int(a.get("min_age", 0)) < 0:
			errors.append("family.json training assignment '%s' needs stones_per_month, days and min_age >= 0" % id)
	if int(rules(data).get("teach_days", 0)) < 0:
		errors.append("family.json training.teach_days must be >= 0")
	return errors
