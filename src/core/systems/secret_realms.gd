class_name SecretRealms
extends RefCounted
## Secret realms (W-005): pocket worlds from data/secret_realms.json that open
## for open_days every period_years, only admit cultivators within a realm
## range, and hold floors of guardians and treasures cleared one per entry.
## Progress (c.secret_realms) resets when the realm opens again.


static func realm(data: GameData, realm_id: String) -> Dictionary:
	return data.secret_realms.get(realm_id, {})


static func _period_days(def: Dictionary) -> int:
	return maxi(1, int(def.get("period_years", 1)) * Calendar.DAYS_PER_YEAR)


static func _offset_days(def: Dictionary) -> int:
	return int(def.get("offset_years", 0)) * Calendar.DAYS_PER_YEAR


## Which opening `total_days` falls in (0 = the first), or -1 before the first.
@warning_ignore("integer_division")
static func opening_index(def: Dictionary, total_days: int) -> int:
	var since := total_days - _offset_days(def)
	if since < 0:
		return -1
	return since / _period_days(def)


static func is_open(def: Dictionary, total_days: int) -> bool:
	var since := total_days - _offset_days(def)
	return since >= 0 and since % _period_days(def) < int(def.get("open_days", 0))


## Days until the realm opens (0 while open).
static func days_until_open(def: Dictionary, total_days: int) -> int:
	if is_open(def, total_days):
		return 0
	var since := total_days - _offset_days(def)
	if since < 0:
		return -since
	return _period_days(def) - since % _period_days(def)


## Days left before an open realm closes (0 when closed).
static func days_until_close(def: Dictionary, total_days: int) -> int:
	if not is_open(def, total_days):
		return 0
	var since := total_days - _offset_days(def)
	return int(def.get("open_days", 0)) - since % _period_days(def)


## True if the realm is open on `to_day` and that opening began after `from_day`
## (it opened while time passed from `from_day` to `to_day`).
static func opened_between(def: Dictionary, from_day: int, to_day: int) -> bool:
	if not is_open(def, to_day):
		return false
	var start := _offset_days(def) + opening_index(def, to_day) * _period_days(def)
	return start > from_day


## True if `c`'s realm is inside the realm's min_realm..max_realm barrier.
static func admits(c: CharacterData, data: GameData, def: Dictionary) -> bool:
	var min_index := data.realm_index_of(String(def.get("min_realm", "mortal")))
	var max_index := data.realm_index_of(String(def.get("max_realm", "tribulation_transcendence")))
	return c.realm_index >= min_index and (max_index < 0 or c.realm_index <= max_index)


## Message-log lines for realms that opened between the two days: always for
## realms in `region_id`, and as rumors for realms elsewhere that admit `c`.
static func opening_news(c: CharacterData, data: GameData, region_id: String, from_day: int, to_day: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ids: Array = data.secret_realms.keys()
	ids.sort()
	for realm_id in ids:
		var def: Dictionary = data.secret_realms[realm_id]
		if not opened_between(def, from_day, to_day):
			continue
		var left := Calendar.format_duration(days_until_close(def, to_day))
		if String(def.get("region", "")) == region_id:
			lines.append("The %s has opened here! Its barrier holds for %s." % [def["name"], left])
		elif admits(c, data, def):
			lines.append("Rumors spread that the %s has opened in %s, for %s." % [def["name"], Exploration.region_name(data, String(def.get("region", ""))), left])
	return lines


## `c`'s progress record for the current opening ({} = not entered yet).
static func _progress(c: CharacterData, def: Dictionary, total_days: int) -> Dictionary:
	var progress: Dictionary = c.secret_realms.get(String(def.get("id", "")), {})
	if progress.is_empty() or int(progress.get("opening", -1)) != opening_index(def, total_days):
		return {}
	return progress


## Floors `c` has cleared in the current opening.
static func floors_cleared(c: CharacterData, def: Dictionary, total_days: int) -> int:
	return int(_progress(c, def, total_days).get("floor", 0))


## Spirit stones to pay before the next floor: entry_stones, once per opening.
static func entry_cost(c: CharacterData, def: Dictionary, total_days: int) -> int:
	return int(def.get("entry_stones", 0)) if _progress(c, def, total_days).is_empty() else 0


## The floor `c` would face next ({} when every floor is cleared).
static func next_floor(c: CharacterData, def: Dictionary, total_days: int) -> Dictionary:
	var floors: Array = def.get("floors", [])
	var cleared := floors_cleared(c, def, total_days)
	return floors[cleared] if cleared < floors.size() else {}


## Why `c` cannot delve into `realm_id` from `region_id` now ("" = allowed).
static func check_enter(c: CharacterData, data: GameData, realm_id: String, region_id: String, total_days: int) -> String:
	var def := realm(data, realm_id)
	if def.is_empty():
		return "Unknown secret realm."
	if String(def.get("region", "")) != region_id:
		return "The entrance to the %s is not here." % def["name"]
	if not is_open(def, total_days):
		return "The %s is sealed. It opens in %s." % [def["name"], Calendar.format_duration(days_until_open(def, total_days))]
	var min_index := data.realm_index_of(String(def.get("min_realm", "mortal")))
	var max_index := data.realm_index_of(String(def.get("max_realm", "tribulation_transcendence")))
	if c.realm_index < min_index:
		return "The barrier of the %s repels anyone below %s." % [def["name"], data.realms[min_index].name]
	if max_index >= 0 and c.realm_index > max_index:
		return "The barrier of the %s rejects cultivators above %s." % [def["name"], data.realms[max_index].name]
	if next_floor(c, def, total_days).is_empty():
		return "You have plundered every floor of the %s. It must close and reopen first." % def["name"]
	var cost := entry_cost(c, def, total_days)
	if c.item_count("spirit_stone") < cost:
		return "Opening a way into the %s takes %d spirit stones." % [def["name"], cost]
	return ""


## Pays the entry cost (if any) of the next floor. Call after check_enter.
static func pay_entry(c: CharacterData, def: Dictionary, total_days: int) -> int:
	var cost := entry_cost(c, def, total_days)
	c.add_item("spirit_stone", -cost)
	if _progress(c, def, total_days).is_empty():
		# Record the opening so a lost guardian fight does not charge again.
		c.secret_realms[String(def["id"])] = {"opening": opening_index(def, total_days), "floor": 0}
	return cost


## Claims the next floor after its guardian (if any) is beaten: draws one
## treasure, records progress. Returns {floor_name, notes, days, last}.
static func claim_floor(c: CharacterData, data: GameData, realm_id: String, total_days: int, flags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var def := realm(data, realm_id)
	var floor_def := next_floor(c, def, total_days)
	var notes: PackedStringArray = []
	var treasure := _draw(floor_def.get("treasures", []), rng)
	if not treasure.is_empty():
		notes = Effects.apply(c, data, treasure.get("effects", {}), flags)
	var cleared := floors_cleared(c, def, total_days) + 1
	c.secret_realms[realm_id] = {"opening": opening_index(def, total_days), "floor": cleared}
	return {"floor_name": String(floor_def.get("name", "")), "notes": notes, "days": int(floor_def.get("days", 1)), "last": cleared >= (def.get("floors", []) as Array).size()}


static func _draw(table: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry: Dictionary in table:
		total += maxi(0, int(entry.get("weight", 1)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for entry: Dictionary in table:
		roll -= maxi(0, int(entry.get("weight", 1)))
		if roll <= 0:
			return entry
	return {}


## One line for menus: "Open (12 days left), floor 2/3" or "Sealed, opens in 3 years".
static func status_text(c: CharacterData, data: GameData, realm_id: String, total_days: int) -> String:
	var def := realm(data, realm_id)
	if not is_open(def, total_days):
		return "Sealed, opens in %s" % Calendar.format_duration(days_until_open(def, total_days))
	var floors: int = (def.get("floors", []) as Array).size()
	return "Open (%s left), %d/%d floors cleared" % [Calendar.format_duration(days_until_close(def, total_days)), floors_cleared(c, def, total_days), floors]


## Secret realm ids whose entrance is in `region_id`, sorted.
static func in_region(data: GameData, region_id: String) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in data.secret_realms.values():
		if String(def.get("region", "")) == region_id:
			out.append(String(def["id"]))
	out.sort()
	return out


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for def: Dictionary in data.secret_realms.values():
		var id := String(def.get("id", "?"))
		if not data.regions.has(String(def.get("region", ""))):
			errors.append("Secret realm '%s' has unknown region '%s'" % [id, def.get("region", "")])
		for key in ["min_realm", "max_realm"]:
			if def.has(key) and data.realm_index_of(String(def[key])) < 0:
				errors.append("Secret realm '%s' has unknown %s '%s'" % [id, key, def[key]])
		if int(def.get("open_days", 0)) <= 0 or int(def.get("open_days", 0)) >= _period_days(def):
			errors.append("Secret realm '%s' needs 0 < open_days < period_years in days" % id)
		var floors: Array = def.get("floors", [])
		if floors.is_empty():
			errors.append("Secret realm '%s' has no floors" % id)
		for floor_def: Dictionary in floors:
			var guardian := String(floor_def.get("guardian", ""))
			if guardian != "" and not data.enemies.has(guardian):
				errors.append("Secret realm '%s' floor '%s' has unknown guardian '%s'" % [id, floor_def.get("name", "?"), guardian])
			for treasure: Dictionary in floor_def.get("treasures", []):
				for item_id in treasure.get("effects", {}).get("items", {}):
					if not data.items.has(item_id):
						errors.append("Secret realm '%s' treasure has unknown item '%s'" % [id, item_id])
	return errors
