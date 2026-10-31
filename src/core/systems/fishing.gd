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


## 0..1 progress from the current rank's threshold to the next; 1.0 at the top rank.
static func progress(xp: int) -> float:
	for i in range(RANKS.size() - 1, -1, -1):
		var lo := int(RANKS[i]["min"])
		if xp >= lo:
			if i == RANKS.size() - 1:
				return 1.0
			var hi := int(RANKS[i + 1]["min"])
			return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)
	return 0.0


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


## FISH-004: first-catch xp bonus.
const FIRST_CATCH_XP := 2


## Fish (items tagged `fish`) that any fishing place's catch_table can yield, in data order.
static func catchable(data: GameData) -> PackedStringArray:
	var seen := {}
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			for entry: Dictionary in place.get("catch_table", []):
				var id := String(entry.get("item", ""))
				if id != "" and data.items.get(id, {}).get("tags", []).has("fish"):
					seen[id] = true
	var out: PackedStringArray = []
	for id: String in data.items:
		if seen.has(id):
			out.append(id)
	return out


## Records a catch; returns true when it is the first of its kind.
static func record_catch(c: CharacterData, item_id: String, count: int) -> bool:
	var first := not c.catch_log.has(item_id)
	c.catch_log[item_id] = int(c.catch_log.get(item_id, 0)) + count
	return first


## "Fish caught: 4 of 9 kinds", "" while the log is empty.
static func log_summary(c: CharacterData, data: GameData) -> String:
	if c.catch_log.is_empty():
		return ""
	var all := catchable(data)
	var known := 0
	for id in all:
		if c.catch_log.has(id):
			known += 1
	return "Fish caught: %d of %d kinds" % [known, all.size()]


## "Golden Eel bites here in summer." for the first uncaught fish a fishing place in `region_id` yields in `season`; "" if none.
static func missing_hint(c: CharacterData, data: GameData, region_id: String, season: String) -> String:
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("type", "")) != "fishing":
			continue
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("catch_table", []), season):
			var id := String(entry.get("item", ""))
			if id != "" and data.items.get(id, {}).get("tags", []).has("fish") and not c.catch_log.has(id):
				return "%s bites here in %s." % [data.items[id].get("name", id), season.to_lower()]
	return ""


## FISH-005: a catch_table entry with `trophy: true` needs a clean strike and an Angler's skill.
const TROPHY_QUALITY := 1.0
const TROPHY_XP := 10


static func is_trophy(entry: Dictionary) -> bool:
	return bool(entry.get("trophy", false))


static func trophy_allowed(quality: float, xp: int) -> bool:
	return quality >= TROPHY_QUALITY and xp >= TROPHY_XP


## `table` without its trophy entries unless `trophy_allowed`; a table with none is returned unchanged.
static func filter_trophy(table: Array, quality: float, xp: int) -> Array:
	if trophy_allowed(quality, xp):
		return table
	var out: Array = []
	for entry: Dictionary in table:
		if not is_trophy(entry):
			out.append(entry)
	return out


## The item id of the table's trophy entry that is in `found`, or "".
static func trophy_in(table: Array, found: Dictionary) -> String:
	for entry: Dictionary in table:
		if is_trophy(entry) and found.has(String(entry.get("item", ""))):
			return String(entry["item"])
	return ""


## Errors for the trophy entries of one catch_table (`who` names the place).
static func validate_table(data: GameData, table: Array, who: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var count := 0
	for entry: Dictionary in table:
		if not is_trophy(entry):
			continue
		count += 1
		if float(entry.get("weight", 1)) > 1.0:
			errors.append("%s: trophy entry weight must be <= 1" % who)
		if not data.items.get(String(entry.get("item", "")), {}).get("tags", []).has("fish"):
			errors.append("%s: trophy entry must be an item tagged fish" % who)
	if count > 1:
		errors.append("%s: at most one trophy entry per table" % who)
	return errors
