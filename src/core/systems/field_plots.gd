class_name FieldPlots
extends RefCounted
## A rented field plot in a village (FARM-001): plant a carried herb, wait out the
## seasons (rain days grow it faster, frozen seasons stop it) and harvest it.
## Pure rules over CharacterData.field_plots =
## {"<region_id>:<display_name>": {paid_until: int (day), crops: [{item, days_left}]}}.
## FARM-002: an entry may also hold watered_day (the last day it was watered by hand) and expanded
## (true once the player paid the place's expand_cost: the plots rise to max_plots).
## Tuned by the region's "field_plot" place in data/regions.json.

const TYPE := "field_plot"
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const RENEW_WINDOW := 10
const WOOD_MIN_PURITY := 50


## The region's field_plot place, or {}.
static func place_def(data: GameData, region_id: String) -> Dictionary:
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.get("type", "") == TYPE:
			return place
	return {}


static func key(region_id: String, place: Dictionary) -> String:
	return "%s:%s" % [region_id, place.get("display_name", "")]


static func _entry(c: CharacterData, plot_key: String) -> Dictionary:
	return c.field_plots.get(plot_key, {})


## How many crops the field holds for `c`: the place's plots, or max_plots once expanded.
static func plots_for(c: CharacterData, place: Dictionary, plot_key: String) -> int:
	if bool(_entry(c, plot_key).get("expanded", false)):
		return maxi(int(place.get("plots", 1)), int(place.get("max_plots", 0)))
	return int(place.get("plots", 1))


static func rented(c: CharacterData, plot_key: String, today: int) -> bool:
	return int(_entry(c, plot_key).get("paid_until", 0)) > today


## Why `c` cannot rent now, or "".
static func check_rent(c: CharacterData, place: Dictionary, plot_key: String, today: int) -> String:
	if rented(c, plot_key, today):
		var left := int(_entry(c, plot_key)["paid_until"]) - today
		if left > RENEW_WINDOW:
			return "The field is rented for another %s." % Calendar.format_duration(left)
	if c.item_count("spirit_stone") < int(place.get("rent", 0)):
		return "You cannot afford the rent (%d spirit stones)." % int(place.get("rent", 0))
	return ""


## Pays the rent. A running rent extends from its end (only within RENEW_WINDOW days of it). Returns {ok, reason}.
static func rent(c: CharacterData, region_id: String, place: Dictionary, today: int) -> Dictionary:
	var plot_key := key(region_id, place)
	var reason := check_rent(c, place, plot_key, today)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item("spirit_stone", -int(place.get("rent", 0)))
	var entry := _entry(c, plot_key)
	var start := maxi(today, int(entry.get("paid_until", 0)))
	entry["paid_until"] = start + int(place.get("rent_days", 1))
	if not entry.has("crops"):
		entry["crops"] = []
	c.field_plots[plot_key] = entry
	return {"ok": true, "reason": ""}


## The plants the field grows; with `today` >= 0 only those that may be planted in its season (FARM-003).
static func plantable(place: Dictionary, today: int = -1) -> Array[String]:
	var out: Array[String] = []
	for item_id in place.get("plants", {}):
		if today < 0 or in_season(place, String(item_id), today):
			out.append(String(item_id))
	return out


## The seasons (lower-case) `item_id` may be planted in; empty = any.
static func plant_seasons(place: Dictionary, item_id: String) -> Array:
	return place.get("plants", {}).get(item_id, {}).get("seasons", [])


static func in_season(place: Dictionary, item_id: String, today: int) -> bool:
	var seasons := plant_seasons(place, item_id)
	return seasons.is_empty() or seasons.has(Calendar.season_of(today).to_lower())


## "spring only" / "spring and summer" / "spring, summer and autumn"; "" for any season.
static func season_note(place: Dictionary, item_id: String) -> String:
	var seasons := plant_seasons(place, item_id)
	if seasons.is_empty():
		return ""
	var names: Array[String] = []
	for s in seasons:
		names.append(String(s))
	if names.size() == 1:
		return "%s only" % names[0]
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


static func check_plant(c: CharacterData, data: GameData, place: Dictionary, plot_key: String, item_id: String, today: int) -> String:
	if not rented(c, plot_key, today):
		return "Rent the field first."
	if not place.get("plants", {}).has(item_id):
		return "That will not grow in the field."
	var name := String(data.items.get(item_id, {}).get("name", item_id))
	if not in_season(place, item_id, today):
		return "%s is only planted in %s." % [name, season_note(place, item_id).trim_suffix(" only")]
	if c.item_count(item_id) < 1:
		return "You have no %s to plant." % name
	if (_entry(c, plot_key).get("crops", []) as Array).size() >= plots_for(c, place, plot_key):
		return "Every plot is planted (%d)." % plots_for(c, place, plot_key)
	return ""


## Why `c` cannot water the field today, or "". Needs a growing crop, a clear or cloudy day, and no earlier watering today.
static func check_water(c: CharacterData, place: Dictionary, plot_key: String, today: int, weather: String) -> String:
	if not rented(c, plot_key, today):
		return "Rent the field first."
	var growing := false
	for crop: Dictionary in _entry(c, plot_key).get("crops", []):
		growing = growing or int(crop["days_left"]) > 0
	if not growing:
		return "Nothing in the field is growing."
	if int(_entry(c, plot_key).get("watered_day", -1)) == today:
		return "You already watered the field today."
	if weather != "clear" and weather != "cloudy":
		return "The weather will do the watering." if weather == "rain" else "Watering would do no good today."
	if (place.get("frozen_seasons", []) as Array).has(Calendar.season_of(today).to_lower()):
		return "The ground is frozen."
	return ""


## Waters the field: tomorrow's growth counts as a rain day (see advance). Returns {ok, reason}.
static func water(c: CharacterData, place: Dictionary, plot_key: String, today: int, weather: String) -> Dictionary:
	var reason := check_water(c, place, plot_key, today, weather)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.field_plots[plot_key]["watered_day"] = today
	return {"ok": true, "reason": ""}


## Why `c` cannot expand the field, or "".
static func check_expand(c: CharacterData, place: Dictionary, plot_key: String, today: int) -> String:
	if int(place.get("expand_cost", 0)) <= 0:
		return "This field cannot be enlarged."
	if bool(_entry(c, plot_key).get("expanded", false)):
		return "The field is already enlarged."
	if not rented(c, plot_key, today):
		return "Rent the field first."
	if c.item_count("spirit_stone") < int(place["expand_cost"]):
		return "You cannot afford it (%d spirit stones)." % int(place["expand_cost"])
	return ""


## Pays expand_cost once to raise the plots to max_plots. Returns {ok, reason}.
static func expand(c: CharacterData, place: Dictionary, plot_key: String, today: int) -> Dictionary:
	var reason := check_expand(c, place, plot_key, today)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item("spirit_stone", -int(place["expand_cost"]))
	c.field_plots[plot_key]["expanded"] = true
	return {"ok": true, "reason": ""}


## Plants one `item_id` from the inventory. Returns {ok, reason}.
static func plant(c: CharacterData, data: GameData, place: Dictionary, plot_key: String, item_id: String, today: int) -> Dictionary:
	var reason := check_plant(c, data, place, plot_key, item_id, today)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item(item_id, -1)
	(c.field_plots[plot_key]["crops"] as Array).append({"item": item_id, "days_left": int(place["plants"][item_id].get("days", 1))})
	return {"ok": true, "reason": ""}


## Lets the `world_days` days ending at `today` pass: a crop grows 1 day on a day the rent covers,
## plus `rain_bonus_days` when it rains, and nothing in a frozen season. `weather_of` is
## Callable(region_id, day) -> weather kind. Returns "<region>:<item>" for crops that just became ready.
static func advance(c: CharacterData, data: GameData, world_days: int, today: int, weather_of: Callable) -> Array[String]:
	var ready: Array[String] = []
	for plot_key: String in c.field_plots:
		var region_id := plot_key.get_slice(":", 0)
		var place := place_def(data, region_id)
		if place.is_empty():
			continue
		var entry: Dictionary = c.field_plots[plot_key]
		for crop: Dictionary in entry.get("crops", []):
			if int(crop["days_left"]) <= 0:
				continue
			var left := int(crop["days_left"])
			for day in range(today - world_days + 1, today + 1):
				if day >= int(entry.get("paid_until", 0)):
					continue
				if (place.get("frozen_seasons", []) as Array).has(Calendar.season_of(day).to_lower()):
					continue
				left -= 1
				if weather_of.call(region_id, day) == "rain" or int(entry.get("watered_day", -1)) == day - 1:
					left -= int(place.get("rain_bonus_days", 0))
				if left <= 0:
					break
			crop["days_left"] = maxi(0, left)
			if left <= 0:
				ready.append("%s:%s" % [region_id, crop["item"]])
	return ready


## Harvests every ready crop. Returns {ok, items: {item_id: count}}.
static func harvest(c: CharacterData, place: Dictionary, plot_key: String, rng: RandomNumberGenerator) -> Dictionary:
	var items := {}
	var orphaned: Array[String] = []
	var entry := _entry(c, plot_key)
	var keep: Array = []
	var bonus := int(place.get("wood_bonus", 1)) if int(c.spiritual_roots.get("wood", 0)) >= WOOD_MIN_PURITY else 0
	for crop: Dictionary in entry.get("crops", []):
		if int(crop["days_left"]) > 0:
			keep.append(crop)
			continue
		var item_id := String(crop["item"])
		var plant: Dictionary = place["plants"].get(item_id, {})
		# A data edit after a save can drop the plant: still pay out a single herb.
		var amount := 1
		if not plant.has("yield"):
			orphaned.append(item_id)
		else:
			var span: Array = plant["yield"]
			amount = rng.randi_range(int(span[0]), int(span[1])) + bonus
		c.add_item(item_id, amount)
		items[item_id] = int(items.get(item_id, 0)) + amount
	if not items.is_empty():
		entry["crops"] = keep
	return {"ok": not items.is_empty(), "items": items, "orphaned": orphaned}


## How far a crop has grown, 0.0 (just planted) .. 1.0 (ripe).
static func growth_fraction(days_left: int, total_days: int) -> float:
	if days_left <= 0 or total_days <= 0:
		return 1.0
	return clampf(1.0 - float(days_left) / float(total_days), 0.0, 1.0)


## Drawn growth stage: 0 sprout (< 0.33), 1 young (< 0.66), 2 leafy (< 1.0), 3 ripe.
static func growth_stage(days_left: int, total_days: int) -> int:
	var f := growth_fraction(days_left, total_days)
	if f >= 1.0:
		return 3
	if f >= 0.66:
		return 2
	if f >= 0.33:
		return 1
	return 0


## Days a crop of `item_id` takes to ripen in `place` (1 when unknown).
static func crop_total_days(place: Dictionary, item_id: String) -> int:
	return maxi(1, int(place.get("plants", {}).get(item_id, {}).get("days", 1)))


## True when `today` falls in one of the place's frozen seasons.
static func is_frozen(place: Dictionary, today: int) -> bool:
	return (place.get("frozen_seasons", []) as Array).has(Calendar.season_of(today).to_lower())


## Status lines for the interact menu.
static func describe(c: CharacterData, data: GameData, place: Dictionary, plot_key: String, today: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var entry := _entry(c, plot_key)
	for crop: Dictionary in entry.get("crops", []):
		var name := String(data.items.get(String(crop["item"]), {}).get("name", crop["item"]))
		if int(crop["days_left"]) <= 0:
			lines.append("%s: ready" % name)
		else:
			var frozen := " (frozen in %s)" % ", ".join(place.get("frozen_seasons", [])) if not (place.get("frozen_seasons", []) as Array).is_empty() else ""
			lines.append("%s: ready in %s%s" % [name, Calendar.format_duration(int(crop["days_left"])), frozen])
	if rented(c, plot_key, today):
		lines.append("Rent paid until %s" % Calendar.format_date(int(entry["paid_until"])))
	else:
		lines.append("Rent: %d spirit stones for %s" % [int(place.get("rent", 0)), Calendar.format_duration(int(place.get("rent_days", 1)))])
	return lines


## Problems with a region's field_plot places, for GameData._validate().
static func validate(data: GameData, region_id: String, region: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var count := 0
	for place: Dictionary in region.get("places", []):
		if place.get("type", "") != TYPE:
			continue
		count += 1
		var who := "Region '%s' field_plot '%s'" % [region_id, place.get("display_name", "")]
		if not (place.get("plots", 0) is int or place.get("plots", 0) is float) or int(place.get("plots", 0)) < 1 or int(place.get("plots", 0)) > 4:
			errors.append("%s: plots must be 1..4" % who)
		if int(place.get("rent", -1)) < 0:
			errors.append("%s: rent must be >= 0" % who)
		if place.has("expand_cost") or place.has("max_plots"):
			if int(place.get("expand_cost", 0)) <= 0:
				errors.append("%s: expand_cost must be > 0" % who)
			if int(place.get("max_plots", 0)) < int(place.get("plots", 0)) or int(place.get("max_plots", 0)) > 8:
				errors.append("%s: max_plots must be plots..8" % who)
		if int(place.get("rent_days", 0)) < 1:
			errors.append("%s: rent_days must be >= 1" % who)
		var rain := int(place.get("rain_bonus_days", 0))
		if rain < 0 or rain > 3:
			errors.append("%s: rain_bonus_days must be 0..3" % who)
		var wood := int(place.get("wood_bonus", 1))
		if wood < 0 or wood > 2:
			errors.append("%s: wood_bonus must be 0..2" % who)
		for season in place.get("frozen_seasons", []):
			if not SEASONS.has(String(season)):
				errors.append("%s: unknown frozen season '%s'" % [who, season])
		var plants: Variant = place.get("plants", {})
		if not (plants is Dictionary and not (plants as Dictionary).is_empty()):
			errors.append("%s: plants must be a non-empty object" % who)
			continue
		for item_id: String in plants:
			if not data.items.has(item_id):
				errors.append("%s: plants unknown item '%s'" % [who, item_id])
			var def: Variant = plants[item_id]
			if not def is Dictionary or int(def.get("days", 0)) < 1:
				errors.append("%s: %s needs days >= 1" % [who, item_id])
				continue
			if def.has("seasons"):
				var seasons: Variant = def["seasons"]
				if not (seasons is Array and not (seasons as Array).is_empty()):
					errors.append("%s: %s seasons must be a non-empty list" % [who, item_id])
				else:
					for season in seasons:
						if not SEASONS.has(String(season)):
							errors.append("%s: %s has unknown season '%s'" % [who, item_id, season])
			var span: Variant = def.get("yield", [])
			if not (span is Array and (span as Array).size() == 2 and int(span[0]) >= 1 and int(span[0]) <= int(span[1])):
				errors.append("%s: %s yield must be [min, max] with 1 <= min <= max" % [who, item_id])
	if count > 1:
		errors.append("Region '%s' has more than one field_plot" % region_id)
	return errors
