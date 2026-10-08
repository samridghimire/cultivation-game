class_name Milestones
extends RefCounted
## Milestones (GOAL-001): data/milestones.json entries the player earns once.
## Earned ids are kept in CharacterData.milestones.

const CHECK_TYPES: Array[String] = ["realm", "life_stat", "flag", "sect_joined", "married", "clan_founded", "item_crafted", "flag_count"]


## Ids of milestones whose check holds now and that are not yet earned, in file order.
static func newly_reached(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[String]:
	var result: Array[String] = []
	for def in data.milestones:
		var id := String(def["id"])
		if not c.milestones.has(id) and is_met(c, data, flags, clan, def["check"]):
			result.append(id)
	return result


static func is_met(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData, check: Dictionary) -> bool:
	match String(check.get("type", "")):
		"realm":
			var target := data.realm_index_of(String(check.get("realm", "")))
			var stage := int(check.get("stage", 0))
			return target >= 0 and (c.realm_index > target or (c.realm_index == target and c.stage >= stage))
		"life_stat":
			return LifeStats.get_stat(c, String(check.get("stat", ""))) >= int(check.get("min", 1))
		"flag":
			return bool(flags.get(String(check.get("flag", "")), false))
		"flag_count":
			return flag_count(flags, check) >= int(check.get("min", 1))
		"sect_joined":
			return not c.sect.is_empty()
		"married":
			return not c.spouses.is_empty()
		"clan_founded":
			return clan != null
		"item_crafted":
			return LifeStats.get_stat(c, "items_crafted") >= int(check.get("min", 1))
	return false


## Set world flags that start with check.prefix and end with check.suffix
## (e.g. errand_*_done counts finished favor errands).
static func flag_count(flags: Dictionary, check: Dictionary) -> int:
	var prefix := String(check.get("prefix", ""))
	var suffix := String(check.get("suffix", ""))
	var n := 0
	for key: String in flags:
		if bool(flags[key]) and key.begins_with(prefix) and key.ends_with(suffix):
			n += 1
	return n


## Progress toward milestone `id` as {current, target}. Countable checks (life_stat,
## item_crafted, realm as a flat stage count) report the stat against its goal; the
## rest are 0 or 1 of 1. An earned milestone is always target/target; unknown ids give {0, 1}.
static func progress(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData, id: String) -> Dictionary:
	var def := data.milestone_def(id)
	if def.is_empty():
		return {"current": 0, "target": 1}
	var check: Dictionary = def["check"]
	var current := 0
	var target := 1
	match String(check.get("type", "")):
		"life_stat":
			target = maxi(1, int(check.get("min", 1)))
			current = LifeStats.get_stat(c, String(check.get("stat", "")))
		"item_crafted":
			target = maxi(1, int(check.get("min", 1)))
			current = LifeStats.get_stat(c, "items_crafted")
		"flag_count":
			target = maxi(1, int(check.get("min", 1)))
			current = flag_count(flags, check)
		"realm":
			var realm_index := data.realm_index_of(String(check.get("realm", "")))
			if realm_index >= 0:
				target = stage_total(data, realm_index) + int(check.get("stage", 0))
				current = stage_total(data, c.realm_index) + c.stage
		_:
			current = 1 if is_met(c, data, flags, clan, check) else 0
	if c.milestones.has(id):
		return {"current": target, "target": target}
	return {"current": clampi(current, 0, target), "target": target}


## Stages in all realms before `realm_index`, so realm + stage becomes one flat count.
static func stage_total(data: GameData, realm_index: int) -> int:
	var total := 0
	for i in mini(realm_index, data.realms.size()):
		total += data.realms[i].stage_count()
	return total


## "4/25" when the milestone is countable (target above 1), else "".
static func progress_text(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData, id: String) -> String:
	var p := progress(c, data, flags, clan, id)
	return "%d/%d" % [p["current"], p["target"]] if int(p["target"]) > 1 else ""


## Marks every newly reached milestone as earned and returns their defs, in file order.
static func award(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	for id in newly_reached(c, data, flags, clan):
		c.milestones.append(id)
		earned.append(data.milestone_def(id))
	return earned
