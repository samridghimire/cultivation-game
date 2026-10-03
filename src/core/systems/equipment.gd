class_name Equipment
extends RefCounted
## Equippable artifacts (weapons, armor) forged by Blacksmiths. An item is
## equipment if it has an `equip` block in data/items.json:
## {"slot": one of SLOTS, "grade": int >= 1, "stats": {stat: flat bonus}}.
## Equipping moves the item out of the inventory into CharacterData.equipment;
## the bonuses are added flat to Combat.stats (before injuries and buffs scale them).
## Evil artifacts may also have `lifespan_drain` (int years): each fight fought
## while wielding them burns that many years of the wielder's lifespan, and
## `alignment_on_first_equip` (int): a one-time alignment shift the first time
## the wielder binds that artifact (tracked in CharacterData.bound_artifacts).

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


## Years of lifespan the item drinks per fight (0 for ordinary equipment).
static func item_drain(data: GameData, item_id: String) -> int:
	return int(data.items.get(item_id, {}).get("equip", {}).get("lifespan_drain", 0))


## Total years per fight drained by everything `c` has equipped.
static func lifespan_drain(c: CharacterData, data: GameData) -> int:
	var total := 0
	for slot in c.equipment:
		total += item_drain(data, String(c.equipment[slot]))
	return total


## Burns the lifespan drained by `c`'s equipment after a fight. Unlike burning
## lifespan by choice, this is never refused: an evil weapon can drink the
## last of your years. Returns the years burned.
static func drain_after_fight(c: CharacterData, data: GameData) -> int:
	var years := lifespan_drain(c, data)
	Cultivation.burn_lifespan(c, years)
	return years


## One-time alignment shift for first binding `item_id` (0 for ordinary gear).
static func first_equip_alignment(data: GameData, item_id: String) -> int:
	return int(data.items.get(item_id, {}).get("equip", {}).get("alignment_on_first_equip", 0))


## Whether `c` has already paid `item_id`'s one-time binding cost.
static func is_bound(c: CharacterData, item_id: String) -> bool:
	return c.bound_artifacts.has(item_id)


## Pays the one-time binding cost of `item_id` (an alignment shift for evil
## artifacts) if `c` has not paid it before. Returns the alignment change
## applied, 0 if there is nothing to pay.
static func bind_artifact(c: CharacterData, data: GameData, item_id: String) -> int:
	var shift := first_equip_alignment(data, item_id)
	if shift == 0 or is_bound(c, item_id):
		return 0
	c.bound_artifacts.append(item_id)
	var before := c.alignment
	Alignment.shift(c, data, shift)
	return c.alignment - before


## "+12 attack, +2 speed" for an item's equip stats, plus any lifespan drain.
static func describe_stats(data: GameData, item_id: String) -> String:
	var parts: PackedStringArray = []
	var stats: Dictionary = data.items.get(item_id, {}).get("equip", {}).get("stats", {})
	for key in STAT_KEYS:
		if stats.has(key):
			parts.append("%+d %s" % [int(stats[key]), key.replace("_", " ")])
	var drain := item_drain(data, item_id)
	if drain > 0:
		parts.append("drinks %d %s of lifespan per fight" % [drain, "year" if drain == 1 else "years"])
	var shift := first_equip_alignment(data, item_id)
	if shift != 0:
		parts.append("%+d alignment to bind" % shift)
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
		if absi(int(e.get("alignment_on_first_equip", 0))) > data.alignment_max - data.alignment_min:
			errors.append("Item '%s' equip alignment_on_first_equip is out of the alignment range" % item["id"])
		if int(e.get("lifespan_drain", 0)) < 0:
			errors.append("Item '%s' needs equip lifespan_drain >= 0" % item["id"])
		for key in e.get("stats", {}):
			if not STAT_KEYS.has(key):
				errors.append("Item '%s' equip has unknown stat '%s'" % [item["id"], key])
	return errors
