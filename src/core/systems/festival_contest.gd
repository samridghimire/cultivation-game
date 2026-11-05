class_name FestivalContest
extends RefCounted
## FEST-006: the once-a-year contest at a festival stall (data/world_events.json `contest` block).
## The player's attribute score plays 2-4 villagers; ties go to the player. Pure: no state, rng passed in.

const DEFAULT_RIVAL_ATTRIBUTE := 8
const CHAMPION_BONUS := 2
const MASTER_STREAK := 3
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
static func run(data: GameData, c: CharacterData, event_id: String, rivals: Array[CharacterData], rng: RandomNumberGenerator, champion_name: String = "", practice: int = 0) -> Dictionary:
	var contest := contest_of(data, event_id)
	if contest.is_empty():
		return {}
	var attribute := String(contest.get("attribute", ""))
	var mine := c.attribute(attribute) + rng.randi_range(0, 10)
	mine += practice
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
		scores.append({"name": name, "score": score, "you": false})
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
	var text := String(contest.get("win_text", "")) if place == 1 else String(contest.get("lose_text", "")).replace("{winner}", String(order[0]["name"]))
	return {"event_id": event_id, "name": String(contest.get("name", event_id)), "place": place, "total": order.size(), "scores": order, "prize": prize, "text": text, "practice": practice}


static func standings_lines(result: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var scores: Array = result.get("scores", [])
	for i in mini(5, scores.size()):
		out.append("%d. %s %d" % [i + 1, scores[i]["name"], int(scores[i]["score"])])
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
		if String(contest.get("name", "")) == "" or String(contest.get("text", "")) == "" or String(contest.get("win_text", "")) == "" or String(contest.get("lose_text", "")) == "":
			errors.append("%s needs name, text, win_text and lose_text" % id)
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
		var stripped := String(contest.get("lose_text", "")).replace("{winner}", "")
		if stripped.contains("{"):
			errors.append("%s lose_text may only use {winner}" % id)
	return errors
