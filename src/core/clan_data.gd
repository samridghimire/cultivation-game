class_name ClanData
extends RefCounted
## The player's clan (FAM-005): plain data. Rules live in Clans.

var name := ""
## Character id of the founder and current head (the player is "player").
var head := ""
## Member character id -> rank id (data/family.json clan.ranks).
var members: Dictionary = {}
## Spirit stones in the clan treasury.
var treasury := 0
var reputation := 0
## Game day (GameClock.total_days) the clan was founded.
var founded_day := 0
## Estate building id -> built level (1 = first level), FAM-006.
var buildings: Dictionary = {}
## The project under way, {"building": id, "level": int, "days_left": int}, or {}.
var construction: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"name": name,
		"head": head,
		"members": members.duplicate(),
		"treasury": treasury,
		"reputation": reputation,
		"founded_day": founded_day,
		"buildings": buildings.duplicate(),
		"construction": construction.duplicate(),
	}


static func from_dict(d: Dictionary) -> ClanData:
	var clan := ClanData.new()
	clan.name = String(d.get("name", ""))
	clan.head = String(d.get("head", ""))
	var saved: Dictionary = d.get("members", {})
	for member_id in saved:
		clan.members[String(member_id)] = String(saved[member_id])
	clan.treasury = int(d.get("treasury", 0))
	clan.reputation = int(d.get("reputation", 0))
	clan.founded_day = int(d.get("founded_day", 0))
	var built: Dictionary = d.get("buildings", {})
	for building_id in built:
		clan.buildings[String(building_id)] = int(built[building_id])
	var project: Dictionary = d.get("construction", {})
	if not project.is_empty():
		clan.construction = {"building": String(project.get("building", "")), "level": int(project.get("level", 1)), "days_left": int(project.get("days_left", 0))}
	return clan
