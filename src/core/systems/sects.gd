class_name Sects
extends RefCounted
## Joining, leaving, contribution and rank within sects, and sect missions
## (data/sect_missions.json). A character with no sect is a rogue cultivator.

const MISSION_KINDS: Array[String] = ["gather", "hunt", "deliver", "guard"]


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
	var rep_reason := Reputation.check_join(c, data, sect_id)
	if rep_reason != "":
		return {"ok": false, "reason": rep_reason}
	return {"ok": true, "reason": ""}


static func join(c: CharacterData, data: GameData, sect_id: String) -> Dictionary:
	var check := check_join(c, data, sect_id)
	if check["ok"]:
		c.sect = {"id": sect_id, "rank": 0, "contribution": 0, "spent": 0}
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


# --- Contribution shop (G-008c) ---------------------------------------------

## Contribution `c` can still spend: earned minus spent. Spending never lowers
## rank, which follows lifetime contribution.
static func contribution_balance(c: CharacterData) -> int:
	if c.is_rogue():
		return 0
	return maxi(0, int(c.sect.get("contribution", 0)) - int(c.sect.get("spent", 0)))


## The shop entries ({item_id, contribution, min_rank}) of `c`'s sect, in data
## order, whether or not `c` can afford them yet. Rogues get none.
static func shop_items(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.is_rogue():
		return out
	out.assign((data.sects[c.sect["id"]] as SectDef).shop)
	return out


## The shop entry for `item_id` in `c`'s sect ({} if it does not sell it).
static func shop_entry(c: CharacterData, data: GameData, item_id: String) -> Dictionary:
	for entry in shop_items(c, data):
		if String(entry["item_id"]) == item_id:
			return entry
	return {}


## Why `c` cannot buy `item_id` from the sect shop now, or "" if they can.
static func check_purchase(c: CharacterData, data: GameData, item_id: String) -> String:
	if c.is_rogue():
		return "Only sect disciples may draw on a sect's treasury."
	var entry := shop_entry(c, data, item_id)
	if entry.is_empty():
		return "Your sect does not offer that."
	var sect: SectDef = data.sects[c.sect["id"]]
	var min_rank := int(entry.get("min_rank", 0))
	if int(c.sect["rank"]) < min_rank:
		return "Only a %s or above may claim this." % sect.rank_name(min_rank)
	var cost := int(entry["contribution"])
	if contribution_balance(c) < cost:
		return "You need %d contribution (you have %d)." % [cost, contribution_balance(c)]
	return ""


## Buys `item_id` with contribution. Returns {ok, reason, cost}.
static func buy_with_contribution(c: CharacterData, data: GameData, item_id: String) -> Dictionary:
	var reason := check_purchase(c, data, item_id)
	if reason != "":
		return {"ok": false, "reason": reason, "cost": 0}
	var cost := int(shop_entry(c, data, item_id)["contribution"])
	c.sect["spent"] = int(c.sect.get("spent", 0)) + cost
	c.add_item(item_id, 1)
	return {"ok": true, "reason": "", "cost": cost}


## Load errors for the sects.json `shop` lists.
static func validate_shops(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for sect: SectDef in data.sects.values():
		var seen := {}
		for entry in sect.shop:
			var item_id := String(entry.get("item_id", ""))
			if not data.items.has(item_id):
				errors.append("Sect '%s' shop sells unknown item '%s'" % [sect.id, item_id])
			if seen.has(item_id):
				errors.append("Sect '%s' shop lists '%s' twice" % [sect.id, item_id])
			seen[item_id] = true
			if int(entry.get("contribution", 0)) < 1:
				errors.append("Sect '%s' shop item '%s' needs contribution >= 1" % [sect.id, item_id])
			var min_rank := int(entry.get("min_rank", 0))
			if min_rank < 0 or min_rank >= sect.ranks.size():
				errors.append("Sect '%s' shop item '%s' has min_rank outside its ranks" % [sect.id, item_id])
	return errors


# --- Missions (G-008) ----------------------------------------------------------

## Mission ids offered by `c`'s sect (missions without a `sects` list are
## offered by every sect), in data order, whether or not `c` qualifies yet.
## Rogues get none.
static func available_missions(c: CharacterData, data: GameData) -> Array[String]:
	var out: Array[String] = []
	if c.is_rogue():
		return out
	for mission: Dictionary in data.sect_missions.values():
		var sects: Array = mission.get("sects", [])
		if sects.is_empty() or sects.has(c.sect["id"]):
			out.append(String(mission["id"]))
	return out


## Days until `c` may take `mission_id` again (0 = ready).
static func mission_cooldown_left(c: CharacterData, mission_id: String) -> int:
	return maxi(0, int(c.mission_cooldowns.get(mission_id, 0)) - c.age_days)


## Why `c` cannot take `mission_id` now, or "" if they can.
static func check_mission(c: CharacterData, data: GameData, mission_id: String) -> String:
	if not data.sect_missions.has(mission_id):
		return "No such mission."
	if c.is_rogue():
		return "Only sect disciples receive sect missions."
	if not available_missions(c, data).has(mission_id):
		return "Your sect does not offer that mission."
	var mission: Dictionary = data.sect_missions[mission_id]
	var sect: SectDef = data.sects[c.sect["id"]]
	var min_rank := int(mission.get("min_rank", 0))
	if int(c.sect["rank"]) < min_rank:
		return "Only a %s or above may take this mission." % sect.rank_name(min_rank)
	var min_realm := data.realm_index_of(String(mission.get("min_realm", "mortal")))
	var min_stage := int(mission.get("min_stage", 0))
	if c.realm_index < min_realm or (c.realm_index == min_realm and c.stage < min_stage):
		return "This mission needs a cultivator of %s or above." % data.realms[min_realm].stage_label(min_stage)
	var wait := mission_cooldown_left(c, mission_id)
	if wait > 0:
		return "This mission is not offered again for %s." % Calendar.format_duration(wait)
	var needed: Dictionary = mission.get("requires", {}).get("items", {})
	for item_id in needed:
		if c.item_count(item_id) < int(needed[item_id]):
			return "You need %d %s." % [int(needed[item_id]), data.items.get(item_id, {}).get("name", item_id)]
	return ""


## Danger label (Combat.danger_label: Weak/Even/Dangerous/Deadly) of the
## mission's fight for `c`, or "" if the mission has no enemy. Missions are
## always fought (a Deadly foe is not evaded), so the board should show this.
static func mission_danger(c: CharacterData, data: GameData, mission_id: String) -> String:
	var enemy_id := String(data.sect_missions.get(mission_id, {}).get("enemy", ""))
	if enemy_id == "" or not data.enemies.has(enemy_id):
		return ""
	return Combat.danger_label(c, data, data.enemies[enemy_id])


## Completes `mission_id` (any fight must already be won): hands in the
## required items, applies the rewards, adds contribution and starts the
## cooldown. Contribution also earns reputation with the sect.
## Returns {ok, reason, contribution, promoted, notes, days}.
static func complete_mission(c: CharacterData, data: GameData, mission_id: String, flags: Dictionary) -> Dictionary:
	var reason := check_mission(c, data, mission_id)
	if reason != "":
		return {"ok": false, "reason": reason, "contribution": 0, "promoted": false, "notes": PackedStringArray(), "days": 0}
	var mission: Dictionary = data.sect_missions[mission_id]
	var needed: Dictionary = mission.get("requires", {}).get("items", {})
	for item_id in needed:
		c.add_item(item_id, -int(needed[item_id]))
	var notes := Effects.apply(c, data, mission.get("rewards", {}), flags)
	var contribution := int(mission.get("contribution", 0))
	var rep := Reputation.change(c, data, String(c.sect["id"]), Reputation.mission_gain(data, contribution))
	if rep != 0:
		notes.append("%s reputation %+d" % [data.sects[c.sect["id"]].name, rep])
	var promoted := add_contribution(c, data, contribution)
	c.mission_cooldowns[mission_id] = c.age_days + int(mission.get("cooldown_days", 0))
	return {"ok": true, "reason": "", "contribution": contribution, "promoted": promoted, "notes": notes, "days": int(mission.get("days", 1))}


## Load errors for data/sect_missions.json.
static func validate_missions(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for mission: Dictionary in data.sect_missions.values():
		var id := String(mission["id"])
		var kind := String(mission.get("kind", ""))
		if not MISSION_KINDS.has(kind):
			errors.append("Mission '%s' has unknown kind '%s'" % [id, kind])
		for sect_id in mission.get("sects", []):
			if not data.sects.has(sect_id):
				errors.append("Mission '%s' has unknown sect '%s'" % [id, sect_id])
		var realm_index := data.realm_index_of(String(mission.get("min_realm", "mortal")))
		if realm_index < 0:
			errors.append("Mission '%s' has unknown min_realm '%s'" % [id, mission.get("min_realm", "")])
		elif int(mission.get("min_stage", 0)) < 0 or int(mission.get("min_stage", 0)) >= data.realms[realm_index].stage_count():
			errors.append("Mission '%s' has min_stage %d outside its min_realm's stages" % [id, int(mission.get("min_stage", 0))])
		if int(mission.get("min_rank", 0)) < 0:
			errors.append("Mission '%s' needs min_rank >= 0" % id)
		if int(mission.get("days", 0)) < 1:
			errors.append("Mission '%s' needs days >= 1" % id)
		if int(mission.get("contribution", 0)) < 0 or int(mission.get("cooldown_days", 0)) < 0:
			errors.append("Mission '%s' needs contribution and cooldown_days >= 0" % id)
		var enemy := String(mission.get("enemy", ""))
		if (kind == "hunt" or kind == "guard") and enemy == "":
			errors.append("Mission '%s' (%s) needs an enemy" % [id, kind])
		if enemy != "" and not data.enemies.has(enemy):
			errors.append("Mission '%s' has unknown enemy '%s'" % [id, enemy])
		var needed: Dictionary = mission.get("requires", {}).get("items", {})
		for item_id in needed:
			if not data.items.has(item_id) or int(needed[item_id]) <= 0:
				errors.append("Mission '%s' requires unknown item or bad count '%s'" % [id, item_id])
		for item_id in mission.get("rewards", {}).get("items", {}):
			if not data.items.has(item_id):
				errors.append("Mission '%s' rewards unknown item '%s'" % [id, item_id])
	return errors
