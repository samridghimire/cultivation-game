class_name VillageCalendar
extends RefCounted
## CAL-001: the month ahead. Lists dated things the player can know about (market days, birthdays of known
## villagers, festivals, season starts) for a window of days. Pure functions, no state, no rng.

const MAX_REMINDERS := 3
const KIND_ORDER := ["market", "festival_active", "festival_month", "birthday", "field", "rent", "request", "secret_realm", "event", "season"]


## Every dated thing in [start, start + span) days, soonest first.
## Each entry: {day: int (total days), kind: String, text: String, region: String ("" = anywhere)}.
## CAL-002: with `c` given, also the player's own dates (crops, rent, requests, secret realms, events).
static func upcoming(data: GameData, npcs: Dictionary, favor: Dictionary, active_events: Array,
		region_id: String, start: int, span: int = 30, c: CharacterData = null) -> Array[Dictionary]:
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
		out.append({"day": start + int(b["in_days"]), "kind": "birthday", "text": "%s's birthday" % npc.name, "region": region_id, "npc_id": npc.id})
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
			out.append({"day": key, "kind": "festival_month", "region": String(def["regions"][0]) if (def.get("regions", []) as Array).size() == 1 else "",
				"text": "%s this month (somewhere in %s)" % [String(def.get("name", eid)), " or ".join(names)]})
	# Season starts.
	for day in range(start, end):
		if day > 0 and Calendar.season_of(day) != Calendar.season_of(day - 1):
			out.append({"day": day, "kind": "season", "text": "%s begins" % Calendar.season_of(day), "region": ""})
	if c != null:
		_own_dates(out, data, npcs, active_events, c, start, end)
	out.sort_custom(_before)
	return out


## CAL-002: the player's own dated things inside [start, end).
static func _own_dates(out: Array[Dictionary], data: GameData, npcs: Dictionary, active_events: Array, c: CharacterData, start: int, end: int) -> void:
	for plot_key: String in c.field_plots:
		var rid := plot_key.get_slice(":", 0)
		var place := FieldPlots.place_def(data, rid)
		var entry: Dictionary = c.field_plots[plot_key]
		var paid := int(entry.get("paid_until", 0))
		if paid >= start and paid < end:
			out.append({"day": paid, "kind": "rent", "region": rid, "text": "Field rent runs out"})
		var seen := {}
		for crop: Dictionary in entry.get("crops", []):
			var left := int(crop.get("days_left", 0))
			if left <= 0 or place.is_empty():
				continue
			# Mirrors FieldPlots.advance: reaching day D grows the crop if D is paid for and not frozen.
			var day := start
			while left > 0 and day + 1 < paid and day < end + 400:
				day += 1
				if not FieldPlots.is_frozen(place, day):
					left -= 1
			if left > 0:
				continue  # never ripens before the rent ends
			var item_id := String(crop.get("item", ""))
			var ready := day  # the first day it stands ripe
			if ready >= end or seen.has("%s@%d" % [item_id, ready]):
				continue
			seen["%s@%d" % [item_id, ready]] = true
			out.append({"day": ready, "kind": "field", "region": rid,
				"text": "Your %s is ready" % String(data.items.get(item_id, {}).get("name", item_id))})
	for req: Dictionary in c.letter_requests:
		var until := int(req.get("until", 0))
		if until < start or until >= end:
			continue
		var asker: CharacterData = npcs.get(req.get("npc_id", ""))
		var npc_name := asker.name if asker != null else "A neighbour"
		var item_id := String(req.get("item", ""))
		var what := "%d %s" % [int(req.get("count", 1)), Items.item_plural(data, item_id, int(req.get("count", 1)))]
		out.append({"day": until, "kind": "request", "region": "", "who": npc_name, "what": what,
			"text": "%s's ask is due: %s" % [npc_name, what]})
	for realm_id: String in data.secret_realms:
		var def: Dictionary = data.secret_realms[realm_id]
		if not SecretRealms.admits(c, data, def):
			continue
		var rname := String(def.get("name", realm_id))
		var rid := String(def.get("region", ""))
		for day in range(start, end):
			var now := SecretRealms.is_open(def, day)
			var before := SecretRealms.is_open(def, day - 1)
			if now and not before:
				out.append({"day": day, "kind": "secret_realm", "region": rid, "text": "%s opens" % rname})
			elif before and not now:
				out.append({"day": day, "kind": "secret_realm", "region": rid, "text": "%s closes" % rname})
	for inst: Dictionary in active_events:
		var eid := String(inst.get("id", ""))
		if WorldEvents.is_festival(data, eid):
			continue
		var ename := WorldEvents.event_name(data, eid)
		var rid := String(inst.get("region", ""))
		var from_day := int(inst.get("start_day", 0))
		var to_day := int(inst.get("end_day", 0))
		if from_day >= start and from_day < end:
			out.append({"day": from_day, "kind": "event", "region": rid, "text": "%s begins in %s" % [ename, Exploration.region_name(data, rid)]})
		if to_day >= start and to_day < end:
			out.append({"day": to_day, "kind": "event", "region": rid, "text": "%s ends in %s" % [ename, Exploration.region_name(data, rid)]})


## CAL-003: tomorrow's entries as at most MAX_REMINDERS short "Tomorrow: ..." lines in KIND_ORDER.
## `flags` (world flags) lets a birthday line name a like the player has learned.
static func reminders(data: GameData, npcs: Dictionary, favor: Dictionary, active_events: Array,
		region_id: String, today: int, c: CharacterData, flags: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in upcoming(data, npcs, favor, active_events, region_id, today + 1, 1, c):
		if out.size() >= MAX_REMINDERS:
			break
		var line := _reminder_line(data, npcs, flags, e)
		if line != "":
			out.append(line)
	return out


static func _reminder_line(data: GameData, npcs: Dictionary, flags: Dictionary, e: Dictionary) -> String:
	var text := String(e["text"])
	match String(e["kind"]):
		"market":
			return "Tomorrow: %s." % text.replace("Market: ", "market day at ")
		"birthday":
			var line := "Tomorrow: %s" % text
			var npc: CharacterData = npcs.get(String(e.get("npc_id", "")))
			if npc != null:
				var likes: Array[String] = []
				var tastes := Family.known_tastes(flags, data, npc.id)
				for item_id: String in tastes:
					if int(tastes[item_id]) > 0:
						likes.append(String(data.items[item_id].get("name", item_id)))
				likes.sort()
				if not likes.is_empty():
					line += " (%s likes %s)" % ["she" if npc.gender == "female" else ("he" if npc.gender == "male" else "they"), likes[0]]
			return line + "."
		"field":
			return "Tomorrow: %s." % text.replace("Your ", "your ")
		"rent":
			return "Tomorrow: field rent is due."
		"request":
			var who := String(e.get("who", ""))
			if who == "A neighbour":
				who = "a neighbour"
			return "Tomorrow: %s's request is due (%s)." % [who, String(e.get("what", ""))]
		"festival_month":
			return ""
		"season":
			return ""
	return "Tomorrow: %s." % text


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["day"] != b["day"]:
		return a["day"] < b["day"]
	var ka := KIND_ORDER.find(a["kind"])
	var kb := KIND_ORDER.find(b["kind"])
	if ka != kb:
		return ka < kb
	return String(a["text"]) < String(b["text"])


## Buckets entries by day of month (1..30). Entries outside the month starting at `month_start_day` are left out
## (a 30-day window from mid-month spans two months, whose days would share cells).
static func month_grid(entries: Array, month_start_day: int) -> Dictionary:
	var grid := {}
	for e: Dictionary in entries:
		var day := int(e["day"])
		if day < month_start_day or day >= month_start_day + Calendar.DAYS_PER_MONTH:
			continue
		var d := Calendar.day_of(day)
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
