class_name VillageHunt
extends RefCounted
## WILD-016: the village hunt. A region (Qingshi) may carry a `hunt` block in regions.json. On the first
## market day of a season that has an in_season beast in the block's `target_region`, the village posts a
## joint hunt for `days` days; joining it fights that beast with the village hunters at your side. Once a
## season (world flag `village_hunt`, the season's first day). Pure functions, no state.

const FLAG := "village_hunt"


static func def(data: GameData, region_id: String) -> Dictionary:
	var d: Variant = data.regions.get(region_id, {}).get("hunt", {})
	return d if d is Dictionary else {}


## The first day of the season `day` falls in.
static func season_start(day: int) -> int:
	var month_in_season := (Calendar.month_of(day) - 1) % 3
	return day - (month_in_season * Calendar.DAYS_PER_MONTH + Calendar.day_of(day) - 1)


## The first market day of today's season in the region, -1 when it has no market day in the season.
static func window_start(data: GameData, region_id: String, day: int) -> int:
	var region: Dictionary = data.regions.get(region_id, {})
	var start := season_start(day)
	for d in range(start, start + 3 * Calendar.DAYS_PER_MONTH):
		if not Places.market_day_stalls(region, d).is_empty():
			return d
	return -1


## The in_season beast of the target region today ("" when none runs this season).
static func quarry(data: GameData, region_id: String, day: int) -> String:
	var target := String(def(data, region_id).get("target_region", ""))
	var season := Calendar.season_of(day).to_lower()
	for e: Dictionary in data.regions.get(target, {}).get("roamers", {}).get("enemies", []):
		if (e.get("in_season", []) as Array).has(season):
			return String(e["enemy"])
	return ""


## True while the hunt is posted in `region_id` on `day` and not yet joined this season.
static func active(data: GameData, region_id: String, day: int, flags: Dictionary) -> bool:
	var d := def(data, region_id)
	if d.is_empty() or quarry(data, region_id, day) == "":
		return false
	if int(flags.get(FLAG, -1)) == season_start(day):
		return false
	var ws := window_start(data, region_id, day)
	return ws >= 0 and day >= ws and day < ws + int(d["days"])


static func mark_done(flags: Dictionary, day: int) -> void:
	flags[FLAG] = season_start(day)


## The notice the village posts on the first day of the window.
static func notice(data: GameData, region_id: String, day: int, npcs: Dictionary = {}) -> String:
	var q := String(data.enemies.get(quarry(data, region_id, day), {}).get("name", "beast")).to_lower()
	var text := "The %s hunt leaves at dawn: the village hunters ride out after the %s." % [Calendar.season_of(day).to_lower(), q]
	var hunter := hunter_of(npcs, data, region_id)
	if hunter != null:
		text += " Hunter %s leads the village hunters." % hunter.name
	return text


## WILD-017: the first living NPC of the region whose npcs.json entry has "hunter": true (null when none).
static func hunter_of(npcs: Dictionary, data: GameData, region_id: String) -> CharacterData:
	for npc_id: String in npcs:
		var npc: CharacterData = npcs[npc_id]
		if npc.alive and npc.home_region == region_id and bool(data.npcs.get(npc_id, {}).get("hunter", false)):
			return npc
	return null


## WILD-017: the calendar entry for the hunt of the season `day` falls in, {} when none (no hunt here,
## no beast in season, already joined). `day` is the hunt day (the first market day).
static func calendar_entry(data: GameData, region_id: String, day: int, flags: Dictionary) -> Dictionary:
	var d := def(data, region_id)
	var q := quarry(data, region_id, day)
	if d.is_empty() or q == "" or int(flags.get(FLAG, -1)) == season_start(day) or window_start(data, region_id, day) != day:
		return {}
	var beast := String(data.enemies.get(q, {}).get("name", "beast"))
	return {"day": day, "kind": "hunt", "region": region_id, "text": "Village hunt (%s)" % beast}


## The village hunters' strike: `bonus` of the player's attack, as a combat ally.
static func ally(c: CharacterData, data: GameData, bonus: float) -> Dictionary:
	return {"name": "The village hunters", "damage": maxi(1, roundi(float(Combat.stats(c, data)["attack"]) * bonus))}


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		if not region.has("hunt"):
			continue
		var where := "Region '%s' hunt" % region["id"]
		var h: Variant = region["hunt"]
		if not h is Dictionary:
			errors.append("%s must be an object" % where)
			continue
		var days: Variant = h.get("days")
		if not ((days is int or days is float) and int(days) >= 1 and int(days) <= 10):
			errors.append("%s days must be 1..10" % where)
		var bonus: Variant = h.get("bonus")
		if not ((bonus is int or bonus is float) and float(bonus) > 0.0 and float(bonus) <= 1.0):
			errors.append("%s bonus must be 0..1" % where)
		if not data.regions.get(String(h.get("target_region", "")), {}).has("roamers"):
			errors.append("%s target_region needs a region with roamers" % where)
	return errors
