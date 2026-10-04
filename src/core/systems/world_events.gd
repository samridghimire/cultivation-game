class_name WorldEvents
extends RefCounted
## World events (LW-001): beast tides, tournaments, auction seasons, demonic
## incursions... defined in data/world_events.json. GameState keeps the active
## ones as [{id, region, start_day, end_day}] (saved) and calls expire() and
## roll() at every month boundary. While an event lasts, its region gets extra
## encounter tags, a merchant price multiplier and a qi density multiplier.


static func def_of(data: GameData, event_id: String) -> Dictionary:
	return data.world_events.get(event_id, {})


static func event_name(data: GameData, event_id: String) -> String:
	return String(def_of(data, event_id).get("name", event_id))


## Active event instances in `region_id`.
static func active_in(active: Array, region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for instance: Dictionary in active:
		if String(instance.get("region", "")) == region_id:
			out.append(instance)
	return out


static func is_active(active: Array, event_id: String) -> bool:
	return active.any(func(i: Dictionary) -> bool: return String(i.get("id", "")) == event_id)


## Removes events that have ended by `total_days`. Returns the ended instances.
static func expire(active: Array, total_days: int) -> Array[Dictionary]:
	var ended: Array[Dictionary] = []
	for i in range(active.size() - 1, -1, -1):
		var instance: Dictionary = active[i]
		if int(instance.get("end_day", 0)) <= total_days:
			ended.push_front(instance)
			active.remove_at(i)
	return ended


## Monthly roll: each event not already under way may start in one of its
## regions. Appends to `active`; returns the started instances.
static func roll(data: GameData, active: Array, total_days: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var started: Array[Dictionary] = []
	for def: Dictionary in data.world_events.values():
		var event_id := String(def["id"])
		var regions: Array = def.get("regions", [])
		if is_active(active, event_id) or regions.is_empty():
			continue
		if rng.randf() >= float(def.get("monthly_chance", 0.0)):
			continue
		var region := String(regions[rng.randi_range(0, regions.size() - 1)])
		var days := rng.randi_range(int(def.get("min_days", 1)), maxi(int(def.get("min_days", 1)), int(def.get("max_days", 1))))
		var instance := {"id": event_id, "region": region, "start_day": total_days, "end_day": total_days + days}
		active.append(instance)
		started.append(instance)
	return started


## Extra encounter tags the active events add in `region_id`.
static func encounter_tags(data: GameData, active: Array, region_id: String) -> Array[String]:
	var tags: Array[String] = []
	for instance in active_in(active, region_id):
		for tag in def_of(data, instance["id"]).get("modifiers", {}).get("encounter_tags", []):
			if not tags.has(String(tag)):
				tags.append(String(tag))
	return tags


## Product of the active events' merchant price multipliers in `region_id`.
static func price_multiplier(data: GameData, active: Array, region_id: String) -> float:
	return _product(data, active, region_id, "price_mult")


## Product of the active events' qi density multipliers in `region_id`.
static func qi_multiplier(data: GameData, active: Array, region_id: String) -> float:
	return _product(data, active, region_id, "qi_density")


static func _product(data: GameData, active: Array, region_id: String, key: String) -> float:
	var mult := 1.0
	for instance in active_in(active, region_id):
		mult *= float(def_of(data, instance["id"]).get("modifiers", {}).get(key, 1.0))
	return mult


## The start or end log line of an instance ({region} filled in).
static func news(data: GameData, instance: Dictionary, starting: bool) -> String:
	var def := def_of(data, instance["id"])
	var text := String(def.get("start_text" if starting else "end_text", ""))
	if text == "":
		text = ("%s begins in {region}." if starting else "%s in {region} is over.") % def.get("name", instance["id"])
	return text.replace("{region}", Exploration.region_name(data, String(instance["region"])))


## "Beast Tide in Misty Forest (12 days left)" per active event, for the UI.
static func describe(data: GameData, active: Array, total_days: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for instance: Dictionary in active:
		lines.append("%s in %s (%s left)" % [event_name(data, instance["id"]), Exploration.region_name(data, String(instance["region"])), Calendar.format_duration(maxi(0, int(instance["end_day"]) - total_days))])
	return lines


## Load errors for data/world_events.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for def: Dictionary in data.world_events.values():
		var id := String(def.get("id", ""))
		var chance := float(def.get("monthly_chance", -1.0))
		if chance < 0.0 or chance > 1.0:
			errors.append("World event '%s' monthly_chance must be in 0..1" % id)
		if int(def.get("min_days", 0)) < 1 or int(def.get("max_days", 0)) < int(def.get("min_days", 0)):
			errors.append("World event '%s' needs 1 <= min_days <= max_days" % id)
		var regions: Array = def.get("regions", [])
		if regions.is_empty():
			errors.append("World event '%s' needs regions" % id)
		for region in regions:
			if not data.regions.has(region):
				errors.append("World event '%s' has unknown region '%s'" % [id, region])
		var mods: Dictionary = def.get("modifiers", {})
		for key in mods:
			if not key in ["encounter_tags", "price_mult", "qi_density"]:
				errors.append("World event '%s' has unknown modifier '%s'" % [id, key])
		for key in ["price_mult", "qi_density"]:
			if float(mods.get(key, 1.0)) <= 0.0:
				errors.append("World event '%s' %s must be > 0" % [id, key])
	return errors
