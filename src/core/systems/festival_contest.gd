class_name FestivalContest
extends RefCounted
## FEST-006: the once-a-year contest at a festival stall (data/world_events.json `contest` block).
## The player's attribute score plays 2-4 villagers; ties go to the player. Pure: no state, rng passed in.

const DEFAULT_RIVAL_ATTRIBUTE := 8
const CHAMPION_BONUS := 2
const MASTER_STREAK := 3
## FOLK-012: friends cheering from the crowd.
const CHEER_MAX := 3
const COMPANY_FAVOR := 4
## FEST-008: practice in the week before the festival.
const PRACTICE_WINDOW := 7
const PRACTICE_PER_DAY := 2
const PRACTICE_MAX := 6


static func contest_of(data: GameData, event_id: String) -> Dictionary:
	return WorldEvents.def_of(data, event_id).get("contest", {})


static func flag_key(event_id: String, year: int) -> String:
	return "contest_%s_%d" % [event_id, year]


static func winner_key(event_id: String) -> String:
	return "contest_winner_%s" % event_id


const HISTORY_YEARS := 10


## FEST-010: world flag {year: place} of the player's own results.
static func history_key(event_id: String) -> String:
	return "contest_history_%s" % event_id


static func keepsake_key(event_id: String) -> String:
	return "keepsake_won_%s" % event_id


## FEST-010: win_text / lose_text may be a String or a non-empty Array of Strings (picked by year % size).
static func pick_text(raw: Variant, year: int) -> String:
	if raw is Array:
		var list := raw as Array
		return String(list[year % list.size()]) if not list.is_empty() else ""
	return String(raw)


## FEST-010: the 1st prize's keepsake item id ("keepsake" tag), or "".
static func keepsake_of(data: GameData, event_id: String) -> String:
	var prizes: Array = contest_of(data, event_id).get("prizes", [])
	if prizes.is_empty():
		return ""
	for item_id: String in (prizes[0] as Dictionary).get("items", {}):
		if data.items.has(item_id) and (data.items[item_id].get("tags", []) as Array).has("keepsake"):
			return item_id
	return ""


## FEST-010: one entry per contest festival, ordered by month (see BACKLOG FEST-010).
static func history(data: GameData, flags: Dictionary, c: CharacterData, year: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event_id: String in data.world_events:
		var contest := contest_of(data, event_id)
		if contest.is_empty():
			continue
		var def: Dictionary = data.world_events[event_id]
		var hist: Variant = flags.get(history_key(event_id), {})
		var places: Dictionary = hist if hist is Dictionary else {}
		var last_year := 0
		for k: String in places:
			last_year = maxi(last_year, int(k))
		var streak := 0
		var y := last_year
		while places.has(str(y)) and int(places[str(y)]) == 1:
			streak += 1
			y -= 1
		var rec := champion(flags, event_id, year + 1)
		var champ := ""
		if not rec.is_empty():
			champ = "You" if bool(rec.get("you", false)) else String(rec.get("name", ""))
		var keepsake := keepsake_of(data, event_id)
		var months: Array = def.get("months", [0])
		var regions: Array = def.get("regions", [])
		out.append({
			"event_id": event_id, "festival": String(def.get("name", event_id)),
			"month": int(months[0]) if not months.is_empty() else 0,
			"region": String(regions[0]) if not regions.is_empty() else "",
			"contest": String(contest.get("name", event_id)),
			"last_place": int(places.get(str(last_year), 0)) if last_year > 0 else 0,
			"last_year": last_year, "champion": champ, "streak": streak, "keepsake": keepsake,
			"keepsake_owned": keepsake != "" and (c.item_count(keepsake) > 0 or bool(flags.get(keepsake_key(event_id), false))),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["month"]) < int(b["month"]))
	return out


static func history_lines(data: GameData, flags: Dictionary, c: CharacterData, year: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for h in history(data, flags, c, year):
		var line := "%s (%s): " % [h["festival"], h["contest"]]
		if int(h["last_place"]) == 0:
			line += "not yet entered"
		else:
			line += "%s in year %d" % [ordinal(int(h["last_place"])), int(h["last_year"])]
			if int(h["streak"]) > 1:
				line += ", %d wins running" % int(h["streak"])
		if h["keepsake"] != "":
			line += "; keepsake %s" % ("won" if bool(h["keepsake_owned"]) else "not yet won")
		lines.append(line + ".")
	return lines


static func master_key(event_id: String) -> String:
	return "contest_master_%s" % event_id


static func practice_key(event_id: String, year: int) -> String:
	return "practice_%s_%d" % [event_id, year]


## The first day of the festival's month after `day` within PRACTICE_WINDOW days, or -1 (festivals start on day 1 of a `months` month).
static func start_within_window(data: GameData, event_id: String, day: int) -> int:
	var months: Array = WorldEvents.def_of(data, event_id).get("months", [])
	for offset in range(1, PRACTICE_WINDOW + 1):
		var d := day + offset
		if Calendar.day_of(d) == 1 and months.any(func(m: Variant) -> bool: return int(m) == Calendar.month_of(d)):
			return d
	return -1


## The contest (event id) that `tags` (a place's tags) can practise for today, or "".
static func practice_event_for(data: GameData, tags: Array, day: int) -> String:
	for event_id: String in data.world_events:
		var place := String(contest_of(data, event_id).get("practice_place", ""))
		if place != "" and tags.has(place) and start_within_window(data, event_id, day) >= 0:
			return event_id
	return ""


## Practice days banked for the festival that starts on `start_day` (flag keyed by that day's year).
static func practice_days(flags: Dictionary, event_id: String, year: int) -> int:
	return int(flags.get(practice_key(event_id, year), 0))


static func practice_bonus(flags: Dictionary, event_id: String, year: int) -> int:
	return mini(PRACTICE_MAX, PRACTICE_PER_DAY * practice_days(flags, event_id, year))


## "" if one more day of practice is allowed, otherwise why not.
static func check_practice(data: GameData, event_id: String, day: int, flags: Dictionary) -> String:
	var name := String(contest_of(data, event_id).get("name", event_id))
	var start := start_within_window(data, event_id, day)
	if start < 0:
		return "It is too early (or too late) to practise for the %s." % name
	if practice_bonus(flags, event_id, Calendar.year_of(start)) >= PRACTICE_MAX:
		return "You cannot get any readier for the %s." % name
	return ""


## Bank one day of practice; returns the bonus now held.
static func practise(data: GameData, event_id: String, day: int, flags: Dictionary) -> int:
	var year := Calendar.year_of(start_within_window(data, event_id, day))
	flags[practice_key(event_id, year)] = practice_days(flags, event_id, year) + 1
	return practice_bonus(flags, event_id, year)


## The previous years' winner record {year, name, you, streak} of a festival's contest, or {} (FEST-007).
## Only a record from before `year` counts: this year's winner is not yet "last year's champion".
static func champion(flags: Dictionary, event_id: String, year: int) -> Dictionary:
	var rec: Variant = flags.get(winner_key(event_id), {})
	if rec is Dictionary and (rec as Dictionary).has("year") and int((rec as Dictionary)["year"]) < year:
		return rec
	return {}


## A rival's name to tease the player about, or "" (a winner that was the player or a stranger is no champion).
static func champion_rival(flags: Dictionary, event_id: String, year: int) -> String:
	var rec := champion(flags, event_id, year)
	if rec.is_empty() or bool(rec.get("you", false)) or String(rec.get("name", "")) in ["", "a stranger"]:
		return ""
	return String(rec["name"])


## Calendar text: "Mei Lan won last year" (or "is the reigning champion"), "" if none.
static func champion_text(flags: Dictionary, event_id: String, year: int) -> String:
	var rec := champion(flags, event_id, year)
	if rec.is_empty():
		return ""
	var who := "You" if bool(rec.get("you", false)) else String(rec.get("name", ""))
	if who == "":
		return ""
	return "%s won last year" % who if int(rec["year"]) == year - 1 else "%s %s the reigning champion" % [who, "are" if who == "You" else "is"]


## Write this year's winner; returns the player's consecutive-win streak for this contest (FEST-007).
## At MASTER_STREAK the world flag `contest_master_<event>` is set (read by milestones).
static func record(flags: Dictionary, event_id: String, year: int, result: Dictionary) -> int:
	var winner: Dictionary = (result.get("scores", []) as Array)[0]
	var you := bool(winner["you"])
	var streak := 0
	if you:
		var prev: Variant = flags.get(winner_key(event_id), {})
		streak = (int((prev as Dictionary).get("streak", 0)) if prev is Dictionary and bool((prev as Dictionary).get("you", false)) else 0) + 1
	var hist_key := history_key(event_id)
	var hist: Dictionary = (flags.get(hist_key, {}) as Dictionary).duplicate() if flags.get(hist_key, {}) is Dictionary else {}
	hist[str(year)] = int(result.get("place", 0))
	while hist.size() > HISTORY_YEARS:
		var oldest := 1 << 30
		for k: String in hist:
			oldest = mini(oldest, int(k))
		hist.erase(str(oldest))
	flags[hist_key] = hist
	if you:
		flags[keepsake_key(event_id)] = true
	flags[winner_key(event_id)] = {"year": year, "name": "You" if you else String(winner["name"]), "you": you, "streak": streak}
	if streak >= MASTER_STREAK:
		flags[master_key(event_id)] = true
	return streak


## "" if the contest can be entered now, otherwise the reason it cannot.
static func check(data: GameData, active: Array, _c: CharacterData, event_id: String, region_id: String, flags: Dictionary, year: int) -> String:
	var contest := contest_of(data, event_id)
	if contest.is_empty():
		return "There is no contest here."
	if WorldEvents.instance_in(active, event_id, region_id).is_empty():
		return "The %s is not on here." % String(contest.get("name", event_id))
	if flags.has(flag_key(event_id, year)):
		return "You have already entered the %s this year." % String(contest.get("name", event_id))
	return ""


## Run the contest. `rivals` are the villagers who enter (fewer than `rivals` is fine; missing ones become strangers).
static func run(data: GameData, c: CharacterData, event_id: String, rivals: Array[CharacterData], rng: RandomNumberGenerator, champion_name: String = "", practice: int = 0, rival_name: String = "", text_year: int = 0, cheer: int = 0) -> Dictionary:
	var contest := contest_of(data, event_id)
	if contest.is_empty():
		return {}
	var attribute := String(contest.get("attribute", ""))
	var mine := c.attribute(attribute) + rng.randi_range(0, 10)
	mine += practice + cheer
	var profession := String(contest.get("profession", ""))
	if profession != "":
		mine += 2 * Professions.rank_of(c, profession)
	var scores: Array[Dictionary] = [{"name": "You", "score": mine, "you": true}]
	var wanted := int(contest.get("rivals", 2))
	for i in wanted:
		var name := "a stranger"
		var base := DEFAULT_RIVAL_ATTRIBUTE
		if i < rivals.size():
			name = rivals[i].name
			base = rivals[i].attribute(attribute) if rivals[i].attributes.has(attribute) else DEFAULT_RIVAL_ATTRIBUTE
		var score := base + rng.randi_range(0, 10)
		if champion_name != "" and name == champion_name:
			score += CHAMPION_BONUS
		var entry := {"name": name, "score": score, "you": false}
		if rival_name != "" and name == rival_name:
			entry["rival"] = true  # FEST-009
		scores.append(entry)
	# Stable sort high to low; the player is first in the list, so ties go to the player.
	var order: Array[Dictionary] = []
	for s in scores:
		var at := order.size()
		for j in order.size():
			if int(s["score"]) > int(order[j]["score"]):
				at = j
				break
		order.insert(at, s)
	var place := 1
	for j in order.size():
		if bool(order[j]["you"]):
			place = j + 1
	var prizes: Array = contest.get("prizes", [])
	var prize: Dictionary = prizes[place - 1] if place - 1 < prizes.size() else {}
	var text := pick_text(contest.get("win_text", ""), text_year) if place == 1 else pick_text(contest.get("lose_text", ""), text_year).replace("{winner}", String(order[0]["name"]))
	return {"event_id": event_id, "name": String(contest.get("name", event_id)), "place": place, "total": order.size(), "scores": order, "prize": prize, "text": text, "practice": practice, "cheer": cheer}


## FOLK-012: villagers of `region_id` at friendship tier Friend or better, best friends first (name tiebreak).
static func friends_of(npcs: Dictionary, data: GameData, favor: Dictionary, region_id: String, min_tier: int = 1) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for npc in Npcs.generated_in_region(npcs, data, region_id):
		if Folk.tier_index(data, int(favor.get(npc.id, 0))) >= min_tier:
			out.append(npc)
	out.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		var fa := int(favor.get(a.id, 0))
		var fb := int(favor.get(b.id, 0))
		return fa > fb if fa != fb else a.id.naturalnocasecmp_to(b.id) < 0)
	return out


## FOLK-012: friends who cheer (max CHEER_MAX, +1 each). Friends in `competing` (the contest's entrants) do not cheer.
static func cheerers(npcs: Dictionary, data: GameData, favor: Dictionary, region_id: String, competing: Array = []) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for npc in friends_of(npcs, data, favor, region_id, 1):
		if out.size() >= CHEER_MAX:
			break
		if not competing.has(npc):
			out.append(npc)
	return out


static func cheer_line(who: Array[CharacterData]) -> String:
	if who.is_empty():
		return ""
	var names: Array[String] = []
	for n in who:
		names.append(n.name)
	var joined := names[0] if names.size() == 1 else ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]
	return "%s cheer%s you on (+%d)." % [joined, "s" if names.size() == 1 else "", who.size()]


## FOLK-012: the festival (event id) whose first day is `day` and the friend (Close friend or better, best favor)
## of its region who invites the player: {event_id, npc} or {}. Pure.
static func invitation(data: GameData, npcs: Dictionary, favor: Dictionary, day: int) -> Dictionary:
	if Calendar.day_of(day) != 1:
		return {}
	for event_id: String in data.world_events:
		if contest_of(data, event_id).is_empty():
			continue
		var def: Dictionary = data.world_events[event_id]
		if not (def.get("months", []) as Array).any(func(m: Variant) -> bool: return int(m) == Calendar.month_of(day)):
			continue
		var regions: Array = def.get("regions", [])
		if regions.is_empty():
			continue
		var friends := friends_of(npcs, data, favor, String(regions[0]), 2)
		if not friends.is_empty():
			return {"event_id": event_id, "npc": friends[0]}
	return {}


static func invitation_line(data: GameData, inv: Dictionary) -> String:
	if inv.is_empty():
		return ""
	return "%s asked you to the %s tomorrow." % [(inv["npc"] as CharacterData).name, WorldEvents.event_name(data, String(inv["event_id"]))]


## FOLK-012: a line from family.json `festival_company`, picked by year ("" if none).
static func company_line(data: GameData, who: String, year: int) -> String:
	var list: Array = data.family.get("festival_company", [])
	return "" if list.is_empty() else String(list[year % list.size()]).replace("{name}", who)


static func standings_lines(result: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var scores: Array = result.get("scores", [])
	for i in mini(5, scores.size()):
		var tag := " (your rival)" if bool(scores[i].get("rival", false)) else ""
		out.append("%d. %s%s %d" % [i + 1, scores[i]["name"], tag, int(scores[i]["score"])])
	return out


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


static func validate(data: GameData) -> PackedStringArray:
	var errors := PackedStringArray()
	for event_id: String in data.world_events:
		var contest := contest_of(data, event_id)
		if not data.world_events[event_id].has("contest"):
			continue
		var id := "World event '%s' contest" % event_id
		if String(contest.get("name", "")) == "" or String(contest.get("text", "")) == "":
			errors.append("%s needs name and text" % id)
		for tk: String in ["win_text", "lose_text"]:
			var tv: Variant = contest.get(tk, "")
			var tok := false
			if tv is String:
				tok = String(tv) != ""
			elif tv is Array:
				tok = not (tv as Array).is_empty() and (tv as Array).all(func(x: Variant) -> bool: return x is String and String(x) != "")
			if not tok:
				errors.append("%s %s must be a string or a non-empty list of strings" % [id, tk])
		if not data.attributes.any(func(a: Dictionary) -> bool: return String(a["id"]) == String(contest.get("attribute", ""))):
			errors.append("%s has unknown attribute '%s'" % [id, contest.get("attribute", "")])
		var profession := String(contest.get("profession", ""))
		if profession != "" and not data.professions.has(profession):
			errors.append("%s has unknown profession '%s'" % [id, profession])
		var practice_place: Variant = contest.get("practice_place", "")
		if not practice_place is String:
			errors.append("%s practice_place must be a tag string" % id)
		elif String(practice_place) != "":
			var found := false
			for rid: String in data.world_events[event_id].get("regions", []):
				for place: Dictionary in data.regions.get(rid, {}).get("places", []):
					if (place.get("tags", []) as Array).has(practice_place):
						found = true
			if not found:
				errors.append("%s practice_place '%s' matches no place tag in its regions" % [id, practice_place])
		var rivals := int(contest.get("rivals", 0))
		if rivals < 2 or rivals > 4:
			errors.append("%s needs rivals 2..4" % id)
		var prizes: Variant = contest.get("prizes", [])
		if not prizes is Array or (prizes as Array).is_empty() or (prizes as Array).size() > 3:
			errors.append("%s needs 1..3 prizes" % id)
			continue
		for prize: Dictionary in prizes:
			for item_id in prize.get("items", {}):
				if not data.items.has(item_id):
					errors.append("%s prize has unknown item '%s'" % [id, item_id])
			if int(prize.get("favor_all", 0)) < 0 or int(prize.get("favor_all", 0)) > 5:
				errors.append("%s prize favor_all must be 0..5" % id)
			if int(prize.get("renown", 0)) < 0 or int(prize.get("renown", 0)) > 5:
				errors.append("%s prize renown must be 0..5" % id)
		var greeting := String(contest.get("champion_greeting", ""))
		if greeting == "":
			errors.append("%s needs a champion_greeting" % id)
		elif greeting.replace("{player}", "").contains("{"):
			errors.append("%s champion_greeting may only use {player}" % id)
		var lose_all: Array = contest.get("lose_text", []) if contest.get("lose_text", "") is Array else [contest.get("lose_text", "")]
		var stripped := "".join(PackedStringArray(lose_all.map(func(x: Variant) -> String: return String(x)))).replace("{winner}", "")
		if stripped.contains("{"):
			errors.append("%s lose_text may only use {winner}" % id)
	return errors


## WU-457: how many villagers gather round the contest stall.
const CROWD_MAX := 4
const CROWD_RADIUS := 74.0
const CROWD_CLEAR := 56.0


## The caption over the festival stall while the contest is still open to you: "<name> today", else "".
static func crowd_caption(data: GameData, event_id: String, open: bool) -> String:
	if event_id == "" or not open:
		return ""
	return "%s today" % String(contest_of(data, event_id).get("name", ""))


## Where `count` (capped at CROWD_MAX) villagers stand: a ring round `center`, skipping spots within
## CROWD_CLEAR of any `avoid` point (roads, other places) by trying wider rings. Deterministic.
static func crowd_positions(center: Vector2, count: int, avoid: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var want := clampi(count, 0, CROWD_MAX)
	var step := 0
	while out.size() < want and step < 48:
		var ring := step / 8
		var angle := TAU * (float(step % 8) + 0.5 * float(ring % 2)) / 8.0 + PI / 2.0
		step += 1
		var pos := center + Vector2.from_angle(angle) * (CROWD_RADIUS + 36.0 * float(ring))
		var clear := true
		for a in avoid:
			if pos.distance_to(a) < CROWD_CLEAR:
				clear = false
				break
		for o in out:
			if pos.distance_to(o) < 36.0:
				clear = false
				break
		if clear:
			out.append(pos)
	return out
