class_name ArtifactFunctions
extends RefCounted
## Sealed functions of the Creation Artifact (ART-002). The player feeds the
## artifact spirit stones and treasures for energy, then spends energy to
## unlock functions listed in data/artifact.json "functions" (each with realm,
## energy and flag conditions). The first function is the Storage Space: a
## separate item store that is never lost, even on death.

## Function ids this code implements; data/artifact.json may only list these.
const KNOWN := ["storage", "appraisal", "inner_world", "spirit_garden"]

## ART-011: how many recent gains the artifact remembers.
const GAINS_KEPT := 6
const SOURCE_ORDER := ["stage", "realm", "first_win", "discovery", "secret_realm_floor"]
const SOURCE_TEXT := {
	"stage": ["a new stage", "new stages", "each new stage"],
	"realm": ["a new realm", "new realms", "each new realm"],
	"first_win": ["first win over a foe", "first wins over foes", "each first win over a foe"],
	"discovery": ["a discovery", "discoveries", "each discovery"],
	"secret_realm_floor": ["a secret realm floor", "secret realm floors", "each secret realm floor"],
	"stones": ["spirit stones", "spirit stones", ""],
	"offering": ["an offering", "offerings", ""],
}


## The data/artifact.json function def for `function_id` ({} if none).
static func get_def(data: GameData, function_id: String) -> Dictionary:
	for def: Dictionary in data.artifact.get("functions", []):
		if String(def.get("id", "")) == function_id:
			return def
	return {}


static func function_name(data: GameData, function_id: String) -> String:
	return String(get_def(data, function_id).get("name", function_id))


static func is_unlocked(c: CharacterData, function_id: String) -> bool:
	return c.artifact_functions.has(function_id)


## Energy one `item_id` gives when fed to the artifact (0 = cannot be fed).
static func energy_value(data: GameData, item_id: String) -> int:
	var rules: Dictionary = data.artifact.get("energy", {})
	if item_id == "spirit_stone":
		return int(rules.get("stone_energy", 1))
	var price := int(data.items.get(item_id, {}).get("price", 0))
	return floori(price * float(rules.get("item_energy_per_price", 0.0)) * tag_mult(data, item_id))


## ART-013: the artifact's taste. The highest `energy.tag_mult` among the item's tags (1.0 when none match; 0 = refused).
static func tag_mult(data: GameData, item_id: String) -> float:
	var mults: Dictionary = data.artifact.get("energy", {}).get("tag_mult", {})
	var best := -1.0
	for tag: Variant in data.items.get(item_id, {}).get("tags", []):
		if mults.has(String(tag)):
			best = maxf(best, float(mults[String(tag)]))
	return 1.0 if best < 0.0 else best


## ART-013: what `c` can feed, best energy first: [{id, name, count, energy_each, sell_each}]. Skips 0-energy and equipped items.
static func feed_choices(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id: String in c.inventory:
		if item_id == "spirit_stone" or c.item_count(item_id) < 1 or c.equipment.values().has(item_id):
			continue
		var each := energy_value(data, item_id)
		if each <= 0:
			continue
		var def: Dictionary = data.items.get(item_id, {})
		out.append({"id": item_id, "name": String(def.get("name", item_id)), "count": c.item_count(item_id), "energy_each": each, "sell_each": int(def.get("price", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["energy_each"] != b["energy_each"]:
			return int(a["energy_each"]) > int(b["energy_each"])
		return String(a["id"]) < String(b["id"]))
	return out


## ART-009: energy one `kind` of progress gives (data energy.progress; 0 if absent).
static func progress_energy(data: GameData, kind: String, count: int = 1) -> int:
	return int(data.artifact.get("energy", {}).get("progress", {}).get(kind, 0)) * count


## ART-009: the artifact drinks `count` of `kind` progress, capped at max_energy.
## Returns the energy actually gained.
static func grant_progress(c: CharacterData, data: GameData, kind: String, count: int = 1, day: int = -1) -> int:
	var cap := int(data.artifact.get("energy", {}).get("max_energy", 0))
	var gained := clampi(progress_energy(data, kind, count), 0, maxi(cap - c.artifact_energy, 0))
	c.artifact_energy += gained
	if day >= 0:
		record_gain(c, kind, gained, day)
	return gained


## ART-011: remembers that `source` fed the artifact `amount` energy on `day` (merges same day and source).
static func record_gain(c: CharacterData, source: String, amount: int, day: int) -> void:
	if amount <= 0:
		return
	if not c.artifact_gains.is_empty():
		var last: Dictionary = c.artifact_gains[c.artifact_gains.size() - 1]
		if int(last.get("day", -1)) == day and String(last.get("source", "")) == source:
			last["amount"] = int(last.get("amount", 0)) + amount
			return
	c.artifact_gains.append({"day": day, "source": source, "amount": amount})
	while c.artifact_gains.size() > GAINS_KEPT:
		c.artifact_gains.pop_front()


## ART-011: "+15 a new stage".
static func gain_text(data: GameData, gain: Dictionary) -> String:
	var amount := int(gain.get("amount", 0))
	var names: Array = SOURCE_TEXT.get(String(gain.get("source", "")), ["something", "things", ""])
	var kind_id := String(gain.get("source", ""))
	var count := 1
	if SOURCE_ORDER.has(kind_id):
		var each := int(data.artifact.get("energy", {}).get("progress", {}).get(kind_id, 0))
		count = amount / each if each > 0 else 1
	return "+%d %s" % [amount, names[0] if count <= 1 else names[1]]


## ART-011: one short line per way to feed the artifact, from the data.
static func energy_sources(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for kind: String in SOURCE_ORDER:
		var value := progress_energy(data, kind)
		if value > 0:
			out.append("+%d %s" % [value, SOURCE_TEXT[kind][2]])
	var per_stone := int(data.artifact.get("energy", {}).get("stone_energy", 1))
	out.append("%d per spirit stone fed" % per_stone)
	return out


## ART-011: "Artifact: 55 / 100 energy toward Storage Space" for the cheapest unopened seal that is within reach, else "".
static func next_seal_line(c: CharacterData, data: GameData, flags: Dictionary) -> String:
	var best := {}
	for function_id: String in KNOWN:
		if get_def(data, function_id).is_empty():
			continue
		var st := status(c, data, function_id, flags)
		if st["state"] == "open":
			continue
		if st["state"] == "sealed" and not String(st["need"]).contains("energy"):
			continue
		if best.is_empty() or int(st["cost"]) < int(best["cost"]):
			best = st
	if best.is_empty():
		return ""
	return "Artifact: %d / %d energy toward %s" % [c.artifact_energy, int(best["cost"]), best["name"]]


## ART-014: "The artifact stirs: Boar Hide would feed it +N." for the best tasty item among `spoils` ({item_id: count}),
## only while a seal is still closed and `next_seal_line` would show. Refused items (tag_mult 0) never count.
static func spoils_hint(c: CharacterData, data: GameData, spoils: Dictionary, flags: Dictionary) -> String:
	if next_seal_line(c, data, flags) == "":
		return ""
	var best_id := ""
	var best := 0
	for item_id: String in spoils:
		if tag_mult(data, item_id) <= 1.0:
			continue
		var total := energy_value(data, item_id) * int(spoils[item_id])
		if total > best or (total == best and total > 0 and item_id < best_id):
			best = total
			best_id = item_id
	if best <= 0:
		return ""
	return "The artifact stirs: %s would feed it +%d." % [data.items.get(best_id, {}).get("name", best_id), best]


## ART-009: records the character's current progress as already credited.
static func sync_marks(c: CharacterData) -> void:
	c.artifact_marks = {"realm": c.realm_index, "stage": c.stage,
			"discoveries": LifeStats.get_stat(c, "discoveries"), "floors": LifeStats.get_stat(c, "realm_floors_cleared")}


## ART-009: credits what grew since the last call (stages, realms, discoveries, secret realm floors).
## The first call on a character only records the marks (older saves get no backlog). Returns energy gained.
static func drink_progress(c: CharacterData, data: GameData, day: int = -1) -> int:
	if c.artifact_marks.is_empty():
		sync_marks(c)
		return 0
	var gained := 0
	var realms := c.realm_index - int(c.artifact_marks.get("realm", 0))
	if realms > 0:
		gained += grant_progress(c, data, "realm", realms, day)
	else:
		var stages := c.stage - int(c.artifact_marks.get("stage", 0))
		if stages > 0:
			gained += grant_progress(c, data, "stage", stages, day)
	var found := LifeStats.get_stat(c, "discoveries") - int(c.artifact_marks.get("discoveries", 0))
	if found > 0:
		gained += grant_progress(c, data, "discovery", found, day)
	var floors := LifeStats.get_stat(c, "realm_floors_cleared") - int(c.artifact_marks.get("floors", 0))
	if floors > 0:
		gained += grant_progress(c, data, "secret_realm_floor", floors, day)
	sync_marks(c)
	return gained


## ART-009: the first defeat of `enemy_id` feeds the artifact once. Returns energy gained.
static func drink_first_win(c: CharacterData, data: GameData, enemy_id: String, day: int = -1) -> int:
	if enemy_id == "" or c.artifact_won.has(enemy_id):
		return 0
	c.artifact_won[enemy_id] = true
	return grant_progress(c, data, "first_win", 1, day)


## ART-009: ids of sealed functions that could be unsealed right now.
static func ready_to_unseal(c: CharacterData, data: GameData, flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in data.artifact.get("functions", []):
		var id := String(def.get("id", ""))
		if not is_unlocked(c, id) and check_unlock(c, data, id, flags) == "":
			out.append(id)
	return out


static func check_feed(c: CharacterData, data: GameData, item_id: String, quantity: int) -> String:
	if quantity < 1 or c.item_count(item_id) < quantity:
		return "You do not have enough."
	if tag_mult(data, item_id) <= 0.0:
		return "The artifact will not take this."
	if energy_value(data, item_id) <= 0:
		return "The artifact finds nothing worth devouring in that."
	if c.artifact_energy >= int(data.artifact.get("energy", {}).get("max_energy", 0)):
		return "The artifact is sated and will take no more."
	return ""


## Feeds `quantity` of `item_id` to the artifact (energy capped at max_energy).
## Returns {ok, reason, energy (gained)}.
static func feed(c: CharacterData, data: GameData, item_id: String, quantity: int = 1, day: int = -1) -> Dictionary:
	var reason := check_feed(c, data, item_id, quantity)
	if reason != "":
		return {"ok": false, "reason": reason, "energy": 0}
	var cap := int(data.artifact.get("energy", {}).get("max_energy", 0))
	var gained := mini(energy_value(data, item_id) * quantity, cap - c.artifact_energy)
	c.add_item(item_id, -quantity)
	c.artifact_energy += gained
	if day >= 0:
		record_gain(c, "stones" if item_id == "spirit_stone" else "offering", gained, day)
	return {"ok": true, "reason": "", "energy": gained}


## Why `c` cannot unlock `function_id` now, or "" if they can.
## `flags` are the world flags (GameState.world_flags).
static func check_unlock(c: CharacterData, data: GameData, function_id: String, flags: Dictionary) -> String:
	var def := get_def(data, function_id)
	if def.is_empty():
		return "The artifact holds no such power."
	if is_unlocked(c, function_id):
		return "%s is already unsealed." % def.get("name", function_id)
	var unlock: Dictionary = def.get("unlock", {})
	var realm_id := String(unlock.get("realm", ""))
	if realm_id != "" and c.realm_index < data.realm_index_of(realm_id):
		return "The seal on %s will not yield before %s." % [def.get("name", function_id), data.realms[data.realm_index_of(realm_id)].name]
	var needed := String(unlock.get("function", ""))
	if needed != "" and not is_unlocked(c, needed):
		return "%s must be unsealed first." % function_name(data, needed)
	var flag := String(unlock.get("flag", ""))
	if flag != "" and not flags.get(flag, false):
		return "Something is still missing before %s can awaken." % def.get("name", function_id)
	var cost := int(unlock.get("energy", 0))
	if c.artifact_energy < cost:
		return "Unsealing %s needs %d artifact energy (you have %d)." % [def.get("name", function_id), cost, c.artifact_energy]
	return ""


## WU-524: one power's card state: {id, name, state ("open" / "ready" / "sealed"), cost, need}.
## `need` is what is missing while sealed, without the power's name ("100 energy (you have 0)").
static func status(c: CharacterData, data: GameData, function_id: String, flags: Dictionary) -> Dictionary:
	var def := get_def(data, function_id)
	var unlock: Dictionary = def.get("unlock", {})
	var out := {"id": function_id, "name": String(def.get("name", function_id)), "state": "sealed",
			"cost": int(unlock.get("energy", 0)), "need": ""}
	if is_unlocked(c, function_id):
		out["state"] = "open"
		return out
	if check_unlock(c, data, function_id, flags) == "":
		out["state"] = "ready"
		return out
	var realm_id := String(unlock.get("realm", ""))
	var needed := String(unlock.get("function", ""))
	var flag := String(unlock.get("flag", ""))
	if def.is_empty():
		out["need"] = "no such power"
	elif realm_id != "" and c.realm_index < data.realm_index_of(realm_id):
		out["need"] = "reach %s" % data.realms[data.realm_index_of(realm_id)].name
	elif needed != "" and not is_unlocked(c, needed):
		out["need"] = "unseal %s first" % function_name(data, needed)
	elif flag != "" and not flags.get(flag, false):
		out["need"] = "something is still missing"
	else:
		out["need"] = "%d energy (you have %d)" % [out["cost"], c.artifact_energy]
	return out


## Spends the energy and unlocks `function_id`. Returns {ok, reason, energy (spent)}.
static func unlock(c: CharacterData, data: GameData, function_id: String, flags: Dictionary) -> Dictionary:
	var reason := check_unlock(c, data, function_id, flags)
	if reason != "":
		return {"ok": false, "reason": reason, "energy": 0}
	var cost := int(get_def(data, function_id).get("unlock", {}).get("energy", 0))
	c.artifact_energy -= cost
	c.artifact_functions.append(function_id)
	return {"ok": true, "reason": "", "energy": cost}


## Distinct item stacks the storage space holds (0 while sealed).
static func storage_slots(c: CharacterData, data: GameData) -> int:
	if not is_unlocked(c, "storage"):
		return 0
	return int(get_def(data, "storage").get("storage_slots", 0))


static func check_store(c: CharacterData, data: GameData, item_id: String, quantity: int) -> String:
	if not is_unlocked(c, "storage"):
		return "The artifact's storage space is still sealed."
	if quantity < 1 or c.item_count(item_id) < quantity:
		return "You do not have enough."
	if not c.artifact_storage.has(item_id) and c.artifact_storage.size() >= storage_slots(c, data):
		return "The storage space is full (%d kinds of items)." % storage_slots(c, data)
	return ""


## Moves items from the inventory into the storage space. Returns {ok, reason}.
static func store(c: CharacterData, data: GameData, item_id: String, quantity: int = 1) -> Dictionary:
	var reason := check_store(c, data, item_id, quantity)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item(item_id, -quantity)
	c.artifact_storage[item_id] = int(c.artifact_storage.get(item_id, 0)) + quantity
	return {"ok": true, "reason": ""}


## Moves items from the storage space back into the inventory. Returns {ok, reason}.
## Taking things out works even if the function were somehow sealed again.
static func retrieve(c: CharacterData, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity < 1 or int(c.artifact_storage.get(item_id, 0)) < quantity:
		return {"ok": false, "reason": "There is not that much in the storage space."}
	var left := int(c.artifact_storage[item_id]) - quantity
	if left <= 0:
		c.artifact_storage.erase(item_id)
	else:
		c.artifact_storage[item_id] = left
	c.add_item(item_id, quantity)
	return {"ok": true, "reason": ""}


## Display lines for the artifact screen / character sheet: energy, each
## function (unlocked, or its conditions), and storage contents.
static func describe(c: CharacterData, data: GameData, flags: Dictionary) -> Array[String]:
	var lines: Array[String] = ["Artifact energy: %d" % c.artifact_energy]
	for def: Dictionary in data.artifact.get("functions", []):
		var function_id := String(def.get("id", ""))
		if is_unlocked(c, function_id):
			lines.append("%s: unsealed" % def.get("name", function_id))
		else:
			var reason := check_unlock(c, data, function_id, flags)
			lines.append("%s: sealed (%s)" % [def.get("name", function_id), "ready to unseal" if reason == "" else reason])
	if is_unlocked(c, "storage"):
		lines.append("Storage: %d / %d kinds" % [c.artifact_storage.size(), storage_slots(c, data)])
		for item_id in c.artifact_storage:
			lines.append("  %s x%d" % [data.items.get(item_id, {}).get("name", item_id), int(c.artifact_storage[item_id])])
	return lines


## Load errors for data/artifact.json energy and functions.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var energy: Dictionary = data.artifact.get("energy", {})
	if int(energy.get("stone_energy", 0)) < 1 or int(energy.get("max_energy", 0)) < 1 or float(energy.get("item_energy_per_price", -1.0)) < 0.0:
		errors.append("artifact.json energy needs stone_energy >= 1, max_energy >= 1, item_energy_per_price >= 0")
	var used_tags := {}
	for item: Dictionary in data.items.values():
		for tag: Variant in item.get("tags", []):
			used_tags[String(tag)] = true
	var tag_mults: Variant = energy.get("tag_mult", {})
	if not (tag_mults is Dictionary):
		errors.append("artifact.json energy.tag_mult must be an object")
	else:
		for tag: String in tag_mults:
			if not (tag_mults[tag] is int or tag_mults[tag] is float) or float(tag_mults[tag]) < 0.0:
				errors.append("artifact.json energy.tag_mult.%s must be a number >= 0" % tag)
			elif not used_tags.has(tag):
				errors.append("artifact.json energy.tag_mult.%s: no item has that tag" % tag)
	var seen := {}
	for def: Dictionary in data.artifact.get("functions", []):
		var function_id := String(def.get("id", ""))
		if not KNOWN.has(function_id):
			errors.append("artifact.json function '%s' is not implemented (known: %s)" % [function_id, ", ".join(KNOWN)])
		if seen.has(function_id):
			errors.append("artifact.json function '%s' is listed twice" % function_id)
		seen[function_id] = true
		var unlock: Dictionary = def.get("unlock", {})
		var realm_id := String(unlock.get("realm", ""))
		if realm_id != "" and data.realm_index_of(realm_id) < 0:
			errors.append("artifact.json function '%s' has unknown realm '%s'" % [function_id, realm_id])
		if unlock.has("function") and not KNOWN.has(String(unlock["function"])):
			errors.append("artifact.json function '%s' needs unknown function '%s'" % [function_id, unlock["function"]])
		if def.has("flavor") and not (def["flavor"] is String):
			errors.append("artifact.json function '%s' flavor must be text" % function_id)
		if int(unlock.get("energy", 0)) < 0:
			errors.append("artifact.json function '%s' needs energy >= 0" % function_id)
		if function_id == "storage" and int(def.get("storage_slots", 0)) < 1:
			errors.append("artifact.json storage needs storage_slots >= 1")
	errors.append_array(Appraisal.validate(data))
	errors.append_array(InnerWorld.validate(data))
	errors.append_array(SpiritGarden.validate(data))
	return errors
