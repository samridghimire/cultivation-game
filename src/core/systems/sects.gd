class_name Sects
extends RefCounted
## Joining, leaving, contribution and rank within sects. A character with no
## sect is a rogue cultivator.


## Returns {ok: bool, reason: String}.
static func check_join(c: CharacterData, data: GameData, sect_id: String) -> Dictionary:
	if not data.sects.has(sect_id):
		return {"ok": false, "reason": "No such sect."}
	var sect: SectDef = data.sects[sect_id]
	if not c.is_rogue():
		return {"ok": false, "reason": "You already belong to a sect."}
	if c.realm_index < data.realm_index_of(sect.min_realm):
		return {"ok": false, "reason": "%s only accepts cultivators of %s or above." % [sect.name, data.realms[data.realm_index_of(sect.min_realm)].name]}
	if c.alignment < sect.min_alignment:
		return {"ok": false, "reason": "%s will not accept someone of your evil reputation." % sect.name}
	if c.alignment > sect.max_alignment:
		return {"ok": false, "reason": "%s has no use for someone so soft-hearted." % sect.name}
	return {"ok": true, "reason": ""}


static func join(c: CharacterData, data: GameData, sect_id: String) -> Dictionary:
	var check := check_join(c, data, sect_id)
	if check["ok"]:
		c.sect = {"id": sect_id, "rank": 0, "contribution": 0}
	return check


## Returns the id of the sect left, or "" if the character was already rogue.
static func leave(c: CharacterData) -> String:
	var old_id: String = c.sect.get("id", "")
	c.sect = {}
	return old_id


## Adds contribution and auto-promotes. Returns true if rank increased.
static func add_contribution(c: CharacterData, data: GameData, amount: int) -> bool:
	if c.is_rogue():
		return false
	var sect: SectDef = data.sects[c.sect["id"]]
	c.sect["contribution"] = int(c.sect["contribution"]) + amount
	var new_rank := sect.rank_for_contribution(c.sect["contribution"])
	if new_rank > int(c.sect["rank"]):
		c.sect["rank"] = new_rank
		return true
	return false


static func cultivation_bonus(c: CharacterData, data: GameData) -> float:
	if c.is_rogue():
		return 1.0
	return (data.sects[c.sect["id"]] as SectDef).cultivation_bonus


static func is_favored_profession(c: CharacterData, data: GameData, prof_id: String) -> bool:
	return not c.is_rogue() and (data.sects[c.sect["id"]] as SectDef).favored_professions.has(prof_id)


static func describe(c: CharacterData, data: GameData) -> String:
	if c.is_rogue():
		return "Rogue Cultivator"
	var sect: SectDef = data.sects[c.sect["id"]]
	return "%s, %s" % [sect.name, sect.rank_name(c.sect["rank"])]
