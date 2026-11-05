class_name FestivalContest
extends RefCounted
## FEST-006: the once-a-year contest at a festival stall (data/world_events.json `contest` block).
## The player's attribute score plays 2-4 villagers; ties go to the player. Pure: no state, rng passed in.

const DEFAULT_RIVAL_ATTRIBUTE := 8


static func contest_of(data: GameData, event_id: String) -> Dictionary:
	return WorldEvents.def_of(data, event_id).get("contest", {})


static func flag_key(event_id: String, year: int) -> String:
	return "contest_%s_%d" % [event_id, year]


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
static func run(data: GameData, c: CharacterData, event_id: String, rivals: Array[CharacterData], rng: RandomNumberGenerator) -> Dictionary:
	var contest := contest_of(data, event_id)
	if contest.is_empty():
		return {}
	var attribute := String(contest.get("attribute", ""))
	var mine := c.attribute(attribute) + rng.randi_range(0, 10)
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
		scores.append({"name": name, "score": base + rng.randi_range(0, 10), "you": false})
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
	return {"event_id": event_id, "name": String(contest.get("name", event_id)), "place": place, "total": order.size(), "scores": order, "prize": prize, "text": text}


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
		var stripped := String(contest.get("lose_text", "")).replace("{winner}", "")
		if stripped.contains("{"):
			errors.append("%s lose_text may only use {winner}" % id)
	return errors
