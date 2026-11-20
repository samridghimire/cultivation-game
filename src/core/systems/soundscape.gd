class_name Soundscape
extends RefCounted
## WU-573: which ambience loops and one-shot accents belong to a region on a given weather and
## season. Pure selection (no audio, no Nodes); Audio synthesizes the named sounds.

const BEDS: Array[String] = ["village", "forest", "marsh", "mountain", "city"]
const KEYS: Array[String] = ["bed", "water"]
const DEFAULT_BED := "village"
const LOOPS: Array[String] = ["amb_wind_soft", "amb_wind_hard", "amb_village", "amb_crowd", "amb_marsh", "amb_water", "amb_rain", "amb_forge", "amb_falls"]
## WU-577: loops a places.json/map.landmarks `sound` field may name (positional, heard near the place).
const PLACE_SOUNDS: Array[String] = ["amb_water", "amb_crowd", "amb_wind_soft", "amb_forge", "amb_falls"]
const ACCENTS: Array[String] = ["bird", "crow", "frog", "insect", "bell"]


## Errors for a region's `map.ambience` (empty = valid).
static func validate(region: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var amb: Variant = region.get("map", {}).get("ambience", {})
	if not amb is Dictionary:
		errs.append("Region '%s' map.ambience must be an object" % region.get("id", "?"))
		return errs
	for key: String in amb:
		if not KEYS.has(key):
			errs.append("Region '%s' map.ambience has unknown key '%s'" % [region.get("id", "?"), key])
	if amb.has("bed") and not BEDS.has(String(amb["bed"])):
		errs.append("Region '%s' map.ambience.bed must be one of %s" % [region.get("id", "?"), ", ".join(BEDS)])
	if amb.has("water") and not amb["water"] is bool:
		errs.append("Region '%s' map.ambience.water must be true or false" % region.get("id", "?"))
	var entries: Array = []
	entries.append_array(region.get("places", []))
	entries.append_array(region.get("map", {}).get("landmarks", []))
	for e: Dictionary in entries:
		if e.has("sound") and not PLACE_SOUNDS.has(String(e["sound"])):
			errs.append("Region '%s' '%s' sound must be one of %s" % [region.get("id", "?"), e.get("display_name", e.get("kind", "?")), ", ".join(PLACE_SOUNDS)])
	return errs


## WU-577: [{sound, pos: [x, y]}] for every place and landmark of a region that names a `sound`.
static func place_sounds(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entries: Array = []
	entries.append_array(region.get("places", []))
	entries.append_array(region.get("map", {}).get("landmarks", []))
	for e: Dictionary in entries:
		if e.has("sound") and PLACE_SOUNDS.has(String(e["sound"])) and e.has("pos"):
			out.append({"sound": String(e["sound"]), "pos": e["pos"]})
	return out


## {layers: loop names, accents: one-shot names, accent_every: Vector2(min, max) seconds}.
static func ambience_for(region: Dictionary, weather: String, season: String) -> Dictionary:
	var amb: Dictionary = region.get("map", {}).get("ambience", {})
	var bed: String = String(amb.get("bed", DEFAULT_BED))
	if not BEDS.has(bed):
		bed = DEFAULT_BED
	var s := season.to_lower()
	var layers: Array[String] = []
	var accents: Array[String] = []
	var mountain := bed == "mountain"
	match bed:
		"mountain", "forest":
			layers.append("amb_wind_hard" if mountain and weather == "snow" else "amb_wind_soft")
		"marsh":
			layers.append("amb_marsh")
		"city":
			layers.append("amb_village")
			layers.append("amb_crowd")
		_:
			layers.append("amb_village")
	if bool(amb.get("water", false)):
		layers.append("amb_water")
	if weather == "rain" or weather == "storm":
		layers.append("amb_rain")
	if weather == "storm":
		layers.append("amb_wind_hard")
	var warm := s == "spring" or s == "summer"
	if weather != "storm":
		if warm and (weather == "clear" or weather == "cloudy") and ["village", "forest", "mountain"].has(bed):
			accents.append("bird")
		if not warm:
			accents.append("crow")
		if bed == "marsh" and warm:
			accents.append("frog")
		if s == "summer" and (bed == "forest" or bed == "marsh"):
			accents.append("insect")
		if mountain:
			accents.append("bell")
	return {"layers": layers, "accents": accents, "accent_every": Vector2(30, 60) if accents == ["bell"] else Vector2(5, 14)}
