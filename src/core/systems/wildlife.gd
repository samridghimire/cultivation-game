class_name Wildlife
extends RefCounted
## WILD-001: beasts you can see. Each wild region may list `roamers` in regions.json; every day a
## deterministic few of them roam the map and the player can pick a fight with one. A beast that has
## been fought stays gone (timed world flag) until the next day.

const MAX_COUNT := 6
const BOUNTY_SLOT := 100
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


static func flag_key(region_id: String, slot: int) -> String:
	return "roamer_down_%s_%d" % [region_id, slot]


## The beast in `slot` leaves for the rest of today.
static func mark_down(flags: Dictionary, region_id: String, slot: int, day: int) -> void:
	flags[flag_key(region_id, slot)] = {"until": day + 1}


## Danger label of a roamer for the player (Weak/Even/Risky/Dangerous/Deadly), as the fight hints show it.
static func threat(c: CharacterData, data: GameData, enemy_id: String) -> String:
	return Combat.danger_label(c, data, data.enemies[enemy_id])


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
		var cnt: Variant = def.get("count")
		if not (cnt is Array and cnt.size() == 2 and _num(cnt[0]) and _num(cnt[1]) \
				and int(cnt[0]) >= 0 and int(cnt[0]) <= int(cnt[1]) and int(cnt[1]) <= MAX_COUNT):
			errors.append("%s count must be [min, max] within 0..%d" % [where, MAX_COUNT])
		var entries: Variant = def.get("enemies")
		if not (entries is Array and not entries.is_empty()):
			errors.append("%s needs a non-empty enemies list" % where)
			continue
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
	return errors
