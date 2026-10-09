class_name Renown
extends RefCounted
## Local renown (RENOWN-001): fame earned per region from bounties, discoveries,
## deeper paths and righteous deeds (data/regions.json "renown"). Higher tiers
## give a title and a small buy discount in that region. Renown only rises.


## Renown of `region_id`.
static func value(c: CharacterData, region_id: String) -> int:
	return int(c.renown.get(region_id, 0))


## Adds the renown for `source` in `region_id`, capped at the config `max`.
## Returns {"gained": int, "new_tier": String}; new_tier is the title of the
## tier this gain crossed into ("" if none or untitled).
static func gain(c: CharacterData, data: GameData, region_id: String, source: String) -> Dictionary:
	var result := {"gained": 0, "new_tier": ""}
	var config: Dictionary = data.renown
	if config.is_empty() or region_id == "":
		return result
	var amount := int((config.get("sources", {}) as Dictionary).get(source, 0))
	if amount <= 0:
		return result
	var before := value(c, region_id)
	var after := mini(before + amount, int(config.get("max", before + amount)))
	if after <= before:
		return result
	c.renown[region_id] = after
	result["gained"] = after - before
	var old_tier := tier(data, before)
	var new_tier := tier(data, after)
	if int(new_tier.get("min", 0)) > int(old_tier.get("min", 0)):
		result["new_tier"] = String(new_tier.get("title", ""))
	return result


## The highest tier whose `min` is <= value ({} without config).
static func tier(data: GameData, amount: int) -> Dictionary:
	var best := {}
	for t: Dictionary in data.renown.get("tiers", []):
		if int(t["min"]) <= amount:
			best = t
	return best


## Index of the tier for `amount` in the regions.json tier order (0 = the untitled lowest tier, also without config).
static func tier_index(data: GameData, amount: int) -> int:
	var best := 0
	var tiers: Array = data.renown.get("tiers", [])
	for i in tiers.size():
		if int((tiers[i] as Dictionary)["min"]) <= amount:
			best = i
	return best


## Tier title in a region ("" at the lowest tier).
static func title(c: CharacterData, data: GameData, region_id: String) -> String:
	return String(tier(data, value(c, region_id)).get("title", ""))


## Share of the buy price paid in the region (1.0 without config).
static func buy_multiplier(c: CharacterData, data: GameData, region_id: String) -> float:
	return float(tier(data, value(c, region_id)).get("buy_mult", 1.0))


## Multiplier on a bounty's pay in the region (1.0 without config or a `bounty_mult`).
static func bounty_multiplier(c: CharacterData, data: GameData, region_id: String) -> float:
	return float(tier(data, value(c, region_id)).get("bounty_mult", 1.0))


## "Misty Forest: Respected (54)" for every region with a title, in data order.
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines := PackedStringArray()
	for region_id: String in data.regions:
		var t := title(c, data, region_id)
		if t != "":
			lines.append("%s: %s (%d)" % [data.regions[region_id].get("name", region_id), t, value(c, region_id)])
	return lines


## Highest renown over all regions.
static func best(c: CharacterData) -> int:
	var top := 0
	for v: Variant in c.renown.values():
		top = maxi(top, int(v))
	return top


## Appends config problems to `errors` (an empty config is valid).
static func validate(config: Dictionary, errors: PackedStringArray) -> void:
	if config.is_empty():
		return
	for source: String in config.get("sources", {}):
		var v: Variant = config["sources"][source]
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT or int(v) < 0 or float(v) != int(v):
			errors.append("renown source '%s' must be an int >= 0" % source)
	var max_v: Variant = config.get("max", 0)
	if typeof(max_v) != TYPE_INT and typeof(max_v) != TYPE_FLOAT or int(max_v) <= 0 or float(max_v) != int(max_v):
		errors.append("renown max must be an int > 0")
	var tiers: Variant = config.get("tiers", [])
	if not (tiers is Array) or (tiers as Array).is_empty():
		errors.append("renown tiers must be a non-empty list")
		return
	var last := -1
	for i in (tiers as Array).size():
		var t: Variant = tiers[i]
		if not (t is Dictionary) or not (t as Dictionary).has("min") or not (t as Dictionary).has("buy_mult") or not (t as Dictionary).has("title"):
			errors.append("renown tier %d needs min, title and buy_mult" % i)
			return
		var m: Variant = t["min"]
		if (typeof(m) != TYPE_INT and typeof(m) != TYPE_FLOAT) or float(m) != int(m):
			errors.append("renown tier %d min must be an int" % i)
			return
		if i == 0 and int(m) != 0:
			errors.append("renown first tier min must be 0")
		if int(m) <= last:
			errors.append("renown tier mins must be strictly rising (tier %d)" % i)
		last = int(m)
		var bm: Variant = t["buy_mult"]
		if (typeof(bm) != TYPE_INT and typeof(bm) != TYPE_FLOAT) or float(bm) <= 0.0 or float(bm) > 1.0:
			errors.append("renown tier %d buy_mult must be in (0, 1]" % i)
		if t.has("bounty_mult") and ((typeof(t["bounty_mult"]) != TYPE_INT and typeof(t["bounty_mult"]) != TYPE_FLOAT) or float(t["bounty_mult"]) < 1.0):
			errors.append("renown tier %d bounty_mult must be a number >= 1.0" % i)
		if typeof(t["title"]) != TYPE_STRING:
			errors.append("renown tier %d title must be a String" % i)
