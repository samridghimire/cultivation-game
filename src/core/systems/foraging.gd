class_name Foraging
extends RefCounted
## FORAGE-001: things to pick up on the way. A region may list `forage` in regions.json; every day a
## deterministic few pickups lie on its map. Picking one costs no time; it stays gone until the next day.

const MAX_COUNT := 8
## FORAGE-005: picks needed for each tier of "a forager's eye" (tier 1 = index 0).
const TIER_PICKS: Array[int] = [25, 75, 150]
## Tier 3: chance that a pick holds one extra copy.
const BONUS_COPY_CHANCE := 0.08
const TIER_LINES: Array[String] = [
	"Your eye for the path sharpens: you start to spot what grows where.",
	"Your eye for the path sharpens: there is more to find wherever you walk.",
	"A forager's eye at last: some finds come in pairs.",
]


## The forager's tier (0..3) for a number of picks.
static func tier_for(picks: int) -> int:
	var t := 0
	for need in TIER_PICKS:
		if picks >= need:
			t += 1
	return t


## The message for reaching `tier` (1..3), "" otherwise.
static func tier_line(tier: int) -> String:
	return TIER_LINES[tier - 1] if tier >= 1 and tier <= TIER_LINES.size() else ""


## Today's pickups in a region: [{slot: int, item: String, amount: int}]. Same inputs give the same list.
## The local rng is a pure derivation from (region, day), not game randomness.
static func nodes(data: GameData, region_id: String, day: int, realm_index: int, flags: Dictionary, tier: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var def: Dictionary = data.regions.get(region_id, {}).get("forage", {})
	if def.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("forage:%s:%d" % [region_id, day])
	var season := Calendar.season_of(day)
	var pool: Array[Dictionary] = []
	var total := 0.0
	for entry: Dictionary in def.get("items", []):
		if not Exploration.in_season(entry, season):
			continue
		if entry.has("weather") and not (entry["weather"] as Array).has(Weather.of(data, region_id, day)):
			continue
		if entry.has("min_realm") and realm_index < data.realm_index_of(String(entry["min_realm"])):
			continue
		pool.append(entry)
		total += float(entry["weight"])
	if pool.is_empty():
		return out
	var count_range: Array = def.get("count", [0, 0])
	var count := rng.randi_range(int(count_range[0]), int(count_range[1]))
	if tier >= 2 and count == int(count_range[1]) and rng.randf() < 0.5:
		count += 1  # FORAGE-005: on half of the full days the eye finds one more (about +17% overall)
	for slot in count:
		var roll := rng.randf() * total
		var pick: Dictionary = pool[pool.size() - 1]
		for entry in pool:
			roll -= float(entry["weight"])
			if roll < 0.0:
				pick = entry
				break
		var lo := int(pick.get("min", 1))
		var amount := rng.randi_range(lo, int(pick.get("max", lo)))
		if tier >= 3 and rng.randf() < BONUS_COPY_CHANCE:
			amount += 1
		if not Effects.flag_active(flags, flag_key(region_id, slot), day):
			out.append({"slot": slot, "item": String(pick["item"]), "amount": amount})
	return out


## FORAGE-002: today's pickups still lying in a region (picked slots already excluded by `nodes`).
static func unpicked(data: GameData, region_id: String, day: int, realm_index: int, flags: Dictionary, tier: int = 0) -> Array[Dictionary]:
	return nodes(data, region_id, day, realm_index, flags, tier)


## "Village Mugwort x2, Morning Dew Mushroom": item display names, a count only when above 1.
static func summary(data: GameData, entries: Array) -> String:
	var counts := {}
	var order: Array[String] = []
	for e: Dictionary in entries:
		var id := String(e["item"])
		if not counts.has(id):
			order.append(id)
			counts[id] = 0
		counts[id] = int(counts[id]) + int(e.get("amount", 1))
	var parts: PackedStringArray = []
	for id in order:
		var name := String(data.items.get(id, {}).get("name", id))
		parts.append("%s x%d" % [name, counts[id]] if int(counts[id]) > 1 else name)
	return ", ".join(parts)


static func flag_key(region_id: String, slot: int) -> String:
	return "forage_%s_%d" % [region_id, slot]


## The pickup in `slot` is gone for the rest of today.
static func mark_picked(flags: Dictionary, region_id: String, slot: int, day: int) -> void:
	flags[flag_key(region_id, slot)] = {"until": day + 1}


static func _num(v: Variant) -> bool:
	return v is float or v is int


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		if not region.has("forage"):
			continue
		var where := "Region '%s' forage" % region["id"]
		var def: Variant = region["forage"]
		if not def is Dictionary:
			errors.append("%s must be an object" % where)
			continue
		var cnt: Variant = def.get("count")
		if not (cnt is Array and cnt.size() == 2 and _num(cnt[0]) and _num(cnt[1]) \
				and int(cnt[0]) >= 0 and int(cnt[0]) <= int(cnt[1]) and int(cnt[1]) <= MAX_COUNT):
			errors.append("%s count must be [min, max] within 0..%d" % [where, MAX_COUNT])
		var entries: Variant = def.get("items")
		if not (entries is Array and not entries.is_empty()):
			errors.append("%s needs a non-empty items list" % where)
			continue
		for e: Variant in entries:
			if not e is Dictionary or not data.items.has(String(e.get("item", ""))):
				errors.append("%s has an unknown item" % where)
				continue
			if not (_num(e.get("weight")) and float(e["weight"]) > 0.0):
				errors.append("%s item '%s' needs weight > 0" % [where, e["item"]])
			var lo := int(e.get("min", 1))
			if lo < 1 or int(e.get("max", lo)) < lo:
				errors.append("%s item '%s' needs 1 <= min <= max" % [where, e["item"]])
			for s: Variant in e.get("seasons", []):
				if not Exploration.SEASON_NAMES.has(String(s)):
					errors.append("%s item '%s' has unknown season '%s'" % [where, e["item"], s])
			if e.has("weather"):
				var kinds: Variant = e["weather"]
				if not (kinds is Array and not kinds.is_empty()):
					errors.append("%s item '%s' weather must be a non-empty list" % [where, e["item"]])
				else:
					for k: Variant in kinds:
						if not Weather.KINDS.has(String(k)):
							errors.append("%s item '%s' has unknown weather '%s'" % [where, e["item"], k])
			if e.has("min_realm") and data.realm_index_of(String(e["min_realm"])) < 0:
				errors.append("%s item '%s' has unknown min_realm" % [where, e["item"]])
	return errors
