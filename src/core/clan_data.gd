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


func to_dict() -> Dictionary:
	return {
		"name": name,
		"head": head,
		"members": members.duplicate(),
		"treasury": treasury,
		"reputation": reputation,
		"founded_day": founded_day,
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
	return clan
