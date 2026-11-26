class_name Sects
extends RefCounted
## Joining, leaving, contribution and rank within sects, and sect missions
## (data/sect_missions.json). A character with no sect is a rogue cultivator.

const MISSION_KINDS: Array[String] = ["gather", "hunt", "deliver", "guard"]


## The region a sect calls home (TRAV-004); "" for a rogue, an unknown sect or one with none.
static func home_region(data: GameData, sect_id: String) -> String:
	var def: SectDef = data.sects.get(sect_id)
	return def.home_region if def != null else ""


## WU-607: the sect's own hall place in its home region ({} when none): the hall naming the sect, else any hall there.
static func home_hall(data: GameData, sect_id: String) -> Dictionary:
	var region: Dictionary = data.regions.get(home_region(data, sect_id), {})
	var any: Dictionary = {}
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) != "sect_hall":
			continue
		if String(p.get("sect", "")) == sect_id:
			return p
		if any.is_empty() and String(p.get("sect", "")) == "":
			any = p
	return any


## WU-607: y of the home region's main road (the first wide-and-flat path's centre line); the map's middle when it has none.
static func road_y(data: GameData, region_id: String) -> float:
	var map: Dictionary = data.regions.get(region_id, {}).get("map", {})
	for path: Array in map.get("paths", []):
		if path.size() == 4 and float(path[2]) >= float(path[3]):
			return float(path[1]) + float(path[3]) / 2.0
	var size: Array = map.get("size", [1600, 1000])
	return float(size[1]) / 2.0


## WU-607: the first arrival line at a member's home region ("" for rogues, other regions, no hall).
static func home_arrival_line(c: CharacterData, data: GameData, region_id: String) -> String:
	if c.is_rogue() or home_region(data, String(c.sect["id"])) != region_id:
		return ""
	var hall := home_hall(data, String(c.sect["id"]))
	if hall.is_empty():
		return ""
	var pos: Array = hall.get("pos", [0, 0])
	var dy := float(pos[1]) - road_y(data, region_id)
	var where := "beside the road" if absf(dy) < 40.0 else ("north of the road" if dy < 0.0 else "south of the road")
	var sect_name := (data.sects[c.sect["id"]] as SectDef).name
	return "%s: home of the %s. The %s stands %s." % [Exploration.region_name(data, region_id), sect_name, hall.get("display_name", "hall"), where]


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
		c.sect = {"id": sect_id, "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	return check


## SECT-032: a new disciple who has not yet reported at the hall. A missing key means reported (old saves, NPCs).
static func needs_report(c: CharacterData) -> bool:
	return not c.is_rogue() and c.sect.get("reported", true) == false


## SECT-032: report at the sect's home hall: {ok, reason, items, line}. Grants the sect's welcome items once.
static func report(c: CharacterData, data: GameData, region_id: String) -> Dictionary:
	var fail := {"ok": false, "reason": "", "items": {}, "line": ""}
	if not needs_report(c):
		fail["reason"] = "You have already reported to the hall."
		return fail
	var sect_id := String(c.sect["id"])
	var home := home_region(data, sect_id)
	if home != "" and region_id != home:
		var hall := hall_name(data, home, c)
		fail["reason"] = "Report at the %s in %s." % [hall if hall != "" else "sect hall", String(data.regions[home].name) if data.regions.has(home) else home]
		return fail
	var welcome: Dictionary = (data.sects[sect_id] as SectDef).welcome
	var items := {}
	for item_id: String in welcome.get("items", {}):
		items[item_id] = int(welcome["items"][item_id])
		c.add_item(item_id, int(items[item_id]))
	c.sect["reported"] = true
	var line := String(welcome.get("line", "The steward records your name in the disciple roll.")).replace("{player}", c.name)
	return {"ok": true, "reason": "", "items": items, "line": line}


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
	var min_stage := int(def.get("min_stage", 0)) if min_realm > 0 else 0
	if c.realm_index < min_realm or (c.realm_index == min_realm and c.stage < min_stage):
		var needed_label: String = data.realms[min_realm].stage_label(min_stage) if min_stage > 0 else data.realms[min_realm].name
		return "%s needs a cultivator of %s or above." % [sect.rank_name(rank), needed_label]
	return ""


## Every unmet need of the next rank as phrases, in check order ("earn 300 contribution (you have 120)",
## "reach Qi Refining 7th Layer"); empty with no next rank or when both are met (GUIDE-181).
static func rank_needs(c: CharacterData, data: GameData) -> PackedStringArray:
	var out := PackedStringArray()
	var rank := next_rank(c, data)
	if rank < 0:
		return out
	var def: Dictionary = (data.sects[c.sect["id"]] as SectDef).ranks[rank]
	var needed := int(def.get("contribution", 0))
	if int(c.sect["contribution"]) < needed:
		out.append("earn %d contribution (you have %d)" % [needed, int(c.sect["contribution"])])
	var min_realm := data.realm_index_of(String(def.get("min_realm", "mortal")))
	var min_stage := int(def.get("min_stage", 0)) if min_realm > 0 else 0
	if c.realm_index < min_realm or (c.realm_index == min_realm and c.stage < min_stage):
		out.append("reach %s" % (data.realms[min_realm].stage_label(min_stage) if min_stage > 0 else data.realms[min_realm].name))
	return out


## True when the next rank exists and is gated by a trial.
static func needs_trial(c: CharacterData, data: GameData) -> bool:
	return next_rank(c, data) >= 0 and trial_enemy(c, data) != ""


## Why `c` falls short of the next rank's contribution/realm, or "" (also "" with no next rank).
static func rank_requirement_reason(c: CharacterData, data: GameData) -> String:
	var rank := next_rank(c, data)
	if rank < 0:
		return ""
	return _rank_requirement_reason(c, data, rank)


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
static func trial_opponent(data: GameData, enemy_id: String, power_mult: float = 1.0) -> Dictionary:
	var enemy: Dictionary = (data.enemies[enemy_id] as Dictionary).duplicate(true)
	if power_mult != 1.0:  # SECT-043: a contest round's own scaling, on top of the foe's power_mult
		enemy["power_mult"] = float(enemy.get("power_mult", 1.0)) * power_mult
	enemy["lethal"] = false
	enemy["spar"] = true
	enemy["rewards"] = {}
	return enemy


## SECT-046: how much weaker the next examiner fights after `c`'s lost trials (0.0 for rogues).
static func trial_lesson(c: CharacterData, data: GameData) -> float:
	if c.is_rogue():
		return 0.0
	return minf(data.trial_lesson_per_loss * float(int(c.sect.get("trial_losses", 0))), data.trial_lesson_max)


## SECT-046: records one lost promotion trial.
static func note_trial_loss(c: CharacterData) -> void:
	if not c.is_rogue():
		c.sect["trial_losses"] = int(c.sect.get("trial_losses", 0)) + 1


## SECT-046: the examiner of the open trial with the lessons of past losses applied ({} when no trial).
## Every fight and every odds display of the promotion trial uses this.
static func trial_foe(c: CharacterData, data: GameData) -> Dictionary:
	var enemy_id := trial_enemy(c, data)
	if enemy_id == "":
		return {}
	return trial_opponent(data, enemy_id, 1.0 - trial_lesson(c, data))


## SECT-040: ONE line naming the biggest gap between `c` and the examiner of the open trial. Order: injured, realm or
## stage below the foe, no combat technique known, otherwise "Close". "" when no trial is open. Pure.
static func trial_advice(c: CharacterData, data: GameData) -> String:
	var enemy_id := trial_enemy(c, data)
	if c.is_rogue() or enemy_id == "" or not data.enemies.has(enemy_id):
		return ""
	if Injuries.has_any(c):
		return "Heal first: you are injured."
	var enemy: Dictionary = data.enemies[enemy_id]
	var foe_realm := data.realm_index_of(String(enemy.get("realm", "mortal")))
	var foe_stage := int(enemy.get("stage", 0))
	if c.realm_index < foe_realm or (c.realm_index == foe_realm and c.stage < foe_stage):
		var realm: RealmDef = data.realms[foe_realm]
		var label: String = realm.stage_label(foe_stage) if foe_stage > 0 else realm.name
		return "The examiner is at %s; reach it first." % label
	if not Techniques.knows_kind(c, data, "combat"):
		var techs: Array = enemy.get("techniques", [])
		var tech_name := "an attack technique"
		if not techs.is_empty() and data.techniques.has(String(techs[0])):
			tech_name = String(data.techniques[String(techs[0])].name)
		return "Learn an attack technique; the examiner uses %s." % tech_name
	return "Close: train a few more days and try again."


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
	c.sect["trial_losses"] = 0  # SECT-046: the lessons were for the old rank's examiner
	c.sect["duty_grace"] = true  # no duty is owed for the month you were promoted


## SECT-031: what the current rank of `c` means: {rank_name, perks_new (shop items this rank unlocks), next_needs}.
static func promotion_summary(c: CharacterData, data: GameData) -> Dictionary:
	var out := {"rank_name": "", "perks_new": PackedStringArray(), "next_needs": ""}
	if c.is_rogue():
		return out
	var sect: SectDef = data.sects[c.sect["id"]]
	var rank := int(c.sect["rank"])
	out["rank_name"] = sect.rank_name(rank)
	var perks := PackedStringArray()
	if rank > 0:  # SECT-034: the rank's stipend, duty and treasury unlocks
		var rows := ladder(c, data)
		if rank < rows.size():
			perks = rows[rank]["perks"]
	out["perks_new"] = perks
	var needs := Array(rank_needs(c, data))
	if needs_trial(c, data):
		var foe := trial_enemy(c, data)
		needs.append("win a trial against %s" % String(data.enemies.get(foe, {}).get("name", foe)))
	out["next_needs"] = ", ".join(PackedStringArray(needs))
	return out


## SECT-033: one row per rank of the player's sect: {name, current, reached, needs, perks}. `needs` lists what
## the rank asks (contribution, realm, "trial vs <foe>"); `perks` its stipend, duty and treasury unlocks. [] for rogues.
static func ladder(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.is_rogue() or not data.sects.has(c.sect["id"]):
		return out
	var sect: SectDef = data.sects[c.sect["id"]]
	var current := int(c.sect["rank"])
	for i in sect.ranks.size():
		var def: Dictionary = sect.ranks[i]
		var needs := PackedStringArray()
		if i > current:
			var need := int(def.get("contribution", 0))
			if need > 0:
				needs.append("earn %d contribution" % need)
			var min_realm := data.realm_index_of(String(def.get("min_realm", "mortal")))
			var min_stage := int(def.get("min_stage", 0)) if min_realm > 0 else 0
			if min_realm > 0:
				needs.append("reach %s" % (data.realms[min_realm].stage_label(min_stage) if min_stage > 0 else data.realms[min_realm].name))
			var trial := String(def.get("trial", ""))
			if trial != "":
				needs.append("trial vs %s" % String(data.enemies.get(trial, {}).get("name", trial)))
		var perks := PackedStringArray()
		var pay: Dictionary = def.get("stipend", {})
		var pay_parts := PackedStringArray()
		if int(pay.get("spirit_stones", 0)) > 0:
			pay_parts.append("%d spirit stones" % int(pay["spirit_stones"]))
		for item_id: String in pay.get("items", {}):
			pay_parts.append("%d %s" % [int(pay["items"][item_id]), String(data.items.get(item_id, {}).get("name", item_id))])
		if not pay_parts.is_empty():
			perks.append("stipend: %s a month" % ", ".join(pay_parts))
		if int(def.get("monthly_duty", 0)) > 0:
			perks.append("duty: %d contribution a month" % int(def["monthly_duty"]))
		for entry: Dictionary in sect.shop:
			if int(entry.get("min_rank", 0)) == i and i > 0:
				perks.append("can buy %s" % String(data.items.get(String(entry["item_id"]), {}).get("name", entry["item_id"])))
		out.append({"name": sect.rank_name(i), "current": i == current, "reached": i <= current, "needs": needs, "perks": perks})
	return out


## SECT-033: this month at a glance: {duty, progress, days_left, stipend, lecture, missions_ready, missions_total,
## balance, claimable}. `lecture` is "" with none, else its name + " today" or " attended"; `claimable` the cheapest
## (max 3) treasury items the balance covers now. {} for rogues.
static func month_status(c: CharacterData, data: GameData, total_days: int, flags: Dictionary = {}) -> Dictionary:
	if c.is_rogue() or not data.sects.has(c.sect["id"]):
		return {}
	var lecture := lecture_def(c, data)
	var lecture_text := ""
	if not lecture.is_empty():
		var name := String(lecture.get("name", "the lecture"))
		lecture_text = "%s attended" % name if check_lecture(c, data, total_days) != "" else "%s: open this month (%dd left)" % [name, days_left_in_month(total_days)]
	var ids := available_missions(c, data, flags)
	var ready := 0
	for id in ids:
		if check_mission(c, data, id, flags) == "":
			ready += 1
	var blockers := mission_blockers(c, data, flags)
	var balance := contribution_balance(c)
	var options: Array[Dictionary] = []
	for entry: Dictionary in shop_items(c, data):
		if check_purchase(c, data, String(entry["item_id"])) == "":
			options.append(entry)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["contribution"]) < int(b["contribution"]))
	var claimable := PackedStringArray()
	for entry: Dictionary in options.slice(0, 3):
		claimable.append(String(data.items.get(String(entry["item_id"]), {}).get("name", entry["item_id"])))
	return {"duty": monthly_duty(c, data), "progress": duty_progress(c), "days_left": duty_days_left(c), "stipend": stipend(c, data),
		"lecture": lecture_text, "contest": contest_line(c, data, total_days), "missions_ready": ready, "missions_total": ids.size(), "blockers": blockers, "balance": balance, "claimable": claimable}


## WU-622: why the listed missions are not ready, bucketed by their first blocker: {"rank": n, "realm": n, "items": n,
## "wait": n, "other": n}; only non-zero buckets appear. Ready missions are not counted. {} for rogues.
static func mission_blockers(c: CharacterData, data: GameData, flags: Dictionary = {}) -> Dictionary:
	var out := {}
	if c.is_rogue():
		return out
	for id in available_missions(c, data, flags):
		if check_mission(c, data, id, flags) == "":
			continue
		var m: Dictionary = data.sect_missions[id]
		var key := "other"
		var min_realm := data.realm_index_of(String(m.get("min_realm", "mortal")))
		var min_stage := int(m.get("min_stage", 0))
		if mission_beneath(c, data, m):
			key = "other"
		elif int(c.sect["rank"]) < int(m.get("min_rank", 0)):
			key = "rank"
		elif c.realm_index < min_realm or (c.realm_index == min_realm and c.stage < min_stage):
			key = "realm"
		elif mission_cooldown_left(c, id) > 0:
			key = "wait"
		else:
			for item_id: String in m.get("requires", {}).get("items", {}):
				if c.item_count(item_id) < int(m["requires"]["items"][item_id]):
					key = "items"
					break
		out[key] = int(out.get(key, 0)) + 1
	return out


## WU-610: progress toward the next rank's contribution: {have, need, next_name, trial_foe}. {} for rogues and at the
## top rank. `have` is lifetime contribution (what promotion checks), `need` the next rank's requirement.
static func rank_progress(c: CharacterData, data: GameData) -> Dictionary:
	var rank := next_rank(c, data)
	if rank < 0:
		return {}
	var sect: SectDef = data.sects[c.sect["id"]]
	var def: Dictionary = sect.ranks[rank]
	var foe := trial_enemy(c, data)
	return {"have": int(c.sect.get("contribution", 0)), "need": int(def.get("contribution", 0)), "next_name": sect.rank_name(rank),
		"trial_foe": String(data.enemies.get(foe, {}).get("name", foe)) if foe != "" else ""}


## WU-610: the treasury as rows {name, cost, affordable, text}; `text` reads "Qi Gathering Pill (20)". `affordable`
## is false when the balance or the rank falls short. Data order. [] for rogues.
static func treasury_rows(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in shop_items(c, data):
		var id := String(entry["item_id"])
		var name := String(data.items.get(id, {}).get("name", id))
		out.append({"name": name, "cost": int(entry["contribution"]), "affordable": check_purchase(c, data, id) == "",
			"text": "%s (%d)" % [name, int(entry["contribution"])]})
	return out


## WU-610: names of the first `limit` missions `c` could take right now, board order.
static func ready_mission_names(c: CharacterData, data: GameData, flags: Dictionary = {}, limit: int = 2) -> PackedStringArray:
	var out := PackedStringArray()
	for id in available_missions(c, data, flags):
		if out.size() >= limit:
			break
		if check_mission(c, data, id, flags) == "":
			out.append(String((data.sect_missions[id] as Dictionary).get("name", id)))
	return out


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


## SECT-034: days from `total_days` to the end of its month (1 on the last day).
static func days_left_in_month(total_days: int) -> int:
	return Calendar.DAYS_PER_MONTH - total_days % Calendar.DAYS_PER_MONTH


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
				LifeStats.record_stones(c, stones)
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
			var rank_realm := data.realm_index_of(String(rank.get("min_realm", "mortal")))
			if rank_realm < 0:
				errors.append("%s has unknown min_realm '%s'" % [label, rank.get("min_realm", "")])
			elif int(rank.get("min_stage", 0)) < 0 or int(rank.get("min_stage", 0)) >= data.realms[rank_realm].stage_count():
				errors.append("%s has min_stage %d outside its min_realm's stages" % [label, int(rank.get("min_stage", 0))])
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


## GUIDE-132: {item_id, name, bonus, cost, min_rank} of the best breakthrough pill for `next_realm_id` in `shop`
## (highest breakthrough_bonus, then cheapest); {} when it has none.
static func best_breakthrough_entry(data: GameData, shop: Array, next_realm_id: String) -> Dictionary:
	var best := {}
	for entry: Dictionary in shop:
		var item: Dictionary = data.items.get(String(entry["item_id"]), {})
		var effects: Dictionary = item.get("effects", {})
		var bonus := float(effects.get("breakthrough_bonus", 0.0))
		if String(effects.get("breakthrough_realm", "")) != next_realm_id or bonus <= 0.0:
			continue
		if best.is_empty() or bonus > float(best["bonus"]) or (is_equal_approx(bonus, float(best["bonus"])) and int(entry["contribution"]) < int(best["cost"])):
			best = {"item_id": String(entry["item_id"]), "name": String(item["name"]), "bonus": bonus, "cost": int(entry["contribution"]), "min_rank": int(entry.get("min_rank", 0))}
	return best


## GUIDE-175: what joining `sect_id` would give `c`, as verb phrases for "Members ...":
## ["gather qi x1.5", "hear Elder Feng's sword lecture each month", "can claim a Foundation Establishment Pill for 250 contribution"].
## Empty for an unknown sect.
static func membership_perks(c: CharacterData, data: GameData, sect_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not data.sects.has(sect_id):
		return out
	var sect: SectDef = data.sects[sect_id]
	if sect.cultivation_bonus > 1.0:
		out.append("gather qi x%s" % String.num(sect.cultivation_bonus, 1))
	if not sect.lecture.is_empty():
		out.append("hear %s each month" % String(sect.lecture.get("name", "the elder's lecture")))
	if not Cultivation.is_final_realm(c, data):
		var pill := best_breakthrough_entry(data, sect.shop, data.realms[c.realm_index + 1].id)
		if not pill.is_empty():
			var gate := String(sect.ranks[int(pill["min_rank"])].get("min_realm", ""))
			if gate == "" or data.realm_index_of(gate) <= c.realm_index:
				out.append("can claim %s for %d contribution" % [Text.a(String(pill["name"])), int(pill["cost"])])
	return out


## "Members gather qi x1.5, hear ... and can claim ... for 250 contribution." ("" when there are no perks).
static func membership_line(c: CharacterData, data: GameData, sect_id: String) -> String:
	var perks := membership_perks(c, data, sect_id)
	return "" if perks.is_empty() else "Members %s." % Text.join_and(perks)


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


# --- The elder's monthly lecture (SECT-005) ----------------------------------

## year * 12 + month index of `total_days`, for once-a-month checks.
static func _month_index(total_days: int) -> int:
	return (Calendar.year_of(total_days) - 1) * Calendar.MONTHS_PER_YEAR + Calendar.month_of(total_days) - 1


## The lecture definition of `c`'s sect ({} for rogues and sects without one).
static func lecture_def(c: CharacterData, data: GameData) -> Dictionary:
	if c.is_rogue() or not data.sects.has(c.sect["id"]):
		return {}
	return (data.sects[c.sect["id"]] as SectDef).lecture


## Why `c` cannot attend the monthly lecture now, or "".
static func check_lecture(c: CharacterData, data: GameData, total_days: int) -> String:
	if c.is_rogue():
		return "Only sect disciples may attend the lecture."
	var lecture := lecture_def(c, data)
	if lecture.is_empty():
		return "Your sect holds no lectures."
	if int(c.sect.get("lecture_month", -1)) == _month_index(total_days):
		return "You have already attended %s this month." % lecture.get("name", "the lecture")
	return ""


## Attends the lecture: qi_days of qi at `density`, and maybe a glimpse of the
## first listed insight not yet known. Returns {ok, reason, name, days, qi, insight_id}.
static func attend_lecture(c: CharacterData, data: GameData, rng: RandomNumberGenerator, total_days: int, density: float = 1.0) -> Dictionary:
	var reason := check_lecture(c, data, total_days)
	if reason != "":
		return {"ok": false, "reason": reason}
	var lecture := lecture_def(c, data)
	c.sect["lecture_month"] = _month_index(total_days)
	LifeStats.add(c, "lectures_attended")
	var qi := 0
	var qi_capped := false  # SECT-037: true only when a bottleneck stopped the qi
	var qi_days := int(lecture.get("qi_days", 0))
	if qi_days > 0:
		if Cultivation.is_at_bottleneck(c, data):
			qi_capped = true
		else:
			qi = int(Cultivation.cultivate(c, data, qi_days, density)["qi_gained"])
	var chance := float(lecture.get("insight_chance", 0.0)) + 0.005 * maxf(0.0, c.attribute("comprehension") - 10.0)
	var insight_id := ""
	if rng.randf() < chance:
		for id: String in lecture.get("insights", []):
			if Dao.level(c, id) <= 0 and Dao.gain_levels(c, data, id) > 0:
				insight_id = id
				break
	return {"ok": true, "reason": "", "line": lecture_line(lecture, _month_index(total_days)), "name": String(lecture.get("name", "the lecture")), "days": int(lecture.get("days", 1)), "qi": qi, "qi_capped": qi_capped, "insight_id": insight_id}


## The scene line of `lecture` for `month_index` (C-270): `lines[month % size]` with
## {elder} and {topic} filled in, or "" when the lecture has no lines.
static func lecture_line(lecture: Dictionary, month_index: int) -> String:
	var lines: Array = lecture.get("lines", [])
	if lines.is_empty():
		return ""
	var line := String(lines[posmod(month_index, lines.size())])
	line = line.replace("{elder}", String(lecture.get("elder", "the elder"))).replace("{topic}", String(lecture.get("topic", "the lesson")))
	# "{elder} speaks..." with elder "the Blood Elder" must still open with a capital.
	return line.left(1).to_upper() + line.substr(1)


# --- The outer-sect contest (SECT-038) ----------------------------------------

## The contest definition of `c`'s sect ({} for rogues and sects without one).
static func contest_def(c: CharacterData, data: GameData) -> Dictionary:
	if c.is_rogue() or not data.sects.has(c.sect["id"]):
		return {}
	return (data.sects[c.sect["id"]] as SectDef).contest


## Why `c` cannot enter the contest on `total_days`, or "" when they can.
static func check_contest(c: CharacterData, data: GameData, total_days: int) -> String:
	if c.is_rogue():
		return "Only sect disciples may enter the contest."
	var contest := contest_def(c, data)
	if contest.is_empty():
		return "Your sect holds no contest."
	if needs_report(c):
		return "Report to the hall first."
	if int(c.sect.get("rank", 0)) > 1:
		return "The outer-sect contest is for disciples of the first two ranks."
	if Calendar.month_of(total_days) != int(contest.get("month", 0)):
		return "The contest is held in month %d of the year." % int(contest.get("month", 1))
	var year := Calendar.year_of(total_days)
	if int(c.sect.get("contest_year", -1)) == year or c.last_contest_year == year:
		return "You have already entered this year's contest."
	return ""


## True while `check_contest` allows entry.
static func contest_open(c: CharacterData, data: GameData, total_days: int) -> bool:
	return check_contest(c, data, total_days) == ""


## WU-621: the contest line for the Sect page and hall overview. "" for rogues and sects without a contest.
## Outside the month "Contest: month M (in N days)"; inside it "Contest: open now at the <hall>" or the
## `check_contest` reason when entry is barred.
static func contest_line(c: CharacterData, data: GameData, total_days: int) -> String:
	var contest := contest_def(c, data)
	if contest.is_empty():
		return ""
	var month := int(contest.get("month", 1))
	if Calendar.month_of(total_days) != month:
		var target := total_days - total_days % Calendar.DAYS_PER_YEAR + (month - 1) * Calendar.DAYS_PER_MONTH
		if target <= total_days:
			target += Calendar.DAYS_PER_YEAR
		return "Contest: month %d (in %d days)" % [month, target - total_days]
	var why := check_contest(c, data, total_days)
	if why == "":
		var sect: SectDef = data.sects[c.sect["id"]]
		var hall := hall_name(data, sect.home_region, c)
		return "Contest: open now at the %s" % (hall if hall != "" else "sect hall")
	if why.begins_with("You have already"):
		return "Contest: already entered this year"
	if why.contains("first two ranks"):
		return "Contest: for the first two ranks"
	return "Contest: %s" % why


## Round `index` (0-based) of `c`'s contest: {foe (enemy id), prize {contribution, spirit_stones}}; {} past the last round.
static func contest_round(c: CharacterData, data: GameData, index: int) -> Dictionary:
	var contest := contest_def(c, data)
	var foes: Array = contest.get("foes", [])
	if index < 0 or index >= foes.size():
		return {}
	var prizes: Array = contest.get("prizes", [])
	var mults: Array = contest.get("power_mults", [])
	return {"foe": String(foes[index]), "prize": prizes[index] if index < prizes.size() else {},
		"power_mult": float(mults[index]) if index < mults.size() else 1.0}


## Marks this year's contest as entered.
static func enter_contest(c: CharacterData, total_days: int) -> void:
	c.sect["contest_year"] = Calendar.year_of(total_days)
	c.last_contest_year = Calendar.year_of(total_days)  # SECT-043: survives leaving and rejoining


## SECT-048: records a finished contest: `rounds_won` bouts won of `rounds` in `total_days`' year.
## Counts rounds, and a full win (all rounds won) once. Returns true on a full win.
static func record_contest(c: CharacterData, rounds_won: int, rounds: int, total_days: int) -> bool:
	if rounds_won <= 0:
		return false
	LifeStats.add(c, "contest_rounds_won", rounds_won)
	var rec := c.contest_record
	rec["best_round"] = maxi(int(rec.get("best_round", 0)), rounds_won)
	var full := rounds > 0 and rounds_won >= rounds
	if full:
		LifeStats.add(c, "contest_wins")
		rec["last_year"] = Calendar.year_of(total_days)
		rec["sect"] = String(c.sect.get("id", ""))
	c.contest_record = rec
	return full


## SECT-048: {best_round, wins, last_year} (last_year -1 and zeros when never entered/won).
static func contest_record(c: CharacterData) -> Dictionary:
	return {"best_round": int(c.contest_record.get("best_round", 0)), "wins": LifeStats.get_stat(c, "contest_wins"),
		"last_year": int(c.contest_record.get("last_year", -1))}


## SECT-048: "Won the <sect> contest in year N" for the latest full win; "" when none.
static func contest_win_line(c: CharacterData, data: GameData) -> String:
	var year := int(c.contest_record.get("last_year", -1))
	if year < 0:
		return ""
	var id := String(c.contest_record.get("sect", ""))
	var name := String((data.sects[id] as SectDef).name) if data.sects.has(id) else "sect"
	return "Won the %s contest in year %d" % [name, year]


## Pays one round's prize. Returns true when its contribution promoted `c` (the caller announces it).
static func pay_contest_prize(c: CharacterData, data: GameData, prize: Dictionary) -> bool:
	var stones := int(prize.get("spirit_stones", 0))
	if stones > 0:
		c.add_item("spirit_stone", stones)
	var contribution := int(prize.get("contribution", 0))
	if contribution > 0:
		return add_contribution(c, data, contribution)
	return false


## Load errors for the sects.json `contest` blocks.
static func validate_contests(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	for sect: SectDef in data.sects.values():
		if sect.contest.is_empty():
			continue
		var label := "Sect '%s' contest" % sect.id
		var month := int(sect.contest.get("month", 0))
		if month < 1 or month > Calendar.MONTHS_PER_YEAR:
			errors.append("%s needs month 1..12" % label)
		var rounds := int(sect.contest.get("rounds", 0))
		if rounds < 2 or rounds > 3:
			errors.append("%s needs rounds 2..3" % label)
		var foes: Array = sect.contest.get("foes", [])
		var prizes: Array = sect.contest.get("prizes", [])
		if foes.size() != rounds or prizes.size() != rounds:
			errors.append("%s needs %d foes and %d prizes" % [label, rounds, rounds])
		var mults: Variant = sect.contest.get("power_mults", [])
		if not (mults is Array) or ((mults as Array).size() != foes.size() and not (mults as Array).is_empty()):
			errors.append("%s power_mults must list one value per foe" % label)
		else:
			for m: Variant in mults:
				if not (m is float or m is int) or float(m) < 0.4 or float(m) > 2.0:
					errors.append("%s power_mults values must be numbers in [0.4, 2.0]" % label)
		for foe: Variant in foes:
			if not data.enemies.has(String(foe)):
				errors.append("%s lists unknown foe '%s'" % [label, foe])
		for prize: Variant in prizes:
			if not (prize is Dictionary) or int((prize as Dictionary).get("contribution", 0)) < 0 or int((prize as Dictionary).get("spirit_stones", 0)) < 0:
				errors.append("%s prizes need contribution and spirit_stones >= 0" % label)
	return errors


## Load errors for the sects.json `lecture` blocks.
static func validate_lectures(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	for sect_id: String in data.sects:
		var lecture: Dictionary = (data.sects[sect_id] as SectDef).lecture
		if lecture.is_empty():
			continue
		var label := "Sect '%s' lecture" % sect_id
		if String(lecture.get("name", "")) == "":
			errors.append("%s needs a name" % label)
		if int(lecture.get("days", 0)) < 1:
			errors.append("%s needs days >= 1" % label)
		if int(lecture.get("qi_days", 0)) < 0:
			errors.append("%s needs qi_days >= 0" % label)
		var chance := float(lecture.get("insight_chance", 0.0))
		if chance < 0.0 or chance > 1.0:
			errors.append("%s needs insight_chance within 0..1" % label)
		var lines: Variant = lecture.get("lines", [])
		if not (lines is Array):
			errors.append("%s lines must be an array" % label)
		else:
			for line: Variant in lines:
				if not (line is String) or String(line) == "":
					errors.append("%s lines must be non-empty strings" % label)
		for id: String in lecture.get("insights", []):
			if not data.dao_insights.has(id):
				errors.append("%s lists unknown insight '%s'" % [label, id])
	return errors


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
		if mission_offered(c, data, mission, flags):
			out.append(String(mission["id"]))
	return out


## True when `c`'s sect lists `mission` right now (sect, flag and max_realm gates; not rank or cooldown).
## QA-213: the single-mission form of available_missions, so check_mission need not scan the board.
static func mission_offered(c: CharacterData, data: GameData, mission: Dictionary, flags: Dictionary = {}) -> bool:
	if c.is_rogue():
		return false
	var sects: Array = mission.get("sects", [])
	var needed_flag := String(mission.get("requires_flag", ""))
	if needed_flag != "" and not flags.get(needed_flag, false):
		return false
	if mission_beneath(c, data, mission):
		return false
	return sects.is_empty() or sects.has(c.sect["id"])


## MISSION-003: True when `mission` has a `max_realm` and `c` has risen above it.
static func mission_beneath(c: CharacterData, data: GameData, mission: Dictionary) -> bool:
	if not mission.has("max_realm"):
		return false
	return c.realm_index > data.realm_index_of(String(mission["max_realm"]))


## Items (id -> count, summed) that `c`'s sect deliver-style missions are waiting on: missions with
## `requires.items` that `c` could take now except for the items (rank/realm met, not on cooldown).
static func deliver_needs(c: CharacterData, data: GameData, flags: Dictionary = {}) -> Dictionary:
	var out := {}
	for id: String in available_missions(c, data, flags):
		var mission: Dictionary = data.sect_missions[id]
		var needed: Dictionary = mission.get("requires", {}).get("items", {})
		if needed.is_empty() or not only_items_missing(c, data, id):
			continue
		for item_id: String in needed:
			out[item_id] = int(out.get(item_id, 0)) + int(needed[item_id])
	return out


## True when `c` meets `mission_id`'s rank/realm and it is off cooldown, so only the items could stop them.
static func only_items_missing(c: CharacterData, data: GameData, mission_id: String) -> bool:
	var mission: Dictionary = data.sect_missions.get(mission_id, {})
	return not mission.is_empty() and mission_rank_realm_reason(c, data, mission) == "" and mission_cooldown_left(c, mission_id) <= 0


## Days until `c` may take `mission_id` again (0 = ready).
static func mission_cooldown_left(c: CharacterData, mission_id: String) -> int:
	return maxi(0, int(c.mission_cooldowns.get(mission_id, 0)) - c.age_days)


## Why `c` falls short of `mission`'s min_rank / min_realm / min_stage, or "" if they meet both.
static func mission_rank_realm_reason(c: CharacterData, data: GameData, mission: Dictionary) -> String:
	if c.is_rogue():
		return "Only sect disciples receive sect missions."
	var sect: SectDef = data.sects[c.sect["id"]]
	var min_rank := int(mission.get("min_rank", 0))
	if int(c.sect["rank"]) < min_rank:
		return "Only %s or above may take this mission." % Text.a(sect.rank_name(min_rank))
	if mission_beneath(c, data, mission):
		return "Beneath you now: %s." % String(mission.get("name", "this mission"))
	var min_realm := data.realm_index_of(String(mission.get("min_realm", "mortal")))
	var min_stage := int(mission.get("min_stage", 0))
	if c.realm_index < min_realm or (c.realm_index == min_realm and c.stage < min_stage):
		return "This mission needs a cultivator of %s or above." % data.realms[min_realm].stage_label(min_stage)
	return ""


## MISSION-001: "" when the mission board is in `region_id` (a region with a `sect_hall` place, or the
## sect's home region); otherwise why not, naming the sect's hall. "" for a rogue or an empty region id.
static func board_reason(c: CharacterData, data: GameData, region_id: String) -> String:
	if region_id == "" or c.is_rogue():
		return ""
	if region_id == home_region(data, String(c.sect["id"])):
		return ""
	if hall_name(data, region_id, c) != "":
		return ""
	var far := Guidance.nearest_selling(c, data, region_id, func(r: String) -> String: return hall_name(data, r, c))
	if not far.is_empty():
		return "The mission board is at a sect hall (nearest: %s, %s)." % [far["result"], far["region_name"]]
	var home := home_region(data, String(c.sect["id"]))
	var regions: Array = [home] + data.regions.keys()
	for r: String in regions:
		var hall := hall_name(data, r, c)
		if hall != "":
			return "The mission board is at a sect hall (nearest: %s, %s)." % [hall, Exploration.region_name(data, r)]
	return "The mission board is at a sect hall."


## MISSION-002: whether the sect_hall `place` serves `c`: a place without a `sect` serves every disciple,
## one with a `sect` only that sect's members. A rogue is served by none (they have no board).
static func hall_serves(c: CharacterData, place: Dictionary) -> bool:
	if c.is_rogue():
		return false
	var sect_id := String(place.get("sect", ""))
	return sect_id == "" or sect_id == String(c.sect["id"])


## The display name of the first sect hall in `region_id` that serves `c` ("" if none). For a rogue
## (who joins at a hall) any hall without a `sect` counts.
static func hall_name(data: GameData, region_id: String, c: CharacterData) -> String:
	for p: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(p.get("type", "")) != "sect_hall":
			continue
		if hall_serves(c, p) or (c.is_rogue() and String(p.get("sect", "")) == ""):
			return String(p.get("display_name", "sect hall"))
	return ""


## Why `c` cannot take `mission_id` now, or "" if they can. A non-empty `region_id` also requires
## the mission board to be there (board_reason); "" skips that check.
static func check_mission(c: CharacterData, data: GameData, mission_id: String, flags: Dictionary = {}, region_id: String = "") -> String:
	if not data.sect_missions.has(mission_id):
		return "No such mission."
	if c.is_rogue():
		return "Only sect disciples receive sect missions."
	var board := board_reason(c, data, region_id)
	if board != "":
		return board
	var offered: Array = data.sect_missions[mission_id].get("sects", [])
	if not offered.is_empty() and not offered.has(c.sect["id"]):
		return "Your sect does not offer that mission."
	var mission: Dictionary = data.sect_missions[mission_id]
	if mission_beneath(c, data, mission):
		return mission_rank_realm_reason(c, data, mission)
	if not mission_offered(c, data, mission, flags):
		return "Your sect has no need of this now."
	var rank_realm := mission_rank_realm_reason(c, data, mission)
	if rank_realm != "":
		return rank_realm
	var wait := mission_cooldown_left(c, mission_id)
	if wait > 0 and c.mission_losses.has(mission_id):
		return "You fell to this mission recently: it is not offered again for %s." % Calendar.format_duration(wait)
	if wait > 0:
		return "This mission is not offered again for %s." % Calendar.format_duration(wait)
	var needed: Dictionary = mission.get("requires", {}).get("items", {})
	for item_id in needed:
		if c.item_count(item_id) < int(needed[item_id]):
			return "You need %d %s." % [int(needed[item_id]), Items.item_plural(data, item_id, int(needed[item_id]))]
	return ""


## GUIDE-235: spirit stones one contribution point is worth at `sect_id`'s treasury: the median over its shop entries
## of item price / contribution. 0.0 for an unknown sect or an empty shop.
static func contribution_value(data: GameData, sect_id: String) -> float:
	if not data.sects.has(sect_id):
		return 0.0
	var vals: Array[float] = []
	for entry: Dictionary in (data.sects[sect_id] as SectDef).shop:
		var cost := int(entry.get("contribution", 0))
		if cost > 0:
			vals.append(float(int(data.items.get(String(entry.get("item_id", "")), {}).get("price", 0))) / float(cost))
	if vals.is_empty():
		return 0.0
	vals.sort()
	var mid := vals.size() / 2
	return vals[mid] if vals.size() % 2 == 1 else (vals[mid - 1] + vals[mid]) / 2.0


## Records a lost mission fight: the mission cools down for
## sect_missions.json `loss_cooldown_days` (never shortening a longer cooldown).
static func fail_mission(c: CharacterData, data: GameData, mission_id: String) -> void:
	var until := c.age_days + data.sect_mission_loss_cooldown_days
	c.mission_cooldowns[mission_id] = maxi(int(c.mission_cooldowns.get(mission_id, 0)), until)
	c.mission_losses[mission_id] = c.age_days


## Days since `mission_id`'s fight was last lost (-1 when never lost).
static func last_loss_days_ago(c: CharacterData, mission_id: String) -> int:
	if not c.mission_losses.has(mission_id):
		return -1
	return c.age_days - int(c.mission_losses[mission_id])


## Danger label (Combat.danger_label: Weak/Even/Risky/Dangerous/Deadly) of the
## mission's fight for `c`, or "" if the mission has no enemy. Missions are
## always fought (a Deadly foe is not evaded), so the board should show this.
static func mission_danger(c: CharacterData, data: GameData, mission_id: String) -> String:
	var enemy_id := String(data.sect_missions.get(mission_id, {}).get("enemy", ""))
	if enemy_id == "" or not data.enemies.has(enemy_id):
		return ""
	return Combat.danger_label(c, data, data.enemies[enemy_id])


## Like mission_danger, but as shown to the player (odds once appraisal is unsealed).
static func mission_danger_text(c: CharacterData, data: GameData, mission_id: String) -> String:
	var enemy_id := String(data.sect_missions.get(mission_id, {}).get("enemy", ""))
	if enemy_id == "" or not data.enemies.has(enemy_id):
		return ""
	return Appraisal.danger_text(c, data, data.enemies[enemy_id])


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
	c.mission_losses.erase(mission_id)
	return {"ok": true, "reason": "", "contribution": contribution, "promoted": promoted, "notes": notes, "days": int(mission.get("days", 1))}


## Load errors for data/sect_missions.json.
static func validate_missions(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.sect_mission_loss_cooldown_days < 0:
		errors.append("sect_missions.json loss_cooldown_days must be >= 0")
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
		if mission.has("max_realm"):
			var max_index := data.realm_index_of(String(mission["max_realm"]))
			if max_index < 0:
				errors.append("Mission '%s' has unknown max_realm '%s'" % [id, mission["max_realm"]])
			elif max_index < realm_index:
				errors.append("Mission '%s' has max_realm below its min_realm" % id)
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
