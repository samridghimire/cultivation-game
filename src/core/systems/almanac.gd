class_name Almanac
extends RefCounted
## CAL-010: the village almanac. One small omen per day, a pure function of (salt, day), so every view of a day agrees
## and nothing is saved. Data in data/almanac.json. Never touches qi, breakthroughs or combat.

const EFFECT_KEYS: Array[String] = ["fishing_mult", "gather_bonus", "gift_favor", "sell_mult", "practice_mult"]
const RANGES: Dictionary = {
	"fishing_mult": [1.0, 1.3], "gather_bonus": [0.0, 0.25], "gift_favor": [0.0, 3.0],
	"sell_mult": [1.0, 1.1], "practice_mult": [1.0, 1.25],
}


## A per-life number so every life gets its own calendar (no save change).
static func salt_of(c: CharacterData) -> int:
	return hash(c.name + ":" + str(c.birthday)) if c != null else 0


## The omen of `day`: {id, name, text, weight, effects}; {} when the data has none.
static func omen_for(data: GameData, day: int, salt: int) -> Dictionary:
	var omens: Array = data.almanac.get("omens", [])
	var total := 0
	for o: Dictionary in omens:
		total += int(o.get("weight", 1))
	if total <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(salt) + ":" + str(day))
	var roll := rng.randi_range(0, total - 1)
	for o: Dictionary in omens:
		roll -= int(o.get("weight", 1))
		if roll < 0:
			return o
	return omens[omens.size() - 1]


static func _eff(omen: Dictionary, key: String, plain: float) -> float:
	return float((omen.get("boost", {}) as Dictionary).get(key, plain))


static func fishing_mult(omen: Dictionary) -> float:
	return _eff(omen, "fishing_mult", 1.0)


static func gather_bonus(omen: Dictionary) -> float:
	return _eff(omen, "gather_bonus", 0.0)


static func gift_favor(omen: Dictionary) -> int:
	return int(_eff(omen, "gift_favor", 0.0))


static func sell_mult(omen: Dictionary) -> float:
	return _eff(omen, "sell_mult", 1.0)


static func practice_mult(omen: Dictionary) -> float:
	return _eff(omen, "practice_mult", 1.0)


## The boost key that names an omen's glyph ("fishing_mult", ...; "" for a plain day or none).
static func boost_key(omen: Dictionary) -> String:
	var boost: Dictionary = omen.get("boost", {})
	for k: String in EFFECT_KEYS:
		if boost.has(k):
			return k
	for k: String in boost:
		return k
	return ""


static func is_plain(omen: Dictionary) -> bool:
	return (omen.get("boost", {}) as Dictionary).is_empty()


## "Almanac: Good for fishing. The water is calm..." ("" only when there is no omen at all).
static func line(omen: Dictionary, salt: int = 0, day: int = 0) -> String:
	if omen.is_empty():
		return ""
	return "Almanac: %s. %s" % [String(omen.get("name", "")), text_of(omen, salt, day)]


## TODAY-004: an omen's `text` is a string or an array of strings; an array is picked by hash(salt:day), so a day
## always shows the same variant.
static func text_of(omen: Dictionary, salt: int = 0, day: int = 0) -> String:
	var t: Variant = omen.get("text", "")
	if t is Array:
		var arr: Array = t
		if arr.is_empty():
			return ""
		return String(arr[absi(hash("%d:%d" % [salt, day])) % arr.size()])
	return String(t)


## "Tomorrow: Good for fishing." for a non-plain omen, else "".
static func tomorrow_line(omen: Dictionary) -> String:
	if omen.is_empty() or is_plain(omen):
		return ""
	return "Tomorrow: %s." % String(omen.get("name", ""))


static func validate(data: GameData) -> Array[String]:
	var errs: Array[String] = []
	var seen := {}
	for o: Dictionary in data.almanac.get("omens", []):
		var id := String(o.get("id", ""))
		if id == "" or seen.has(id):
			errs.append("almanac.json omen id '%s' is missing or duplicated" % id)
		seen[id] = true
		if String(o.get("name", "")).is_empty() or String(o.get("name", "")).length() > 30:
			errs.append("almanac.json omen '%s' needs a name of 1..30 chars" % id)
		var texts: Array = o.get("text", []) if o.get("text", "") is Array else [o.get("text", "")]
		if texts.is_empty():
			errs.append("almanac.json omen '%s' needs text of 1..120 chars" % id)
		for t: Variant in texts:
			if not (t is String) or String(t).is_empty() or String(t).length() > 120:
				errs.append("almanac.json omen '%s' needs text of 1..120 chars" % id)
		if o.has("talk"):
			var talk: Variant = o["talk"]
			if not (talk is Array) or (talk as Array).is_empty() or (talk as Array).size() > 4:
				errs.append("almanac.json omen '%s' talk must be 1..4 strings" % id)
			else:
				for t: Variant in talk:
					if not (t is String) or String(t).is_empty() or String(t).length() > 90:
						errs.append("almanac.json omen '%s' talk lines must be 1..90 chars" % id)
		if int(o.get("weight", 0)) < 1:
			errs.append("almanac.json omen '%s' weight must be >= 1" % id)
		var eff: Dictionary = o.get("boost", {})
		for key: String in eff:
			if not RANGES.has(key):
				errs.append("almanac.json omen '%s' has unknown effect '%s'" % [id, key])
			elif float(eff[key]) < float(RANGES[key][0]) or float(eff[key]) > float(RANGES[key][1]):
				errs.append("almanac.json omen '%s' effect '%s' is out of range" % [id, key])
	return errs
