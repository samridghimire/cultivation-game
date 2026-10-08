class_name Milestones
extends RefCounted
## Milestones (GOAL-001): data/milestones.json entries the player earns once.
## Earned ids are kept in CharacterData.milestones.

const CHECK_TYPES: Array[String] = ["realm", "life_stat", "flag", "sect_joined", "married", "clan_founded", "item_crafted"]


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
		"sect_joined":
			return not c.sect.is_empty()
		"married":
			return not c.spouses.is_empty()
		"clan_founded":
			return clan != null
		"item_crafted":
			return LifeStats.get_stat(c, "items_crafted") >= int(check.get("min", 1))
	return false


## Marks every newly reached milestone as earned and returns their defs, in file order.
static func award(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	for id in newly_reached(c, data, flags, clan):
		c.milestones.append(id)
		earned.append(data.milestone_def(id))
	return earned
