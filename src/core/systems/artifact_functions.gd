class_name ArtifactFunctions
extends RefCounted
## Sealed functions of the Creation Artifact (ART-002). The player feeds the
## artifact spirit stones and treasures for energy, then spends energy to
## unlock functions listed in data/artifact.json "functions" (each with realm,
## energy and flag conditions). The first function is the Storage Space: a
## separate item store that is never lost, even on death.

## Function ids this code implements; data/artifact.json may only list these.
const KNOWN := ["storage", "appraisal"]


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
	return floori(price * float(rules.get("item_energy_per_price", 0.0)))


static func check_feed(c: CharacterData, data: GameData, item_id: String, quantity: int) -> String:
	if quantity < 1 or c.item_count(item_id) < quantity:
		return "You do not have enough."
	if energy_value(data, item_id) <= 0:
		return "The artifact finds nothing worth devouring in that."
	if c.artifact_energy >= int(data.artifact.get("energy", {}).get("max_energy", 0)):
		return "The artifact is sated and will take no more."
	return ""


## Feeds `quantity` of `item_id` to the artifact (energy capped at max_energy).
## Returns {ok, reason, energy (gained)}.
static func feed(c: CharacterData, data: GameData, item_id: String, quantity: int = 1) -> Dictionary:
	var reason := check_feed(c, data, item_id, quantity)
	if reason != "":
		return {"ok": false, "reason": reason, "energy": 0}
	var cap := int(data.artifact.get("energy", {}).get("max_energy", 0))
	var gained := mini(energy_value(data, item_id) * quantity, cap - c.artifact_energy)
	c.add_item(item_id, -quantity)
	c.artifact_energy += gained
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
	var flag := String(unlock.get("flag", ""))
	if flag != "" and not flags.get(flag, false):
		return "Something is still missing before %s can awaken." % def.get("name", function_id)
	var cost := int(unlock.get("energy", 0))
	if c.artifact_energy < cost:
		return "Unsealing %s needs %d artifact energy (you have %d)." % [def.get("name", function_id), cost, c.artifact_energy]
	return ""


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
		if int(unlock.get("energy", 0)) < 0:
			errors.append("artifact.json function '%s' needs energy >= 0" % function_id)
		if function_id == "storage" and int(def.get("storage_slots", 0)) < 1:
			errors.append("artifact.json storage needs storage_slots >= 1")
	errors.append_array(Appraisal.validate(data))
	return errors
