class_name VillageCalendar
extends RefCounted
## CAL-001: the month ahead. Lists dated things the player can know about (market days, birthdays of known
## villagers, festivals, season starts) for a window of days. Pure functions, no state, no rng.

const MAX_REMINDERS := 3
const KIND_ORDER := ["market", "hunt", "festival_active", "festival_day", "festival_month", "birthday", "field", "rent", "request", "secret_realm", "event", "forage", "season"]


## CAL-009: "Your birthday" plus the birthdays of a living spouse and children in [start, start + span), region "" (anywhere).
static func family_birthdays(c: CharacterData, npcs: Dictionary, data: GameData, start: int, span: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own := Folk.player_birthday_day(c)
	var own_in := posmod(own - start, Calendar.DAYS_PER_YEAR)
	if own_in < span:
		out.append({"day": start + own_in, "kind": "birthday", "text": "Your birthday", "region": ""})
	var seen := {}
	for id: String in c.spouses + c.children:
		if seen.has(id):
			continue
		seen[id] = true
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive:
			continue
		var d := Folk.days_to_birthday(npc, data, start)
		if d >= 0 and d < span:
			out.append({"day": start + d, "kind": "birthday", "text": "%s's birthday" % npc.name, "region": "", "npc_id": id, "family": true})
	return out


## Every dated thing in [start, start + span) days, soonest first.
## Each entry: {day: int (total days), kind: String, text: String, region: String ("" = anywhere)}.
## CAL-002: with `c` given, also the player's own dates (crops, rent, requests, secret realms, events).
static func upcoming(data: GameData, npcs: Dictionary, favor: Dictionary, active_events: Array,
		region_id: String, start: int, span: int = 30, c: CharacterData = null, flags: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var end := start + span
	# Market days of timed places in this region.
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if not place.has("open_days"):
			continue
		for day in range(start, end):
			if Places.is_open(place, day):
				var base := "Market: %s%s" % [String(place.get("display_name", "stall")), " (new wares each time)" if place.has("rotating_stock") else ""]
				var entry := {"day": day, "kind": "market", "text": base, "region": region_id}
				# MARKET-012: a regular hears what the stall wants.
				if c != null and Places.is_regular(place, int(c.market_regular.get(Places.place_key(String(place.get("display_name", ""))), 0))):
					var wp := Places.wanted_phrase(place, day, data)
					if wp != "":
						entry["text"] = "%s, wants %s" % [base, wp]
						entry["plain"] = base
				out.append(entry)
	# WILD-017: the season's village hunt, on its first day.
	for day in range(start, end):
		var hunt := VillageHunt.calendar_entry(data, region_id, day, flags)
		if not hunt.is_empty():
			out.append(hunt)
	# Birthdays of villagers you know.
	for b: Dictionary in Folk.birthdays_soon(npcs, data, region_id, start, favor, span - 1):
		var npc: CharacterData = b["npc"]
		out.append({"day": start + int(b["in_days"]), "kind": "birthday", "text": "%s's birthday" % npc.name, "region": region_id, "npc_id": npc.id})
	# CAL-009: your own birthday and the living family's, wherever you are.
	# A spouse or child you know in this region is already listed above; keep one entry each.
	if c != null:
		for fe: Dictionary in family_birthdays(c, npcs, data, start, span):
			if not out.any(func(x: Dictionary) -> bool: return x["kind"] == "birthday" and x.get("npc_id", "") == fe.get("npc_id", "-")):
				out.append(fe)
	# Festivals under way.
	for inst: Dictionary in active_events:
		if not WorldEvents.is_festival(data, String(inst.get("id", ""))):
			continue
		var first := maxi(start, int(inst.get("start_day", 0)))
		var last := int(inst.get("end_day", 0)) - 1
		if first > last or first >= end:
			continue
		var rid := String(inst.get("region", ""))
		var until := Calendar.format_date(last)
		var stall := ", festival stall open" if not Places.festival_stalls_open(data, [inst], rid, first).is_empty() else ""  # FEST-012
		var wares := Places.open_stall_wares(data, [inst], rid, first, 4)  # GUIDE-221
		if not wares.is_empty():
			stall += ": " + ", ".join(wares)
		out.append({"day": first, "kind": "festival_active", "region": rid, "last_day": last, "festival_id": String(inst["id"]), "name": WorldEvents.event_name(data, String(inst["id"])),
			"text": "%s in %s (to %s%s)%s" % [WorldEvents.event_name(data, String(inst["id"])), Exploration.region_name(data, rid), until, stall, _contest_suffix(data, String(inst["id"]), flags, start)]})
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
				"text": "%s this month (somewhere in %s)%s" % [String(def.get("name", eid)), " or ".join(names), _contest_suffix(data, eid, flags, start)]})
	# Season starts.
	for day in range(start, end):
		if day > 0 and Calendar.season_of(day) != Calendar.season_of(day - 1):
			out.append({"day": day, "kind": "season", "text": "%s begins" % Calendar.season_of(day), "region": ""})
	if c != null:
		_great_beasts(out, data, c, start, end)
		_forage_seasons(out, data, c, start, end)
		_own_dates(out, data, npcs, active_events, c, start, end)
	out.sort_custom(_before)
	return out


## FORAGE-003: the first day in the window a visited region's seasonal forage comes into season (one line per region).
## WILD-020: a wild region (no timed places) with a season already under way lists what is in season on `start`, and
## its in-season beasts get their own line the same way.
static func _forage_seasons(out: Array[Dictionary], data: GameData, c: CharacterData, start: int, end: int) -> void:
	for rid: String in c.visited_regions:
		var def: Dictionary = data.regions.get(rid, {})
		var wild := true
		for place: Dictionary in def.get("places", []):
			if place.has("open_days"):
				wild = false
		var items: Array = def.get("forage", {}).get("items", [])
		var forage_done := items.is_empty()
		var beast_done := false
		for day in range(start, end):
			var boundary := day > 0 and Calendar.season_of(day) != Calendar.season_of(day - 1)
			if not boundary and not (wild and day == start):
				continue
			var season := Calendar.season_of(day)
			var now := "" if boundary else " (in season now)"
			if not forage_done:
				var names: PackedStringArray = []
				for e: Dictionary in items:
					if e.has("seasons") and (e["seasons"] as Array).has(season.to_lower()):
						var nm := String(data.items.get(String(e["item"]), {}).get("name", e["item"]))
						if not names.has(nm):
							names.append(nm)
				if not names.is_empty():
					forage_done = true
					out.append({"day": day, "kind": "forage", "region": rid,
						"text": "%s forage on the %s paths: %s%s" % [season, Exploration.region_name(data, rid), ", ".join(names), now], "ongoing": not boundary})
			if wild and not beast_done:
				var clause := Wildlife.season_clause(data, rid, day)
				if clause != "":
					beast_done = true
					out.append({"day": day, "kind": "forage", "region": rid, "text": clause.trim_suffix(".") + now, "ongoing": not boundary})
			if forage_done and (beast_done or not wild):
				break


## WILD-006: days a great beast walks an explored region, inside [start, end).
static func _great_beasts(out: Array[Dictionary], data: GameData, c: CharacterData, start: int, end: int) -> void:
	for rid: String in c.visited_regions:
		var day := Wildlife.next_great_day(data, rid, start, c.realm_index, c)
		while day >= 0 and day < end:
			var enemy := Wildlife.active_great_enemy(c, data, rid)
			var beast := Wildlife.display_name(data, enemy, true)
			out.append({"day": day, "kind": "great_beast", "region": rid, "enemy": enemy,
				"text": "The %s walks %s" % [beast, Exploration.region_name(data, rid)]})
			day = Wildlife.next_great_day(data, rid, day + 1, c.realm_index, c)


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
				out.append({"day": day, "kind": "secret_realm", "region": rid, "last_day": day + int(def.get("open_days", 1)) - 1, "text": "%s opens" % rname})
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
			out.append({"day": from_day, "kind": "event", "region": rid, "last_day": to_day - 1, "text": "%s begins in %s" % [ename, Exploration.region_name(data, rid)]})
		if to_day >= start and to_day < end:
			out.append({"day": to_day, "kind": "event", "region": rid, "text": "%s ends in %s" % [ename, Exploration.region_name(data, rid)]})


## CAL-003: tomorrow's entries as at most MAX_REMINDERS short "Tomorrow: ..." lines in KIND_ORDER.
## `flags` (world flags) lets a birthday line name a like the player has learned.
static func reminders(data: GameData, npcs: Dictionary, favor: Dictionary, active_events: Array,
		region_id: String, today: int, c: CharacterData, flags: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	var inv := FestivalContest.invitation(data, npcs, favor, today + 1)
	var invite := ""
	if not inv.is_empty():
		# FEST-011: only when the player is in the festival's region or one route away.
		var fest_regions: Array = data.world_events[String(inv["event_id"])].get("regions", [])
		if not fest_regions.is_empty() and Exploration.is_nearby(data, region_id, String(fest_regions[0])):
			invite = FestivalContest.invitation_line(data, inv)
	if invite != "":
		out.append(invite)  # FOLK-012
	for e: Dictionary in upcoming(data, npcs, favor, active_events, region_id, today + 1, 1, c):
		if out.size() >= MAX_REMINDERS:
			break
		# WILD-011: only a beast that is close and that the player has not beaten yet is worth a reminder.
		if String(e["kind"]) == "great_beast" and (not _near(data, region_id, String(e["region"]))
				or (c != null and c.great_beasts.has(String(e.get("enemy", ""))))):
			continue
		if String(e["kind"]) == "festival_active" and _festival_running_today(active_events, String(e.get("festival_id", "")), today):
			continue  # GUIDE-230: today's list already says the festival is on
		if bool(e.get("ongoing", false)):
			continue  # WILD-020: "in season now" is for the calendar, not a "Tomorrow" reminder
		var line := reminder_line(data, npcs, flags, e)
		if line == "":
			continue
		# CAL-008: a far-away festival, event or realm opening is only worth a reminder if you could still make it.
		var far_region := String(e.get("region", ""))
		var kind := String(e["kind"])
		if far_region != "" and far_region != region_id and _is_far(data, region_id, far_region) \
				and (kind == "festival_active" or kind == "secret_realm" or (kind == "event" and String(e["text"]).contains(" begins "))):
			if c == null:
				continue
			var days := Guidance.route_days(c, data, region_id, far_region)
			if days < 0:
				continue
			if e.has("last_day") and today + days > int(e["last_day"]):  # leave today, arrive on day today + days
				continue
			if line.ends_with("."):
				line = line.substr(0, line.length() - 1) + " (%d days' travel)." % days
			else:
				line += " (%d days' travel)" % days
		out.append(line)
	# MARKET-012: a regular learns the stall's wanted item a day early.
	if c != null and out.size() < MAX_REMINDERS:
		for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
			var item_id := String(Places.wanted_today(place, today + 1).get("item", ""))
			var line := Places.regular_tomorrow_line(place, int(c.market_regular.get(Places.place_key(String(place.get("display_name", ""))), 0)), today + 1, data, c.item_count(item_id) if item_id != "" else 0)
			if line != "":
				out.append(line)
				break
	return out


## GUIDE-230: whether an instance of festival `festival_id` has already started and has not ended on `today`.
static func _festival_running_today(active_events: Array, festival_id: String, today: int) -> bool:
	for inst: Dictionary in active_events:
		if String(inst.get("id", "")) == festival_id and int(inst.get("start_day", 0)) <= today and int(inst.get("end_day", 0)) > today:
			return true
	return false


## CAL-006: the player's marks.
const MAX_MARKS := 5


## "" if `day` may be marked with `label` (a label the calendar shows that day), else why not.
static func check_mark(c: CharacterData, entries: Array[Dictionary], today: int, day: int, label: String) -> String:
	if day <= today:
		return "Only a future day can be marked."
	if c.marked_days.has(day):
		return "That day is already marked."
	if c.marked_days.size() >= MAX_MARKS:
		return "You can mark at most %d days; unmark one first." % MAX_MARKS
	for e: Dictionary in entries:
		if int(e["day"]) == day and String(e["text"]) == label:
			return ""
	return "The calendar shows nothing like that on that day."


## Drops marks of days that are over.
static func prune_marks(c: CharacterData, today: int) -> void:
	for day: int in c.marked_days.keys():
		if day < today:
			c.marked_days.erase(day)


## Lines for marked days: today's "Today: <label> (you marked it)." and tomorrow's "Tomorrow: <label>.".
static func mark_lines(c: CharacterData, today: int) -> PackedStringArray:
	var out := PackedStringArray()
	if c.marked_days.has(today):
		out.append("Today: %s (you marked it)." % String(c.marked_days[today]))
	if c.marked_days.has(today + 1):
		out.append("Tomorrow: %s." % String(c.marked_days[today + 1]))
	return out


## CAL-008: true when `rid` is not `here`, nor one short direct route (3 days or less) from it.
static func _is_far(data: GameData, here: String, rid: String) -> bool:
	if rid == here:
		return false
	for r: Dictionary in data.regions.get(here, {}).get("routes", []):
		if String(r.get("to", "")) == rid:
			return int(r.get("days", 1)) > 3
	return true


## True when `rid` is `here` or one direct route from it.
static func _near(data: GameData, here: String, rid: String) -> bool:
	if rid == here:
		return true
	for r: Dictionary in data.regions.get(here, {}).get("routes", []):
		if String(r.get("to", "")) == rid:
			return true
	return false


static func reminder_line(data: GameData, npcs: Dictionary, flags: Dictionary, e: Dictionary) -> String:
	var text := String(e.get("plain", e["text"]))
	match String(e["kind"]):
		"great_beast":
			return "Tomorrow: %s." % text.replace("A great", "a great")
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
	# CAL-007: the other days of a festival's span inside the month get a light festival_day entry.
	var month_end := month_start_day + Calendar.DAYS_PER_MONTH - 1
	for e: Dictionary in entries:
		if String(e["kind"]) != "festival_active" or not e.has("last_day"):
			continue
		for day in range(maxi(int(e["day"]) + 1, month_start_day), mini(int(e["last_day"]), month_end) + 1):
			var d2 := Calendar.day_of(day)
			if not grid.has(d2):
				grid[d2] = []
			grid[d2].append({"day": day, "kind": "festival_day", "text": String(e.get("name", e.get("text", ""))), "region": e.get("region", ""), "first": false})
	for d3: int in grid:
		(grid[d3] as Array).sort_custom(_before)
	return grid


## Total days of day 1 of the month containing `total_days`.
static func month_start(total_days: int) -> int:
	return total_days - (Calendar.day_of(total_days) - 1)


static func _in_month(def: Dictionary, month: int) -> bool:
	for v in def.get("months", []):
		if int(v) == month:
			return true
	return false


## " (contest: Lantern riddles)" when the festival has a contest (FEST-006).
static func _contest_suffix(data: GameData, event_id: String, flags: Dictionary = {}, today: int = 0) -> String:
	var contest := FestivalContest.contest_of(data, event_id)
	if contest.is_empty():
		return ""
	var champ := FestivalContest.champion_text(flags, event_id, Calendar.year_of(today))
	return " (contest: %s%s)" % [String(contest["name"]), "; " + champ if champ != "" else ""]
