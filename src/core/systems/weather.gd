class_name Weather
extends RefCounted
## Daily weather (WEATHER-001): a pure function of region and date, so every view of a day agrees and nothing is saved.
## Weights come from data/regions.json "weather"; spells persist with regions.json "weather_persist".

const KINDS: Array[String] = ["clear", "cloudy", "rain", "snow", "fog"]
const DEFAULT_PERSIST := 0.6
const MAX_SPELL_DAYS := 30
const QI_ELEMENTS: Array[String] = ["metal", "wood", "water", "fire", "earth"]
const QI_ELEMENT_MIN_PURITY := 50


## The weather of `region_id` on `day` (GameClock.total_days): clear, cloudy, rain, snow or fog.
static func of(data: GameData, region_id: String, day: int) -> String:
	var region: Dictionary = data.regions.get(region_id, {})
	if not region.has("weather"):
		return "clear"
	var persist: float = data.weather_persist
	var d := day
	# Walk back to the day a new spell began, then roll that day's weather.
	for _i in MAX_SPELL_DAYS:
		if d <= 0:
			break
		if _rng(region_id, d).randf() >= persist:
			break
		d -= 1
	return _roll(region, region_id, d)


static func label(kind: String) -> String:
	return kind.capitalize()


static func _rng(region_id: String, day: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id) ^ day
	return rng


static func _weights(region: Dictionary, day: int) -> Dictionary:
	var table: Dictionary = region.get("weather", {})
	var season := Calendar.season_of(day).to_lower()
	if table.has(season):
		return table[season]
	return table.get("any", {})


static func _roll(region: Dictionary, region_id: String, day: int) -> String:
	var weights := _weights(region, day)
	var total := 0.0
	for kind: String in weights:
		total += float(weights[kind])
	if total <= 0.0:
		return "clear"
	var rng := _rng(region_id, day)
	rng.randf()  # the persistence draw, so the two never correlate
	var pick := rng.randf() * total
	for kind: String in KINDS:
		if not weights.has(kind):
			continue
		pick -= float(weights[kind])
		if pick < 0.0:
			return kind
	return "clear"


## Checks regions.json `weather_effects` (WEATHER-002), appending problems to `errors`.
static func validate_effects(effects: Dictionary, errors: Array[String]) -> void:
	for kind: String in effects:
		var e: Variant = effects[kind]
		if not KINDS.has(kind) or not e is Dictionary:
			errors.append("weather_effects '%s' must be a weather kind with an object" % kind)
			continue
		for key: String in e:
			var v: Variant = e[key]
			if key == "herb_bonus_chance" and kind == "rain":
				if not (v is float or v is int) or float(v) < 0.0 or float(v) > 1.0:
					errors.append("weather_effects.rain.herb_bonus_chance must be 0..1")
			elif key == "travel_extra_days" and kind == "snow":
				if not (v is float or v is int) or float(v) != floorf(float(v)) or int(v) < 1 or int(v) > 5:
					errors.append("weather_effects.snow.travel_extra_days must be an int 1..5")
			elif key == "qi_element":
				_validate_qi_element(kind, v, errors)
			else:
				errors.append("weather_effects.%s has unknown key '%s'" % [kind, key])


## Checks regions.json `fishing_weather` (FISH-001), appending problems to `errors`.
static func validate_fishing(table: Dictionary, errors: Array[String]) -> void:
	for kind: String in table:
		var v: Variant = table[kind]
		if not KINDS.has(kind) or not (v is float or v is int) or float(v) <= 0.0:
			errors.append("fishing_weather '%s' must be a weather kind with a multiplier > 0" % kind)


## Multiplier on a catch table's non-empty entries on a `kind` day (1.0 when unlisted).
static func fishing_multiplier(data: GameData, kind: String) -> float:
	return float(data.fishing_weather.get(kind, 1.0))


## `table` with every non-empty entry's weight times `mult`, so the chance of a catch moves with the weather.
static func scale_catch(table: Array, mult: float) -> Array:
	var scaled: Array = []
	for entry: Dictionary in table:
		var e := entry.duplicate()
		if String(e.get("item", "")) != "":
			e["weight"] = float(e.get("weight", 1)) * mult
		scaled.append(e)
	return scaled


## Extra days a journey starting from `region_id` on `day` takes (snow).
static func travel_extra_days(data: GameData, region_id: String, day: int) -> int:
	var e: Dictionary = data.weather_effects.get(of(data, region_id, day), {})
	return int(e.get("travel_extra_days", 0))


## One extra unit of each herb in `found` (item id -> count) that the weather grants:
## a chance per herb stack on a rain day. Draws from `rng` only when it rains with herbs found.
static func herb_bonus(data: GameData, kind: String, found: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var chance := float(data.weather_effects.get(kind, {}).get("herb_bonus_chance", 0.0))
	var extra: Array[String] = []
	if chance <= 0.0:
		return extra
	for item_id: String in found:
		if (data.items.get(item_id, {}).get("tags", []) as Array).has("herb") and rng.randf() < chance:
			extra.append(item_id)
	return extra


## The parenthesis the UI adds to a gather ("gather") or journey ("travel") entry on a `kind` day, "" if none.
static func effect_note(data: GameData, kind: String, context: String) -> String:
	var e: Dictionary = data.weather_effects.get(kind, {})
	if context == "gather" and float(e.get("herb_bonus_chance", 0.0)) > 0.0:
		return "(%s: herbs thrive)" % kind
	if context == "meditate" and e.has("qi_element"):
		return "(%s: %s qi stirs)" % [kind, e["qi_element"]["element"]]
	if context == "travel" and int(e.get("travel_extra_days", 0)) > 0:
		return "(%s: +%d %s)" % [kind, int(e["travel_extra_days"]), "day" if int(e["travel_extra_days"]) == 1 else "days"]
	return ""


static func _validate_qi_element(kind: String, v: Variant, errors: Array[String]) -> void:
	if not v is Dictionary or not QI_ELEMENTS.has(String((v as Dictionary).get("element", ""))):
		errors.append("weather_effects.%s.qi_element needs an element of %s" % [kind, ", ".join(QI_ELEMENTS)])
		return
	var mult: Variant = (v as Dictionary).get("mult")
	if not (mult is float or mult is int) or float(mult) < 1.0 or float(mult) > 1.25:
		errors.append("weather_effects.%s.qi_element.mult must be 1.0..1.25" % kind)


## Cultivation multiplier of a `kind` day for `c` (WEATHER-003): the weather's qi_element mult when the
## character's root has that element at 50+ purity, else 1.0.
static func qi_mult(data: GameData, kind: String, c: CharacterData) -> float:
	var q: Dictionary = data.weather_effects.get(kind, {}).get("qi_element", {})
	if q.is_empty() or int(c.spiritual_roots.get(String(q.get("element", "")), 0)) < QI_ELEMENT_MIN_PURITY:
		return 1.0
	return float(q.get("mult", 1.0))
