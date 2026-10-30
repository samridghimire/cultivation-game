class_name Fishing
extends RefCounted
## FISH-003: the fishing skill. Each trip adds xp (CharacterData.fishing_xp); skill and the
## quality of the cast (0..1, 0.5 = an ordinary cast) shift the odds of the pond's rare entries.
## Pure and deterministic: randomness comes from the rng passed in.

const RARE_WEIGHT := 2.0  # a non-empty catch_table entry at or below this weight is "rare"
const XP_CAP := 100
const GOT_AWAY_CHANCE := 0.3
const RANKS: Array[Dictionary] = [
	{"min": 0, "name": "Novice"},
	{"min": 10, "name": "Angler"},
	{"min": 40, "name": "Old Hand"},
	{"min": 100, "name": "Master"},
]


static func is_rare(entry: Dictionary) -> bool:
	return String(entry.get("item", "")) != "" and float(entry.get("weight", 1)) <= RARE_WEIGHT


## Rank title for `xp`.
static func rank_name(xp: int) -> String:
	var name := ""
	for r in RANKS:
		if xp >= int(r["min"]):
			name = String(r["name"])
	return name


## Multiplier on rare entries' weight: 1.0 at quality 0.5 and no xp.
static func rare_mult(quality: float, xp: int) -> float:
	return 1.0 + 0.5 * (clampf(quality, 0.0, 1.0) - 0.5) + float(mini(maxi(xp, 0), XP_CAP)) / 200.0


## `table` with every rare entry's weight scaled by `rare_mult`.
static func skill_table(table: Array, quality: float, xp: int) -> Array:
	var mult := rare_mult(quality, xp)
	var scaled: Array = []
	for entry: Dictionary in table:
		var e := entry.duplicate()
		if is_rare(e):
			e["weight"] = float(e.get("weight", 1)) * mult
		scaled.append(e)
	return scaled


## True when a quality-0 cast loses the fish (30%); draws from `rng` only then.
static func got_away(quality: float, rng: RandomNumberGenerator) -> bool:
	return quality <= 0.0 and rng.randf() < GOT_AWAY_CHANCE


## Width of the sweet zone of the cast bar for WU-412: 0.18 at 0 xp to 0.35 at 100.
static func zone_width(xp: int) -> float:
	return lerpf(0.18, 0.35, float(mini(maxi(xp, 0), XP_CAP)) / XP_CAP)


## Xp for a trip that found `found` (item -> count) from `table`: 1, or 2 with a rare catch.
static func xp_gain(table: Array, found: Dictionary) -> int:
	for entry: Dictionary in table:
		if is_rare(entry) and found.has(String(entry["item"])):
			return 2
	return 1
