class_name ClanEstate
extends RefCounted
## The clan estate (FAM-006), tuned by data/clan_buildings.json. The clan
## builds or upgrades one building at a time, paid from its treasury; the work
## finishes after build_days of world time. Each built building applies the
## effects of its current level: monthly income and reputation, herbs
## harvested for the clan head, extra seclusion qi density at the clan seat
## abode, faster training for children and a ward that keeps hostile
## encounters and ambushes away from the seat's region (FAM-006c). State lives
## on ClanData.

## Effect keys a building level may have (see the data file's _doc).
const EFFECTS := ["income", "reputation", "qi_density", "training_speed", "herbs", "ward"]
## The ward never removes hostile encounters entirely.
const MAX_WARD := 0.9


## Building ids in data order.
static func building_ids(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for building: Dictionary in data.clan_estate.get("buildings", []):
		out.append(String(building.get("id", "")))
	return out


static func building_name(data: GameData, building_id: String) -> String:
	return String(data.clan_buildings.get(building_id, {}).get("name", building_id))


static func max_level(data: GameData, building_id: String) -> int:
	return (data.clan_buildings.get(building_id, {}).get("levels", []) as Array).size()


## The level def for `level` (1-based), or {}.
static func level_def(data: GameData, building_id: String, level: int) -> Dictionary:
	var levels: Array = data.clan_buildings.get(building_id, {}).get("levels", [])
	if level < 1 or level > levels.size():
		return {}
	return levels[level - 1]


## Built level of `building_id` (0 = not built).
static func level(clan: ClanData, building_id: String) -> int:
	return int(clan.buildings.get(building_id, 0)) if clan != null else 0


## Why the clan headed by `c` cannot start building the next level of
## `building_id`, or "".
static func check_build(c: CharacterData, clan: ClanData, building_id: String, data: GameData) -> String:
	if clan == null:
		return "You have no clan."
	if not data.clan_buildings.has(building_id):
		return "There is no such building."
	var name := building_name(data, building_id)
	if not clan.construction.is_empty():
		return "Builders are still at work on the %s." % building_name(data, String(clan.construction.get("building", "")))
	var next := level(clan, building_id) + 1
	if next > max_level(data, building_id):
		return "The %s cannot be improved further." % name
	var def := level_def(data, building_id, next)
	var min_index := data.realm_index_of(String(def.get("min_realm", "mortal")))
	if c.realm_index < min_index:
		return "Only a clan head of the %s realm can raise such %s." % [data.realms[min_index].name, Text.a(name)]
	var cost := int(def.get("cost", 0))
	if clan.treasury < cost:
		return "The %s costs %d spirit stones from the clan treasury (it holds %d)." % [name, cost, clan.treasury]
	return ""


## Starts the next level of `building_id`, paid from the treasury.
## Returns {ok, reason, level, cost, days}.
static func start_build(c: CharacterData, clan: ClanData, building_id: String, data: GameData) -> Dictionary:
	var reason := check_build(c, clan, building_id, data)
	if reason != "":
		return {"ok": false, "reason": reason, "level": 0, "cost": 0, "days": 0}
	var next := level(clan, building_id) + 1
	var def := level_def(data, building_id, next)
	var cost := int(def.get("cost", 0))
	var days := int(def.get("build_days", 0))
	clan.treasury -= cost
	clan.construction = {"building": building_id, "level": next, "days_left": days}
	return {"ok": true, "reason": "", "level": next, "cost": cost, "days": days}


## Advances construction by `days`. Returns the completed {building, level}, or {}.
static func advance_construction(clan: ClanData, days: int) -> Dictionary:
	if clan == null or clan.construction.is_empty():
		return {}
	clan.construction["days_left"] = int(clan.construction.get("days_left", 0)) - days
	if int(clan.construction["days_left"]) > 0:
		return {}
	var done := {"building": String(clan.construction.get("building", "")), "level": int(clan.construction.get("level", 1))}
	clan.construction = {}
	clan.buildings[done["building"]] = done["level"]
	return done


## Sum of a numeric effect over all built buildings (unknown buildings ignored).
static func total(clan: ClanData, data: GameData, effect: String) -> float:
	var sum := 0.0
	if clan == null:
		return sum
	for building_id in clan.buildings:
		sum += float(level_def(data, building_id, int(clan.buildings[building_id])).get("effects", {}).get(effect, 0.0))
	return sum


## Herbs harvested each month: item id -> quantity.
static func monthly_herbs(clan: ClanData, data: GameData) -> Dictionary:
	var out := {}
	if clan == null:
		return out
	for building_id in clan.buildings:
		var herbs: Dictionary = level_def(data, building_id, int(clan.buildings[building_id])).get("effects", {}).get("herbs", {})
		for item_id in herbs:
			out[item_id] = int(out.get(item_id, 0)) + int(herbs[item_id])
	return out


## Multiplier on seclusion qi density at the clan seat.
static func qi_multiplier(clan: ClanData, data: GameData) -> float:
	return 1.0 + total(clan, data, "qi_density")


## The qi_density bonus applies only at the clan seat abode (FAM-006c):
## the multiplier for secluding at `abode_id`.
static func seat_qi_multiplier(clan: ClanData, data: GameData, abode_id: String) -> float:
	if clan == null or abode_id == "" or clan.seat != abode_id:
		return 1.0
	return qi_multiplier(clan, data)


## Fraction by which hostile encounters (misfortune) and road ambushes are
## reduced in `region_id`: the estate's ward while it is the seat's region.
static func ward(clan: ClanData, data: GameData, region_id: String) -> float:
	if clan == null or region_id == "" or clan.seat_region != region_id:
		return 0.0
	return minf(MAX_WARD, total(clan, data, "ward"))


## Multiplier on the days of children's monthly training.
static func training_multiplier(clan: ClanData, data: GameData) -> float:
	return 1.0 + total(clan, data, "training_speed")


## Applies `months` months of estate effects: income and reputation to the
## clan, herbs to `head`. Returns {income, reputation, herbs}.
static func apply_months(clan: ClanData, head: CharacterData, data: GameData, months: int) -> Dictionary:
	var result := {"income": 0, "reputation": 0, "herbs": {}}
	if clan == null or months <= 0:
		return result
	result["income"] = int(total(clan, data, "income")) * months
	result["reputation"] = int(total(clan, data, "reputation")) * months
	clan.treasury += int(result["income"])
	clan.reputation += int(result["reputation"])
	var herbs := monthly_herbs(clan, data)
	for item_id in herbs:
		var quantity := int(herbs[item_id]) * months
		head.add_item(item_id, quantity)
		result["herbs"][item_id] = quantity
	return result


## One line per effect of a building level, for UI ("+15 spirit stones a month").
static func describe_effects(data: GameData, building_id: String, building_level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var effects: Dictionary = level_def(data, building_id, building_level).get("effects", {})
	if effects.has("income"):
		lines.append("+%d spirit stones a month" % int(effects["income"]))
	if effects.has("reputation"):
		lines.append("+%d clan reputation a month" % int(effects["reputation"]))
	if effects.has("qi_density"):
		lines.append("+%d%% qi in seclusion at the clan seat" % roundi(float(effects["qi_density"]) * 100.0))
	if effects.has("training_speed"):
		lines.append("+%d%% children's training" % roundi(float(effects["training_speed"]) * 100.0))
	if effects.has("ward"):
		lines.append("-%d%% hostile encounters and ambushes around the seat" % roundi(float(effects["ward"]) * 100.0))
	var herbs: Dictionary = effects.get("herbs", {})
	for item_id in herbs:
		lines.append("%d %s a month" % [int(herbs[item_id]), String(data.items.get(item_id, {}).get("name", item_id))])
	return lines


## Load errors for data/clan_buildings.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if int(data.clan_estate.get("max_projects", 1)) != 1:
		errors.append("clan_buildings.json max_projects must be 1 (only one project at a time is supported)")
	var seen := {}
	for building: Dictionary in data.clan_estate.get("buildings", []):
		var id := String(building.get("id", ""))
		if id == "" or String(building.get("name", "")) == "":
			errors.append("clan_buildings.json buildings need an id and a name")
		if seen.has(id):
			errors.append("clan_buildings.json has duplicate building '%s'" % id)
		seen[id] = true
		var levels: Array = building.get("levels", [])
		if levels.is_empty():
			errors.append("clan building '%s' needs at least one level" % id)
		for i in levels.size():
			var def: Dictionary = levels[i]
			if int(def.get("cost", -1)) < 0 or int(def.get("build_days", -1)) < 0:
				errors.append("clan building '%s' level %d needs cost and build_days >= 0" % [id, i + 1])
			if def.has("min_realm") and data.realm_index_of(String(def["min_realm"])) < 0:
				errors.append("clan building '%s' level %d has unknown min_realm" % [id, i + 1])
			var effects: Dictionary = def.get("effects", {})
			for key in effects:
				if not EFFECTS.has(key):
					errors.append("clan building '%s' level %d has unknown effect '%s'" % [id, i + 1, key])
				elif key == "herbs":
					for item_id in effects[key]:
						if not data.items.has(item_id) or int(effects[key][item_id]) < 1:
							errors.append("clan building '%s' level %d harvests unknown item '%s' (or quantity < 1)" % [id, i + 1, item_id])
				elif float(effects[key]) < 0.0:
					errors.append("clan building '%s' level %d effect '%s' must be >= 0" % [id, i + 1, key])
	return errors
