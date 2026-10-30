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
static func greeting(npc: CharacterData, favor: int, day: int, data: GameData, flags: Dictionary = {}) -> String:
	var bands: Dictionary = data.family.get("folk_greetings", {})
	var party: Array = bands.get("celebration", {}).get(celebration_kind(flags, npc.id), [])
	if celebration_open(flags, npc.id, day) and not party.is_empty():
		return String(party[absi(hash(npc.id + str(day))) % party.size()])
	var band: Dictionary = {}
	if favor >= int(bands.get("warm", {}).get("min_favor", 1000)):
		band = bands["warm"]
	elif favor <= int(bands.get("cool", {}).get("max_favor", -1000)):
		band = bands["cool"]
	var lines: Array = band.get("lines", [])
	if lines.is_empty():
		return ""
	return String(lines[absi(hash(npc.id + str(day))) % lines.size()])


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
	errors.append_array(validate_requests(data))
	errors.append_array(validate_celebrations(data))
	errors.append_array(validate_tips(data))
	errors.append_array(validate_visits(data))
	errors.append_array(validate_quarrels(data))
	errors.append_array(validate_gifts(data))
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
		if not (line is String) or not String(line).contains("{item}"):
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


## The villager's words, from folk_tips.lines[line_index % size], with {villager}, {item}, {region}, {place_kind} filled.
static func tip_line(data: GameData, tip: Dictionary, villager_name: String, line_index: int) -> String:
	var lines: Array = tip_rules(data).get("lines", [])
	if lines.is_empty() or tip.is_empty():
		return ""
	var item_id := String(tip["item"])
	var tags: Array = data.items.get(item_id, {}).get("tags", [])
	var kind := "gathering ground"
	if tags.has("herb"):
		kind = "herb slope"
	elif tags.has("ore"):
		kind = "ore tailings"
	return String(lines[absi(line_index) % lines.size()]).replace("{villager}", villager_name) \
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
	if int(o["extort"].get("stones", -1)) < 0:
		errors.append("family.json folk_quarrels extort.stones must be >= 0")
	return errors
