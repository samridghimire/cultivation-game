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
		c.sect = {"id": sect_id, "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0}
	return check


## Returns the id of the sect left, or "" if the character was already rogue.
static func leave(c: CharacterData) -> String:
	var old_id: String = c.sect.get("id", "")
	c.sect = {}
	return old_id


## Adds contribution (also counted toward this month's duty) and promotes
## through ranks that need no trial. Returns true if rank increased.
static func add_contribution(c: CharacterData, data: GameData, amount: int) -> bool:
	if c.is_rogue():
		return false
	c.sect["contribution"] = int(c.sect["contribution"]) + amount
	if amount > 0:
		c.sect["month_earned"] = int(c.sect.get("month_earned", 0)) + amount
	return auto_promote(c, data)


# --- NPC members (FAM-009c) ----------------------------------------------------

static func _entry_rules(data: GameData) -> Dictionary:
	return data.family.get("sect_entry", {})


## An NPC's rank in `sect_id` from their realm: the highest rank whose min_realm
## they reach (ranks without one only count as the first).
static func npc_rank(data: GameData, sect_id: String, realm_index: int) -> int:
	var sect: SectDef = data.sects.get(sect_id)
	if sect == null:
		return 0
	var rank := 0
	for i in sect.ranks.size():
		var min_realm := String(sect.ranks[i].get("min_realm", ""))
		if min_realm != "" and realm_index >= data.realm_index_of(min_realm):
			rank = i
	return rank


## Puts NPC `c` into `sect_id` at the rank their realm earns.
static func npc_join(c: CharacterData, data: GameData, sect_id: String) -> void:
	c.sect = {"id": sect_id, "rank": npc_rank(data, sect_id, c.realm_index), "contribution": 0}


## Raises NPC `c`'s sect rank after a breakthrough. True if it rose.
static func npc_promote(c: CharacterData, data: GameData) -> bool:
	if c.is_rogue() or not data.sects.has(String(c.sect["id"])):
		return false
	var rank := npc_rank(data, String(c.sect["id"]), c.realm_index)
	if rank <= int(c.sect["rank"]):
		return false
	c.sect["rank"] = rank
	return true


## Sect ids (sorted) that would accept `c` (Sects.check_join).
static func accepting_sects(c: CharacterData, data: GameData) -> Array[String]:
	var out: Array[String] = []
	for sect_id in data.sects:
		if check_join(c, data, sect_id)["ok"]:
			out.append(String(sect_id))
	out.sort()
	return out


## "an Outer Disciple of the Azure Cloud Sect" for a sect member, else "".
static func member_text(c: CharacterData, data: GameData) -> String:
	if c.is_rogue() or not data.sects.has(String(c.sect["id"])):
		return ""
	var sect: SectDef = data.sects[c.sect["id"]]
	return "%s of the %s" % [Text.a(sect.rank_name(int(c.sect["rank"]))), sect.name]


## Why `parent` cannot send their child `child` to `sect_id`, or "".
static func check_send_child(parent: CharacterData, child: CharacterData, data: GameData, sect_id: String) -> String:
	if child == null or not child.alive or not parent.children.has(child.id):
		return "Only your own living children can be sent to a sect."
	if not data.sects.has(sect_id):
		return "No such sect."
	if not child.is_rogue():
		return "%s already belongs to the %s." % [child.name, (data.sects[child.sect["id"]] as SectDef).name]
	var min_age := int(_entry_rules(data).get("min_age_years", 12))
	if child.age_years() < min_age:
		return "%s is too young; sects take disciples from age %d." % [child.name, min_age]
	var check := check_join(child, data, sect_id)
	if not check["ok"]:
		return "%s: %s" % [child.name, check["reason"]]
	return ""


## Sends `child` to `sect_id`. Returns {ok, reason, days}.
static func send_child(parent: CharacterData, child: CharacterData, data: GameData, sect_id: String) -> Dictionary:
	var reason := check_send_child(parent, child, data, sect_id)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0}
	npc_join(child, data, sect_id)
	return {"ok": true, "reason": "", "days": int(_entry_rules(data).get("days", 1))}


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


# --- Ranks: realm minimums, trials, stipends and duties (G-011) --------------

## The rank above `c`'s current one, or -1 for rogues and the top rank.
static func next_rank(c: CharacterData, data: GameData) -> int:
	if c.is_rogue():
		return -1
	var rank := int(c.sect["rank"]) + 1
	return rank if rank < (data.sects[c.sect["id"]] as SectDef).ranks.size() else -1


## The enemy id `c` must defeat to reach the next rank ("" if none).
static func trial_enemy(c: CharacterData, data: GameData) -> String:
	var rank := next_rank(c, data)
	if rank < 0:
		return ""
	return String((data.sects[c.sect["id"]] as SectDef).ranks[rank].get("trial", ""))


## Why `c` cannot take the next rank yet, ignoring any trial, or "".
static func _rank_requirement_reason(c: CharacterData, data: GameData, rank: int) -> String:
	var sect: SectDef = data.sects[c.sect["id"]]
	var def: Dictionary = sect.ranks[rank]
	var needed := int(def.get("contribution", 0))
	if int(c.sect["contribution"]) < needed:
		return "%s needs %d contribution (you have %d)." % [sect.rank_name(rank), needed, int(c.sect["contribution"])]
	var min_realm := data.realm_index_of(String(def.get("min_realm", "mortal")))
	if c.realm_index < min_realm:
		return "%s needs a cultivator of %s or above." % [sect.rank_name(rank), data.realms[min_realm].name]
	return ""


## Promotes `c` through every next rank whose contribution and realm minimum
## are met and which has no trial. Returns true if rank increased.
static func auto_promote(c: CharacterData, data: GameData) -> bool:
	var promoted := false
	while true:
		var rank := next_rank(c, data)
		if rank < 0 or trial_enemy(c, data) != "" or _rank_requirement_reason(c, data, rank) != "":
			break
		_set_rank(c, rank)
		promoted = true
	return promoted


## Why `c` cannot attempt the promotion trial now, or "" if they can.
static func check_promotion(c: CharacterData, data: GameData) -> String:
	if c.is_rogue():
		return "Only sect disciples can be promoted."
	var rank := next_rank(c, data)
	if rank < 0:
		return "You already hold your sect's highest rank."
	var reason := _rank_requirement_reason(c, data, rank)
	if reason != "":
		return reason
	if trial_enemy(c, data) == "":
		return "No trial is needed: your rank follows your contribution."
	return ""


## The trial opponent for `enemy_id`: a sparring match that never kills, takes
## no spirit stones and grants no loot (a defeat can still injure).
static func trial_opponent(data: GameData, enemy_id: String) -> Dictionary:
	var enemy: Dictionary = (data.enemies[enemy_id] as Dictionary).duplicate(true)
	enemy["lethal"] = false
	enemy["spar"] = true
	enemy["rewards"] = {}
	return enemy


## Promotes `c` one rank after a won trial (then through any trial-free ranks
## that follow). Returns false if `c` could not attempt the trial.
static func pass_trial(c: CharacterData, data: GameData) -> bool:
	if check_promotion(c, data) != "":
		return false
	_set_rank(c, next_rank(c, data))
	auto_promote(c, data)
	return true


static func _set_rank(c: CharacterData, rank: int) -> void:
	c.sect["rank"] = rank
	c.sect["duty_grace"] = true  # no duty is owed for the month you were promoted


## Contribution `c` owes each month at their rank (0 = none).
static func monthly_duty(c: CharacterData, data: GameData) -> int:
	if c.is_rogue():
		return 0
	return int((data.sects[c.sect["id"]] as SectDef).ranks[int(c.sect["rank"])].get("monthly_duty", 0))


## Contribution `c` earned so far this month.
static func duty_progress(c: CharacterData) -> int:
	return 0 if c.is_rogue() else int(c.sect.get("month_earned", 0))


## Days left in the current sect month (months close on `age_days`).
static func duty_days_left(c: CharacterData) -> int:
	return Calendar.DAYS_PER_MONTH - c.age_days % Calendar.DAYS_PER_MONTH


## Days left at which the duty reminder appears.
const DUTY_REMINDER_DAYS := 7


## "" for rogues, no duty, duty met or grace; else how much is still owed this month.
static func duty_reminder(c: CharacterData, data: GameData) -> String:
	var duty := monthly_duty(c, data)
	if duty <= 0 or duty_progress(c) >= duty or bool(c.sect.get("duty_grace", false)):
		return ""
	return "Your sect duty is %d / %d contribution with %d days left this month." % [duty_progress(c), duty, duty_days_left(c)]


## The monthly stipend of `c`'s rank: {spirit_stones, items} ({} if none).
static func stipend(c: CharacterData, data: GameData) -> Dictionary:
	if c.is_rogue():
		return {}
	return (data.sects[c.sect["id"]] as SectDef).ranks[int(c.sect["rank"])].get("stipend", {})


## Closes `c`'s sect month: pays the rank stipend if the monthly duty was met
## (or waived the month of a promotion), resets duty progress and applies
## promotions a realm breakthrough has unlocked. Never demotes.
## Returns {paid, skipped, stones, items, promoted}.
static func month_end(c: CharacterData, data: GameData) -> Dictionary:
	var result := {"paid": false, "skipped": false, "stones": 0, "items": {}, "promoted": false}
	if c.is_rogue():
		return result
	var duty := monthly_duty(c, data)
	var met := duty <= 0 or duty_progress(c) >= duty or bool(c.sect.get("duty_grace", false))
	var pay := stipend(c, data)
	c.sect["month_earned"] = 0
	c.sect.erase("duty_grace")
	if not pay.is_empty():
		if met:
			var stones := int(pay.get("spirit_stones", 0))
			if stones > 0:
				c.add_item("spirit_stone", stones)
			var items: Dictionary = pay.get("items", {})
			for item_id in items:
				c.add_item(item_id, int(items[item_id]))
			result["paid"] = true
			result["stones"] = stones
			result["items"] = items.duplicate()
		else:
			result["skipped"] = true
	result["promoted"] = auto_promote(c, data)
	return result


## Load errors for the sects.json rank fields.
static func validate_ranks(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for sect: SectDef in data.sects.values():
		var last := -1
		for i in sect.ranks.size():
			var rank: Dictionary = sect.ranks[i]
			var label := "Sect '%s' rank %d" % [sect.id, i]
			var contribution := int(rank.get("contribution", 0))
			if contribution < last or (i == 0 and contribution != 0):
				errors.append("%s: contribution must start at 0 and never decrease" % label)
			last = contribution
			if data.realm_index_of(String(rank.get("min_realm", "mortal"))) < 0:
				errors.append("%s has unknown min_realm '%s'" % [label, rank.get("min_realm", "")])
			var trial := String(rank.get("trial", ""))
			if trial != "" and (i == 0 or not data.enemies.has(trial)):
				errors.append("%s has a bad trial '%s' (unknown enemy, or on the first rank)" % [label, trial])
			if int(rank.get("monthly_duty", 0)) < 0:
				errors.append("%s needs monthly_duty >= 0" % label)
			var pay: Dictionary = rank.get("stipend", {})
			if int(pay.get("spirit_stones", 0)) < 0:
				errors.append("%s stipend needs spirit_stones >= 0" % label)
			var items: Dictionary = pay.get("items", {})
			for item_id in items:
				if not data.items.has(item_id) or int(items[item_id]) <= 0:
					errors.append("%s stipend has unknown item or bad count '%s'" % [label, item_id])
	return errors


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
		return "Only %s or above may claim this." % Text.a(sect.rank_name(min_rank))
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
## Rogues get none. A mission with `requires_flag` is offered only while that
## world flag is set in `flags`.
static func available_missions(c: CharacterData, data: GameData, flags: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	if c.is_rogue():
		return out
	for mission: Dictionary in data.sect_missions.values():
		var sects: Array = mission.get("sects", [])
		var needed_flag := String(mission.get("requires_flag", ""))
		if needed_flag != "" and not flags.get(needed_flag, false):
			continue
		if sects.is_empty() or sects.has(c.sect["id"]):
			out.append(String(mission["id"]))
	return out


## Days until `c` may take `mission_id` again (0 = ready).
static func mission_cooldown_left(c: CharacterData, mission_id: String) -> int:
	return maxi(0, int(c.mission_cooldowns.get(mission_id, 0)) - c.age_days)


## Why `c` cannot take `mission_id` now, or "" if they can.
static func check_mission(c: CharacterData, data: GameData, mission_id: String, flags: Dictionary = {}) -> String:
	if not data.sect_missions.has(mission_id):
		return "No such mission."
	if c.is_rogue():
		return "Only sect disciples receive sect missions."
	var offered: Array = data.sect_missions[mission_id].get("sects", [])
	if not offered.is_empty() and not offered.has(c.sect["id"]):
		return "Your sect does not offer that mission."
	if not available_missions(c, data, flags).has(mission_id):
		return "Your sect has no need of this now."
	var mission: Dictionary = data.sect_missions[mission_id]
	var sect: SectDef = data.sects[c.sect["id"]]
	var min_rank := int(mission.get("min_rank", 0))
	if int(c.sect["rank"]) < min_rank:
		return "Only %s or above may take this mission." % Text.a(sect.rank_name(min_rank))
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
	var reason := check_mission(c, data, mission_id, flags)
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
		if mission.has("requires_flag") and String(mission["requires_flag"]) == "":
			errors.append("Mission '%s' has an empty requires_flag" % id)
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
