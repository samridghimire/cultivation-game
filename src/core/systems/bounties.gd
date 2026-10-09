class_name Bounties
extends RefCounted
## Bounties (BOUNTY-001): the player takes a hunt on a region's foe (data/bounties.json); exploring
## there may pick up its trail, and winning the fight pays spirit stones. State lives in
## CharacterData.bounty {id, until_day} and bounty_cooldowns (bounty id -> first day it can be taken again).


static func def_of(data: GameData, bounty_id: String) -> Dictionary:
	return data.bounties.get(bounty_id, {})


## Bounties the character meets the gates of, off cooldown and not already taken. With a
## `region_id`, hunts in that region come first, then those in neighbouring regions, then the
## rest (data order inside each group); the board's limit is applied after that ordering.
static func offers(c: CharacterData, data: GameData, today: int, region_id: String = "") -> Array[Dictionary]:
	var local: Array[Dictionary] = []
	var near: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for b: Dictionary in data.bounties.values():
		var id := String(b["id"])
		var where := String(b["region"])
		if not data.regions.has(where) or String(c.bounty.get("id", "")) == id:
			continue
		if today < int(c.bounty_cooldowns.get(id, 0)) or not Exploration.realm_allows(c, data, b):
			continue
		if region_id != "" and where == region_id:
			local.append(b)
		elif region_id != "" and Exploration.is_nearby(data, region_id, where):
			near.append(b)
		else:
			rest.append(b)
	var out: Array[Dictionary] = []
	out.append_array(local)
	out.append_array(near)
	out.append_array(rest)
	var limit := int(data.bounty_config.get("offers", 3))
	return out.slice(0, limit)


## "" when `bounty_id` can be taken, else the reason.
static func check_take(c: CharacterData, data: GameData, bounty_id: String, today: int) -> String:
	if not c.bounty.is_empty():
		return "You are already on a hunt."
	var b := def_of(data, bounty_id)
	if b.is_empty() or not Exploration.realm_allows(c, data, b):
		return "That bounty is not posted for you."
	var wait := int(c.bounty_cooldowns.get(bounty_id, 0)) - today
	if wait > 0:
		return "Posted again in %d days." % wait
	return ""


static func take(c: CharacterData, data: GameData, bounty_id: String, today: int) -> void:
	c.bounty = {"id": bounty_id, "until_day": today + int(def_of(data, bounty_id).get("days", 0))}


## The active bounty's definition plus `until_day`, or {} (none, or run out).
static func active(c: CharacterData, data: GameData, today: int) -> Dictionary:
	if c.bounty.is_empty() or today > int(c.bounty.get("until_day", 0)):
		return {}
	var b := def_of(data, String(c.bounty.get("id", "")))
	if b.is_empty():
		return {}
	return b.merged({"until_day": int(c.bounty["until_day"])})


## Clears a hunt that ran out (starting its cooldown); returns its id, else "".
static func expire(c: CharacterData, data: GameData, today: int) -> String:
	if c.bounty.is_empty() or today <= int(c.bounty.get("until_day", 0)):
		return ""
	var id := String(c.bounty.get("id", ""))
	_clear(c, data, id, today)
	return id


## The active bounty's enemy id when it lives in `region_id` and its trail turns up, else "".
static func hunt_roll(c: CharacterData, data: GameData, region_id: String, today: int, rng: RandomNumberGenerator) -> String:
	var b := active(c, data, today)
	if b.is_empty() or String(b["region"]) != region_id:
		return ""
	if rng.randf() < float(data.bounty_config.get("hunt_chance", 0.3)):
		return String(b["enemy"])
	return ""


## Pays the active bounty (or `bounty_id`, the hunt a fight began on, even if it lapsed
## during that fight) and clears it (cooldown starts). The pay is scaled by the renown tier held
## in the bounty's region. Returns {"stones": int paid, "bonus": int of that earned by renown}.
static func complete(c: CharacterData, data: GameData, today: int, bounty_id: String = "") -> Dictionary:
	var b := def_of(data, bounty_id if bounty_id != "" else String(c.bounty.get("id", "")))
	if b.is_empty():
		return {"stones": 0, "bonus": 0}
	var stones := paid_stones(c, data, b)
	c.add_item("spirit_stone", stones)
	LifeStats.record_stones(c, stones)
	LifeStats.add(c, "bounties_done")
	_clear(c, data, String(b["id"]), today)
	return {"stones": stones, "bonus": stones - int(b["reward_stones"])}


## What `b` pays this character: its reward times the renown multiplier of its region.
static func paid_stones(c: CharacterData, data: GameData, b: Dictionary) -> int:
	return int(round(float(b["reward_stones"]) * Renown.bounty_multiplier(c, data, String(b["region"]))))


static func abandon(c: CharacterData, data: GameData, today: int) -> void:
	if not c.bounty.is_empty():
		_clear(c, data, String(c.bounty.get("id", "")), today)


static func _clear(c: CharacterData, data: GameData, bounty_id: String, today: int) -> void:
	c.bounty_cooldowns[bounty_id] = today + int(def_of(data, bounty_id).get("cooldown_days", 0))
	c.bounty = {}
