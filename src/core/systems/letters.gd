class_name Letters
extends RefCounted
## LETTER-001: people who like you write between visits. Tunables live in
## data/family.json `letters`; a letter may invite you to visit, which the next
## chat with that person rewards once.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("letters", {})


static func visit_flag(npc_id: String) -> String:
	return "letter_visit_" + npc_id


## The living NPC the player knows best who is not family and likes them enough
## to write (ties: lowest id, so the result is stable). "" when nobody does.
static func writer(c: CharacterData, npcs: Dictionary, favor: Dictionary, data: GameData) -> String:
	var min_favor := int(rules(data).get("min_favor", 0))
	var best := ""
	var best_favor := -1
	var ids: Array = favor.keys()
	ids.sort()
	for id: String in ids:
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive:
			continue
		if c.spouses.has(id) or c.children.has(id) or c.parents.has(id):
			continue
		var f := int(favor[id])
		if f >= min_favor and f > best_favor:
			best = id
			best_favor = f
	return best


## Rolls this month's letter. Applies its effects and returns
## {npc_id, text, notes}, or {} when nobody writes.
static func monthly(c: CharacterData, npcs: Dictionary, favor: Dictionary, data: GameData, rng: RandomNumberGenerator, flags: Dictionary, today: int = -1) -> Dictionary:
	var r := rules(data)
	if r.is_empty():
		return {}
	var id := writer(c, npcs, favor, data)
	if id == "" or rng.randf() >= float(r.get("monthly_chance", 0.0)):
		return {}
	var npc_favor := int(favor[id])
	var kinds: Array = []
	var total := 0
	for kind: Dictionary in r.get("kinds", []):
		if npc_favor >= int(kind.get("min_favor", 0)):
			kinds.append(kind)
			total += int(kind.get("weight", 1))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for kind: Dictionary in kinds:
		roll -= int(kind.get("weight", 1))
		if roll > 0:
			continue
		var npc: CharacterData = npcs[id]
		var region: Dictionary = data.regions.get(Npcs.region_of(npc, data), {})
		var text := String(kind.get("text", "")).replace("{name}", npc.name).replace("{region}", String(region.get("name", "their home")))
		var notes := Effects.apply(c, data, kind.get("effects", {}), flags)
		if kind.get("visit", false):
			flags[visit_flag(id)] = true
		var asked := false
		var request: Dictionary = kind.get("request", {})
		if not request.is_empty() and open_request(c, id, _today(c, today)).is_empty():
			c.letter_requests.append({"npc_id": id, "item": String(request["item"]), "count": int(request.get("count", 1)), "until": _today(c, today) + int(request.get("days", 1)), "favor": int(request.get("favor", 0)), "effects": (request.get("effects", {}) as Dictionary).duplicate(true)})
			asked = true
		return {"npc_id": id, "text": text, "notes": notes, "request": asked}
	return {}


static func _today(c: CharacterData, today: int) -> int:
	return today if today >= 0 else c.age_days


## The open, unexpired request from `npc_id`, or {}.
static func open_request(c: CharacterData, npc_id: String, today: int) -> Dictionary:
	for req in c.letter_requests:
		if req["npc_id"] == npc_id and int(req["until"]) >= today:
			return req
	return {}


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


## "" or why the request cannot be answered.
static func check_answer(c: CharacterData, data: GameData, npc_id: String, today: int) -> String:
	var req := open_request(c, npc_id, today)
	if req.is_empty():
		return "No letter from them is waiting for an answer."
	var have := c.item_count(String(req["item"]))
	if have < int(req["count"]):
		return "They asked for %d %s; you have %d." % [int(req["count"]), _item_name(data, String(req["item"])), have]
	return ""


## Hands over the items: {ok, reason, favor, notes}. GameState applies the favor.
static func answer(c: CharacterData, data: GameData, npc_id: String, today: int, flags: Dictionary) -> Dictionary:
	var reason := check_answer(c, data, npc_id, today)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "notes": PackedStringArray()}
	var req := open_request(c, npc_id, today)
	c.add_item(String(req["item"]), -int(req["count"]))
	c.letter_requests.erase(req)
	var notes := Effects.apply(c, data, req.get("effects", {}), flags)
	return {"ok": true, "reason": "", "favor": int(req["favor"]), "notes": notes}


## Drops requests past their deadline (no penalty); returns the npc ids.
static func expire_requests(c: CharacterData, today: int) -> Array[String]:
	var gone: Array[String] = []
	for req in c.letter_requests.duplicate():
		if int(req["until"]) < today:
			c.letter_requests.erase(req)
			gone.append(String(req["npc_id"]))
	return gone


## "<Name> asked for 1 Qi Gathering Pill in a letter (N days left; give it in person in <Region>)." per open request.
static func request_lines(c: CharacterData, data: GameData, npcs: Dictionary, today: int) -> Array[String]:
	var out: Array[String] = []
	for req in c.letter_requests:
		var npc: CharacterData = npcs.get(req["npc_id"])
		if npc == null or not npc.alive or int(req["until"]) < today:
			continue
		var region: Dictionary = data.regions.get(Npcs.region_of(npc, data), {})
		out.append("%s asked for %d %s in a letter (%d days left; give it in person in %s)." % [npc.name, int(req["count"]), _item_name(data, String(req["item"])), int(req["until"]) - today, String(region.get("name", "their home"))])
	return out


## Extra favor for a chat with `npc_id` after an invitation; consumes it.
static func take_visit_bonus(npc_id: String, data: GameData, flags: Dictionary) -> int:
	if not flags.has(visit_flag(npc_id)):
		return 0
	flags.erase(visit_flag(npc_id))
	return int(rules(data).get("visit_favor", 0))


## Remembers a letter (newest last), keeping data's `max_kept`.
static func remember(c: CharacterData, data: GameData, line: String, today: int = -1) -> void:
	c.letters.append(line)
	c.letter_day = today
	var keep := maxi(1, int(rules(data).get("max_kept", 10)))
	while c.letters.size() > keep:
		c.letters.pop_front()


## "<Name>'s letter waits: <first 60 chars>..." for a letter that arrived within `within_days` of `today`, else "" (GUIDE-018).
static func recent_line(c: CharacterData, today: int, within_days: int = 30) -> String:
	if c.letters.is_empty() or c.letter_day < 0 or today - c.letter_day > within_days:
		return ""
	var body := c.letters[c.letters.size() - 1].trim_prefix("A letter from ")
	var colon := body.find(":")
	var who := body.substr(0, colon) if colon > 0 else "A friend"
	var text := body.substr(colon + 1).strip_edges() if colon > 0 else body
	if text.length() > 60:
		text = text.substr(0, 60) + "..."
	return "%s's letter waits: %s" % [who, text]


## Journal lines for the last `limit` letters, newest first, without the "A letter from " prefix (WU-081).
static func journal_lines(c: CharacterData, limit: int = 5) -> Array[String]:
	var out: Array[String] = []
	for i in range(c.letters.size() - 1, -1, -1):
		if out.size() >= limit:
			break
		out.append(c.letters[i].trim_prefix("A letter from "))
	return out


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	var chance := float(r.get("monthly_chance", 0.0))
	if chance < 0.0 or chance > 1.0:
		errors.append("family.json letters.monthly_chance must be 0..1")
	if int(r.get("min_favor", 0)) > 100:
		errors.append("family.json letters.min_favor must be <= 100")
	if int(r.get("visit_favor", 0)) < 0 or int(r.get("max_kept", 1)) < 1:
		errors.append("family.json letters.visit_favor must be >= 0 and max_kept >= 1")
	if not (r.get("kinds") is Array) or r["kinds"].is_empty():
		errors.append("family.json letters.kinds must be a non-empty list")
		return errors
	for kind: Dictionary in r["kinds"]:
		if not kind.has("id") or String(kind.get("text", "")) == "" or int(kind.get("weight", 0)) <= 0:
			errors.append("family.json letters kind %s needs id, text and weight > 0" % kind.get("id", "?"))
		var request: Dictionary = kind.get("request", {})
		if not request.is_empty():
			if (not data.items.is_empty() and not data.items.has(String(request.get("item", "")))) or int(request.get("count", 0)) < 1 or int(request.get("days", 0)) < 1 or int(request.get("favor", -1)) < 0:
				errors.append("family.json letters kind %s has an invalid request (item, count >= 1, days >= 1, favor >= 0)" % kind.get("id", "?"))
		var effects: Dictionary = kind.get("effects", {})
		for item_id in effects.get("items", {}):
			if not data.items.is_empty() and not data.items.has(item_id):
				errors.append("family.json letters kind %s gives unknown item %s" % [kind.get("id", "?"), item_id])
	return errors
