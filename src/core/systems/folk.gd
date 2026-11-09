class_name Folk
extends RefCounted
## Happenings that name the people who live there (ENC-011). Encounter text may use {villager} (a living
## generated adult of the current region, not family, not the rival) and {elder} (the oldest such person).
## `pick` chooses them when the encounter is rolled; `fill` writes their names into any text shown.

const VILLAGER := "{villager}"
const ELDER := "{elder}"
const FAVOR_LIMIT := 20


## The texts of `encounter` that may carry placeholders: its text and each choice's label, text and on_fail text.
static func texts(encounter: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = [String(encounter.get("text", ""))]
	for choice: Dictionary in encounter.get("choices", []):
		out.append(String(choice.get("label", "")))
		out.append(String(choice.get("text", "")))
		out.append(String(choice.get("on_fail", {}).get("text", "")))
	return out


## Whether any text of `encounter` names a villager or an elder.
static func uses(encounter: Dictionary) -> bool:
	for text in texts(encounter):
		if text.contains(VILLAGER) or text.contains(ELDER):
			return true
	return false


## Living generated adults of `region_id` who are neither the player's family nor their rival, by id.
static func candidates(npcs: Dictionary, data: GameData, player: CharacterData, region_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	if region_id == "":
		return out
	var adult := int(data.family.get("adult_age", 16))
	for c in Npcs.generated_in_region(npcs, data, region_id):
		if c.age_years() < adult or c.id == player.rival:
			continue
		if player.spouses.has(c.id) or player.children.has(c.id) or player.parents.has(c.id):
			continue
		out.append(c)
	return out


## Whether `encounter` can happen in `region_id`: one that names people needs someone there to name.
static func available(encounter: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, region_id: String) -> bool:
	return not uses(encounter) or not candidates(npcs, data, player, region_id).is_empty()


## Chooses the cast of `encounter`: {villager: id, elder: id}, or {} when it names nobody or nobody lives there.
## Half the time the villager is someone the player already knows (favor > 0), if anyone is. Uses `rng` only
## when the encounter names people.
static func pick(encounter: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, region_id: String, favor: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not uses(encounter):
		return {}
	var pool := candidates(npcs, data, player, region_id)
	if pool.is_empty():
		return {}
	var known: Array[CharacterData] = []
	for c in pool:
		if int(favor.get(c.id, 0)) > 0:
			known.append(c)
	var from: Array[CharacterData] = known if not known.is_empty() and rng.randf() < 0.5 else pool
	var villager := from[rng.randi_range(0, from.size() - 1)]
	var elder := pool[0]
	for c in pool:
		if c.age_days > elder.age_days:
			elder = c
	return {"villager": villager.id, "elder": elder.id}


## `text` with {villager} and {elder} replaced by the names in `cast` (left as is without a cast).
static func fill(text: String, cast: Dictionary, npcs: Dictionary) -> String:
	if cast.is_empty() or not (text.contains(VILLAGER) or text.contains(ELDER)):
		return text
	var villager: CharacterData = npcs.get(String(cast.get("villager", "")))
	var elder: CharacterData = npcs.get(String(cast.get("elder", "")))
	if villager != null:
		text = text.replace(VILLAGER, villager.name)
	if elder != null:
		text = text.replace(ELDER, elder.name)
	return text


## The favor changes an effects block asks for with the cast: {npc_id: delta} (the elder and villager may be one person).
static func favor_changes(effects: Dictionary, cast: Dictionary) -> Dictionary:
	var out := {}
	for pair: Array in [["villager_favor", "villager"], ["elder_favor", "elder"]]:
		var npc_id := String(cast.get(pair[1], ""))
		if effects.has(pair[0]) and npc_id != "":
			out[npc_id] = int(out.get(npc_id, 0)) + int(effects[pair[0]])
	return out


## What `npc` says in passing (WORLD-003) given the player's `favor` with them: a warm or cool line from
## data/family.json folk_greetings picked by hash(npc id + day), with {player} left for the caller. "" in between.
## WEATHER-006: with today's `weather` and a warm villager, `folk_greetings.weather[weather]` lines come first.
static func greeting(npc: CharacterData, favor: int, day: int, data: GameData, flags: Dictionary = {}, weather: String = "", region_id: String = "") -> String:
	var bands: Dictionary = data.family.get("folk_greetings", {})
	var party: Array = bands.get("celebration", {}).get(celebration_kind(flags, npc.id), [])
	if celebration_open(flags, npc.id, day) and not party.is_empty():
		return String(party[absi(hash(npc.id + str(day))) % party.size()])
	var cake: Array = bands.get("birthday", [])
	if birthday_today(npc, data, day) and data.npcs.has(npc.id) and String(data.npcs[npc.id].get("birthday_line", "")) != "":
		return String(data.npcs[npc.id]["birthday_line"])  # FOLK-022
	if not cake.is_empty() and birthday_today(npc, data, day):
		return String(cake[absi(hash(npc.id + str(day))) % cake.size()])
	var shunned: Array = bands.get("shunned", [])
	if not shunned.is_empty() and shunned_by_mark(flags, npc.id, day):
		return String(shunned[absi(hash(npc.id + str(day))) % shunned.size()])
	if region_id != "" and favor > int(bands.get("cool", {}).get("max_favor", -1000)):
		var news := news_line(npc, flags, data, region_id, day)
		if news != "":
			return news
	var band: Dictionary = {}
	var rainy: Array = bands.get("weather", {}).get(weather, [])
	if weather != "" and not rainy.is_empty() and favor >= int(bands.get("warm", {}).get("min_favor", 1000)):
		return String(rainy[absi(hash(npc.id + str(day))) % rainy.size()])
	if favor >= int(bands.get("warm", {}).get("min_favor", 1000)):
		band = bands["warm"]
	elif favor <= int(bands.get("cool", {}).get("max_favor", -1000)):
		band = bands["cool"]
	var lines: Array = band.get("lines", [])
	if lines.is_empty():
		return ""
	return String(lines[absi(hash(npc.id + str(day))) % lines.size()])


## FOLK-025: the festival line `npc` says while a festival runs in `region_id`: {"event": id, "line": text} or {}.
## A named villager's own `festival_lines[event]` first, else the shared family.json folk_greetings.festival pool
## (picked by day + npc id hash, {name}/{festival} filled). Birthdays win, and a line is told once per festival per year.
static func festival_line(npc: CharacterData, data: GameData, events: Array, region_id: String, day: int, flags: Dictionary) -> Dictionary:
	if birthday_today(npc, data, day):
		return {}
	var year := Calendar.year_of(day)
	var told: Dictionary = flags.get("festival_lines_%d" % year, {})
	for e in WorldEvents.active_in(events, region_id):
		var fid := String(e.get("id", ""))
		if not WorldEvents.is_festival(data, fid) or (told.get(npc.id, []) as Array).has(fid):
			continue
		var own: Dictionary = data.npcs.get(npc.id, {}).get("festival_lines", {})
		var pool: Array = data.family.get("folk_greetings", {}).get("festival", [])
		var line := ""
		if own.has(fid):
			line = String(own[fid])
		elif not pool.is_empty():
			line = String(pool[absi(hash(npc.id + str(day))) % pool.size()])
		if line != "":
			line = line.replace("{name}", npc.name).replace("{festival}", String(WorldEvents.def_of(data, fid).get("name", fid)))
			return {"event": fid, "line": line}
	return {}


## FOLK-025: remember that `npc_id` told the `event_id` line this year.
static func mark_festival_told(flags: Dictionary, npc_id: String, event_id: String, day: int) -> void:
	var key := "festival_lines_%d" % Calendar.year_of(day)
	var told: Dictionary = flags.get(key, {})
	var list: Array = told.get(npc_id, [])
	if not list.has(event_id):
		list.append(event_id)
	told[npc_id] = list
	flags[key] = told


## FOLK-025: load errors for npcs.json festival_lines and family.json folk_greetings.festival.
static func validate_festival_lines(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	var pool: Variant = data.family.get("folk_greetings", {}).get("festival", [])
	if not (pool is Array):
		errors.append("family.json folk_greetings.festival must be an array of strings")
	else:
		for line: Variant in pool:
			if not (line is String) or String(line) == "" or String(line).length() > 160:
				errors.append("family.json folk_greetings.festival lines must be strings of 1..160 characters")
	for id: String in data.npcs:
		var lines: Variant = data.npcs[id].get("festival_lines", {})
		if not (lines is Dictionary):
			errors.append("NPC '%s' festival_lines must be an object" % id)
			continue
		for fid: String in lines:
			if not WorldEvents.is_festival(data, fid):
				errors.append("NPC '%s' festival_lines: '%s' is not a festival world event" % [id, fid])
			if not (lines[fid] is String) or String(lines[fid]) == "" or String(lines[fid]).length() > 160:
				errors.append("NPC '%s' festival_lines.%s must be a string of 1..160 characters" % [id, fid])
	return errors


## FOLK-026: remember that `npc_id` went to `event_id` with the player (a Close friend's invitation, FOLK-012).
static func note_festival_company(flags: Dictionary, npc_id: String, event_id: String, day: int) -> void:
	var memory: Dictionary = flags.get("festival_memory", {})
	memory[npc_id] = {"event": event_id, "day": day, "told": false}
	flags["festival_memory"] = memory


## FOLK-026: favor a friend gives when they recall the festival you shared.
const FESTIVAL_MEMORY_FAVOR := 2
## FOLK-026: days after the festival in which the friend still remembers it.
const FESTIVAL_MEMORY_DAYS := 10


## FOLK-026: the remembered festival line `npc` says on their first chat within FESTIVAL_MEMORY_DAYS of a shared festival,
## or "". Own `festival_memory_line` first, else family.json folk_greetings.festival_memory ({name}/{festival}/{player}).
## With `consume` it is marked told (once per festival per year).
static func festival_memory_line(npc: CharacterData, data: GameData, flags: Dictionary, day: int, consume: bool) -> String:
	var memory: Dictionary = flags.get("festival_memory", {})
	var entry: Variant = memory.get(npc.id)
	if not (entry is Dictionary) or bool(entry.get("told", false)):
		return ""
	var since := day - int(entry.get("day", day))
	if since < 0 or since > FESTIVAL_MEMORY_DAYS:
		return ""
	var fid := String(entry.get("event", ""))
	var pool: Array = data.family.get("folk_greetings", {}).get("festival_memory", [])
	var line := String(data.npcs.get(npc.id, {}).get("festival_memory_line", ""))
	if line == "" and not pool.is_empty():
		line = String(pool[absi(hash(npc.id + fid)) % pool.size()])
	if line == "":
		return ""
	if consume:
		entry["told"] = true
		memory[npc.id] = entry
		flags["festival_memory"] = memory
	return line.replace("{name}", npc.name).replace("{festival}", String(WorldEvents.def_of(data, fid).get("name", fid)))


## FOLK-026: load errors for npcs.json festival_memory_line and family.json folk_greetings.festival_memory.
static func validate_festival_memory(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	var pool: Variant = data.family.get("folk_greetings", {}).get("festival_memory", [])
	if not (pool is Array):
		errors.append("family.json folk_greetings.festival_memory must be an array of strings")
	else:
		for line: Variant in pool:
			if not (line is String) or String(line) == "" or String(line).length() > 160:
				errors.append("family.json folk_greetings.festival_memory lines must be strings of 1..160 characters")
	for id: String in data.npcs:
		if data.npcs[id].has("festival_memory_line"):
			var l: Variant = data.npcs[id]["festival_memory_line"]
			if not (l is String) or String(l) == "" or String(l).length() > 160:
				errors.append("NPC '%s' festival_memory_line must be a string of 1..160 characters" % id)
	return errors


## FOLK-030: load errors for npcs.json player_birthday_gift {item, count 1..3}.
static func validate_player_birthday_gifts(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	for id: String in data.npcs:
		if not data.npcs[id].has("player_birthday_gift"):
			continue
		var g: Variant = data.npcs[id]["player_birthday_gift"]
		if not (g is Dictionary) or not data.items.has(String(g.get("item", ""))):
			errors.append("NPC '%s' player_birthday_gift.item must be an items.json id" % id)
		elif not (g.get("count") is int or g.get("count") is float) or int(g["count"]) < 1 or int(g["count"]) > 3:
			errors.append("NPC '%s' player_birthday_gift.count must be 1..3" % id)
	return errors


## FOLK-030: true when the villager has their own player_birthday_line (the gift rides that line, not the shared pool).
static func player_birthday_own_line(npc_id: String, data: GameData) -> bool:
	return String(data.npcs.get(npc_id, {}).get("player_birthday_line", "")) != ""


## FOLK-030: the gift a named villager gives on the player's birthday with their own line: {item, count} or {}.
static func player_birthday_gift_of(npc_id: String, data: GameData) -> Dictionary:
	var g: Variant = data.npcs.get(npc_id, {}).get("player_birthday_gift", {})
	if not (g is Dictionary) or not data.items.has(String(g.get("item", ""))):
		return {}
	return {"item": String(g["item"]), "count": clampi(int(g.get("count", 1)), 1, 3)}


## COOK-003: favor a friend's remark about their dish gives (once per dish).
const DISH_NOTICED_FAVOR := 3
## COOK-003: days after the first cook in which the teacher's next chat mentions it.
const DISH_NOTICED_DAYS := 14


## COOK-003: the named friend whose lesson teaches `meal_id` (effects.learn_dish) and that `c` has been taught
## ("npc_id:index" in lessons_taught), or "".
static func dish_teacher(c: CharacterData, data: GameData, meal_id: String) -> String:
	for npc_id: String in data.npcs:
		var lessons: Array = data.npcs[npc_id].get("lessons", [])
		for i in lessons.size():
			if String(lessons[i].get("effects", {}).get("learn_dish", "")) == meal_id and c.lessons_taught.has("%s:%d" % [npc_id, i]):
				return npc_id
	return ""


## COOK-003: the first time `c` cooks a dish a friend taught, remember it (world flag "dish_memory", one entry per
## dish) so that friend's next chat can say a line. True when something was recorded.
static func record_dish_cooked(flags: Dictionary, c: CharacterData, data: GameData, meal_id: String, day: int) -> bool:
	var memory: Dictionary = flags.get("dish_memory", {})
	if memory.has(meal_id):
		return false
	var npc_id := dish_teacher(c, data, meal_id)
	if npc_id == "" or String(data.npcs[npc_id].get("taught_dish_line", "")) == "":
		return false
	memory[meal_id] = {"npc": npc_id, "day": day, "told": false}
	flags["dish_memory"] = memory
	return true


## COOK-003: the line `npc` says about a dish they taught that you cooked, within DISH_NOTICED_DAYS (once per dish),
## or "". With `consume` the entry is marked told. Returns {line, dish} fields as a dictionary, empty when nothing.
static func dish_noticed(npc: CharacterData, data: GameData, flags: Dictionary, day: int, consume: bool) -> Dictionary:
	var memory: Variant = flags.get("dish_memory", {})
	if not (memory is Dictionary) or not data.npcs.has(npc.id):
		return {}
	var template := String(data.npcs[npc.id].get("taught_dish_line", ""))
	if template == "":
		return {}
	for meal_id: String in (memory as Dictionary):
		var m: Dictionary = memory[meal_id]
		var age := day - int(m.get("day", -9999))
		if String(m.get("npc", "")) != npc.id or bool(m.get("told", false)) or age < 0 or age > DISH_NOTICED_DAYS:
			continue
		if consume:
			m["told"] = true
		var dish_name := String(Cooking.meal(data, meal_id).get("name", meal_id)).to_lower()
		return {"line": template.replace("{dish}", dish_name), "dish": meal_id}
	return {}


## COOK-003: load errors in npcs.json taught_dish_line.
static func validate_taught_dish_line(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	for id: String in data.npcs:
		if data.npcs[id].has("taught_dish_line"):
			var l: Variant = data.npcs[id]["taught_dish_line"]
			if not (l is String) or String(l) == "" or String(l).length() > 160 or not String(l).contains("{dish}"):
				errors.append("NPC '%s' taught_dish_line must be a string of 1..160 characters containing {dish}" % id)
	return errors


## FOLK-018: remember `npc_id`'s newest gift from the player (taste 1 liked, 0 neutral, -1 disliked).
static func record_gift(flags: Dictionary, npc_id: String, item_id: String, day: int, taste: int) -> void:
	var memory: Dictionary = flags.get("gift_memory", {})
	memory[npc_id] = {"item": item_id, "day": day, "taste": taste, "told": false}
	flags["gift_memory"] = memory


static func _taste_key(taste: int) -> String:
	return "liked" if taste > 0 else ("disliked" if taste < 0 else "neutral")


## FOLK-018: the line `npc_id` says about the last gift (once, from the day after, within gift_memory.days), or "".
## With `consume` the line is marked told. Pure apart from that mark.
static func gift_memory_line(flags: Dictionary, npc_id: String, data: GameData, day: int, consume: bool) -> String:
	var rules: Dictionary = data.family.get("gift_memory", {})
	var memory: Variant = flags.get("gift_memory", {})
	if rules.is_empty() or not (memory is Dictionary) or not (memory as Dictionary).has(npc_id):
		return ""
	var m: Dictionary = memory[npc_id]
	var age := day - int(m.get("day", -9999))
	if bool(m.get("told", false)) or age < 1 or age > int(rules.get("days", 30)):
		return ""
	var lines: Array = rules.get(_taste_key(int(m.get("taste", 0))), [])
	if lines.is_empty():
		return ""
	if consume:
		m["told"] = true
	var item_name := String(data.items.get(String(m["item"]), {}).get("name", m["item"])).to_lower()
	return String(lines[absi(hash(npc_id + str(day))) % lines.size()]).replace("{item}", item_name)


## FOLK-018: "Last gift: Mugwort (liked)" for the village book, "" when nothing was given.
static func last_gift_text(flags: Dictionary, npc_id: String, data: GameData) -> String:
	var memory: Variant = flags.get("gift_memory", {})
	if not (memory is Dictionary) or not (memory as Dictionary).has(npc_id):
		return ""
	var m: Dictionary = memory[npc_id]
	var item_name := String(data.items.get(String(m.get("item", "")), {}).get("name", m.get("item", "")))
	return "Last gift: %s (%s)" % [item_name, _taste_key(int(m.get("taste", 0)))]


## Load errors in family.json gift_memory.
static func validate_gift_memory(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not data.family.has("gift_memory"):
		return errors
	var rules: Dictionary = data.family["gift_memory"]
	var days: Variant = rules.get("days", 0)
	if not (days is int or days is float) or int(days) < 1 or int(days) > 90:
		errors.append("family.json gift_memory.days must be 1..90")
	for key in ["liked", "neutral", "disliked"]:
		var lines: Variant = rules.get(key, [])
		if not (lines is Array) or (lines as Array).is_empty():
			errors.append("family.json gift_memory.%s must be a non-empty array" % key)
			continue
		for line: Variant in lines:
			if not (line is String) or not String(line).contains("{item}"):
				errors.append("family.json gift_memory.%s lines need {item}" % key)
	return errors


const NEWS_KINDS: Array[String] = ["contest_win", "great_beast", "great_trail", "shrine_stage", "project_stage", "season_done", "breakthrough"]


## FOLK-015: remember the newest notable deed (a newer one replaces it).
static func record_news(flags: Dictionary, kind: String, subject: String, region_id: String, day: int) -> void:
	flags["village_news"] = {"kind": kind, "subject": subject, "region": region_id, "day": day}


## FOLK-015: the line a villager says about the newest deed ({player} left for the caller), or "" when there is no
## fresh news, it happened far away, `npc` is not a villager here, or the kind has no lines. Pure.
static func news_line(npc: CharacterData, flags: Dictionary, data: GameData, region_id: String, day: int, named: bool = false) -> String:
	var news: Variant = flags.get("village_news")
	if not (news is Dictionary) or region_id == "":
		return ""
	var bands: Dictionary = data.family.get("folk_greetings", {}).get("news", {})
	if bands.is_empty() or day - int(news.get("day", -9999)) >= int(bands.get("news_days", 7)) or day < int(news.get("day", 0)):
		return ""
	var where := String(news.get("region", ""))
	if where != region_id and not Exploration.is_nearby(data, where, region_id):
		return ""
	if named:  # FOLK-019: a named NPC with a dialogue file hears the news too
		if npc == null or not npc.alive or Npcs.region_of(npc, data) != region_id:
			return ""
	elif not is_villager(npc, data, Npcs.region_of(npc, data)):
		return ""
	var lines: Array = bands.get(String(news.get("kind", "")), [])
	if lines.is_empty():
		return ""
	return String(lines[absi(hash(npc.id + str(day))) % lines.size()]).replace("{subject}", String(news.get("subject", ""))).replace("{project}", String(news.get("subject", ""))).replace("{beast}", String(news.get("subject", "")))


## Load errors in folk_greetings: both bands, non-empty string lines, min_favor above max_favor.
static func validate_greetings(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var bands: Dictionary = data.family.get("folk_greetings", {})
	if bands.is_empty():
		return errors
	var party: Variant = bands.get("celebration", {})
	if not (party is Dictionary):
		errors.append("family.json folk_greetings.celebration must be an object")
	else:
		for kind: String in party:
			var plines: Variant = party[kind]
			if not (plines is Array) or plines.is_empty():
				errors.append("family.json folk_greetings.celebration.%s: lines must be a non-empty array" % kind)
				continue
			for line: Variant in plines:
				if not (line is String) or String(line) == "":
					errors.append("family.json folk_greetings.celebration.%s: lines must be non-empty strings" % kind)
	var tidings: Variant = bands.get("news", {})
	if not (tidings is Dictionary):
		errors.append("family.json folk_greetings.news must be an object")
	else:
		for kind: String in tidings:
			if kind == "news_days":
				if not (tidings[kind] is int or tidings[kind] is float) or int(tidings[kind]) < 1 or int(tidings[kind]) > 30:
					errors.append("family.json folk_greetings.news.news_days must be 1..30")
			elif not NEWS_KINDS.has(kind):
				errors.append("family.json folk_greetings.news: unknown kind %s" % kind)
			elif not (tidings[kind] is Array) or tidings[kind].is_empty() or not (tidings[kind] as Array).all(func(v: Variant) -> bool: return v is String and String(v) != ""):
				errors.append("family.json folk_greetings.news.%s: lines must be a non-empty array of strings" % kind)
	var cake: Variant = bands.get("birthday", [])
	if not (cake is Array) or not (cake as Array).all(func(v: Variant) -> bool: return v is String and String(v) != ""):
		errors.append("family.json folk_greetings.birthday must be an array of non-empty strings")
	var mine: Variant = bands.get("player_birthday", [])
	if not (mine is Array) or not (mine as Array).all(func(v: Variant) -> bool: return v is String and String(v) != "" and String(v).length() <= 160):
		errors.append("family.json folk_greetings.player_birthday must be an array of 1..160 character strings")
	var pgift: Variant = data.family.get("player_birthday_gift", "")
	if not (pgift is String) or (String(pgift) != "" and not data.items.has(String(pgift))):
		errors.append("family.json player_birthday_gift must be an items.json id")
	var home_lines: Variant = data.family.get("birthday_home_lines", [])
	if not (home_lines is Array) or not (home_lines as Array).all(func(x: Variant) -> bool: return x is String and String(x) != "" and String(x).length() <= 160):
		errors.append("family.json birthday_home_lines must be an array of 1..160 character strings")
	var thanks: Variant = bands.get("birthday_thanks", [])
	if not (thanks is Array) or not (thanks as Array).all(func(v: Variant) -> bool: return v is String and String(v) != ""):
		errors.append("family.json folk_greetings.birthday_thanks must be an array of non-empty strings")
	var skies: Variant = bands.get("weather", {})
	if not (skies is Dictionary):
		errors.append("family.json folk_greetings.weather must be an object")
	else:
		for kind: String in skies:
			var wlines: Variant = skies[kind]
			if not (wlines is Array) or wlines.is_empty() or not (wlines as Array).all(func(v: Variant) -> bool: return v is String and String(v) != ""):
				errors.append("family.json folk_greetings.weather.%s: lines must be a non-empty array of strings" % kind)
	for key: String in ["warm", "cool"]:
		var band: Variant = bands.get(key)
		if not (band is Dictionary):
			errors.append("family.json folk_greetings: missing band %s" % key)
			continue
		var lines: Variant = band.get("lines")
		if not (lines is Array) or lines.is_empty():
			errors.append("family.json folk_greetings.%s: lines must be a non-empty array" % key)
		else:
			for line: Variant in lines:
				if not (line is String) or String(line) == "":
					errors.append("family.json folk_greetings.%s: lines must be non-empty strings" % key)
		if not band.has("min_favor" if key == "warm" else "max_favor"):
			errors.append("family.json folk_greetings.%s: needs %s" % [key, "min_favor" if key == "warm" else "max_favor"])
	if errors.is_empty() and int(bands["warm"]["min_favor"]) <= int(bands["cool"]["max_favor"]):
		errors.append("family.json folk_greetings: warm min_favor must be above cool max_favor")
	return errors


## FOLK-002: the gift `npc` presses on the player today, {item, count, text} (text has {villager}/{item}/{count}
## filled), or {} when favor is below min_favor, the cooldown since their last gift (`c.folk_gift_day`) has not
## passed, or no gifts are defined. The pick is a hash of npc id + day, weighted by `weight`; no rng.
static func gift(c: CharacterData, npc: CharacterData, favor: int, day: int, data: GameData) -> Dictionary:
	var rules: Dictionary = data.family.get("folk_gifts", {})
	var gifts: Array = rules.get("gifts", [])
	if gifts.is_empty() or favor < int(rules.get("min_favor", 40)):
		return {}
	if c.folk_gift_day.has(npc.id) and day - int(c.folk_gift_day[npc.id]) < int(rules.get("cooldown_days", 45)):
		return {}
	var total := 0
	for g: Dictionary in gifts:
		total += int(g.get("weight", 1))
	var pick := absi(hash(npc.id + "|gift|" + str(day))) % maxi(total, 1)
	for g: Dictionary in gifts:
		pick -= int(g.get("weight", 1))
		if pick < 0:
			var count := int(g.get("count", 1))
			var item := String(g["item"])
			var text := String(g["text"]).replace(VILLAGER, npc.name).replace("{count}", str(count))
			text = text.replace("{item}", Items.item_plural(data, item, count))
			return {"item": item, "count": count, "text": text}
	return {}


## Load errors in family.json folk_gifts: ints, a non-empty gift list of known items with positive weight and count.
static func validate_gifts(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var rules: Dictionary = data.family.get("folk_gifts", {})
	if rules.is_empty():
		return errors
	if absi(int(rules.get("min_favor", 0))) > 100 or int(rules.get("cooldown_days", 0)) < 1:
		errors.append("family.json folk_gifts needs min_favor -100..100 and cooldown_days >= 1")
	if not (rules.get("gifts") is Array) or rules["gifts"].is_empty():
		errors.append("family.json folk_gifts.gifts must be a non-empty list")
		return errors
	for i in rules["gifts"].size():
		var g: Dictionary = rules["gifts"][i]
		var where := "family.json folk_gifts gift %d" % i
		if not data.items.is_empty() and not data.items.has(String(g.get("item", ""))):
			errors.append("%s names unknown item %s" % [where, g.get("item", "?")])
		if int(g.get("count", 0)) < 1 or int(g.get("weight", 0)) < 1:
			errors.append("%s needs count >= 1 and weight >= 1" % where)
		var text := String(g.get("text", ""))
		for token: String in [VILLAGER, "{item}"]:
			if not text.contains(token):
				errors.append("%s text needs %s" % [where, token])
	return errors


## FOLK-007: friendship tiers (family.json folk_tiers, ascending `min` favor). Index -1 = below the first tier.
static func tier_index(data: GameData, favor: int) -> int:
	var tiers: Array = data.family.get("folk_tiers", [])
	var found := -1
	for i in tiers.size():
		if favor >= int(tiers[i]["min"]):
			found = i
	return found


static func tier_name(data: GameData, favor: int) -> String:
	var i := tier_index(data, favor)
	return "" if i < 0 else String(data.family["folk_tiers"][i]["name"])


## WU-418: "Friends: A, B (+N more)" for the generated villagers of `region_id` at friendship tier >= 0, highest tier
## first then name, at most 3 names. "" when there are none. Pure.
static func friends_line(npcs: Dictionary, data: GameData, region_id: String, favor: Dictionary) -> String:
	var found: Array[Dictionary] = []
	for c in Npcs.generated_in_region(npcs, data, region_id):
		var t := tier_index(data, int(favor.get(c.id, 0)))
		if t >= 0:
			found.append({"name": c.name, "tier": t})
	if found.is_empty():
		return ""
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["tier"] != b["tier"]:
			return int(a["tier"]) > int(b["tier"])
		return String(a["name"]) < String(b["name"]))
	var names: PackedStringArray = []
	for i in mini(found.size(), 3):
		names.append(String(found[i]["name"]))
	var line := "Friends: " + ", ".join(names)
	if found.size() > 3:
		line += " (+%d more)" % (found.size() - 3)
	return line


## FOLK-009: the people page. Every living NPC of `region_id` (generated villagers and named story NPCs) with favor >= 10,
## favor desc then name. Entry: {id, name, favor, tier_index, tier_name, birthday_text, birthday_in, likes_known,
## dislikes_known, likes_total, last_gift}. Tastes come from the `taste_<npc>_<item>` world flags a gift leaves. Pure.
static func people_entries(npcs: Dictionary, data: GameData, region_id: String, favor: Dictionary, flags: Dictionary, today: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in Npcs.in_region(npcs, data, region_id):
		var f := int(favor.get(c.id, 0))
		if f < 10:
			continue
		var b := birthday_day(c, data)
		var likes: Array[String] = []
		var dislikes: Array[String] = []
		var tastes := Family.known_tastes(flags, data, c.id)  # real item ids only, so "li" never reads "li_wei"'s flags
		for item_id: String in tastes:
			if int(tastes[item_id]) > 0:
				likes.append(item_id)
			else:
				dislikes.append(item_id)
		likes.sort()
		dislikes.sort()
		out.append({"id": c.id, "name": c.name, "favor": f, "tier_index": tier_index(data, f), "tier_name": tier_name(data, f),
			"birthday_text": "" if b < 0 else "Month %d, Day %d" % [Calendar.month_of(b), Calendar.day_of(b)],
			"birthday_in": days_to_birthday(c, data, today), "likes_known": likes, "dislikes_known": dislikes,
			"likes_total": (Family.taste_lists(data, c.id)["likes"] as Array).size(),
			"last_gift": last_gift_text(flags, c.id, data)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["favor"] != b["favor"]:
			return int(a["favor"]) > int(b["favor"])
		return String(a["name"]) < String(b["name"]))
	return out


## "a friend", "an acquaintance": the tier name for the Look sentence. "" below the first tier.
static func counts_you_line(data: GameData, npc_name: String, favor: int) -> String:
	var tier := tier_name(data, favor).to_lower()
	if tier == "":
		return ""
	return "%s counts you %s %s." % [npc_name, "an" if "aeiou".contains(tier.substr(0, 1)) else "a", tier]


## Villagers in `ids` whose tier rose above what `seen` records: [{id, tier}], the highest new tier only. Pure.
static func new_tiers(data: GameData, seen: Dictionary, favor_by_id: Dictionary, ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ids:
		var t := tier_index(data, int(favor_by_id.get(id, 0)))
		if t > int(seen.get(id, -1)):
			result.append({"id": id, "tier": t})
	return result


## WU-486: the emote a gift draws: "love" (liked, or any non-disliked gift on their birthday), "happy" (neutral),
## "sweat" (disliked). `taste` is the gift's taste (-1 disliked, 0 neutral, 1 liked). Pure.
static func gift_reaction(taste: int, birthday: bool) -> String:
	if taste < 0:
		return "sweat"
	if taste > 0 or birthday:
		return "love"
	return "happy"


## FOLK-020: the lessons a named villager teaches (npcs.json `lessons`), [] when none. Pure.
static func lessons_of(data: GameData, npc_id: String) -> Array:
	var raw: Variant = data.npcs.get(npc_id, {}).get("lessons", [])
	return raw if raw is Array else []


## FOLK-020: lessons with tier <= `tier` not yet in `taught` ("<npc_id>:<index>" -> day): [{key, index, lesson}]. Pure.
static func due_lessons(data: GameData, npc_id: String, tier: int, taught: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lessons := lessons_of(data, npc_id)
	for i in lessons.size():
		var key := "%s:%d" % [npc_id, i]
		if int(lessons[i].get("tier", 99)) <= tier and not taught.has(key):
			result.append({"key": key, "index": i, "lesson": lessons[i]})
	return result


## GUIDE-219: true when `npc_id` already taught a lesson on `day` (one lesson a day per teacher).
static func taught_today(npc_id: String, taught: Dictionary, day: int) -> bool:
	for key: String in taught:
		if key.begins_with(npc_id + ":") and int(taught[key]) == day:
			return true
	return false


## GUIDE-218: named villagers of `region_id` with a lesson due at their friendship tier, as [{npc, key}] by name.
static func lessons_waiting(npcs: Dictionary, data: GameData, region_id: String, favor: Dictionary, taught: Dictionary, day: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc in Npcs.in_region(npcs, data, region_id):
		if not data.npcs.has(npc.id) or (day >= 0 and taught_today(npc.id, taught, day)):
			continue
		var due := due_lessons(data, npc.id, tier_index(data, int(favor.get(npc.id, 0))), taught)
		if not due.is_empty():
			out.append({"npc": npc, "key": String(due[0]["key"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["npc"].name) < String(b["npc"].name))
	return out


## GUIDE-218: where named villager `npc_id` stands today in words: the nearest place on their region map (within 200 px)
## by display name, else the region's name. "" for a generated villager.
static func stand_phrase(data: GameData, npc_id: String, day: int, events: Array) -> String:
	var def: Dictionary = data.npcs.get(npc_id, {})
	if def.is_empty():
		return ""
	var region_id := String(def.get("region", ""))
	var spot := spot_for(data, def, day, Weather.of(data, region_id, day), events)
	var best := ""
	var best_d := 200.0
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.has("festival_only") or not place.has("pos"):
			continue
		var d: float = _point(place["pos"]).distance_to(spot["pos"])
		if d < best_d:
			best_d = d
			best = String(place.get("display_name", ""))
	return best if best != "" else Exploration.region_name(data, region_id)


static func lesson_line(lesson: Dictionary, npc_name: String, player_name: String) -> String:
	return String(lesson.get("text", "")).replace("{name}", npc_name).replace("{player}", player_name)


const LESSON_EFFECT_KEYS: Array[String] = ["learn_recipe", "learn_dish", "learn_technique", "profession_xp", "attributes", "dao_insight", "practice_days", "items"]


## FOLK-020: load errors in npcs.json lessons.
static func validate_lessons(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var tier_count: int = data.family.get("folk_tiers", []).size()
	for npc_id: String in data.npcs:
		var lessons := lessons_of(data, npc_id)
		if lessons.size() > 2:
			errors.append("npc %s: at most 2 lessons" % npc_id)
		var last := 0
		for i in lessons.size():
			var l: Dictionary = lessons[i]
			var where := "npc %s lesson %d" % [npc_id, i]
			var t := int(l.get("tier", 0))
			if t < 1 or t >= tier_count:
				errors.append("%s: tier must be 1..%d" % [where, tier_count - 1])
			if t <= last:
				errors.append("%s: tiers must rise strictly" % where)
			last = t
			var text := String(l.get("text", ""))
			if text.is_empty() or text.length() > 220:
				errors.append("%s: text must be 1..220 characters" % where)
			var fx: Variant = l.get("effects", {})
			if not (fx is Dictionary) or fx.is_empty():
				errors.append("%s: effects must be a non-empty Dictionary" % where)
				continue
			for key: Variant in fx:
				if not LESSON_EFFECT_KEYS.has(String(key)):
					errors.append("%s: effect '%s' is not allowed in a lesson" % [where, key])
			if fx.has("attributes"):
				for v: Variant in fx["attributes"].values():
					if int(v) < 1 or int(v) > 2:
						errors.append("%s: attributes values must be 1..2" % where)
			if fx.has("practice_days") and (int(fx["practice_days"]) < 1 or int(fx["practice_days"]) > 10):
				errors.append("%s: practice_days must be 1..10" % where)
			errors.append_array(Effects.validate(data, fx, where))
	return errors


## Load errors in folk_tiers: strictly rising mins 1..100, names, known gift items with count 1..3.
static func validate_tiers(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var tiers: Array = data.family.get("folk_tiers", [])
	var last := 0
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var where := "family.json folk_tiers %d" % i
		var m := int(t.get("min", 0))
		if m <= last or m > 100:
			errors.append("%s: min must rise strictly within 1..100" % where)
		last = m
		if String(t.get("name", "")).is_empty():
			errors.append("%s needs a name" % where)
		if t.has("gift"):
			var g: Dictionary = t["gift"]
			if not data.items.is_empty() and not data.items.has(String(g.get("item", ""))):
				errors.append("%s gift names unknown item %s" % [where, g.get("item", "?")])
			if int(g.get("count", 0)) < 1 or int(g.get("count", 0)) > 3:
				errors.append("%s gift count must be 1..3" % where)
	return errors


## Load errors in folk_tastes: pools are arrays of non-empty strings, counts ints >= 0 and within the pool size.
static func validate_tastes(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var t: Dictionary = data.family.get("folk_tastes", {})
	for key in ["likes", "dislikes"]:
		var pool: Array = t.get(key + "_pool", [])
		for e in pool:
			if typeof(e) != TYPE_STRING or String(e).is_empty():
				errors.append("family.json folk_tastes %s_pool entries must be non-empty strings" % key)
		if t.has(key) and (int(t[key]) < 0 or int(t[key]) > pool.size()):
			errors.append("family.json folk_tastes %s must be 0..%d" % [key, pool.size()])
	var company: Variant = data.family.get("festival_company", [])
	if not (company is Array):
		errors.append("family.json festival_company must be a list")
	else:
		for line in company:
			if typeof(line) != TYPE_STRING or not String(line).contains("{name}"):
				errors.append("family.json festival_company lines must be strings with {name}")
	return errors


static func request_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_requests", {})


## FOLK-001: this month's favour a villager of `region_id` asks of the player, stored as a letter request with
## source "folk" and returned ({} when nobody asks). The chance is rolled first, so a closed door costs one draw.
static func monthly_request(c: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String, favor: Dictionary, today: int) -> Dictionary:
	var r := request_rules(data)
	if r.is_empty() or rng.randf() >= float(r.get("monthly_chance", 0.0)):
		return {}
	var open := 0
	for req: Dictionary in c.letter_requests:
		if String(req.get("source", "letter")) == "folk" and int(req["until"]) >= today:
			open += 1
	if open >= int(r.get("max_open", 1)):
		return {}
	var min_favor := int(r.get("min_favor", 0))
	var villagers: Array[CharacterData] = []
	for npc in candidates(npcs, data, c, region_id):
		if int(favor.get(npc.id, 0)) >= min_favor and Letters.open_request(c, npc.id, today).is_empty():
			villagers.append(npc)
	var season := Calendar.season_of(today).to_lower()
	var asks: Array[Dictionary] = []
	for ask: Dictionary in r.get("asks", []):
		if ask.has("regions") and not (ask["regions"] as Array).has(region_id):
			continue
		if ask.has("seasons") and not (ask["seasons"] as Array).has(season):
			continue
		asks.append(ask)
	if villagers.is_empty() or asks.is_empty():
		return {}
	villagers.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.id < b.id)
	var npc: CharacterData = villagers[rng.randi_range(0, villagers.size() - 1)]
	var ask: Dictionary = asks[rng.randi_range(0, asks.size() - 1)]
	var count := rng.randi_range(int(ask["count"][0]), int(ask["count"][1]))
	var stones := rng.randi_range(int(ask["stones"][0]), int(ask["stones"][1]))
	var text := String(ask["text"]).replace(VILLAGER, npc.name).replace("{count}", str(count)).replace("{item}", Items.item_plural(data, String(ask["item"]), count))
	var entry := {"npc_id": npc.id, "item": String(ask["item"]), "count": count, "until": today + int(r.get("days", 20)),
		"favor": int(ask["favor"]), "effects": {"items": {"spirit_stone": stones}} if stones > 0 else {}, "source": "folk", "text": text}
	c.letter_requests.append(entry)
	return entry


static func validate_requests(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := request_rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("monthly_chance", 0.0))
	if chance < 0.0 or chance > 1.0 or absi(int(r.get("min_favor", 0))) > 100 or int(r.get("days", 0)) < 1 or int(r.get("max_open", 0)) < 1:
		errors.append("family.json folk_requests needs monthly_chance 0..1, min_favor -100..100, days >= 1, max_open >= 1")
	if not (r.get("asks") is Array) or r["asks"].is_empty():
		errors.append("family.json folk_requests.asks must be a non-empty list")
		return errors
	for i in r["asks"].size():
		var ask: Dictionary = r["asks"][i]
		var where := "family.json folk_requests ask %d" % i
		if not data.items.is_empty() and not data.items.has(String(ask.get("item", ""))):
			errors.append("%s names unknown item %s" % [where, ask.get("item", "?")])
		for key: String in ["count", "stones"]:
			var range_v: Variant = ask.get(key)
			var low := 1 if key == "count" else 0
			if not (range_v is Array) or range_v.size() != 2 or int(range_v[0]) < low or int(range_v[0]) > int(range_v[1]):
				errors.append("%s %s must be [min, max] with %d <= min <= max" % [where, key, low])
		if int(ask.get("favor", 0)) < 1 or int(ask.get("favor", 0)) > 15:
			errors.append("%s favor must be 1..15" % where)
		var text := String(ask.get("text", ""))
		for token: String in [VILLAGER, "{count}", "{item}"]:
			if not text.contains(token):
				errors.append("%s text needs %s" % [where, token])
		for key: String in ["regions", "seasons"]:
			if ask.has(key) and (not (ask[key] is Array) or ask[key].is_empty()):
				errors.append("%s %s must be a non-empty list" % [where, key])
		for region_id: String in ask.get("regions", []):
			if not data.regions.is_empty() and not data.regions.has(region_id):
				errors.append("%s names unknown region %s" % [where, region_id])
	return errors


## Load errors: favor effects are ints within +-FAVOR_LIMIT and need their placeholder in the encounter's texts.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = validate_greetings(data)
	errors.append_array(validate_festival_lines(data))
	errors.append_array(validate_festival_memory(data))
	errors.append_array(validate_player_birthday_gifts(data))
	errors.append_array(validate_taught_dish_line(data))
	errors.append_array(validate_gift_memory(data))
	errors.append_array(validate_requests(data))
	errors.append_array(validate_celebrations(data))
	errors.append_array(validate_tips(data))
	errors.append_array(validate_visits(data))
	errors.append_array(validate_companions(data))
	errors.append_array(validate_quarrels(data))
	errors.append_array(validate_gifts(data))
	errors.append_array(validate_tiers(data))
	errors.append_array(validate_tastes(data))
	for e: Dictionary in data.encounters.values():
		var blocks: Array = [[String(e["id"]), e.get("effects", {})]]
		for i in e.get("choices", []).size():
			var choice: Dictionary = e["choices"][i]
			blocks.append(["%s choice %d" % [e["id"], i], choice.get("effects", {})])
			if choice.has("on_fail"):
				blocks.append(["%s choice %d on_fail" % [e["id"], i], choice["on_fail"].get("effects", {})])
		var joined := " ".join(texts(e))
		for block: Array in blocks:
			for pair: Array in [["villager_favor", VILLAGER], ["elder_favor", ELDER]]:
				if not block[1].has(pair[0]):
					continue
				var v: Variant = block[1][pair[0]]
				if not (v is int or (v is float and v == floorf(v))) or absi(int(v)) > FAVOR_LIMIT or int(v) == 0:
					errors.append("%s: %s must be a non-zero int within +-%d" % [block[0], pair[0], FAVOR_LIMIT])
				if not joined.contains(pair[1]):
					errors.append("%s: %s needs %s in the encounter's text" % [block[0], pair[0], pair[1]])
	return errors


# --- WORLD-005 / WORLD-006: village weddings, full-month feasts and funerals you can attend --------

const CELEBRATION_PREFIX := "celebration_"
const ATTENDED_PREFIX := "celebration_attended_"
const GIFT_PREFIX := "celebration_gift_"
const KIND_PREFIX := "celebration_kind_"
const WEDDING := "wedding"
## Keys of a celebration type (the top-level family.json `celebrations` keys are the wedding type).
const CELEBRATION_KEYS: PackedStringArray = ["days", "attend_days", "favor", "alignment", "gift_mult", "label", "news", "attend_text"]


## The rules of celebration type `kind`: the top-level keys are the wedding, `types` holds the others
## (a `types.wedding` entry overrides the top level). {} for an unknown type.
static func celebration_rules(data: GameData, kind: String = WEDDING) -> Dictionary:
	var all: Dictionary = data.family.get("celebrations", {})
	var types: Dictionary = all.get("types", {})
	if kind != WEDDING:
		return types.get(kind, {})
	var rules := {}
	for key in CELEBRATION_KEYS:
		if all.has(key):
			rules[key] = all[key]
	rules.merge(types.get(WEDDING, {}), true)
	return rules


## C-274: the news line of a `kind` celebration on day `today`: a `news` array is picked by today % size, a single string is used as is.
static func celebration_news(data: GameData, kind: String, today: int) -> String:
	var news: Variant = celebration_rules(data, kind).get("news", "{text}")
	if news is Array and not (news as Array).is_empty():
		return String(news[posmod(today, (news as Array).size())])
	return String(news)


## Opens a `kind` celebration for each of `ids` until day `today` + the type's days.
static func start_celebration(flags: Dictionary, ids: Array, today: int, data: GameData, kind: String = WEDDING) -> void:
	var days := int(celebration_rules(data, kind).get("days", 0))
	if days <= 0:
		return
	for id: Variant in ids:
		flags[CELEBRATION_PREFIX + String(id)] = today + days
		flags[KIND_PREFIX + String(id)] = kind


## Whether a celebration for `npc_id` is still open on day `today`.
static func celebration_open(flags: Dictionary, npc_id: String, today: int) -> bool:
	return flags.has(CELEBRATION_PREFIX + npc_id) and today <= int(flags[CELEBRATION_PREFIX + npc_id])


## The type of `npc_id`'s celebration (a missing kind flag, as in older saves, is a wedding).
static func celebration_kind(flags: Dictionary, npc_id: String) -> String:
	return String(flags.get(KIND_PREFIX + npc_id, WEDDING))


## The menu label of `npc_id`'s celebration, with its days: "Attend the wedding (1 day)".
static func celebration_label(flags: Dictionary, npc_id: String, data: GameData) -> String:
	var r := celebration_rules(data, celebration_kind(flags, npc_id))
	return "%s (%s)" % [r.get("label", "Attend the celebration"), Calendar.format_duration(int(r.get("attend_days", 1)))]


## GFX-023: which of `ids` have a celebration open on day `today`: {npc_id: kind}.
static func celebrants(flags: Dictionary, ids: Array, today: int) -> Dictionary:
	var out := {}
	for id in ids:
		if celebration_open(flags, String(id), today):
			out[String(id)] = celebration_kind(flags, String(id))
	return out


## GFX-023: the sash colour a villager wears during a celebration: red at a wedding, grey-white at a funeral.
static func celebration_sash(kind: String) -> Color:
	return Color("e8e4dc") if kind == "funeral" else Color("d02828")


## GFX-023: the lantern colour strung for a celebration of `kind`.
static func celebration_lantern(kind: String) -> Color:
	return Color("f4f0e6") if kind == "funeral" else Color("e03030")


## Whether `key` is a celebration end-day flag (not an attended / gift / kind mark).
static func _is_end_key(key: String) -> bool:
	return key.begins_with(CELEBRATION_PREFIX) and not key.begins_with(ATTENDED_PREFIX) and not key.begins_with(GIFT_PREFIX) and not key.begins_with(KIND_PREFIX)


## Removes celebrations (and their attended / gift / kind marks) that ended before `today`.
static func expire_celebrations(flags: Dictionary, today: int) -> void:
	for key: String in flags.keys():
		if _is_end_key(key) and int(flags[key]) < today:
			var id := key.trim_prefix(CELEBRATION_PREFIX)
			flags.erase(key)
			flags.erase(ATTENDED_PREFIX + id)
			flags.erase(GIFT_PREFIX + id)
			flags.erase(KIND_PREFIX + id)


## Why the player cannot attend `npc_id`'s celebration ("" when they can).
static func check_attend(flags: Dictionary, npc_id: String, today: int) -> String:
	var wedding := celebration_kind(flags, npc_id) == WEDDING
	if not celebration_open(flags, npc_id, today):
		return "There is no wedding to attend." if wedding else "There is nothing to attend."
	if flags.has(ATTENDED_PREFIX + npc_id):
		return "You have already attended this wedding." if wedding else "You have already paid your respects."
	return ""


## Attending: {ok, reason, favor, alignment, days, text}. Marks it attended for `npc_id` and `partner_id`.
static func attend(flags: Dictionary, npc_id: String, partner_id: String, today: int, data: GameData) -> Dictionary:
	var reason := check_attend(flags, npc_id, today)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "alignment": 0, "days": 0, "text": ""}
	flags[ATTENDED_PREFIX + npc_id] = true
	if partner_id != "":
		flags[ATTENDED_PREFIX + partner_id] = true
	var r := celebration_rules(data, celebration_kind(flags, npc_id))
	return {"ok": true, "reason": "", "favor": int(r.get("favor", 0)), "alignment": int(r.get("alignment", 0)), "days": int(r.get("attend_days", 1)), "text": String(r.get("attend_text", ""))}


## FOLK-008: the day of the year (0..DAYS_PER_YEAR-1) of a generated villager's birthday: a stable hash of the id, never rng.
## Named story NPCs have none (-1).
static func birthday_day(npc: CharacterData, data: GameData) -> int:
	if npc == null:
		return -1
	if data.npcs.has(npc.id):  # FOLK-022: a named NPC has a birthday only when npcs.json gives one
		var bd: Variant = data.npcs[npc.id].get("birthday", null)
		if bd is Dictionary:
			return (int(bd["month"]) - 1) * Calendar.DAYS_PER_MONTH + int(bd["day"]) - 1
		return -1
	return absi(hash("birthday:" + npc.id)) % Calendar.DAYS_PER_YEAR


static func birthday_today(npc: CharacterData, data: GameData, day: int) -> bool:
	var b := birthday_day(npc, data)
	return b >= 0 and day >= 0 and day % Calendar.DAYS_PER_YEAR == b


## Days from `day` until the villager's next birthday (0 = today, wraps over the year); -1 for no birthday.
static func days_to_birthday(npc: CharacterData, data: GameData, day: int) -> int:
	var b := birthday_day(npc, data)
	if b < 0:
		return -1
	return posmod(b - day, Calendar.DAYS_PER_YEAR)


## WU-482: true when it is `npc`'s birthday on `day` and you know them (favor >= min_favor), so the world marks it. Pure.
static func is_birthday_today(npc: CharacterData, data: GameData, day: int, favor: Dictionary, min_favor: int = 10) -> bool:
	return npc != null and int(favor.get(npc.id, 0)) >= min_favor and birthday_today(npc, data, day)


## FOLK-008: living generated villagers of `region_id` you know (favor >= min_favor) whose birthday falls within
## `span` days of `day`, as [{npc, in_days}] soonest first (ties by id). Pure.
static func birthdays_soon(npcs: Dictionary, data: GameData, region_id: String, day: int, favor: Dictionary, span: int = 7, min_favor: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc in Npcs.in_region(npcs, data, region_id):
		if int(favor.get(npc.id, 0)) < min_favor:
			continue
		var n := days_to_birthday(npc, data, day)
		if n >= 0 and n <= span:
			out.append({"npc": npc, "in_days": n})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["in_days"] != b["in_days"]:
			return a["in_days"] < b["in_days"]
		return String(a["npc"].id) < String(b["npc"].id))
	return out


const BIRTHDAY_GIFT_PREFIX := "birthday_gift_"
const PLAYER_BIRTHDAY_PREFIX := "player_birthday_"
const PLAYER_BIRTHDAY_FAVOR := 2


## FOLK-027: the player's birthday as a day of the year; a missing one (old saves) hashes the name, never rng.
static func player_birthday_day(c: CharacterData) -> int:
	if c.birthday >= 0:
		return c.birthday % Calendar.DAYS_PER_YEAR
	return absi(hash("birthday:" + c.name)) % Calendar.DAYS_PER_YEAR


static func player_birthday_today(c: CharacterData, _data: GameData, day: int) -> bool:
	return day >= 0 and day % Calendar.DAYS_PER_YEAR == player_birthday_day(c)


## FOLK-027: "Month M, Day D" for the character sheet.
static func player_birthday_text(c: CharacterData) -> String:
	var b := player_birthday_day(c)
	return "Month %d, Day %d" % [Calendar.month_of(b), Calendar.day_of(b)]


## FOLK-027: on the player's birthday the first chat with each villager you know (favor reaches the first tier) says a
## line from family.json folk_greetings.player_birthday, once per villager per year. The villager's own birthday wins.
## `consume` marks it told. Returns "" when nothing is said.
static func player_birthday_line(npc: CharacterData, c: CharacterData, data: GameData, day: int, favor: int, flags: Dictionary, consume: bool) -> String:
	if npc == null or not player_birthday_today(c, data, day) or birthday_today(npc, data, day) or tier_index(data, favor) < 0:
		return ""
	var own := String(data.npcs.get(npc.id, {}).get("player_birthday_line", ""))  # FOLK-029
	var pool: Array = data.family.get("folk_greetings", {}).get("player_birthday", [])
	var year := Calendar.year_of(day)
	if (own == "" and pool.is_empty()) or int(flags.get(PLAYER_BIRTHDAY_PREFIX + npc.id, -1)) == year:
		return ""
	if consume:
		flags[PLAYER_BIRTHDAY_PREFIX + npc.id] = year
	if own != "":
		return own.replace("{player}", c.name)
	return String(pool[absi(hash(npc.id + str(day))) % pool.size()]).replace("{player}", c.name)


## FOLK-027: the dish family gives on the player's birthday (family.json player_birthday_gift), once per year, to a
## player who has a spouse or child. Returns the item id or "". `consume` marks the year.
static func player_birthday_gift(c: CharacterData, data: GameData, day: int, flags: Dictionary, consume: bool) -> String:
	var item := String(data.family.get("player_birthday_gift", ""))
	if item == "" or not player_birthday_today(c, data, day) or (c.spouses.is_empty() and c.children.is_empty()):
		return ""
	var year := Calendar.year_of(day)
	if int(flags.get(PLAYER_BIRTHDAY_PREFIX + "family", -1)) == year:
		return ""
	if consume:
		flags[PLAYER_BIRTHDAY_PREFIX + "family"] = year
	return item


## FOLK-028: the line posted when family sets out the birthday dish at home (family.json birthday_home_lines,
## {name}/{dish}), picked by day. "" when the file has none.
static func birthday_home_line(data: GameData, name: String, dish_name: String, day: int) -> String:
	var pool: Array = data.family.get("birthday_home_lines", [])
	if pool.is_empty():
		return ""
	return String(pool[absi(day) % pool.size()]).replace("{name}", name).replace("{dish}", dish_name)


## FOLK-028: a player without family who has 2+ Close friends (tier 2 and up) gets one small gift on their birthday,
## once a year (world flag player_birthday_friend). Returns {npc_id, item} or {}. The friend is the closest (then by id)
## whose first liked item id is cheap (price <= FRIEND_GIFT_MAX_PRICE). `consume` marks the year.
const FRIEND_GIFT_MAX_PRICE := 20
const CLOSE_FRIEND_TIER := 2

static func birthday_friend_gift(c: CharacterData, people: Dictionary, favor: Dictionary, data: GameData, day: int, flags: Dictionary, consume: bool) -> Dictionary:
	if not player_birthday_today(c, data, day) or not (c.spouses.is_empty() and c.children.is_empty()):
		return {}
	var year := Calendar.year_of(day)
	if int(flags.get(PLAYER_BIRTHDAY_PREFIX + "friend", -1)) == year:
		return {}
	var close: Array[String] = []
	for id: String in people:
		var npc: CharacterData = people[id]
		if npc != null and npc.alive and tier_index(data, int(favor.get(id, 0))) >= CLOSE_FRIEND_TIER:
			close.append(id)
	if close.size() < 2:
		return {}
	close.sort_custom(func(a: String, b: String) -> bool:
		var fa := int(favor.get(a, 0))
		var fb := int(favor.get(b, 0))
		return fa > fb if fa != fb else a < b)
	for id in close:
		for entry: Variant in Family.taste_lists(data, id)["likes"]:
			if data.items.has(String(entry)) and int(data.items[String(entry)].get("price", 999)) <= FRIEND_GIFT_MAX_PRICE:
				if consume:
					flags[PLAYER_BIRTHDAY_PREFIX + "friend"] = year
				return {"npc_id": id, "item": String(entry)}
	return {}


## FOLK-008: 2 for the first gift to `npc` on their birthday this year, else 1. `consume` marks it used.
static func birthday_gift_multiplier(flags: Dictionary, npc: CharacterData, data: GameData, day: int, consume: bool) -> int:
	if not birthday_today(npc, data, day):
		return 1
	var year := day / Calendar.DAYS_PER_YEAR
	if int(flags.get(BIRTHDAY_GIFT_PREFIX + npc.id, -1)) == year:
		return 1
	if consume:
		flags[BIRTHDAY_GIFT_PREFIX + npc.id] = year
	return 2


## The multiplier for a gift to `npc_id` now: the type's gift_mult once per open celebration, else 1. `consume` marks it used.
static func gift_multiplier(flags: Dictionary, npc_id: String, today: int, data: GameData, consume: bool) -> int:
	if not celebration_open(flags, npc_id, today) or flags.has(GIFT_PREFIX + npc_id):
		return 1
	if consume:
		flags[GIFT_PREFIX + npc_id] = true
	return maxi(1, int(celebration_rules(data, celebration_kind(flags, npc_id)).get("gift_mult", 1)))


## The living relatives (spouses, parents, children) of `dead` who live in `region_id`, minus the player's own family.
static func mourners(npcs: Dictionary, data: GameData, dead: CharacterData, region_id: String, player: CharacterData) -> Array[String]:
	var out: Array[String] = []
	for group: Array in [dead.spouses, dead.parents, dead.children]:
		for id: Variant in group:
			var sid := String(id)
			if out.has(sid) or not npcs.has(sid) or _is_player_family(player, sid):
				continue
			var rel: CharacterData = npcs[sid]
			if rel.alive and Npcs.region_of(rel, data) == region_id:
				out.append(sid)
	return out


static func _is_player_family(player: CharacterData, id: String) -> bool:
	return player.spouses.has(id) or player.children.has(id) or player.parents.has(id)


static func validate_celebrations(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var all: Dictionary = data.family.get("celebrations", {})
	if all.is_empty():
		return errors
	var types: Dictionary = all.get("types", {})
	var checks: Dictionary = {WEDDING: celebration_rules(data, WEDDING)}
	for kind: String in types:
		if kind != WEDDING:
			checks[kind] = types[kind]
	for kind: String in checks:
		var r: Dictionary = checks[kind]
		var who := "family.json celebrations (%s)" % kind
		if int(r.get("days", 0)) < 1 or int(r.get("attend_days", 1)) < 1:
			errors.append("%s: days and attend_days must be >= 1" % who)
		if int(r.get("favor", 0)) < 0:
			errors.append("%s: favor must be >= 0" % who)
		if int(r.get("gift_mult", 1)) < 1:
			errors.append("%s: gift_mult must be >= 1" % who)
		if r.get("news") is Array:
			var ok := not (r["news"] as Array).is_empty()
			for line: Variant in r["news"]:
				ok = ok and line is String and String(line) != ""
			if not ok:
				errors.append("%s: news must be a non-empty array of non-empty strings" % who)
		for key in ["label", "news", "attend_text"]:
			if r.get(key) is Array and key == "news":
				continue
			if (kind != WEDDING or r.has(key)) and String(r.get(key, "")) == "":
				errors.append("%s: %s must be non-empty" % [who, key])
	return errors


# --- A friend's tip (FOLK-003) ---

const TIP_KEY := "folk_tip"
const TIP_LAST_KEY := "folk_tip_last"


## data/family.json folk_visits ({} = feature off).
static func visit_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_visits", {})


## C-277: the line for a shared pot of tea on `today`. `tea_lines` (or, when a tip comes with it, `tip_tea_lines`) is an array of
## strings or {season, text}; entries for another season are skipped, the rest are picked by today % size. {name} and {progress} are filled.
static func tea_line(data: GameData, npc_name: String, progress: String, today: int, season: String, with_tip: bool) -> String:
	var lines: Array = _tea_pool(visit_rules(data).get("tip_tea_lines" if with_tip else "tea_lines", []), season)
	var text := "You share a pot of tea with {name} and talk about small things. ({progress})" if lines.is_empty() else String(lines[posmod(today, lines.size())])
	return text.replace("{name}", npc_name).replace("{progress}", progress)


static func _tea_pool(entries: Variant, season: String) -> Array:
	var pool: Array = []
	if not (entries is Array):
		return pool
	for entry: Variant in entries:
		if entry is Dictionary:
			if String((entry as Dictionary).get("season", season)) == season:
				pool.append(String((entry as Dictionary).get("text", "")))
		else:
			pool.append(String(entry))
	return pool


## Load errors in folk_visits: chance in (0, 1], tip_chance in [0, 1], whole numbers >= 0, min_favor not below folk_tips.min_favor.
static func validate_visits(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r: Dictionary = visit_rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("chance", 0))
	if chance <= 0.0 or chance > 1.0:
		errors.append("family.json folk_visits: chance must be in (0, 1]")
	var tip_chance := float(r.get("tip_chance", 0))
	if tip_chance < 0.0 or tip_chance > 1.0:
		errors.append("family.json folk_visits: tip_chance must be in [0, 1]")
	for key in ["min_favor", "cooldown_days", "tea_favor"]:
		if not (r.get(key, -1) is int or r.get(key, -1) is float) or int(r.get(key, -1)) < 0:
			errors.append("family.json folk_visits: %s must be a whole number >= 0" % key)
	if int(r.get("min_favor", 0)) < int(tip_rules(data).get("min_favor", 0)):
		errors.append("family.json folk_visits: min_favor must be at least folk_tips.min_favor")
	for key in ["tea_lines", "tip_tea_lines"]:
		if not r.has(key):
			continue
		if not (r[key] is Array) or (r[key] as Array).is_empty():
			errors.append("family.json folk_visits.%s must be a non-empty array" % key)
			continue
		for entry: Variant in r[key]:
			var text := String((entry as Dictionary).get("text", "")) if entry is Dictionary else (String(entry) if entry is String else "")
			if text == "":
				errors.append("family.json folk_visits.%s: lines must be non-empty strings or {season, text}" % key)
			elif entry is Dictionary and not ["spring", "summer", "autumn", "winter"].has(String(entry.get("season", ""))):
				errors.append("family.json folk_visits.%s: unknown season in '%s'" % [key, text])
			elif not text.contains("{name}"):
				errors.append("family.json folk_visits.%s: '%s' needs {name}" % [key, text])
			else:
				var stripped := text.replace("{name}", "").replace("{progress}", "")
				if stripped.contains("{"):
					errors.append("family.json folk_visits.%s: '%s' has an unknown placeholder" % [key, text])
	return errors


## WORLD-007: the generated villager who drops by on `day` ("" = nobody). `npcs` id -> CharacterData, `favors` id -> favor,
## `last_visit` id -> day of their last tea. Only on clear or cloudy days, among adult villagers living in `region_id`
## with enough favor and no tea in the last cooldown_days (a tea taken today keeps today's visitor). Deterministic: a hash
## of day and region against `chance`, then a hash picks among the eligible in id order. No rng.
static func visitor(npcs: Dictionary, favors: Dictionary, data: GameData, player: CharacterData, region_id: String, day: int, weather: String, last_visit: Dictionary) -> String:
	var r: Dictionary = visit_rules(data)
	if r.is_empty() or not ["clear", "cloudy"].has(weather):
		return ""
	var adult_age := int(data.family.get("adult_age", 16))
	var eligible: Array[String] = []
	for c in Npcs.generated_in_region(npcs, data, region_id):
		if c.age_years() < adult_age or player.spouses.has(c.id) or player.children.has(c.id) or player.parents.has(c.id):
			continue
		if int(favors.get(c.id, 0)) < int(r["min_favor"]):
			continue
		var last := int(last_visit.get(c.id, -100000))
		if last != day and day - last < int(r["cooldown_days"]):
			continue
		eligible.append(c.id)
	if eligible.is_empty():
		return ""
	var roll := float(absi(hash("%d|%s|visit" % [day, region_id])) % 10000) / 10000.0
	if roll >= float(r["chance"]):
		return ""
	return eligible[absi(hash("%d|%s|who" % [day, region_id])) % eligible.size()]


## data/family.json folk_tips ({} = feature off).
static func tip_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_tips", {})


## Load errors in folk_tips: numbers in range, lines non-empty and each naming {item}.
static func validate_tips(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r: Dictionary = tip_rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("chance", 0))
	if chance <= 0.0 or chance > 1.0:
		errors.append("family.json folk_tips: chance must be in (0, 1]")
	for key in ["min_favor", "cooldown_days", "days", "bonus"]:
		if int(r.get(key, 0)) <= 0:
			errors.append("family.json folk_tips: %s must be > 0" % key)
	if int(r.get("days", 0)) > 60:
		errors.append("family.json folk_tips: days must be <= 60")
	var chat_max := int(data.family.get("acquaintance", {}).get("chat_max_favor", 0))
	if chat_max > 0 and int(r.get("min_favor", 0)) >= chat_max:
		errors.append("family.json folk_tips: min_favor must be below acquaintance.chat_max_favor (%d), or no chat can ever give a tip" % chat_max)
	if int(r.get("bonus", 0)) > 5:
		errors.append("family.json folk_tips: bonus must be 1..5")
	var lines: Array = r.get("lines", [])
	if lines.is_empty():
		errors.append("family.json folk_tips: lines must be a non-empty array")
	for line in lines:
		var text := ""
		if line is String:
			text = line
		elif line is Dictionary:
			text = String((line as Dictionary).get("text", ""))
			for season in (line as Dictionary).get("seasons", []):
				if not ["spring", "summer", "autumn", "winter"].has(String(season)):
					errors.append("family.json folk_tips: unknown season '%s'" % season)
			var weather := String((line as Dictionary).get("weather", ""))
			if weather != "" and not Weather.KINDS.has(weather):
				errors.append("family.json folk_tips: unknown weather '%s'" % weather)
		if not text.contains("{item}"):
			errors.append("family.json folk_tips: every line needs {item}")
	return errors


## Item ids the gather places of `region_id` can yield this season for `c`, de-duplicated and sorted.
static func tip_candidates(c: CharacterData, data: GameData, region_id: String, season: String) -> Array[String]:
	var out: Array[String] = []
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.get("type", "") != "gather":
			continue
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("gather_table", []), season):
			var item_id := String(entry.get("item", ""))
			if item_id != "" and not out.has(item_id):
				out.append(item_id)
	out.sort()
	return out


## The tip in force on `today`, {region, item, until, npc_id}, or {}.
static func active_tip(flags: Dictionary, today: int) -> Dictionary:
	var tip: Dictionary = flags.get(TIP_KEY, {})
	if tip.is_empty() or today > int(tip.get("until", -1)):
		return {}
	return tip


## `chance_override` >= 0 (WORLD-007 tea) replaces the chance and skips the cooldown.
## A friend may let slip a gathering tip while you chat. Returns the new tip ({} = none) and stores it in `flags`.
## The chance is rolled before the item is picked, so the rng stream does not depend on the candidates.
static func roll_tip(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, neighbours: Array, favor: int, npc_id: String, today: int, season: String, rng: RandomNumberGenerator, chance_override: float = -1.0) -> Dictionary:
	var r: Dictionary = tip_rules(data)
	if r.is_empty() or favor < int(r["min_favor"]) or not active_tip(flags, today).is_empty():
		return {}
	if chance_override < 0.0 and flags.has(TIP_LAST_KEY) and today - int(flags[TIP_LAST_KEY]) < int(r["cooldown_days"]):
		return {}
	if rng.randf() >= (float(r["chance"]) if chance_override < 0.0 else chance_override):
		return {}
	var where := region_id
	var options := tip_candidates(c, data, region_id, season)
	if options.is_empty():
		for other in neighbours:
			options = tip_candidates(c, data, String(other), season)
			if not options.is_empty():
				where = String(other)
				break
	if options.is_empty():
		return {}
	var tip := {"region": where, "item": options[rng.randi_range(0, options.size() - 1)], "until": today + int(r["days"]), "npc_id": npc_id}
	flags[TIP_KEY] = tip
	flags[TIP_LAST_KEY] = today
	return tip


## {item: bonus} when the active tip is for `region_id` and the (season/realm-filtered) table can yield its item.
static func tip_bonus(data: GameData, flags: Dictionary, today: int, region_id: String, season_table: Array) -> Dictionary:
	var tip := active_tip(flags, today)
	if tip.is_empty() or String(tip.get("region", "")) != region_id:
		return {}
	for entry: Dictionary in season_table:
		if String(entry.get("item", "")) == String(tip["item"]):
			return {String(tip["item"]): int(tip_rules(data).get("bonus", 0))}
	return {}


## True when a tip line may be told on `day` in `weather` (plain strings and unconstrained objects always may).
static func tip_line_fits(line: Variant, day: int, weather: String) -> bool:
	if not line is Dictionary:
		return true
	var l: Dictionary = line
	if l.has("seasons") and not (l["seasons"] as Array).has(Calendar.season_of(day).to_lower()):
		return false
	return not l.has("weather") or String(l["weather"]) == weather


## The villager's words, from the folk_tips.lines that fit today's season and `weather` (line_index % count),
## with {villager}, {item}, {region}, {place_kind} filled. A line is a string or {text, seasons, weather}.
static func tip_line(data: GameData, tip: Dictionary, villager_name: String, line_index: int, weather: String = "") -> String:
	var lines: Array = []
	for line: Variant in tip_rules(data).get("lines", []):
		if tip_line_fits(line, line_index, weather):
			lines.append(line)
	if lines.is_empty() or tip.is_empty():
		return ""
	var item_id := String(tip["item"])
	var tags: Array = data.items.get(item_id, {}).get("tags", [])
	var kind := "gathering ground"
	if tags.has("herb"):
		kind = "herb slope"
	elif tags.has("ore"):
		kind = "ore tailings"
	var chosen: Variant = lines[absi(line_index) % lines.size()]
	return (String((chosen as Dictionary).get("text", "")) if chosen is Dictionary else String(chosen)).replace("{villager}", villager_name) \
		.replace("{item}", String(data.items.get(item_id, {}).get("name", item_id))) \
		.replace("{region}", String(data.regions.get(String(tip["region"]), {}).get("name", tip["region"]))) \
		.replace("{place_kind}", kind)


# --- FOLK-004: a quarrel between two villagers that the player may settle ------------------------

const QUARREL_PREFIX := "quarrel_"
const QUARREL_CHOICES: PackedStringArray = ["mediate", "side_a", "side_b", "extort"]


## data/family.json folk_quarrels ({} = feature off).
static func quarrel_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_quarrels", {})


static func quarrel_flag(region_id: String) -> String:
	return QUARREL_PREFIX + region_id


## The open quarrel of `region_id` ({} when none or it has run out).
static func open_quarrel(flags: Dictionary, region_id: String, today: int) -> Dictionary:
	var q: Variant = flags.get(quarrel_flag(region_id))
	if q is Dictionary and int(q.get("until", -1)) >= today:
		return q
	return {}


## This month's quarrel in `region_id`, stored in flags and returned ({} when none starts). An expired one is cleared
## quietly; while one is open nothing is drawn. The chance is rolled first, then two different non-family adults are picked.
static func monthly_quarrel(c: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String, today: int, flags: Dictionary) -> Dictionary:
	var r := quarrel_rules(data)
	if r.is_empty() or region_id == "":
		return {}
	if not open_quarrel(flags, region_id, today).is_empty():
		return {}
	flags.erase(quarrel_flag(region_id))
	expire_mark(flags, region_id, today)
	if rng.randf() >= float(r.get("chance", 0.0)):
		return {}
	var pool := candidates(npcs, data, c, region_id)
	if pool.size() < 2:
		return {}
	pool.sort_custom(func(x: CharacterData, y: CharacterData) -> bool: return x.id < y.id)
	var ia := rng.randi_range(0, pool.size() - 1)
	var ib := rng.randi_range(0, pool.size() - 2)
	if ib >= ia:
		ib += 1
	var topics: Array = r["topics"]
	var topic: Dictionary = topics[rng.randi_range(0, topics.size() - 1)]
	var q := {"a": pool[ia].id, "b": pool[ib].id, "topic": String(topic["id"]), "until": today + int(r.get("days", 20))}
	flags[quarrel_flag(region_id)] = q
	return q


## The quarrel's one-line description with the villagers' names.
static func quarrel_text(q: Dictionary, npcs: Dictionary, data: GameData) -> String:
	var a: CharacterData = npcs.get(String(q.get("a", "")))
	var b: CharacterData = npcs.get(String(q.get("b", "")))
	for topic: Dictionary in quarrel_rules(data).get("topics", []):
		if String(topic["id"]) == String(q.get("topic", "")) and a != null and b != null:
			return String(topic["text"]).replace("{a}", a.name).replace("{b}", b.name)
	return ""


## Why the quarrel of `region_id` cannot be settled through `npc_id` now ("" when it can).
static func check_settle(npcs: Dictionary, data: GameData, flags: Dictionary, region_id: String, npc_id: String, today: int) -> String:
	var q := open_quarrel(flags, region_id, today)
	if q.is_empty() or (String(q["a"]) != npc_id and String(q["b"]) != npc_id):
		return "There is no quarrel to settle."
	for id: String in [q["a"], q["b"]]:
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive:
			return "One of them is no longer here to settle with."
	return ""


## The other villager of a quarrel `npc_id` is in ("" when not in `q`).
static func quarrel_other(q: Dictionary, npc_id: String) -> String:
	if String(q.get("a", "")) == npc_id:
		return String(q.get("b", ""))
	if String(q.get("b", "")) == npc_id:
		return String(q.get("a", ""))
	return ""


## Odds of the mediate check, 0.1..0.9 like exploration checks.
static func mediate_chance(c: CharacterData, data: GameData) -> float:
	var check: Dictionary = quarrel_rules(data)["outcomes"]["mediate"]["check"]
	return clampf(float(c.attribute(String(check["attribute"]))) / float(check["target"]), 0.1, 0.9)


## Applies `choice` (QUARREL_CHOICES) to quarrel `q`: {favor: {npc id: delta}, alignment: int, stones: int, ok: bool}.
## Only mediate draws from `rng` (the check). The caller applies the numbers and clears the flag.
static func settle(c: CharacterData, data: GameData, q: Dictionary, choice: String, rng: RandomNumberGenerator) -> Dictionary:
	var o: Dictionary = quarrel_rules(data)["outcomes"]
	var a := String(q["a"])
	var b := String(q["b"])
	var out := {"favor": {a: 0, b: 0}, "alignment": 0, "stones": 0, "ok": true}
	match choice:
		"mediate":
			var m: Dictionary = o["mediate"]
			if rng.randf() < mediate_chance(c, data):
				out["favor"] = {a: int(m["favor_a"]), b: int(m["favor_b"])}
				out["alignment"] = int(m["alignment"])
			else:
				out["ok"] = false
				out["favor"] = {a: int(m["fail_favor"]), b: int(m["fail_favor"])}
		"side_a", "side_b":
			var s: Dictionary = o[choice]
			var a_wins := choice == "side_a"
			out["favor"] = {a: int(s["favor_winner"] if a_wins else s["favor_loser"]), b: int(s["favor_loser"] if a_wins else s["favor_winner"])}
		"extort":
			var e: Dictionary = o["extort"]
			out["favor"] = {a: int(e["favor_a"]), b: int(e["favor_b"])}
			out["alignment"] = int(e["alignment"])
			out["stones"] = int(e["stones"])
	return out


static func validate_quarrels(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := quarrel_rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("chance", 0.0))
	if chance <= 0.0 or chance > 1.0 or int(r.get("days", 0)) < 1:
		errors.append("family.json folk_quarrels needs chance in (0, 1] and days >= 1")
	if not (r.get("topics") is Array) or r["topics"].is_empty():
		errors.append("family.json folk_quarrels.topics must be a non-empty list")
	else:
		for topic: Dictionary in r["topics"]:
			var text := String(topic.get("text", ""))
			if String(topic.get("id", "")) == "" or not text.contains("{a}") or not text.contains("{b}"):
				errors.append("family.json folk_quarrels topic needs an id and a text with {a} and {b}")
	var o: Variant = r.get("outcomes")
	if not (o is Dictionary):
		errors.append("family.json folk_quarrels.outcomes is missing")
		return errors
	for key in ["mediate", "side_a", "side_b", "extort"]:
		if not (o.get(key) is Dictionary):
			errors.append("family.json folk_quarrels.outcomes.%s is missing" % key)
			return errors
	var check: Variant = o["mediate"].get("check")
	if not (check is Dictionary) or not (data.attributes.is_empty() or data.attribute_ids().has(String(check.get("attribute", "")))) or int(check.get("target", 0)) < 1:
		errors.append("family.json folk_quarrels mediate.check needs a known attribute and target >= 1")
	if int(o["mediate"].get("fail_favor", 1)) > 0:
		errors.append("family.json folk_quarrels mediate.fail_favor must be <= 0")
	if int(r.get("mark_days", 1)) < 1:
		errors.append("family.json folk_quarrels.mark_days must be >= 1")
	if int(o["extort"].get("stones", -1)) < 0:
		errors.append("family.json folk_quarrels extort.stones must be >= 0")
	return errors


# --- FOLK-006: quarrels leave marks for a season ---

const QUARREL_MARK_PREFIX := "quarrel_mark_"


static func mark_flag(region_id: String) -> String:
	return QUARREL_MARK_PREFIX + region_id


## Stores how the quarrel `q` was settled (`choice`) in `region_id`'s mark flag for `marks_days` (folk_quarrels.mark_days):
## {choice, a, b, until}. For side_a/side_b `loser` is the villager turned cold. A new mark replaces the old one.
static func record_mark(data: GameData, flags: Dictionary, region_id: String, q: Dictionary, choice: String, today: int) -> void:
	var days := int(quarrel_rules(data).get("mark_days", 0))
	if days < 1 or region_id == "":
		return
	var mark := {"choice": choice, "a": String(q["a"]), "b": String(q["b"]), "until": today + days}
	if choice == "side_a":
		mark["loser"] = String(q["b"])
	elif choice == "side_b":
		mark["loser"] = String(q["a"])
	flags[mark_flag(region_id)] = mark


## The mark of `region_id` still in force on `today` ({} when none or it has run out).
static func active_mark(flags: Dictionary, region_id: String, today: int) -> Dictionary:
	var m: Variant = flags.get(mark_flag(region_id))
	if m is Dictionary and int(m.get("until", -1)) >= today:
		return m
	return {}


## Whether a mark in force makes `npc_id` greet you coldly (you sided against them).
static func shunned_by_mark(flags: Dictionary, npc_id: String, today: int) -> bool:
	for key: Variant in flags:
		if String(key).begins_with(QUARREL_MARK_PREFIX):
			var m: Dictionary = active_mark(flags, String(key).substr(QUARREL_MARK_PREFIX.length()), today)
			if String(m.get("loser", "")) == npc_id:
				return true
	return false


## Whether `region_id` has a mark of `choice` in force (an unknown `today` < 0 counts any stored mark).
static func has_mark(flags: Dictionary, region_id: String, choice: String, today: int) -> bool:
	var m: Variant = flags.get(mark_flag(region_id))
	if not (m is Dictionary) or String(m.get("choice", "")) != choice:
		return false
	return today < 0 or int(m.get("until", -1)) >= today


## Mediated villagers are seen together: both stand at the first one's haunt place. {npc id: place} (empty without
## an active mediate mark or when the pair is not in `region`). `adult_age` decides their haunt anchors.
static func together_places(npcs: Dictionary, flags: Dictionary, region_id: String, region: Dictionary, today: int, weather: String) -> Dictionary:
	var m := active_mark(flags, region_id, today)
	if String(m.get("choice", "")) != "mediate":
		return {}
	var a: CharacterData = npcs.get(String(m["a"]))
	if a == null or not a.alive or not npcs.has(String(m["b"])) or not npcs[String(m["b"])].alive:
		return {}
	var place := Npcs.haunt_place(a, region, today, true, weather)
	if place.is_empty():
		return {}
	return {String(m["a"]): place, String(m["b"]): place}


## Clears the mark of `region_id` once it has run out.
static func expire_mark(flags: Dictionary, region_id: String, today: int) -> void:
	if flags.has(mark_flag(region_id)) and active_mark(flags, region_id, today).is_empty():
		flags.erase(mark_flag(region_id))


# --- A friend at your side (FOLK-005) ---


## data/family.json folk_companions ({} = feature off).
static func companion_rules(data: GameData) -> Dictionary:
	return data.family.get("folk_companions", {})


## Load errors in folk_companions: whole numbers, chance in [0, 1], a known injury.
static func validate_companions(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r: Dictionary = companion_rules(data)
	if r.is_empty():
		return errors
	for key in ["min_favor", "cooldown_days", "favor_win", "favor_loss", "blows"]:
		if not (r.get(key, -1) is int or r.get(key, -1) is float) or int(r.get(key, -1)) < 0:
			errors.append("family.json folk_companions: %s must be a whole number >= 0" % key)
	if int(r.get("blows", 0)) < 1:
		errors.append("family.json folk_companions: blows must be >= 1")
	var chance := float(r.get("injury_chance", -1))
	if chance < 0.0 or chance > 1.0:
		errors.append("family.json folk_companions: injury_chance must be in [0, 1]")
	if not data.injuries.has(String(r.get("injury", ""))):
		errors.append("family.json folk_companions: injury must be an injuries.json id")
	return errors


## Why `npc` cannot be asked along now ("" when they can): a living adult cultivator
## of the region, favor >= min_favor, not asked within cooldown_days, nobody else coming today.
static func check_invite(c: CharacterData, npc: CharacterData, favor: int, data: GameData, region_id: String, today: int) -> String:
	var r: Dictionary = companion_rules(data)
	if r.is_empty() or npc == null or not npc.alive:
		return "Nobody can come with you."
	if companion_today(c, today) != "":
		return "A friend is already coming with you today."
	if npc.realm_index < 1:
		return "%s is no cultivator and could not keep up." % npc.name
	if favor < int(r["min_favor"]):
		return "%s does not know you well enough yet (favor %d needed)." % [npc.name, int(r["min_favor"])]
	var left := int(c.folk_companion_day.get(npc.id, -100000)) + int(r["cooldown_days"]) - today
	if left > 0:
		return "%s has helped you lately; ask again in %d days." % [npc.name, left]
	return ""


## Ask `npc` along for today's fight.
static func invite(c: CharacterData, npc_id: String, today: int) -> void:
	c.folk_companion = {"npc": npc_id, "day": today}
	c.folk_companion_day[npc_id] = today


## The friend coming along today ("" = none).
static func companion_today(c: CharacterData, today: int) -> String:
	if int(c.folk_companion.get("day", -1)) != today:
		return ""
	return String(c.folk_companion.get("npc", ""))


## The companion's strike: {name, damage}, like Karma.ally_strike but free.
static func companion_strike(people: Dictionary, data: GameData, npc_id: String) -> Dictionary:
	var ally: CharacterData = people[npc_id]
	var blows := int(companion_rules(data).get("blows", 1))
	return {"name": ally.name, "damage": maxi(1, int(Combat.stats(ally, data)["attack"]) * blows)}


## After the fight: favor +favor_win / -favor_loss, and on a loss maybe an injury for them.
## Returns the favor change. Clears the companion.
static func finish_companion(c: CharacterData, people: Dictionary, favors: Dictionary, data: GameData, rng: RandomNumberGenerator, npc_id: String, won: bool) -> int:
	var r: Dictionary = companion_rules(data)
	c.folk_companion = {}
	var delta := int(r["favor_win"]) if won else -int(r["favor_loss"])
	favors[npc_id] = clampi(int(favors.get(npc_id, 0)) + delta, -100, 100)
	if not won and people.has(npc_id) and rng.randf() < float(r["injury_chance"]):
		Injuries.inflict(people[npc_id], data, String(r["injury"]))
	return delta


## FOLK-013: the first unseen scene due for `npc_id` at `favor` ({} = none). A scene for this villager comes
## before an "any_villager" one. A scene with `weather` waits for that weather (FOLK-021). Pure.
static func scene_due(c: CharacterData, data: GameData, npc_id: String, favor: int, npc: CharacterData = null, region_id: String = "", weather: String = "") -> Dictionary:
	var generic := {}
	var villager := is_villager(npc, data, region_id)
	for scene: Dictionary in data.scenes:
		if c.scenes_seen.has(String(scene["id"])) or favor < int(scene["min_favor"]):
			continue
		if scene.has("weather") and not (scene["weather"] as Array).has(weather):  # FOLK-021
			continue
		if String(scene["npc"]) == npc_id:
			return scene
		if villager and generic.is_empty() and String(scene["npc"]) == "any_villager":
			generic = scene
	return generic


## FOLK-014: whether `npc` is an ordinary villager of `region_id`: a living generated NPC (no data/npcs.json
## entry, so no role such as elder or merchant) who lives there and belongs to no sect. Pure.
static func is_villager(npc: CharacterData, data: GameData, region_id: String) -> bool:
	if npc == null or not npc.alive or data.npcs.has(npc.id) or not npc.sect.is_empty():
		return false
	return Npcs.region_of(npc, data) == region_id


## FOLK-013: remember that `scene_id` played on `day`.
static func mark_scene(c: CharacterData, scene_id: String, day: int) -> void:
	if not c.scenes_seen.has(scene_id):
		c.scenes_seen.append(scene_id)
	c.scene_day = day


## FOLK-017: where a named NPC stands on `day`: {pos: Vector2, why: String}, why one of "home", "work", "market",
## "rain", "festival", "rest". `events` are the active world events. Priority: festival > rain/storm > rest weekday
## > market day > work > home; a missing optional spot falls through. Pure, no randomness except a seeded offset.
static func spot_for(data: GameData, npc_def: Dictionary, day: int, weather: String, events: Array) -> Dictionary:
	var home := _point(npc_def.get("pos", [0, 0]))
	var spots: Dictionary = npc_def.get("spots", {})
	var region_id := String(npc_def.get("region", ""))
	if spots.is_empty():
		return {"pos": home, "why": "home"}
	for e in WorldEvents.active_in(events, region_id):
		if WorldEvents.is_festival(data, String(e.get("id", ""))):
			if spots.has("festival"):
				return {"pos": _point(spots["festival"]), "why": "festival"}
			var square: Variant = data.regions.get(region_id, {}).get("festival_square")
			if square is Array:
				var ring := festival_ring(_point(square), FESTIVAL_SLOTS, festival_blockers(data, region_id))
				var slot := posmod(hash(String(npc_def.get("id", ""))), maxi(ring.size(), 1))
				return {"pos": _point(square) if ring.is_empty() else ring[slot], "why": "festival"}
			break
	if (weather == "rain" or weather == "storm") and spots.has("rain"):
		return {"pos": _point(spots["rain"]), "why": "rain"}
	if spots.has("rest_weekday") and Calendar.weekday_name(day) == String(spots["rest_weekday"]):
		return {"pos": home, "why": "rest"}
	if spots.has("market") and _market_day(data, region_id, day):
		return {"pos": _point(spots["market"]), "why": "market"}
	if spots.has("work"):
		return {"pos": _point(spots["work"]), "why": "work"}
	return {"pos": home, "why": "home"}


## GFX-090: slots on the festival ring a named villager picks from.
const FESTIVAL_SLOTS := 24
const FESTIVAL_RADII: Array[float] = [70.0, 90.0, 110.0]
const FESTIVAL_GAP := 28.0
const FESTIVAL_CLEAR := 24.0
const SOLID_LANDMARKS: Array[String] = ["house", "well", "wall", "cliff", "lantern", "pine", "stall"]


## GFX-090: `count` spots on rings (radius 70-110 px) around `center`, evenly spaced, at least 28 px apart and
## 24 px clear of every blocker rect. WU-478: `keep_clear` points (the player) get no slot within 28 px.
## Pure and deterministic; may return fewer if the rings are crowded out.
static func festival_ring(center: Vector2, count: int, blockers: Array[Rect2], keep_clear: Array[Vector2] = []) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ring in FESTIVAL_RADII.size():
		var radius := FESTIVAL_RADII[ring]
		var slots := clampi(count, 1, int(TAU * radius / (FESTIVAL_GAP + 2.0)))
		for k in slots:
			if out.size() >= count:
				return out
			var pos := center + Vector2.from_angle(TAU * float(k) / float(slots) + 0.5 * float(ring)) * radius
			var ok := true
			for b in blockers:
				if b.grow(FESTIVAL_CLEAR).has_point(pos):
					ok = false
					break
			for o in out:
				if ok and pos.distance_to(o) < FESTIVAL_GAP:
					ok = false
			for q in keep_clear:
				if ok and pos.distance_to(q) < FESTIVAL_GAP:
					ok = false
			if ok:
				out.append(pos)
	return out


## GFX-090: rects festival villagers must keep off in `region_id`: festival stalls and solid landmarks.
static func festival_blockers(data: GameData, region_id: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var region: Dictionary = data.regions.get(region_id, {})
	for place: Dictionary in region.get("places", []):
		if place.has("festival_only"):
			out.append(_rect(place))
	for lm: Dictionary in region.get("map", {}).get("landmarks", []):
		if SOLID_LANDMARKS.has(String(lm.get("kind", ""))):
			out.append(_rect(lm))
	return out


static func _rect(d: Dictionary) -> Rect2:
	var size := _point(d.get("size", [0, 0]))
	return Rect2(_point(d.get("pos", [0, 0])) - size / 2.0, size)


static func _market_day(data: GameData, region_id: String, day: int) -> bool:
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.has("open_days") and Places.is_open(place, day):
			return true
	return false


static func _point(v: Variant) -> Vector2:
	var a: Array = v
	return Vector2(float(a[0]), float(a[1]))


## Load-time errors for the optional `spots` of named NPC `npc` (FOLK-017).
static func validate_spots(npc: Dictionary, data: GameData) -> Array[String]:
	var errors: Array[String] = []
	if not npc.has("spots"):
		return errors
	var who := String(npc.get("id", ""))
	if not npc.get("spots") is Dictionary or String(npc.get("region", "")) == "":
		errors.append("NPC '%s' spots must be an object on an NPC with a region" % who)
		return errors
	var size: Array = data.regions.get(String(npc["region"]), {}).get("map", {}).get("size", [1600, 1000])
	for key: String in npc["spots"]:
		var v: Variant = npc["spots"][key]
		if key == "rest_weekday":
			if not Calendar.WEEKDAY_NAMES.has(String(v)):
				errors.append("NPC '%s' spots rest_weekday '%s' is not a weekday name" % [who, str(v)])
		elif key in ["work", "market", "rain", "festival"]:
			if not (v is Array and (v as Array).size() == 2 and ((v as Array)[0] is float or (v as Array)[0] is int) and ((v as Array)[1] is float or (v as Array)[1] is int)):
				errors.append("NPC '%s' spots %s must be [x, y]" % [who, key])
			else:
				var p := _point(v)
				if p.x < 0.0 or p.y < 0.0 or p.x > float(size[0]) or p.y > float(size[1]):
					errors.append("NPC '%s' spots %s is outside the map" % [who, key])
				for place: Dictionary in data.regions.get(String(npc["region"]), {}).get("places", []):
					if place.get("type", "") == "travel":
						var pp: Array = place.get("pos", [0, 0])
						if p.distance_to(Vector2(float(pp[0]), float(pp[1]))) < GameData.SIGNPOST_CLEAR:
							errors.append("NPC '%s' spots %s is within %d px of signpost '%s'" % [who, key, int(GameData.SIGNPOST_CLEAR), place.get("display_name", "")])
		else:
			errors.append("NPC '%s' spots has unknown key '%s'" % [who, key])
	return errors
