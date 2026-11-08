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


## Fish (tag "fish") some catch_table entry only rolls in `kind` weather (e.g. "rain").
static func weather_fish(data: GameData, kind: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			for entry: Dictionary in place.get("catch_table", []):
				var id := String(entry.get("item", ""))
				if id != "" and (entry.get("weather", []) as Array).has(kind) and not out.has(id):
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
## MARKET-005: a fish whose entry lists `weather` reads "... bites here in summer when it rains." (no "in <season>" when
## the entry has no `seasons`), and with a `weather` given (today's kind) a fish catchable today beats one that is not.
static func missing_hint(c: CharacterData, data: GameData, region_id: String, season: String, weather: String = "") -> String:
	var fallback := ""
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("type", "")) != "fishing":
			continue
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("catch_table", []), season):
			var id := String(entry.get("item", ""))
			if id == "" or not data.items.get(id, {}).get("tags", []).has("fish") or c.catch_log.has(id):
				continue
			var line := "%s bites here%s." % [data.items[id].get("name", id), _when_clause(entry, season)]
			var kinds: Array = entry.get("weather", [])
			if weather == "" or kinds.is_empty() or kinds.has(weather):
				return line
			if fallback == "":
				fallback = line
	return fallback


static func _when_clause(entry: Dictionary, season: String) -> String:
	var kinds: Array = entry.get("weather", [])
	var text := ""
	if kinds.is_empty() or entry.has("seasons"):
		text = " in " + season.to_lower()
	if not kinds.is_empty():
		var words: PackedStringArray = []
		for k: Variant in kinds:
			words.append("it " + ("rains" if String(k) == "rain" else "snows" if String(k) == "snow" else "is %s" % String(k)))
		text += " when " + " or ".join(words)
	return text


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


## Item ids of every trophy entry in any fishing place's catch_table (GOAL-005).
static func trophy_items(data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			for entry: Dictionary in place.get("catch_table", []):
				if is_trophy(entry) and not out.has(String(entry.get("item", ""))):
					out.append(String(entry["item"]))
	return out


## Errors for the trophy entries of one catch_table (`who` names the place).
static func validate_table(data: GameData, table: Array, who: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var count := 0
	for entry: Dictionary in table:
		if entry.has("requires_flag") and String(entry["requires_flag"]) == "":
			errors.append("%s: requires_flag must be a non-empty world flag" % who)
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


## FISH-006: rain on the water. A catch_table entry may carry `weather` (list of weather kinds): it only rolls on those days.
const STORM_REFUSAL := "The pond is too wild to fish in a storm."
const DEFAULT_RAIN_EXTRA_DRAWS := 1


## `table` without entries whose `weather` list excludes `kind`; entries without `weather` always stay.
static func filter_weather(table: Array, kind: String) -> Array:
	var out: Array = []
	for entry: Dictionary in table:
		if entry.has("weather") and not (entry["weather"] as Array).has(kind):
			continue
		out.append(entry)
	return out


## SEASON-011: `table` without entries whose `requires_flag` world flag is not set.
static func filter_flags(table: Array, flags: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in table:
		if entry.has("requires_flag") and not bool(flags.get(String(entry["requires_flag"]), false)):
			continue
		out.append(entry)
	return out


## Extra draws a trip makes on a `kind` day (regions.json `fishing.rain_extra_draws`, default 1; rain only).
static func extra_draws(data: GameData, kind: String) -> int:
	if kind != "rain":
		return 0
	return int(data.fishing_rules.get("rain_extra_draws", DEFAULT_RAIN_EXTRA_DRAWS))


## True when casting is refused (a storm day).
static func too_wild(kind: String) -> bool:
	return kind == "storm"


## One hint line for the pond on a `kind` day ("" on other days).
static func weather_line(data: GameData, kind: String) -> String:
	if too_wild(kind):
		return STORM_REFUSAL
	if extra_draws(data, kind) > 0:
		return "Fish bite in the rain."
	return ""


## Errors for regions.json `fishing` (rain_extra_draws int 0..3).
static func validate_rules(rules: Dictionary, errors: Array[String]) -> void:
	for key: String in rules:
		if key != "rain_extra_draws":
			errors.append("fishing has unknown key '%s'" % key)
		elif not (rules[key] is int or rules[key] is float) or int(rules[key]) < 0 or int(rules[key]) > 3 or float(rules[key]) != int(rules[key]):
			errors.append("fishing.rain_extra_draws must be an int 0..3")


## Errors for `weather` lists on catch_table entries.
static func validate_weather(table: Array, who: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	for entry: Dictionary in table:
		if not entry.has("weather"):
			continue
		var kinds: Variant = entry["weather"]
		if not (kinds is Array) or (kinds as Array).is_empty():
			errors.append("%s: weather must be a non-empty list" % who)
			continue
		for k in kinds:
			if not (k is String) or not Weather.KINDS.has(k):
				errors.append("%s: unknown weather '%s'" % [who, k])
	return errors
