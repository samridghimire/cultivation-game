class_name Karma
extends RefCounted
## Grudges and gratitude (RIV-001). Rules in data/karma.json.
##
## The ledgers live on the wronged/indebted side's counterpart: c.grudges[npc_id]
## is how much that NPC hates `c`, c.gratitude[npc_id] how much they owe `c`.
## Hostile acts (humiliate, rob, kill) raise the victim's grudge and spread a
## kin_grudge to their living parents, children and spouses, so killing a man
## earns you his son's hatred. Making amends with spirit stones clears a grudge.


static func act(data: GameData, act_id: String) -> Dictionary:
	return data.karma.get("acts", {}).get(act_id, {})


## Act ids in data order.
static func act_ids(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for act_id in data.karma.get("acts", {}):
		out.append(String(act_id))
	return out


static func grudge(c: CharacterData, npc_id: String) -> int:
	return int(c.grudges.get(npc_id, 0))


static func gratitude(c: CharacterData, npc_id: String) -> int:
	return int(c.gratitude.get(npc_id, 0))


## Adds (or with a negative amount removes) grudge, capped at max_grudge.
## A grudge at 0 is dropped from the ledger. Returns the new value.
static func add_grudge(c: CharacterData, data: GameData, npc_id: String, amount: int) -> int:
	return _add(c.grudges, npc_id, amount, int(data.karma.get("max_grudge", 100)))


static func add_gratitude(c: CharacterData, data: GameData, npc_id: String, amount: int) -> int:
	return _add(c.gratitude, npc_id, amount, int(data.karma.get("max_gratitude", 100)))


static func _add(ledger: Dictionary, npc_id: String, amount: int, cap: int) -> int:
	var value := clampi(int(ledger.get(npc_id, 0)) + amount, 0, cap)
	if value == 0:
		ledger.erase(npc_id)
	else:
		ledger[npc_id] = value
	return value


static func _is_family(c: CharacterData, other: CharacterData) -> bool:
	return c.spouses.has(other.id) or c.children.has(other.id) or c.parents.has(other.id) \
		or other.spouses.has(c.id) or other.children.has(c.id) or other.parents.has(c.id)


## Living parents, children and spouses of `npc` in `people` (never `exclude`).
static func kin_of(npc: CharacterData, people: Dictionary, exclude: String = "player") -> Array[String]:
	var out: Array[String] = []
	for id in npc.parents + npc.children + npc.spouses:
		if id != exclude and not out.has(id) and people.has(id) and Family.is_living(id, people):
			out.append(id)
	return out


## Why `c` cannot commit `act_id` against `npc` ("" = allowed).
static func check_act(c: CharacterData, npc: CharacterData, act_id: String, data: GameData) -> String:
	var a := act(data, act_id)
	if a.is_empty():
		return "Unknown act."
	if npc == null or not npc.alive:
		return "There is no one here."
	if npc.age_years() < int(data.family.get("adult_age", 16)):
		return "Even you will not harm a child."
	if _is_family(c, npc):
		return "You will not raise a hand against your own family."
	if bool(a.get("requires_stronger", false)) and c.realm_index <= npc.realm_index:
		return "%s is not weaker than you." % npc.name
	return ""


## Enemy dictionary (data/enemies.json format) for fighting `npc`. Losing to an
## NPC is never lethal: they beat you and take some of your stones.
static func npc_enemy(npc: CharacterData, data: GameData) -> Dictionary:
	return {
		"id": npc.id,
		"name": npc.name,
		"realm": data.realms[npc.realm_index].id,
		"stage": npc.stage,
		"lethal": false,
		"techniques": npc.techniques.keys(),
		"rewards": {},
	}


## Applies `act_id` after its fight (if any) ended with `won`. Changes `c`
## (alignment, loot, grudges) and `npc` (death, lost items). Returns
## {notes: PackedStringArray, favor: int (victim's favor change), days: int,
## kin: Array[String] (kin who now hold a grudge)}. Call check_act first.
static func commit(c: CharacterData, npc: CharacterData, act_id: String, won: bool, people: Dictionary, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var a := act(data, act_id)
	var notes: PackedStringArray = []
	var kin: Array[String] = []
	if not won:
		var failed := int(a.get("failed_grudge", 0))
		if failed > 0:
			add_grudge(c, data, npc.id, failed)
			notes.append("%s will not forget this" % npc.name)
		return {"notes": notes, "favor": int(a.get("favor", 0)), "days": 0, "kin": kin}
	var before := c.alignment
	Alignment.shift(c, data, int(a.get("alignment", 0)))
	if c.alignment != before:
		notes.append("Alignment %+d" % (c.alignment - before))
	var loot: Array = a.get("loot_stones", [])
	if loot.size() == 2:
		var stones := rng.randi_range(int(loot[0]), int(loot[1])) * (npc.realm_index + 1)
		c.add_item("spirit_stone", stones)
		notes.append("+%d Spirit Stone" % stones)
		for item_id in npc.inventory.keys():
			c.add_item(item_id, npc.item_count(item_id))
			notes.append("+%d %s" % [npc.item_count(item_id), data.items.get(item_id, {}).get("name", item_id)])
		npc.inventory.clear()
	if bool(a.get("kills", false)):
		npc.alive = false
		npc.cause_of_death = "slain by %s" % c.name
		c.grudges.erase(npc.id)
		c.gratitude.erase(npc.id)
	elif int(a.get("grudge", 0)) > 0:
		add_grudge(c, data, npc.id, int(a["grudge"]))
	var kin_amount := int(a.get("kin_grudge", 0))
	if kin_amount > 0:
		for kin_id in kin_of(npc, people, c.id):
			var relative: CharacterData = people.get(kin_id)
			if relative != null and _is_family(c, relative):
				continue
			add_grudge(c, data, kin_id, kin_amount)
			kin.append(kin_id)
	if not kin.is_empty():
		notes.append("%d of their kin swear vengeance" % kin.size())
	return {"notes": notes, "favor": int(a.get("favor", 0)), "days": int(a.get("days", 0)), "kin": kin}


## Spirit stones it takes to make amends with `npc_id` (0 = no grudge).
static func amends_cost(c: CharacterData, npc_id: String, data: GameData) -> int:
	var g := grudge(c, npc_id)
	if g <= 0:
		return 0
	var rules: Dictionary = data.karma.get("amends", {})
	return maxi(int(rules.get("min_cost", 0)), g * int(rules.get("stones_per_point", 1)))


static func check_amends(c: CharacterData, npc: CharacterData, data: GameData) -> String:
	if npc == null or not npc.alive:
		return "There is no one here."
	var cost := amends_cost(c, npc.id, data)
	if cost <= 0:
		return "%s holds no grudge against you." % npc.name
	if c.item_count("spirit_stone") < cost:
		return "Making amends needs %d spirit stones." % cost
	return ""


## Pays spirit stones to clear `npc`'s grudge. Returns {ok, reason, cost}.
static func make_amends(c: CharacterData, npc: CharacterData, data: GameData) -> Dictionary:
	var reason := check_amends(c, npc, data)
	if reason != "":
		return {"ok": false, "reason": reason, "cost": 0}
	var cost := amends_cost(c, npc.id, data)
	c.add_item("spirit_stone", -cost)
	c.grudges.erase(npc.id)
	return {"ok": true, "reason": "", "cost": cost}


## Grudge points that fade between two ages (whole years crossed x decay_per_year).
@warning_ignore("integer_division")
static func decay_amount(data: GameData, age_days_before: int, age_days_after: int) -> int:
	var years := age_days_after / Calendar.DAYS_PER_YEAR - age_days_before / Calendar.DAYS_PER_YEAR
	return maxi(0, years) * int(data.karma.get("decay_per_year", 0))


## Fades every grudge by `amount`; grudges that reach 0 are forgotten.
static func decay(c: CharacterData, data: GameData, amount: int) -> void:
	if amount <= 0:
		return
	for npc_id in c.grudges.keys():
		add_grudge(c, data, npc_id, -amount)


## Lines for the character sheet: living people who hate or owe `c`, strongest first.
static func describe(c: CharacterData, people: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry in [[c.grudges, "Grudge"], [c.gratitude, "Owes you"]]:
		var ledger: Dictionary = entry[0]
		var ids: Array = ledger.keys().filter(func(id: Variant) -> bool: return Family.is_living(String(id), people))
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(ledger[a]) > int(ledger[b]))
		for id in ids:
			var who: CharacterData = people.get(id)
			out.append("%s: %s (%d)" % [entry[1], who.name if who != null else String(id), int(ledger[id])])
	return out


## Sentences for an NPC's "Look" text: how much `npc` hates or owes `c`, in
## words from data/karma.json "attitudes" (empty when neither ledger has them).
static func attitude(c: CharacterData, npc: CharacterData, data: GameData) -> Array[String]:
	var out: Array[String] = []
	var attitudes: Dictionary = data.karma.get("attitudes", {})
	for entry in [["grudge", grudge(c, npc.id)], ["gratitude", gratitude(c, npc.id)]]:
		var sentence := ""
		for tier: Array in attitudes.get(entry[0], []):
			if int(entry[1]) >= int(tier[0]):
				sentence = String(tier[1])
		if sentence != "":
			out.append(sentence.replace("{name}", npc.name))
	return out


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.karma.is_empty():
		return errors
	for a: Dictionary in data.karma.get("acts", {}).values():
		var loot: Array = a.get("loot_stones", [])
		if not loot.is_empty() and (loot.size() != 2 or int(loot[0]) > int(loot[1]) or int(loot[0]) < 0):
			errors.append("karma act '%s': loot_stones must be [min, max]" % a.get("id", "?"))
		for key in ["grudge", "kin_grudge", "failed_grudge", "days"]:
			if int(a.get(key, 0)) < 0:
				errors.append("karma act '%s': %s must not be negative" % [a.get("id", "?"), key])
		if String(a.get("name", "")) == "":
			errors.append("karma act '%s' has no name" % a.get("id", "?"))
	for ledger in ["grudge", "gratitude"]:
		var last := 0
		for tier: Variant in data.karma.get("attitudes", {}).get(ledger, []):
			if not tier is Array or tier.size() != 2 or int(tier[0]) <= last or String(tier[1]) == "":
				errors.append("karma attitudes.%s: tiers must be [min_points > 0, sentence] in ascending order" % ledger)
				break
			last = int(tier[0])
	return errors
