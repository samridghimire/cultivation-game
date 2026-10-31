class_name ShopDiscounts
extends RefCounted
## WEATHER-006: a merchant place's `discount_flag` {flag, buy_mult 0.5..1, tags}: while the world flag is
## active (plain or timed, see Effects.flag_active) items with one of the tags cost buy_mult as much.


## The place named `merchant_name` in `region_id`'s data, or {}.
static func place_named(data: GameData, region_id: String, merchant_name: String) -> Dictionary:
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("display_name", "")) == merchant_name:
			return place
	return {}


## Buy-price factor for `item_id` at that merchant today (1.0 = none).
static func discount_mult(data: GameData, region_id: String, merchant_name: String, item_id: String, flags: Dictionary, today: int) -> float:
	var rule: Dictionary = place_named(data, region_id, merchant_name).get("discount_flag", {})
	if rule.is_empty() or not Effects.flag_active(flags, String(rule.get("flag", "")), today):
		return 1.0
	if not Items.has_tag(data, item_id, rule.get("tags", [])):
		return 1.0
	return float(rule["buy_mult"])


## Load-time check of a place's discount_flag (empty array = fine).
static func validate(rule: Variant, where: String) -> Array[String]:
	var errors: Array[String] = []
	if not rule is Dictionary:
		errors.append("%s: discount_flag must be an object" % where)
		return errors
	var d: Dictionary = rule
	if String(d.get("flag", "")).strip_edges() == "":
		errors.append("%s: discount_flag needs a flag" % where)
	var mult: Variant = d.get("buy_mult", 0)
	if not (mult is float or mult is int) or float(mult) < 0.5 or float(mult) > 1.0:
		errors.append("%s: discount_flag buy_mult must be 0.5..1" % where)
	var tags: Variant = d.get("tags", [])
	if not (tags is Array and not (tags as Array).is_empty()):
		errors.append("%s: discount_flag needs a non-empty tags array" % where)
	return errors
