class_name Equipment
extends RefCounted
## Equippable artifacts (weapons, armor) forged by Blacksmiths. An item is
## equipment if it has an `equip` block in data/items.json:
## {"slot": one of SLOTS, "grade": int >= 1, "stats": {stat: flat bonus}}.
## Equipping moves the item out of the inventory into CharacterData.equipment;
## the bonuses are added flat to Combat.stats (before injuries and buffs scale them).

const SLOTS: PackedStringArray = ["weapon", "armor"]
const STAT_KEYS: PackedStringArray = ["attack", "defense", "max_hp", "speed"]


static func is_equipment(data: GameData, item_id: String) -> bool:
	return data.items.get(item_id, {}).has("equip")


static func slot_of(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("equip", {}).get("slot", ""))


## Why `c` cannot equip `item_id`, or "" if they can.
static func check_equip(c: CharacterData, data: GameData, item_id: String) -> String:
	if not is_equipment(data, item_id):
		return "That cannot be equipped."
	if c.item_count(item_id) <= 0:
		return "You have none left."
	return ""


## Equips `item_id`, returning whatever was in its slot to the inventory.
## Returns the replaced item id ("" if the slot was empty), or "" on failure
## (check with check_equip first).
static func equip(c: CharacterData, data: GameData, item_id: String) -> String:
	if check_equip(c, data, item_id) != "":
		return ""
	var slot := slot_of(data, item_id)
	var previous := String(c.equipment.get(slot, ""))
	c.add_item(item_id, -1)
	if previous != "":
		c.add_item(previous, 1)
	c.equipment[slot] = item_id
	return previous


## Moves the item in `slot` back to the inventory. Returns its id, or "" if empty.
static func unequip(c: CharacterData, slot: String) -> String:
	var item_id := String(c.equipment.get(slot, ""))
	if item_id == "":
		return ""
	c.equipment.erase(slot)
	c.add_item(item_id, 1)
	return item_id


## Sum of the flat `stat` bonus of everything `c` has equipped.
static func bonus(c: CharacterData, data: GameData, stat: String) -> int:
	var total := 0
	for slot in c.equipment:
		total += int(data.items.get(c.equipment[slot], {}).get("equip", {}).get("stats", {}).get(stat, 0))
	return total


## "+12 attack, +2 speed" for an item's equip stats.
static func describe_stats(data: GameData, item_id: String) -> String:
	var parts: PackedStringArray = []
	var stats: Dictionary = data.items.get(item_id, {}).get("equip", {}).get("stats", {})
	for key in STAT_KEYS:
		if stats.has(key):
			parts.append("%+d %s" % [int(stats[key]), key.replace("_", " ")])
	return ", ".join(parts)


## Load errors for equipment definitions in data/items.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for item: Dictionary in data.items.values():
		if not item.has("equip"):
			continue
		var e: Dictionary = item["equip"]
		if not SLOTS.has(String(e.get("slot", ""))):
			errors.append("Item '%s' has unknown equip slot '%s'" % [item["id"], e.get("slot", "")])
		if int(e.get("grade", 0)) < 1:
			errors.append("Item '%s' needs equip grade >= 1" % item["id"])
		for key in e.get("stats", {}):
			if not STAT_KEYS.has(key):
				errors.append("Item '%s' equip has unknown stat '%s'" % [item["id"], key])
	return errors
