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
static func monthly(c: CharacterData, npcs: Dictionary, favor: Dictionary, data: GameData, rng: RandomNumberGenerator, flags: Dictionary) -> Dictionary:
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
		return {"npc_id": id, "text": text, "notes": notes}
	return {}


## Extra favor for a chat with `npc_id` after an invitation; consumes it.
static func take_visit_bonus(npc_id: String, data: GameData, flags: Dictionary) -> int:
	if not flags.has(visit_flag(npc_id)):
		return 0
	flags.erase(visit_flag(npc_id))
	return int(rules(data).get("visit_favor", 0))


## Remembers a letter (newest last), keeping data's `max_kept`.
static func remember(c: CharacterData, data: GameData, line: String) -> void:
	c.letters.append(line)
	var keep := maxi(1, int(rules(data).get("max_kept", 10)))
	while c.letters.size() > keep:
		c.letters.pop_front()


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
		var effects: Dictionary = kind.get("effects", {})
		for item_id in effects.get("items", {}):
			if not data.items.is_empty() and not data.items.has(item_id):
				errors.append("family.json letters kind %s gives unknown item %s" % [kind.get("id", "?"), item_id])
	return errors
