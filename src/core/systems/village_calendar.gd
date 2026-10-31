class_name VillageCalendar
extends RefCounted
## CAL-001: the month ahead. Lists dated things the player can know about (market days, birthdays of known
## villagers, festivals, season starts) for a window of days. Pure functions, no state, no rng.

const KIND_ORDER := ["market", "festival_active", "festival_month", "birthday", "season"]


## Every dated thing in [start, start + span) days, soonest first.
## Each entry: {day: int (total days), kind: String, text: String, region: String ("" = anywhere)}.
static func upcoming(data: GameData, npcs: Dictionary, favor: Dictionary, active_events: Array,
		region_id: String, start: int, span: int = 30) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var end := start + span
	# Market days of timed places in this region.
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if not place.has("open_days"):
			continue
		for day in range(start, end):
			if Places.is_open(place, day):
				out.append({"day": day, "kind": "market", "text": "Market: %s" % String(place.get("display_name", "stall")), "region": region_id})
	# Birthdays of villagers you know.
	for b: Dictionary in Folk.birthdays_soon(npcs, data, region_id, start, favor, span - 1):
		var npc: CharacterData = b["npc"]
		out.append({"day": start + int(b["in_days"]), "kind": "birthday", "text": "%s's birthday" % npc.name, "region": region_id})
	# Festivals under way.
	for inst: Dictionary in active_events:
		if not WorldEvents.is_festival(data, String(inst.get("id", ""))):
			continue
		var first := maxi(start, int(inst.get("start_day", 0)))
		var last := int(inst.get("end_day", 0)) - 1
		if first > last or first >= end:
			continue
		var rid := String(inst.get("region", ""))
		var until := Calendar.format_date(int(inst.get("end_day", 0)))
		out.append({"day": first, "kind": "festival_active", "region": rid,
			"text": "%s in %s (until %s)" % [WorldEvents.event_name(data, String(inst["id"])), Exploration.region_name(data, rid), until]})
	# Festival months inside the window that are not under way.
	var seen_months := {}
	for day in range(start, end):
		var m := Calendar.month_of(day)
		var key := day - (Calendar.day_of(day) - 1)
		if seen_months.has(key):
			continue
		seen_months[key] = true
		if key < start:
			continue  # day 1 of that month is already behind us
		for eid: String in data.world_events:
			var def: Dictionary = data.world_events[eid]
			if not bool(def.get("festival", false)) or not _in_month(def, m):
				continue
			if WorldEvents.is_active(active_events, eid):
				continue
			var names: Array[String] = []
			for r in def.get("regions", []):
				names.append(Exploration.region_name(data, String(r)))
			out.append({"day": key, "kind": "festival_month", "region": "",
				"text": "%s this month (somewhere in %s)" % [String(def.get("name", eid)), " or ".join(names)]})
	# Season starts.
	for day in range(start, end):
		if day > 0 and Calendar.season_of(day) != Calendar.season_of(day - 1):
			out.append({"day": day, "kind": "season", "text": "%s begins" % Calendar.season_of(day), "region": ""})
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["day"] != b["day"]:
		return a["day"] < b["day"]
	var ka := KIND_ORDER.find(a["kind"])
	var kb := KIND_ORDER.find(b["kind"])
	if ka != kb:
		return ka < kb
	return String(a["text"]) < String(b["text"])


## Buckets entries by day of month (1..30).
static func month_grid(entries: Array, _month_start: int) -> Dictionary:
	var grid := {}
	for e: Dictionary in entries:
		var d := Calendar.day_of(int(e["day"]))
		if not grid.has(d):
			grid[d] = []
		grid[d].append(e)
	return grid


## Total days of day 1 of the month containing `total_days`.
static func month_start(total_days: int) -> int:
	return total_days - (Calendar.day_of(total_days) - 1)


static func _in_month(def: Dictionary, month: int) -> bool:
	for v in def.get("months", []):
		if int(v) == month:
			return true
	return false
