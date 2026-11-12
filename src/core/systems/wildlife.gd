class_name Wildlife
extends RefCounted
## WILD-001: beasts you can see. Each wild region may list `roamers` in regions.json; every day a
## deterministic few of them roam the map and the player can pick a fight with one. A beast that has
## been fought stays gone (timed world flag) until the next day.

const MAX_COUNT := 6
const BOUNTY_SLOT := 100
const GREAT_SLOT := 101
const GREAT_LOOKAHEAD := 400
const TEMPERS: Array[String] = ["flees", "wary", "bold"]


## Today's roamers in a region: [{slot: int, enemy: String, temper: String}] (temper "" = by threat). Same inputs give the same list.
## The local rng below is a pure derivation from (region, day), not game randomness.
static func roamers(data: GameData, region_id: String, day: int, realm_index: int, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var def: Dictionary = data.regions.get(region_id, {}).get("roamers", {})
	if def.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [region_id, day])
	var season := Calendar.season_of(day)
	var pool: Array[Dictionary] = []
	var total := 0.0
	for entry: Dictionary in def.get("enemies", []):
		if not Exploration.in_season(entry, season):
			continue
		if entry.has("min_realm") and realm_index < data.realm_index_of(String(entry["min_realm"])):
			continue
		if entry.has("max_realm") and realm_index > data.realm_index_of(String(entry["max_realm"])):
			continue
		pool.append(entry)
		total += float(entry["weight"])
	if pool.is_empty():
		return out
	var count_range: Array = def.get("count", [0, 0])
	var count := rng.randi_range(int(count_range[0]), int(count_range[1]))
	for slot in count:
		var roll := rng.randf() * total
		var pick: Dictionary = pool[pool.size() - 1]
		for entry in pool:
			roll -= float(entry["weight"])
			if roll < 0.0:
				pick = entry
				break
		if not Effects.flag_active(flags, flag_key(region_id, slot), day):
			out.append({"slot": slot, "enemy": String(pick["enemy"]), "temper": String(pick.get("temper", ""))})
	return out


## WILD-003: the beast of the player's active bounty walks its region's map (slot 100), unless it is down
## today, out of reach (exploration's evade rule) or not a non-lethal beast: lethal hunts and human or
## ghost quarry stay exploration-only, like every map roamer (WILD-001). Returns {} when it does not.
static func bounty_roamer(c: CharacterData, data: GameData, region_id: String, day: int, flags: Dictionary) -> Dictionary:
	var b := Bounties.active(c, data, day)
	if b.is_empty() or String(b["region"]) != region_id or not data.enemies.has(String(b["enemy"])):
		return {}
	var enemy_id := String(b["enemy"])
	if Effects.flag_active(flags, flag_key(region_id, BOUNTY_SLOT), day):
		return {}
	var enemy: Dictionary = data.enemies[enemy_id]
	if bool(enemy.get("lethal", false)) or not (enemy.get("tags", []) as Array).has("beast"):
		return {}
	if Exploration.should_evade(c, data, enemy_id):
		return {}
	return {"slot": BOUNTY_SLOT, "enemy": enemy_id, "temper": "bold"}


## WILD-006: the weekday (0-6) a region's great beast walks: `def.weekday`, else a stable hash of the region id.
static func great_day(region_id: String, def: Dictionary) -> int:
	if def.has("weekday"):
		return posmod(int(def["weekday"]), 7)
	return posmod(hash(region_id), 7)


static func _great_def(data: GameData, region_id: String) -> Dictionary:
	return data.regions.get(region_id, {}).get("roamers", {}).get("great", {})


## WILD-020: a region's great beasts as a chain of steps: the slot itself, then each nested `return` (any depth).
static func great_chain(def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var step: Variant = def
	while step is Dictionary and not (step as Dictionary).is_empty():
		out.append(step)
		step = (step as Dictionary).get("return")
	return out


## WILD-019/020: which beast the great slot holds for `c`: {enemy, ret, step} or {} when nothing walks for them. The
## walking beast is the first step not yet beaten; an unbeaten step the player has outgrown (`max_realm`) is skipped, an
## unbeaten step above their realm (`min_realm`, defaulting to the previous step's) stops the walk. When every step is
## beaten or skipped the last step keeps walking while the player is in its range. With no character the first beast
## gates on `realm_index` only (old callers, sims).
static func _great_pick(c: CharacterData, data: GameData, def: Dictionary, realm_index: int) -> Dictionary:
	if def.is_empty():
		return {}
	var chain := great_chain(def)
	var first := String(def.get("enemy", ""))
	var mins: Array[int] = []
	var inherited := -1
	for step: Dictionary in chain:
		if step.has("min_realm"):
			inherited = data.realm_index_of(String(step["min_realm"]))
		mins.append(inherited)
	if c == null:
		return {} if realm_index < mins[0] else {"enemy": first, "ret": false, "step": 0}
	for i in chain.size():
		var step: Dictionary = chain[i]
		var enemy := String(step.get("enemy", first))
		if c.great_beasts.has(enemy):
			continue
		if step.has("max_realm") and realm_index > data.realm_index_of(String(step["max_realm"])):
			continue
		if realm_index < mins[i]:
			return {}
		return {"enemy": enemy, "ret": i > 0, "step": i}
	var last := chain.size() - 1
	var ls: Dictionary = chain[last]
	if realm_index < mins[last]:
		return {}
	if ls.has("max_realm") and realm_index > data.realm_index_of(String(ls["max_realm"])):
		return {}
	return {"enemy": String(ls.get("enemy", first)), "ret": last > 0, "step": last}


## WILD-019: the enemy walking the region's great slot for `c`, "" when nothing does. Every great-beast caller uses it.
static func great_enemy_for(c: CharacterData, data: GameData, region_id: String) -> String:
	var def := _great_def(data, region_id)
	var realm := c.realm_index if c != null else 0
	return String(_great_pick(c, data, def, realm).get("enemy", ""))


## True when the region's great beast may walk on `day` for a player at `realm_index` (weekday, season, realm).
static func _great_walks(data: GameData, region_id: String, def: Dictionary, day: int, realm_index: int, c: CharacterData = null) -> bool:
	if def.is_empty() or day % 7 != great_day(region_id, def):
		return false
	if not Exploration.in_season(def, Calendar.season_of(day)):
		return false
	return not _great_pick(c, data, def, realm_index).is_empty()


## The region's great beast ({slot 101, enemy, temper "wary", great true}) on its weekday, unless it is down today. Pure.
static func great_roamer(c: CharacterData, data: GameData, region_id: String, day: int, flags: Dictionary) -> Dictionary:
	var def := _great_def(data, region_id)
	if not _great_walks(data, region_id, def, day, c.realm_index, c):
		return {}
	if Effects.flag_active(flags, flag_key(region_id, GREAT_SLOT), day):
		return {}
	return {"slot": GREAT_SLOT, "enemy": active_great_enemy(c, data, region_id), "temper": "wary", "great": true}


## WILD-014: the enemy the region's great-beast slot spawns (WILD-019: see `great_enemy_for`; falls back to the first
## beast's id when nothing walks, for callers that only name it).
static func active_great_enemy(c: CharacterData, data: GameData, region_id: String) -> String:
	var e := great_enemy_for(c, data, region_id)
	return e if e != "" else String(_great_def(data, region_id).get("enemy", ""))


## C-297/WILD-020: the hunters' rumour about a region's great beast (the step now walking, else the first unbeaten
## one), "" when it has none. Later steps without a rumour fall back to the slot's own.
static func rumor_of(data: GameData, region_id: String, c: CharacterData = null) -> String:
	var def := _great_def(data, region_id)
	if c != null:
		var chain := great_chain(def)
		var idx := -1
		var pick := _great_pick(c, data, def, c.realm_index)
		if not pick.is_empty():
			idx = int(pick["step"])
		else:
			idx = chain.size() - 1
			for i in chain.size():
				if not c.great_beasts.has(String(chain[i].get("enemy", ""))):
					idx = i
					break
		if idx > 0 and chain[idx].has("rumor"):
			return String(chain[idx]["rumor"])
	return String(def.get("rumor", ""))


## The first day >= from_day the region's great beast walks (for a player at `realm_index`); -1 when it has none.
static func next_great_day(data: GameData, region_id: String, from_day: int, realm_index: int, c: CharacterData = null) -> int:
	var def := _great_def(data, region_id)
	if def.is_empty():
		return -1
	for day in range(from_day, from_day + GREAT_LOOKAHEAD):
		if _great_walks(data, region_id, def, day, realm_index, c):
			return day
	return -1


## WILD-012: true on the day before the region's great beast walks (for a player at `realm_index`).
static func tracks_today(data: GameData, region_id: String, day: int, realm_index: int, c: CharacterData = null) -> bool:
	var def := _great_def(data, region_id)
	return _great_walks(data, region_id, def, day + 1, realm_index, c)


## WILD-015: the bait item the player would spend on the region's great-beast trail: a `great.bait` id they hold,
## else any held item tagged `bait`; "" when the region has no great beast or they hold none.
static func bait_item(c: CharacterData, data: GameData, region_id: String) -> String:
	var def := _great_def(data, region_id)
	if def.is_empty():
		return ""
	for id: Variant in def.get("bait", []):
		if c.item_count(String(id)) > 0:
			return String(id)
	for id: String in c.inventory:
		if c.item_count(id) > 0 and (data.items.get(id, {}).get("tags", []) as Array).has("bait"):
			return id
	return ""


## WILD-015: the share of hp and attack a baited great beast loses.
static func bait_weaken(data: GameData, region_id: String) -> float:
	return float(_great_def(data, region_id).get("bait_weaken", 0.1))


## WILD-015: a copy of the enemy that starts the fight weakened.
static func weakened(enemy: Dictionary, frac: float) -> Dictionary:
	var e := enemy.duplicate(true)
	e["weaken"] = frac
	return e


## WU-456: the menu description of the bait row. With `item_id` held: what it costs and what it does; with "": which
## items the region's great beast takes as bait. "" when the region has no great beast.
static func bait_line(data: GameData, region_id: String, item_id: String, c: CharacterData = null) -> String:
	var def := _great_def(data, region_id)
	if def.is_empty():
		return ""
	var enemy := active_great_enemy(c, data, region_id) if c != null else String(def.get("enemy", ""))
	var beast := display_name(data, enemy, true)
	if item_id != "":
		return "Uses 1 %s, 1 day. Tomorrow the %s comes in weakened." % [String(data.items[item_id]["name"]).to_lower(), beast]
	var names: Array[String] = []
	for id: Variant in def.get("bait", []):
		names.append(String(data.items.get(String(id), {}).get("name", String(id))).to_lower())
	if names.is_empty():
		return "You need something tagged bait to lure the %s." % beast
	return "You need " + " or ".join(names) + " to lure the " + beast + "."


## WILD-015: world flag holding the day a baited trail's beast walks.
static func bait_flag(region_id: String) -> String:
	return "bait_" + region_id


## WILD-012: the line shown when exploring on a tracks day.
const TRACKS_LINE := "Fresh tracks, wider than a cart: something big walks here tomorrow."


## WILD-008: an enemy's display name; the great beast reads "Great <name>".
static func display_name(data: GameData, enemy_id: String, great: bool) -> String:
	var n := String(data.enemies.get(enemy_id, {}).get("name", enemy_id))
	return "Great " + n if great else n


## WILD-013: true when `enemy_id` has a roamers entry in `region_id` whose `in_season` list holds today's season:
## its spoils then roll twice.
static func in_season_now(data: GameData, region_id: String, enemy_id: String, day: int) -> bool:
	var season := Calendar.season_of(day).to_lower()
	for e: Dictionary in data.regions.get(region_id, {}).get("roamers", {}).get("enemies", []):
		if String(e["enemy"]) == enemy_id and (e.get("in_season", []) as Array).has(season):
			return true
	return false


## WILD-013: "Fat Mist Foxes run in Misty Forest this autumn." for the first in-season beast kind, "" if none.
static func season_clause(data: GameData, region_id: String, day: int) -> String:
	var season := Calendar.season_of(day).to_lower()
	for e: Dictionary in data.regions.get(region_id, {}).get("roamers", {}).get("enemies", []):
		if (e.get("in_season", []) as Array).has(season):
			var n := String(data.enemies.get(String(e["enemy"]), {}).get("name", e["enemy"]))
			var plural := Text.plural(n, 2)
			return "Fat %s run in %s this %s." % [plural, Exploration.region_name(data, region_id), season]
	return ""


static func flag_key(region_id: String, slot: int) -> String:
	return "roamer_down_%s_%d" % [region_id, slot]


## The beast in `slot` leaves for the rest of today.
static func mark_down(flags: Dictionary, region_id: String, slot: int, day: int) -> void:
	flags[flag_key(region_id, slot)] = {"until": day + 1}


## Danger label of a roamer for the player (Weak/Even/Risky/Dangerous/Deadly), as the fight hints show it.
static func threat(c: CharacterData, data: GameData, enemy_id: String) -> String:
	return Combat.danger_label(c, data, data.enemies[enemy_id])


const THREAT_ORDER: Array[String] = ["Weak", "Even", "Risky", "Dangerous", "Deadly"]


## GUIDE-237: the worst danger label among a region's ordinary roamers that can spawn on `day` for the player's realm
## (season, min_realm, max_realm as `roamers` applies them; the great beast is left out): {label, names} with up to
## 2 names of beasts at that label. {label: "", names: []} when the region has none.
static func region_threat(c: CharacterData, data: GameData, region_id: String, day: int) -> Dictionary:
	var def: Dictionary = data.regions.get(region_id, {}).get("roamers", {})
	var season := Calendar.season_of(day)
	var worst := -1
	var names: Array[String] = []
	for entry: Dictionary in def.get("enemies", []):
		if not Exploration.in_season(entry, season):
			continue
		if entry.has("min_realm") and c.realm_index < data.realm_index_of(String(entry["min_realm"])):
			continue
		if entry.has("max_realm") and c.realm_index > data.realm_index_of(String(entry["max_realm"])):
			continue
		var enemy_id := String(entry["enemy"])
		if not data.enemies.has(enemy_id):
			continue
		var rank := THREAT_ORDER.find(threat(c, data, enemy_id))
		var shown := GameData.plain_name(String(data.enemies[enemy_id].get("name", enemy_id)))
		if rank > worst:
			worst = rank
			names = [shown]
		elif rank == worst and names.size() < 2 and not names.has(shown):
			names.append(shown)
	return {"label": THREAT_ORDER[worst] if worst >= 0 else "", "names": names}


## GUIDE-237: true when the label of `region_threat` deserves a warning (Dangerous or Deadly).
static func is_grave(label: String) -> bool:
	return label == "Dangerous" or label == "Deadly"


## WILD-002: how a beast reacts to the player: the override if set, else by threat
## (Weak flees, Even is wary, Risky and worse is bold).
static func temper(c: CharacterData, data: GameData, enemy_id: String, override: String = "") -> String:
	if override != "":
		return override
	match threat(c, data, enemy_id):
		"Weak":
			return "flees"
		"Even":
			return "wary"
	return "bold"


## WILD-004: records a map beast beaten (hunt_log + the life stat).
static func record_hunt(c: CharacterData, enemy_id: String) -> void:
	c.hunt_log[enemy_id] = int(c.hunt_log.get(enemy_id, 0)) + 1
	LifeStats.add(c, "beasts_hunted")


## WILD-005: adds what a win dropped (`gained`: item id -> count) to the hunt's spoils.
static func record_spoils(c: CharacterData, enemy_id: String, gained: Dictionary) -> void:
	if gained.is_empty():
		return
	var seen: Dictionary = c.hunt_spoils.get(enemy_id, {})
	for item_id: String in gained:
		seen[item_id] = int(seen.get(item_id, 0)) + int(gained[item_id])
	c.hunt_spoils[enemy_id] = seen


## WILD-007: the trophy item id of a great beast kind (from any region whose great beast it is), "" when none.
static func great_trophy(data: GameData, enemy_id: String) -> String:
	for region: Dictionary in data.regions.values():
		var g: Dictionary = region.get("roamers", {}).get("great", {})
		if not g.is_empty() and String(g.get("enemy", "")) == enemy_id and g.has("trophy"):
			return String(g["trophy"])
		for step in great_chain(g):
			if String(step.get("enemy", "")) == enemy_id and step.has("trophy"):
				return String(step["trophy"])
	return ""


## WILD-007: records a great-beast win. Returns the trophy item id to give the first time ("" when
## already recorded or the beast has no trophy). The first win's day is always stored.
static func record_great(c: CharacterData, data: GameData, enemy_id: String, region_id: String, day: int) -> String:
	# GOAL-012: remember the best realm each kind was beaten in (a re-win in a higher realm counts).
	c.great_beast_realms[enemy_id] = maxi(int(c.great_beast_realms.get(enemy_id, -1)), c.realm_index)
	if c.great_beasts.has(enemy_id):
		return ""
	c.great_beasts[enemy_id] = day
	var def := _great_def(data, region_id)
	if String(def.get("enemy", "")) == enemy_id and def.has("trophy"):
		return String(def["trophy"])
	for step in great_chain(def):
		if String(step.get("enemy", "")) == enemy_id and step.has("trophy"):
			return String(step["trophy"])
	return great_trophy(data, enemy_id)


## WILD-021: world flag set once a region's great-beast trail has been walked to its last step.
static func trail_flag(region_id: String) -> String:
	return "great_trail_done_" + region_id


## WILD-021: true when `enemy_id` is the last step of `region_id`'s great chain (and the chain is more than one step).
static func is_trail_end(data: GameData, region_id: String, enemy_id: String) -> bool:
	var chain := great_chain(_great_def(data, region_id))
	return chain.size() >= 2 and String(chain.back().get("enemy", "")) == enemy_id


## WILD-021: call on a great-beast win (`first_win`: the kind was not in great_beasts before). The first win of the
## trail's last step sets the flag once and returns the line to post ("" otherwise).
static func finish_trail(data: GameData, flags: Dictionary, region_id: String, enemy_id: String, first_win: bool) -> String:
	if not first_win or not is_trail_end(data, region_id, enemy_id) or flags.has(trail_flag(region_id)):
		return ""
	flags[trail_flag(region_id)] = true
	var text := String(_great_def(data, region_id).get("trail_done_text", "The hunters of {region} will tell this hunt for years."))
	return text.replace("{region}", String(data.regions[region_id].get("name", region_id)))


## WILD-021: sets the trail flag, silently, for every region whose last great beast `c` has already felled (saves from
## before WILD-021, where the first win of the last step never set it). Returns the regions flagged.
static func backfill_trails(c: CharacterData, data: GameData, flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for region_id: String in data.regions:
		var chain := great_chain(_great_def(data, region_id))
		if chain.size() < 2 or flags.has(trail_flag(region_id)):
			continue
		if c.great_beasts.has(String(chain.back().get("enemy", ""))):
			flags[trail_flag(region_id)] = true
			out.append(region_id)
	return out


## Item id -> count of everything this beast has dropped for the player so far.
static func spoils_of(c: CharacterData, enemy_id: String) -> Dictionary:
	return c.hunt_spoils.get(enemy_id, {}).duplicate()


## What `after` has more of than `before` (two inventories), item id -> count.
static func inventory_gain(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for item_id: String in after:
		var d := int(after[item_id]) - int(before.get(item_id, 0))
		if d > 0:
			out[item_id] = d
	return out


## WILD-009: what a hunter knows of a beast kind after 3 wins: its temper and its usual spoils (most often
## dropped first, then by name, at most 3). "" below 3 hunts. Spoils are left out for saves that predate them.
static func quarry_notes(c: CharacterData, data: GameData, enemy_id: String) -> String:
	if int(c.hunt_log.get(enemy_id, 0)) < 3 or not data.enemies.has(enemy_id):
		return ""
	var parts: PackedStringArray = []
	var spoils := spoils_of(c, enemy_id)
	var ids: Array = []
	for item_id: String in spoils:
		if data.items.has(item_id) and item_id != "spirit_stone":
			ids.append(item_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := int(spoils[a])
		var cb := int(spoils[b])
		if ca != cb:
			return ca > cb
		return String(data.items[a]["name"]) < String(data.items[b]["name"]))
	var names: PackedStringArray = []
	for item_id: String in ids.slice(0, 3):
		names.append(String(data.items[item_id]["name"]))
	if not names.is_empty():
		parts.append("Usually leaves: %s (from your hunts)" % ", ".join(names))
	var override := ""
	for region: Dictionary in data.regions.values():
		for e: Dictionary in region.get("roamers", {}).get("enemies", []):
			if String(e["enemy"]) == enemy_id and override == "":
				override = String(e.get("temper", ""))
	match temper(c, data, enemy_id, override):
		"flees":
			parts.append("flees when you come close")
		"wary":
			parts.append("keeps its distance, wary")
		_:
			parts.append("charges when it sees you")
	return "; ".join(parts)


## Every enemy any region's roamers list, sorted.
static func huntable(data: GameData) -> PackedStringArray:
	var seen := {}
	for region: Dictionary in data.regions.values():
		for e: Dictionary in region.get("roamers", {}).get("enemies", []):
			seen[String(e["enemy"])] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## "Beasts hunted: 7 of 12 kinds", "" while the log is empty.
static func log_summary(c: CharacterData, data: GameData) -> String:
	if c.hunt_log.is_empty():
		return ""
	var all := huntable(data)
	var known := 0
	for id in all:
		if c.hunt_log.has(id):
			known += 1
	return "Beasts hunted: %d of %d kinds" % [known, all.size()]


static func _num(v: Variant) -> bool:
	return v is float or v is int


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		if not region.has("roamers"):
			continue
		var where := "Region '%s' roamers" % region["id"]
		var def: Variant = region["roamers"]
		if not def is Dictionary:
			errors.append("%s must be an object" % where)
			continue
		var great: Variant = def.get("great")
		if great != null:
			if not great is Dictionary or not data.enemies.has(String(great.get("enemy", ""))):
				errors.append("%s great needs a known enemy" % where)
			else:
				var ge: Dictionary = data.enemies[great["enemy"]]
				if not (ge.get("tags", []) as Array).has("beast") or bool(ge.get("lethal", false)):
					errors.append("%s great enemy '%s' must be a non-lethal beast" % [where, great["enemy"]])
				if great.has("weekday") and not (_num(great["weekday"]) and int(great["weekday"]) >= 0 and int(great["weekday"]) <= 6):
					errors.append("%s great weekday must be 0..6" % where)
				if great.has("rumor") and not (great["rumor"] is String and not String(great["rumor"]).strip_edges().is_empty()):
					errors.append("%s great rumor must be a non-empty string" % where)
				if great.has("trail_done_text") and not (great["trail_done_text"] is String and not String(great["trail_done_text"]).strip_edges().is_empty() and String(great["trail_done_text"]).length() <= 160):
					errors.append("%s great trail_done_text must be a non-empty string of at most 160 characters" % where)
				if great.has("min_realm") and data.realm_index_of(String(great["min_realm"])) < 0:
					errors.append("%s great has unknown min_realm" % where)
				errors.append_array(_max_realm_errors(data, great, "%s great" % where))
				if great.has("trophy"):
					var ti: Variant = data.items.get(String(great["trophy"]))
					if ti == null or not ((ti as Dictionary).get("tags", []) as Array).has("trophy"):
						errors.append("%s great trophy '%s' must be an item tagged trophy" % [where, great["trophy"]])
				if great.has("bait"):
					var bl: Variant = great["bait"]
					if not (bl is Array and not (bl as Array).is_empty()):
						errors.append("%s great bait must be a non-empty list of item ids" % where)
					else:
						for bid: Variant in bl:
							if not data.items.has(String(bid)):
								errors.append("%s great bait '%s' is not an item" % [where, bid])
				if great.has("bait_weaken") and not (_num(great["bait_weaken"]) and float(great["bait_weaken"]) >= 0.02 and float(great["bait_weaken"]) <= 0.5):
					errors.append("%s great bait_weaken must be 0.02..0.5" % where)
				_return_errors(data, great, "%s great" % where, errors)
				for gs: Variant in great.get("seasons", []):
					if not Exploration.SEASON_NAMES.has(String(gs)):
						errors.append("%s great has unknown season '%s'" % [where, gs])
		var cnt: Variant = def.get("count")
		if not (cnt is Array and cnt.size() == 2 and _num(cnt[0]) and _num(cnt[1]) \
				and int(cnt[0]) >= 0 and int(cnt[0]) <= int(cnt[1]) and int(cnt[1]) <= MAX_COUNT):
			errors.append("%s count must be [min, max] within 0..%d" % [where, MAX_COUNT])
		var entries: Variant = def.get("enemies")
		if not (entries is Array and not entries.is_empty()):
			errors.append("%s needs a non-empty enemies list" % where)
			continue
		var in_season_count: int = 0
		for e: Variant in entries:
			if not e is Dictionary or not data.enemies.has(String(e.get("enemy", ""))):
				errors.append("%s has an unknown enemy" % where)
				continue
			var enemy: Dictionary = data.enemies[e["enemy"]]
			if not (enemy.get("tags", []) as Array).has("beast") or bool(enemy.get("lethal", false)):
				errors.append("%s enemy '%s' must be a non-lethal beast" % [where, e["enemy"]])
			if not ((e.get("weight") is float or e.get("weight") is int) and float(e["weight"]) > 0.0):
				errors.append("%s enemy '%s' needs weight > 0" % [where, e["enemy"]])
			if e.has("temper") and not TEMPERS.has(String(e["temper"])):
				errors.append("%s enemy '%s' has unknown temper '%s'" % [where, e["enemy"], e["temper"]])
			for s: Variant in e.get("seasons", []):
				if not Exploration.SEASON_NAMES.has(String(s)):
					errors.append("%s enemy '%s' has unknown season '%s'" % [where, e["enemy"], s])
			if e.has("min_realm") and data.realm_index_of(String(e["min_realm"])) < 0:
				errors.append("%s enemy '%s' has unknown min_realm" % [where, e["enemy"]])
			if e.has("max_realm"):
				if data.realm_index_of(String(e["max_realm"])) < 0:
					errors.append("%s enemy '%s' has unknown max_realm" % [where, e["enemy"]])
				elif e.has("min_realm") and data.realm_index_of(String(e["max_realm"])) < data.realm_index_of(String(e["min_realm"])):
					errors.append("%s enemy '%s' max_realm is below its min_realm" % [where, e["enemy"]])
			if e.has("in_season") and not e["in_season"] is Array:
				errors.append("%s enemy '%s' in_season must be a list of seasons" % [where, e["enemy"]])
			for s: Variant in e.get("in_season", []) if e.get("in_season") is Array else []:
				if not Exploration.SEASON_NAMES.has(String(s)):
					errors.append("%s enemy '%s' has unknown in_season '%s'" % [where, e["enemy"], s])
				elif e.has("seasons") and not (e["seasons"] as Array).has(s):
					errors.append("%s enemy '%s' in_season '%s' is not one of its seasons" % [where, e["enemy"], s])
			if e.get("in_season") is Array and not (e["in_season"] as Array).is_empty():
				in_season_count += 1
		if in_season_count > 4:
			errors.append("%s has %d in_season beasts (max 4)" % [where, in_season_count])
	return errors


## WILD-020: validates a step's nested `return` chain (any depth) with the same rules at every level.
static func _return_errors(data: GameData, parent: Dictionary, label: String, errors: PackedStringArray) -> void:
	var rt: Variant = parent.get("return")
	if rt == null:
		return
	if not rt is Dictionary or not data.enemies.has(String(rt.get("enemy", ""))):
		errors.append("%s return needs a known enemy" % label)
		return
	var re: Dictionary = data.enemies[rt["enemy"]]
	if bool(re.get("lethal", false)) or not (re.get("tags", []) as Array).has("beast"):
		errors.append("%s return enemy '%s' must be a non-lethal beast" % [label, rt["enemy"]])
	var rti: Variant = data.items.get(String(rt.get("trophy", "")))
	if rti == null or not (rti.get("tags", []) as Array).has("trophy"):
		errors.append("%s return trophy must be an item tagged trophy" % label)
	if rt.has("min_realm") and data.realm_index_of(String(rt["min_realm"])) < 0:
		errors.append("%s return has unknown min_realm" % label)
	errors.append_array(_max_realm_errors(data, rt, "%s return" % label))
	if rt.has("rumor") and not (rt["rumor"] is String and not String(rt["rumor"]).is_empty() and String(rt["rumor"]).length() <= 140):
		errors.append("%s return rumor must be a string of at most 140 characters" % label)
	_return_errors(data, rt, "%s return" % label, errors)


## WILD-019: errors for an optional `max_realm` on a great beast or its return: a known realm, not below its min_realm.
static func _max_realm_errors(data: GameData, def: Dictionary, label: String) -> Array[String]:
	var out: Array[String] = []
	if not def.has("max_realm"):
		return out
	var mx := data.realm_index_of(String(def["max_realm"]))
	if mx < 0:
		out.append("%s has unknown max_realm" % label)
	elif def.has("min_realm") and data.realm_index_of(String(def["min_realm"])) > mx:
		out.append("%s max_realm is below its min_realm" % label)
	return out
