class_name Places
extends RefCounted
## MARKET-002: places that are only there on some days. A place may carry `open_days` (day-of-month
## ints 1..30, regions.json `_doc`); without it a place is always open. Pure functions, no state.


## True when `place` is present on the in-game day `today` (total days).
static func is_open(place: Dictionary, today: int) -> bool:
	var days: Array = place.get("open_days", [])
	return days.is_empty() or _has_day(days, Calendar.day_of(today))


## Days from `today` until the place is next open (0 = today); -1 if it never is.
static func days_until_open(place: Dictionary, today: int) -> int:
	var days: Array = place.get("open_days", [])
	if days.is_empty():
		return 0
	for ahead in Calendar.DAYS_PER_MONTH:
		if _has_day(days, Calendar.day_of(today + ahead)):
			return ahead
	return -1


## Journal hint for the region's timed places: "Market day in 3 days: Travelling Market Stall" when 1-5 days
## away, "... today" on the day, "" otherwise. The nearest one wins.
static func hint_line(region: Dictionary, today: int, window: int = 5) -> String:
	var best_name := ""
	var best := window + 1
	for place: Dictionary in region.get("places", []):
		if not place.has("open_days"):
			continue
		var ahead := days_until_open(place, today)
		if ahead >= 0 and ahead < best:
			best = ahead
			best_name = String(place.get("display_name", "Market"))
	if best_name == "":
		return ""
	if best == 0:
		return "Market day today: %s is open" % best_name
	return "Market day in %d day%s: %s" % [best, "" if best == 1 else "s", best_name]


## JSON numbers load as floats, so compare as ints.
static func _has_day(days: Array, day: int) -> bool:
	for d: Variant in days:
		if int(d) == day:
			return true
	return false


## Load-time check of an `open_days` value (empty array = fine).
static func validate(days: Variant, where: String) -> Array[String]:
	var problems: Array[String] = []
	if not days is Array or (days as Array).is_empty():
		problems.append("%s open_days must be a non-empty array of days 1..30" % where)
		return problems
	for d: Variant in days:
		if not (d is int or d is float) or int(d) != float(d) or int(d) < 1 or int(d) > Calendar.DAYS_PER_MONTH:
			problems.append("%s open_days has an invalid day '%s'" % [where, str(d)])
	return problems
