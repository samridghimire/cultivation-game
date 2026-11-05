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
static func hint_line(region: Dictionary, today: int, window: int = 5, data: GameData = null, regulars: Dictionary = {}) -> String:
	var best_name := ""
	var best_place: Dictionary = {}
	var best := window + 1
	for place: Dictionary in region.get("places", []):
		if not place.has("open_days"):
			continue
		var ahead := days_until_open(place, today)
		if ahead >= 0 and ahead < best:
			best = ahead
			best_name = String(place.get("display_name", "Market"))
			best_place = place
	if best_name == "":
		return ""
	var rotates := best_place.has("rotating_stock")
	if best == 0:
		if rotates and data != null:  # MARKET-007: name today's wares
			var names: Array[String] = []
			var is_reg := is_regular(best_place, int(regulars.get(place_key(best_name), 0)))
			for id: String in rotating_picks(best_place, today, is_reg):
				names.append(String(data.items.get(id, {}).get("name", id)))
			if not names.is_empty():
				var wants := wanted_phrase(best_place, today, data)
				var reg_note := "; %d%% off for you" % roundi(regular_discount(best_place) * 100.0) if is_reg else ""
				return "Market day today: %s%s sells %s%s%s" % [best_name, " (regular)" if is_reg else "", ", ".join(names), "" if wants == "" else "; wants " + wants, reg_note]
		return "Market day today: %s is open" % best_name
	var reg_tag := " (regular)" if rotates and is_regular(best_place, int(regulars.get(place_key(best_name), 0))) else ""
	return "Market day in %d day%s: %s%s%s" % [best, "" if best == 1 else "s", best_name, reg_tag, " (new wares each time)" if rotates else ""]


## "market days 10 and 25" / "market days 5, 15 and 25" for a place with `open_days`; "" without (MARKET-003).
static func days_phrase(place: Dictionary) -> String:
	var days: Array = place.get("open_days", [])
	if days.is_empty():
		return ""
	var parts: Array[String] = []
	for d: Variant in days:
		parts.append(str(int(d)))
	var text := parts[0]
	if parts.size() > 1:
		text = ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
	return "market day%s %s" % ["" if parts.size() == 1 else "s", text]


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


## MARKET-007: the `count` distinct pool items a merchant place sells on `today` ([] without `rotating_stock` or when
## closed). Deterministic per (display_name, day): a weighted pick without replacement from a local seeded rng.
## MARKET-009: a regular gets one extra pick (`count` + 1; the first `count` picks are unchanged).
static func rotating_picks(place: Dictionary, today: int, regular: bool = false) -> Array[String]:
	var picks: Array[String] = []
	var rot: Dictionary = place.get("rotating_stock", {})
	if rot.is_empty() or not is_open(place, today):
		return picks
	var pool: Array = (rot.get("pool", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(place.get("display_name", ""))) ^ today
	for n in mini(int(rot.get("count", 0)) + (1 if regular else 0), pool.size()):
		var total := 0.0
		for e: Dictionary in pool:
			total += float(e.get("weight", 1.0))
		var roll := rng.randf() * total
		var chosen := pool.size() - 1
		for i in pool.size():
			roll -= float((pool[i] as Dictionary).get("weight", 1.0))
			if roll < 0.0:
				chosen = i
				break
		picks.append(String((pool[chosen] as Dictionary)["item"]))
		pool.remove_at(chosen)
	return picks


## WU-445: true while `place` is a rotating-stock stall open on `today` (draws the bunting and sparkle).
static func is_market_day_stall(place: Dictionary, today: int) -> bool:
	return place.has("rotating_stock") and is_open(place, today)


## WU-445: names of the rotating-stock stalls open today in `region`.
static func market_day_stalls(region: Dictionary, today: int) -> Array[String]:
	var out: Array[String] = []
	for place: Dictionary in region.get("places", []):
		if is_market_day_stall(place, today):
			out.append(String(place.get("display_name", "Market")))
	return out


## WU-445: "Market day today: Travelling Market Stall (new wares)" for the world map region detail; "" otherwise.
static func market_day_line(region: Dictionary, today: int) -> String:
	var stalls := market_day_stalls(region, today)
	if stalls.is_empty():
		return ""
	return "Market day today: %s (new wares)" % " and ".join(stalls)


## WU-445: "  New today: A, B, C" for the shop title of the stall called `stall_name` in `region`; "" when it has none.
static func new_today_note(region: Dictionary, stall_name: String, today: int, data: GameData) -> String:
	for place: Dictionary in region.get("places", []):
		if String(place.get("display_name", "")) != stall_name:
			continue
		var names: Array[String] = []
		for id: String in rotating_picks(place, today):
			names.append(String(data.items.get(id, {}).get("name", id)))
		return "" if names.is_empty() else "  New today: " + ", ".join(names)
	return ""


## MARKET-007: `stock_tags` plus today's rotating picks.
static func stock_tags_today(place: Dictionary, today: int, regular: bool = false) -> Array:
	var tags: Array = (place.get("stock_tags", []) as Array).duplicate()
	var picks := rotating_picks(place, today, regular)
	if tags.is_empty() and not picks.is_empty():
		tags.append("untagged")  # MARKET-010: keep the stall's plain wares beside the picks
	tags.append_array(picks)
	return tags


## MARKET-009: key of a stall in CharacterData.market_regular and the per-day wanted tally.
static func place_key(display_name: String) -> String:
	return display_name.to_snake_case()


## MARKET-009: different market days of selling the wanted item that make the player a regular (wanted.regular_after, default 3).
static func regular_after(place: Dictionary) -> int:
	return int((place.get("wanted", {}) as Dictionary).get("regular_after", 3))


## MARKET-009: price cut on a regular's rotating wares (wanted.regular_discount, default 0.1).
static func regular_discount(place: Dictionary) -> float:
	return float((place.get("wanted", {}) as Dictionary).get("regular_discount", 0.1))


## WU-453: shop title note for a stall with a `wanted` block: "  Regular here: 10% off new wares, 4 on the table"
## for a regular, "  Wanted today: Boar Hide (x1.5). Sold on 1 of 3 market days to become a regular." otherwise; "" without `wanted`.
static func regular_note(place: Dictionary, days_sold: int, today: int, data: GameData) -> String:
	if not place.has("wanted"):
		return ""
	if is_regular(place, days_sold):
		return "  Regular here: %d%% off new wares, %d on the table" % [roundi(regular_discount(place) * 100.0), rotating_picks(place, today, true).size()]
	var wants := wanted_phrase(place, today, data)
	return "  %sSold on %d of %d market days to become a regular." % ["" if wants == "" else "Wanted today: %s. " % wants, mini(days_sold, regular_after(place)), regular_after(place)]


## MARKET-009: true when `days_sold` market days of wanted sales earn the stall's regular status.
static func is_regular(place: Dictionary, days_sold: int) -> bool:
	return place.has("wanted") and days_sold >= regular_after(place)


## MARKET-008: most units of the wanted item a stall buys at the bonus price per open day.
const WANTED_CAP := 5


## MARKET-008: {item, mult} the stall wants on `today` ({} without `wanted` or `rotating_stock`, or when closed).
## One uniform pick from `wanted.pool`, deterministic per (display_name, day).
static func wanted_today(place: Dictionary, today: int) -> Dictionary:
	var wanted: Dictionary = place.get("wanted", {})
	var pool: Array = wanted.get("pool", [])
	if wanted.is_empty() or pool.is_empty() or not place.has("rotating_stock") or not is_open(place, today):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(place.get("display_name", "")) + "/wanted") ^ today
	return {"item": String(pool[rng.randi_range(0, pool.size() - 1)]), "mult": float(wanted.get("mult", 1.0))}


## MARKET-008: "Boar Hide (x1.5)" for the journal's market-day line; "" when nothing is wanted today.
static func wanted_phrase(place: Dictionary, today: int, data: GameData) -> String:
	var w := wanted_today(place, today)
	if w.is_empty():
		return ""
	return "%s (x%s)" % [String(data.items.get(w["item"], {}).get("name", w["item"])), String.num(float(w["mult"]), 2).trim_suffix("0")]


## Load-time check of a `wanted` value on a place that has `rotating_stock`.
static func validate_wanted(wanted: Variant, place: Dictionary, items: Dictionary, where: String) -> Array[String]:
	var problems: Array[String] = []
	if not wanted is Dictionary or not (wanted as Dictionary).get("pool") is Array or ((wanted as Dictionary)["pool"] as Array).is_empty():
		problems.append("%s wanted needs a non-empty pool" % where)
		return problems
	if not place.has("rotating_stock"):
		problems.append("%s wanted needs rotating_stock" % where)
	var mult := float((wanted as Dictionary).get("mult", 0.0))
	if mult < 1.2 or mult > 2.0:
		problems.append("%s wanted mult must be 1.2..2.0" % where)
	for id: Variant in (wanted as Dictionary)["pool"]:
		if not items.has(String(id)) or int((items[String(id)] as Dictionary).get("price", 0)) <= 0:
			problems.append("%s wanted item '%s' is unknown or has no price" % [where, id])
	var w := wanted as Dictionary
	if w.has("regular_after") and (not (w["regular_after"] is int or w["regular_after"] is float) or int(w["regular_after"]) < 1):
		problems.append("%s wanted regular_after must be an int >= 1" % where)
	if w.has("regular_discount") and (not (w["regular_discount"] is int or w["regular_discount"] is float) or float(w["regular_discount"]) < 0.0 or float(w["regular_discount"]) > 0.3):
		problems.append("%s wanted regular_discount must be 0..0.3" % where)
	return problems


## Load-time check of a `rotating_stock` value on a merchant place with items `items`.
static func validate_rotating(rot: Variant, place: Dictionary, items: Dictionary, restricted: PackedStringArray, where: String) -> Array[String]:
	var problems: Array[String] = []
	if not rot is Dictionary or not (rot as Dictionary).get("pool") is Array or ((rot as Dictionary)["pool"] as Array).is_empty():
		problems.append("%s rotating_stock needs a non-empty pool" % where)
		return problems
	if String(place.get("type", "")) != "merchant":
		problems.append("%s rotating_stock is only for merchant places" % where)
	var pool: Array = (rot as Dictionary)["pool"]
	var count: Variant = (rot as Dictionary).get("count")
	if not (count is int or count is float) or int(count) != float(count) or int(count) < 1 or int(count) > mini(6, pool.size()):
		problems.append("%s rotating_stock count must be 1..min(6, pool size)" % where)
	for e: Variant in pool:
		if not e is Dictionary or not items.has(String((e as Dictionary).get("item", ""))):
			problems.append("%s rotating_stock has an unknown item" % where)
			continue
		var w: Variant = (e as Dictionary).get("weight")
		if not (w is int or w is float) or float(w) <= 0.0:
			problems.append("%s rotating_stock weight of '%s' must be > 0" % [where, (e as Dictionary)["item"]])
		var item: Dictionary = items[(e as Dictionary)["item"]]
		var price := int(item.get("price", 0))
		var max_price := int(place.get("max_price", 0))
		if price <= 0 or (max_price > 0 and price > max_price):
			problems.append("%s rotating_stock item '%s' has no price or exceeds max_price" % [where, (e as Dictionary)["item"]])
		for tag: Variant in item.get("tags", []):
			if restricted.has(String(tag)):
				problems.append("%s rotating_stock item '%s' carries a restricted tag" % [where, (e as Dictionary)["item"]])
	return problems
