class_name Weather
extends RefCounted
## Daily weather (WEATHER-001): a pure function of region and date, so every view of a day agrees and nothing is saved.
## Weights come from data/regions.json "weather"; spells persist with regions.json "weather_persist".

const KINDS: Array[String] = ["clear", "cloudy", "rain", "snow", "fog"]
const DEFAULT_PERSIST := 0.6
const MAX_SPELL_DAYS := 30


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
