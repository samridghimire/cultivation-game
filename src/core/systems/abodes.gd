class_name Abodes
extends RefCounted
## Cave abodes (G-010): the player may claim one dwelling (data/regions.json
## region "abodes") for spirit stones, keep items in its storage chest and
## cultivate there in seclusion at its qi density. An abode with an anchor_id
## can be bound as a Creation Artifact anchor.


## The abode def (with "region") for `abode_id`, or {}.
static func get_def(data: GameData, abode_id: String) -> Dictionary:
	return data.abodes.get(abode_id, {})


static func abode_name(data: GameData, abode_id: String) -> String:
	return String(get_def(data, abode_id).get("display_name", abode_id))


## Abode ids in `region_id`, in data order.
static func in_region(data: GameData, region_id: String) -> Array[String]:
	var out: Array[String] = []
	for abode: Dictionary in data.regions.get(region_id, {}).get("abodes", []):
		out.append(String(abode.get("id", "")))
	return out


## Whether `c` owns an abode in `region_id` (so they are "at home" there).
static func owns_in_region(c: CharacterData, data: GameData, region_id: String) -> bool:
	return c.abode != "" and String(get_def(data, c.abode).get("region", "")) == region_id


## Why `c` (standing in `region_id`) cannot claim `abode_id`, or "" if they can.
static func check_claim(c: CharacterData, data: GameData, abode_id: String, region_id: String) -> String:
	var def := get_def(data, abode_id)
	if def.is_empty() or String(def["region"]) != region_id:
		return "There is no abode to claim here."
	if c.abode == abode_id:
		return "This abode is already yours."
	var realm_id := String(def.get("min_realm", ""))
	if realm_id != "" and c.realm_index < data.realm_index_of(realm_id):
		return "The spirits of this place will not accept anyone below %s." % data.realms[data.realm_index_of(realm_id)].name
	if c.abode != "" and not c.abode_storage.is_empty():
		return "Empty the storage chest at %s before you leave it." % abode_name(data, c.abode)
	var cost := int(def.get("cost", 0))
	if c.item_count("spirit_stone") < cost:
		return "Claiming %s costs %d spirit stones." % [def.get("display_name", abode_id), cost]
	return ""


## Claims `abode_id` (giving up any previous abode). Returns {ok, reason, cost,
## previous (old abode id or ""), anchor_id (the abode's anchor or "")}.
static func claim(c: CharacterData, data: GameData, abode_id: String, region_id: String) -> Dictionary:
	var reason := check_claim(c, data, abode_id, region_id)
	if reason != "":
		return {"ok": false, "reason": reason, "cost": 0, "previous": "", "anchor_id": ""}
	var def := get_def(data, abode_id)
	var cost := int(def.get("cost", 0))
	var previous := c.abode
	c.add_item("spirit_stone", -cost)
	c.abode = abode_id
	return {"ok": true, "reason": "", "cost": cost, "previous": previous, "anchor_id": String(def.get("anchor_id", ""))}


## Qi density multiplier for cultivating in seclusion at `c`'s abode while in
## `region_id` (0.0 if they have no abode there).
static func seclusion_density(c: CharacterData, data: GameData, region_id: String) -> float:
	if not owns_in_region(c, data, region_id):
		return 0.0
	return float(get_def(data, c.abode).get("qi_density", 1.0))


static func storage_slots(c: CharacterData, data: GameData) -> int:
	return int(get_def(data, c.abode).get("storage_slots", 0)) if c.abode != "" else 0


static func check_store(c: CharacterData, data: GameData, region_id: String, item_id: String, quantity: int) -> String:
	if not owns_in_region(c, data, region_id):
		return "You have no abode here."
	if quantity < 1 or c.item_count(item_id) < quantity:
		return "You do not have enough."
	if not c.abode_storage.has(item_id) and c.abode_storage.size() >= storage_slots(c, data):
		return "The storage chest is full (%d kinds of items)." % storage_slots(c, data)
	return ""


## Moves items from the inventory into the abode chest. Returns {ok, reason}.
static func store(c: CharacterData, data: GameData, region_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	var reason := check_store(c, data, region_id, item_id, quantity)
	if reason != "":
		return {"ok": false, "reason": reason}
	c.add_item(item_id, -quantity)
	c.abode_storage[item_id] = int(c.abode_storage.get(item_id, 0)) + quantity
	return {"ok": true, "reason": ""}


## Moves items from the abode chest into the inventory. Returns {ok, reason}.
static func retrieve(c: CharacterData, data: GameData, region_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if not owns_in_region(c, data, region_id):
		return {"ok": false, "reason": "You have no abode here."}
	if quantity < 1 or int(c.abode_storage.get(item_id, 0)) < quantity:
		return {"ok": false, "reason": "There is not that much in the chest."}
	var left := int(c.abode_storage[item_id]) - quantity
	if left <= 0:
		c.abode_storage.erase(item_id)
	else:
		c.abode_storage[item_id] = left
	c.add_item(item_id, quantity)
	return {"ok": true, "reason": ""}


## Load errors for regions.json abodes.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for abode_id in data.abodes:
		var def: Dictionary = data.abodes[abode_id]
		if String(abode_id) == "":
			errors.append("Region '%s' has an abode without an id" % def["region"])
		if int(def.get("cost", -1)) < 0 or float(def.get("qi_density", 0.0)) <= 0.0 or int(def.get("storage_slots", 0)) < 1:
			errors.append("Abode '%s' needs cost >= 0, qi_density > 0 and storage_slots >= 1" % abode_id)
		var realm_id := String(def.get("min_realm", ""))
		if realm_id != "" and data.realm_index_of(realm_id) < 0:
			errors.append("Abode '%s' has unknown min_realm '%s'" % [abode_id, realm_id])
	return errors
