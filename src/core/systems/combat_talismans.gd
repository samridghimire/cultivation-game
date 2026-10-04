class_name CombatTalismans
extends RefCounted
## Talismans burned during a fight (G-005b). An item with a `combat` block in
## data/items.json ({kind, grade, power}) can be readied (CharacterData.
## readied_talismans, at most MAX_READIED kinds of item). Combat.resolve uses one
## of each readied talisman the player still carries:
## - strike: an opening blow of `power` damage, scaled by the talisman grade,
## - shield: a barrier absorbing `power` damage, scaled by the grade,
## - escape: only on a defeat; turns it into a flight with no further losses.
## Combat.apply_outcome then consumes the talismans that were burned.

const KINDS: Array[String] = ["strike", "shield", "escape"]
const MAX_READIED := 3


static func combat_def(data: GameData, item_id: String) -> Dictionary:
	return data.items.get(item_id, {}).get("combat", {})


static func is_combat_talisman(data: GameData, item_id: String) -> bool:
	return not combat_def(data, item_id).is_empty()


static func kind_of(data: GameData, item_id: String) -> String:
	return String(combat_def(data, item_id).get("kind", ""))


## Damage dealt (strike) or absorbed (shield): power times the combat power of
## the realm matching the grade (grade 1 = mortal, 2 = Qi Refining, ...).
static func amount(data: GameData, item_id: String) -> int:
	var def := combat_def(data, item_id)
	return roundi(float(def.get("power", 0)) * Combat.realm_power(maxi(0, int(def.get("grade", 1)) - 1), 0))


## Why `c` cannot ready `item_id`, or "" if they can.
static func check_ready(c: CharacterData, data: GameData, item_id: String) -> String:
	if not is_combat_talisman(data, item_id):
		return "That cannot be used in battle."
	if c.item_count(item_id) <= 0:
		return "You have no %s." % data.items[item_id].get("name", item_id)
	if c.readied_talismans.has(item_id):
		return "That talisman is already readied."
	if _carried_readied(c).size() >= MAX_READIED:
		return "You can only keep %d kinds of talisman at hand." % MAX_READIED
	return ""


## Readies `item_id`; readied talismans `c` has run out of give up their slot.
static func ready_talisman(c: CharacterData, data: GameData, item_id: String) -> String:
	var reason := check_ready(c, data, item_id)
	if reason == "":
		c.readied_talismans = _carried_readied(c)
		c.readied_talismans.append(item_id)
	return reason


## Readied talismans `c` still carries at least one of.
static func _carried_readied(c: CharacterData) -> Array[String]:
	var out: Array[String] = []
	for item_id in c.readied_talismans:
		if c.item_count(item_id) > 0:
			out.append(item_id)
	return out


static func unready_talisman(c: CharacterData, item_id: String) -> bool:
	if not c.readied_talismans.has(item_id):
		return false
	c.readied_talismans.erase(item_id)
	return true


## Readied talismans of `kind` that `c` still carries, in readied order.
static func available(c: CharacterData, data: GameData, kind: String) -> Array[String]:
	var out: Array[String] = []
	for item_id in c.readied_talismans:
		if kind_of(data, item_id) == kind and c.item_count(item_id) > 0:
			out.append(item_id)
	return out


## Removes one of each burned talisman from the inventory. Returns their names.
static func consume(c: CharacterData, data: GameData, used: Array) -> PackedStringArray:
	var names: PackedStringArray = []
	for item_id in used:
		if c.item_count(String(item_id)) > 0:
			c.add_item(String(item_id), -1)
			names.append(String(data.items.get(item_id, {}).get("name", item_id)))
	return names


## Load errors for `combat` blocks in data/items.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for item: Dictionary in data.items.values():
		if not item.has("combat"):
			continue
		var def: Dictionary = item["combat"]
		var kind := String(def.get("kind", ""))
		if not KINDS.has(kind):
			errors.append("Item '%s' has unknown combat kind '%s'" % [item["id"], kind])
		if int(def.get("grade", 0)) < 1 or int(def.get("grade", 0)) > data.realms.size():
			errors.append("Item '%s' needs combat grade 1..%d" % [item["id"], data.realms.size()])
		if kind != "escape" and float(def.get("power", 0)) <= 0.0:
			errors.append("Item '%s' needs combat power > 0" % item["id"])
	return errors
