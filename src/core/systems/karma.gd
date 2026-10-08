class_name Karma
extends RefCounted
## Grudges and gratitude (RIV-001). Rules in data/karma.json.
##
## The ledgers live on the wronged/indebted side's counterpart: c.grudges[npc_id]
## is how much that NPC hates `c`, c.gratitude[npc_id] how much they owe `c`.
## Hostile acts (humiliate, rob, kill) raise the victim's grudge and spread a
## kin_grudge to their living parents, children and spouses, so killing a man
## earns you his son's hatred. Making amends with spirit stones clears a grudge.
## RIV-001e: healing and gifts earn gratitude (karma.json `gratitude`); grateful
## NPCs warm to you faster and now and then repay the debt with a gift.


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
		"proper_name": true,
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
	var looted := 0
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
		LifeStats.record_stones(c, stones)
		looted = stones
		notes.append("+%d Spirit Stone" % stones)
		for item_id in npc.inventory.keys():
			c.add_item(item_id, npc.item_count(item_id))
			notes.append("+%d %s" % [npc.item_count(item_id), data.items.get(item_id, {}).get("name", item_id)])
		npc.inventory.clear()
	if bool(a.get("kills", false)):
		if Npcs.die(npc, "slain by %s" % c.name):
			notes.append("the unborn child dies with them")
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
	return {"notes": notes, "favor": int(a.get("favor", 0)), "days": int(a.get("days", 0)), "kin": kin, "stones": looted}


## One sentence for a committed act, from the result of commit().
static func act_sentence(npc: CharacterData, act_id: String, result: Dictionary) -> String:
	match act_id:
		"rob":
			var stones := int(result.get("stones", 0))
			return "You rob %s of %d spirit stone%s." % [npc.name, stones, "" if stones == 1 else "s"]
		"humiliate":
			return "You humiliate %s before onlookers." % npc.name
		"kill":
			return "You kill %s." % npc.name
	return "You act against %s." % npc.name


static func _gratitude_rules(data: GameData) -> Dictionary:
	return data.karma.get("gratitude", {})


## Gratitude earned from a kind act (karma.json gratitude.sources, e.g.
## "treat_npc", "gift"). Adds it to `npc_id`'s ledger and returns the amount.
static func on_kindness(c: CharacterData, data: GameData, npc_id: String, source: String) -> int:
	var amount := int(_gratitude_rules(data).get("sources", {}).get(source, 0))
	if amount <= 0:
		return 0
	var before := gratitude(c, npc_id)
	return add_gratitude(c, data, npc_id, amount) - before


## Extra favor a grateful NPC gives on top of `gain` (gain x gratitude x
## favor_bonus_per_point, rounded down), never more than `room`.
static func favor_bonus(c: CharacterData, data: GameData, npc_id: String, gain: int, room: int) -> int:
	if gain <= 0:
		return 0
	var bonus := int(gain * gratitude(c, npc_id) * float(_gratitude_rules(data).get("favor_bonus_per_point", 0.0)))
	return clampi(bonus, 0, maxi(0, room))


## Grateful NPCs repay their debt over `months`: each living NPC owing at least
## repay.min_gratitude has chance_per_month to send spirit stones (stones_per_realm
## [min, max] x (their realm index + 1)) plus one weighted gift, which spends
## repay.cost gratitude. Returns [{npc_id, notes}].
static func repay_debts(c: CharacterData, people: Dictionary, data: GameData, months: int, rng: RandomNumberGenerator, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rules: Dictionary = _gratitude_rules(data).get("repay", {})
	if rules.is_empty() or months <= 0:
		return out
	var ids: Array = c.gratitude.keys()
	ids.sort()
	for npc_id in ids:
		var npc: CharacterData = people.get(npc_id)
		if npc == null or not npc.alive:
			continue
		for i in months:
			if gratitude(c, npc_id) < int(rules.get("min_gratitude", 1)) or rng.randf() >= float(rules.get("chance_per_month", 0.0)):
				continue
			out.append({"npc_id": String(npc_id), "notes": _repay(c, npc, rules, data, rng, flags)})
			add_gratitude(c, data, npc_id, -int(rules.get("cost", 0)))
	return out


static func _repay(c: CharacterData, npc: CharacterData, rules: Dictionary, data: GameData, rng: RandomNumberGenerator, flags: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	var range_: Array = rules.get("stones_per_realm", [])
	if range_.size() == 2:
		var stones := rng.randi_range(int(range_[0]), int(range_[1])) * (npc.realm_index + 1)
		if stones > 0:
			c.add_item("spirit_stone", stones)
			LifeStats.record_stones(c, stones)
			notes.append("+%d Spirit Stone" % stones)
	var total := 0
	for gift: Dictionary in rules.get("gifts", []):
		total += maxi(0, int(gift.get("weight", 1)))
	if total > 0:
		var roll := rng.randi_range(1, total)
		for gift: Dictionary in rules.get("gifts", []):
			roll -= maxi(0, int(gift.get("weight", 1)))
			if roll <= 0:
				notes.append_array(Effects.apply(c, data, gift.get("effects", {}), flags))
				break
	return notes


# --- Hunting the player (RIV-003) -----------------------------------------------

static func _hunt_rules(data: GameData) -> Dictionary:
	return data.karma.get("hunt", {})


## Chance that `npc` ambushes `c` after a journey (0 below hunt.min_grudge).
static func hunt_chance(c: CharacterData, npc: CharacterData, data: GameData) -> float:
	var r := _hunt_rules(data)
	var g := grudge(c, npc.id)
	if r.is_empty() or g < int(r.get("min_grudge", 1)):
		return 0.0
	var chance := minf(float(r.get("max_chance", 1.0)), g * float(r.get("chance_per_point", 0.0)))
	return chance * pow(float(r.get("weaker_scale", 1.0)), maxi(0, c.realm_index - npc.realm_index))


## The living NPC with the strongest grudge (ties by id) if it decides to
## ambush `c` on the road; "" if nobody does. `chance_scale` multiplies the
## chance (a clan estate's ward at the destination).
static func roll_hunter(c: CharacterData, people: Dictionary, data: GameData, rng: RandomNumberGenerator, chance_scale: float = 1.0) -> String:
	var best := ""
	var family := Children.descendants(c, people)
	for npc_id in c.grudges:
		var npc: CharacterData = people.get(npc_id)
		if npc == null or not npc.alive or family.has(npc_id):
			continue
		if best == "" or grudge(c, npc_id) > grudge(c, best) or (grudge(c, npc_id) == grudge(c, best) and String(npc_id) < best):
			best = String(npc_id)
	if best == "" or rng.randf() >= hunt_chance(c, people[best], data) * chance_scale:
		return ""
	return best


## The grateful NPC who comes to `c`'s aid in an ambush, or "". Spends their
## gratitude and grants the aid buff when they come.
static func roll_ally(c: CharacterData, people: Dictionary, data: GameData, rng: RandomNumberGenerator, hunter_id: String) -> String:
	var aid: Dictionary = _hunt_rules(data).get("aid", {})
	if aid.is_empty():
		return ""
	var best := ""
	for npc_id in c.gratitude:
		var npc: CharacterData = people.get(npc_id)
		if npc == null or not npc.alive or npc_id == hunter_id or gratitude(c, npc_id) < int(aid.get("min_gratitude", 1)):
			continue
		if best == "" or gratitude(c, npc_id) > gratitude(c, best):
			best = String(npc_id)
	if best == "" or rng.randf() >= float(aid.get("chance", 0.0)):
		return ""
	add_gratitude(c, data, best, -int(aid.get("gratitude_cost", 0)))
	Buffs.add_from_effect(c, aid.get("buff", {}))
	return best


## RIV-001f: the grateful NPC who joins a fight `c` starts in `region_id`: the
## most grateful living adult there owing at least ally_strike.min_gratitude,
## other than `exclude_id` (the foe), or "".
static func strike_ally(c: CharacterData, people: Dictionary, data: GameData, region_id: String, exclude_id: String = "") -> String:
	var rules: Dictionary = _gratitude_rules(data).get("ally_strike", {})
	if rules.is_empty():
		return ""
	var best := ""
	for npc_id in c.gratitude:
		var npc: CharacterData = people.get(npc_id)
		if npc == null or not npc.alive or npc_id == exclude_id or Npcs.region_of(npc, data) != region_id:
			continue
		if npc.age_years() < int(data.family.get("adult_age", 16)) or gratitude(c, npc_id) < int(rules.get("min_gratitude", 1)):
			continue
		if best == "" or gratitude(c, npc_id) > gratitude(c, best):
			best = String(npc_id)
	return best


## `ally_id` strikes for `c`: {name, damage} (ally_strike.blows x their attack),
## spending ally_strike.cost of their gratitude.
static func ally_strike(c: CharacterData, people: Dictionary, data: GameData, ally_id: String) -> Dictionary:
	var rules: Dictionary = _gratitude_rules(data).get("ally_strike", {})
	var ally: CharacterData = people[ally_id]
	add_gratitude(c, data, ally_id, -int(rules.get("cost", 0)))
	var damage := int(Combat.stats(ally, data)["attack"]) * int(rules.get("blows", 1))
	return {"name": ally.name, "damage": maxi(1, damage)}


## After an ambush by `npc_id`: beating them humbles them, losing to them
## partly satisfies their vengeance (hunt.beaten_grudge / victory_grudge).
static func after_hunt(c: CharacterData, data: GameData, npc_id: String, player_won: bool) -> void:
	var r := _hunt_rules(data)
	add_grudge(c, data, npc_id, int(r.get("beaten_grudge" if player_won else "victory_grudge", 0)))


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


## A grudge value in words (data/karma.json "grudge_words": [[min_points, word], ...]).
static func grudge_word(value: int, data: GameData) -> String:
	var word := "a slight"
	for tier: Array in data.karma.get("grudge_words", []):
		if value >= int(tier[0]):
			word = String(tier[1])
	return word


## Lines for the character sheet: living people who hate or owe `c`, strongest first.
static func describe(c: CharacterData, people: Dictionary, data: GameData = null) -> Array[String]:
	var out: Array[String] = []
	for entry in [[c.grudges, "Grudge"], [c.gratitude, "Owes you"]]:
		var ledger: Dictionary = entry[0]
		var ids: Array = ledger.keys().filter(func(id: Variant) -> bool: return Family.is_living(String(id), people))
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(ledger[a]) > int(ledger[b]))
		for id in ids:
			var who: CharacterData = people.get(id)
			var shown := who.name if who != null else "someone long gone"
			if data != null and entry[0] == c.grudges:
				out.append("%s: %s (%s, %d)" % [entry[1], shown, grudge_word(int(ledger[id]), data), int(ledger[id])])
			else:
				out.append("%s: %s (%d)" % [entry[1], shown, int(ledger[id])])
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
	var hunt := _hunt_rules(data)
	for key in ["chance_per_point", "max_chance", "weaker_scale"]:
		if hunt.has(key) and (float(hunt[key]) < 0.0 or float(hunt[key]) > 1.0):
			errors.append("karma.json hunt %s must be in 0..1" % key)
	var aid: Dictionary = hunt.get("aid", {})
	if not aid.is_empty():
		if float(aid.get("chance", 0.0)) < 0.0 or float(aid.get("chance", 0.0)) > 1.0:
			errors.append("karma.json hunt aid chance must be in 0..1")
		for key in aid.get("buff", {}).get("mults", {}):
			if not Buffs.STAT_KEYS.has(key):
				errors.append("karma.json hunt aid buff has unknown stat '%s'" % key)
	for a: Dictionary in data.karma.get("acts", {}).values():
		var loot: Array = a.get("loot_stones", [])
		if not loot.is_empty() and (loot.size() != 2 or int(loot[0]) > int(loot[1]) or int(loot[0]) < 0):
			errors.append("karma act '%s': loot_stones must be [min, max]" % a.get("id", "?"))
		for key in ["grudge", "kin_grudge", "failed_grudge", "days"]:
			if int(a.get(key, 0)) < 0:
				errors.append("karma act '%s': %s must not be negative" % [a.get("id", "?"), key])
		if String(a.get("name", "")) == "":
			errors.append("karma act '%s' has no name" % a.get("id", "?"))
	var rules := _gratitude_rules(data)
	for source in rules.get("sources", {}):
		if int(rules["sources"][source]) < 0:
			errors.append("karma gratitude source '%s' must not be negative" % source)
	var repay: Dictionary = rules.get("repay", {})
	var range_: Array = repay.get("stones_per_realm", [])
	if not range_.is_empty() and (range_.size() != 2 or int(range_[0]) > int(range_[1]) or int(range_[0]) < 0):
		errors.append("karma gratitude repay.stones_per_realm must be [min, max]")
	if not repay.is_empty() and int(repay.get("cost", 0)) <= 0:
		errors.append("karma gratitude repay.cost must be positive")
	for gift: Dictionary in repay.get("gifts", []):
		for item_id in gift.get("effects", {}).get("items", {}):
			if not data.items.has(item_id):
				errors.append("karma gratitude repay gift has unknown item '%s'" % item_id)
	var last_word := -1
	for tier: Variant in data.karma.get("grudge_words", []):
		if not tier is Array or tier.size() != 2 or int(tier[0]) <= last_word or String(tier[1]) == "":
			errors.append("karma grudge_words: tiers must be [min_points, word] in ascending order")
			break
		last_word = int(tier[0])
	for ledger in ["grudge", "gratitude"]:
		var last := 0
		for tier: Variant in data.karma.get("attitudes", {}).get(ledger, []):
			if not tier is Array or tier.size() != 2 or int(tier[0]) <= last or String(tier[1]) == "":
				errors.append("karma attitudes.%s: tiers must be [min_points > 0, sentence] in ascending order" % ledger)
				break
			last = int(tier[0])
	return errors
