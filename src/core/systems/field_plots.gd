class_name FieldPlots
extends RefCounted
## A rented field plot in a village (FARM-001): plant a carried herb, wait out the
## seasons (rain days grow it faster, frozen seasons stop it) and harvest it.
## Pure rules over CharacterData.field_plots =
## {"<region_id>:<display_name>": {paid_until: int (day), crops: [{item, days_left}]}}.
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


static func plantable(place: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for item_id in place.get("plants", {}):
		out.append(String(item_id))
	return out


static func check_plant(c: CharacterData, data: GameData, place: Dictionary, plot_key: String, item_id: String, today: int) -> String:
	if not rented(c, plot_key, today):
		return "Rent the field first."
	if not place.get("plants", {}).has(item_id):
		return "That will not grow in the field."
	var name := String(data.items.get(item_id, {}).get("name", item_id))
	if c.item_count(item_id) < 1:
		return "You have no %s to plant." % name
	if (_entry(c, plot_key).get("crops", []) as Array).size() >= int(place.get("plots", 1)):
		return "Every plot is planted (%d)." % int(place.get("plots", 1))
	return ""


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
				if weather_of.call(region_id, day) == "rain":
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
	var entry := _entry(c, plot_key)
	var keep: Array = []
	var bonus := int(place.get("wood_bonus", 1)) if int(c.spiritual_roots.get("wood", 0)) >= WOOD_MIN_PURITY else 0
	for crop: Dictionary in entry.get("crops", []):
		if int(crop["days_left"]) > 0:
			keep.append(crop)
			continue
		var item_id := String(crop["item"])
		var span: Array = place["plants"][item_id]["yield"]
		var amount := rng.randi_range(int(span[0]), int(span[1])) + bonus
		c.add_item(item_id, amount)
		items[item_id] = int(items.get(item_id, 0)) + amount
	if not items.is_empty():
		entry["crops"] = keep
	return {"ok": not items.is_empty(), "items": items}


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
			lines.append("%s: %s%s" % [name, Calendar.format_duration(int(crop["days_left"])), frozen])
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
			var span: Variant = def.get("yield", [])
			if not (span is Array and (span as Array).size() == 2 and int(span[0]) >= 1 and int(span[0]) <= int(span[1])):
				errors.append("%s: %s yield must be [min, max] with 1 <= min <= max" % [who, item_id])
	if count > 1:
		errors.append("Region '%s' has more than one field_plot" % region_id)
	return errors
