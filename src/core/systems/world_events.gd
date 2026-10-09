class_name WorldEvents
extends RefCounted
## World events (LW-001): beast tides, tournaments, auction seasons, demonic
## incursions... defined in data/world_events.json. GameState keeps the active
## ones as [{id, region, start_day, end_day, done}] (saved) and calls expire() and
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
		var months: Array = def.get("months", [])
		if not months.is_empty() and not months.any(func(m: Variant) -> bool: return int(m) == Calendar.month_of(total_days)):
			continue
		# Fixed-date events roll from their own seeded stream so they never shift the shared rng.
		var roller := rng
		if not months.is_empty():
			roller = RandomNumberGenerator.new()
			roller.seed = hash(event_id) + total_days
		if roller.randf() >= float(def.get("monthly_chance", 0.0)):
			continue
		var region := String(regions[roller.randi_range(0, regions.size() - 1)])
		var days := roller.randi_range(int(def.get("min_days", 1)), maxi(int(def.get("min_days", 1)), int(def.get("max_days", 1))))
		var instance := {"id": event_id, "region": region, "start_day": total_days, "end_day": total_days + days, "done": false}
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


## How an event under way is named in the HUD and map: "Festival: <name>" for festivals, "<name>!" otherwise.
static func active_label(data: GameData, event_id: String) -> String:
	if is_festival(data, event_id):
		return "Festival: %s" % event_name(data, event_id)
	return "%s!" % event_name(data, event_id)


## Product of the active events' favor multipliers (festivals) in `region_id`.
static func favor_multiplier(data: GameData, active: Array, region_id: String) -> float:
	return _product(data, active, region_id, "favor_mult")


static func is_festival(data: GameData, event_id: String) -> bool:
	return bool(def_of(data, event_id).get("festival", false))


## `favor` scaled by the festival multiplier in `region_id` (rounded).
static func scaled_favor(data: GameData, active: Array, region_id: String, favor: int) -> int:
	return roundi(favor * favor_multiplier(data, active, region_id))


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


## Gossip lines for a merchant's "Ask about rumors": every event under way
## (with where and how long), then `extra` lines (e.g. auction dates).
static func rumors(data: GameData, active: Array, extra: PackedStringArray, total_days: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for instance: Dictionary in active:
		var def := def_of(data, instance["id"])
		lines.append("Rumor has it the %s in %s will last another %s. %s" % [def.get("name", instance["id"]), Exploration.region_name(data, String(instance["region"])), Calendar.format_duration(maxi(0, int(instance["end_day"]) - total_days)), def.get("description", "")])
	if lines.is_empty():
		lines.append("The merchant shrugs: no beast tides, no wars, nothing worth gossiping about.")
	lines.append_array(extra)
	return lines


## The active instance of `event_id` in `region_id` ({} when none).
static func instance_in(active: Array, event_id: String, region_id: String) -> Dictionary:
	for instance: Dictionary in active:
		if String(instance.get("id", "")) == event_id and String(instance.get("region", "")) == region_id:
			return instance
	return {}


## "" if `c` can take part in the event's `kind` ("tournament" or "defence") in
## `region_id`, otherwise the reason they cannot (LW-003).
static func check_join(data: GameData, active: Array, c: CharacterData, event_id: String, kind: String, region_id: String) -> String:
	var def := def_of(data, event_id)
	if not def.has(kind):
		return "Nothing like that is going on."
	var instance := instance_in(active, event_id, region_id)
	if instance.is_empty():
		return "The %s is not happening here." % String(def.get("name", event_id))
	if bool(instance.get("done", false)):
		return "You have already taken part."
	if c.realm_index < 1:
		return "Only cultivators can take part."
	return ""


## A generated cultivator for `kind` round `round_index` (0-based), of `c`'s own
## realm and stage plus `round_index` stages, as a non-lethal sparring enemy.
static func opponent(data: GameData, event_id: String, kind: String, c: CharacterData, round_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var def := def_of(data, event_id)
	var base: Dictionary = data.enemies[def["defence"]["enemy"]] if kind == "defence" else {"id": "tournament_rival", "description": "A cultivator fighting for the prize.", "tags": ["cultivator"]}
	var enemy := (base as Dictionary).duplicate(true)
	var gender := Names.roll_gender(data, rng)
	var title := Names.full_name(Names.roll_surname(data, rng), Names.roll_given_name(data, gender, rng))
	enemy["name"] = title if kind == "tournament" else "%s, %s" % [title, base.get("name", "raider")]
	enemy["proper_name"] = kind == "tournament"
	enemy["realm"] = data.realms[c.realm_index].id
	enemy["stage"] = mini(c.stage + round_index, data.realms[c.realm_index].stage_count() - 1)
	enemy["lethal"] = false
	enemy["rewards"] = {}
	enemy["spar"] = kind == "tournament"
	for key in ["hp", "attack", "defense", "speed"]:
		enemy[key] = int(enemy.get(key, 0))
	return enemy


## Pays the tournament prize. Returns the notes to show.
static func pay_prize(data: GameData, c: CharacterData, event_id: String, flags: Dictionary, rng: RandomNumberGenerator) -> PackedStringArray:
	var prize: Dictionary = def_of(data, event_id)["tournament"].get("prize", {})
	var effects := {"items": (prize.get("items", {}) as Dictionary).duplicate()}
	var manuals: Array = prize.get("manuals", [])
	if not manuals.is_empty():
		var manual := String(manuals[rng.randi_range(0, manuals.size() - 1)])
		effects["items"][manual] = int(effects["items"].get(manual, 0)) + 1
	var notes := Effects.apply(c, data, effects, flags)
	var rep := int(prize.get("reputation", 0))
	if rep != 0 and not c.is_rogue():
		notes.append_array(Reputation.apply_changes(c, data, {String(c.sect["id"]): rep}))
	return notes


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
			if not key in ["encounter_tags", "price_mult", "qi_density", "favor_mult"]:
				errors.append("World event '%s' has unknown modifier '%s'" % [id, key])
		for key in ["price_mult", "qi_density"]:
			if float(mods.get(key, 1.0)) <= 0.0:
				errors.append("World event '%s' %s must be > 0" % [id, key])
		if float(mods.get("favor_mult", 1.0)) < 1.0:
			errors.append("World event '%s' favor_mult must be >= 1.0" % id)
		if def.has("months"):
			var months: Array = def["months"]
			if months.is_empty():
				errors.append("World event '%s' months must not be empty" % id)
			for month in months:
				if typeof(month) not in [TYPE_INT, TYPE_FLOAT] or int(month) < 1 or int(month) > 12:
					errors.append("World event '%s' has invalid month '%s'" % [id, str(month)])
		var tournament: Dictionary = def.get("tournament", {})
		if def.has("tournament"):
			if int(tournament.get("rounds", 0)) < 1:
				errors.append("World event '%s' tournament needs rounds >= 1" % id)
			var prize: Dictionary = tournament.get("prize", {})
			for item_id in prize.get("items", {}):
				if not data.items.has(item_id):
					errors.append("World event '%s' prize has unknown item '%s'" % [id, item_id])
			for item_id in prize.get("manuals", []):
				if not data.items.has(item_id):
					errors.append("World event '%s' prize has unknown manual '%s'" % [id, item_id])
		if def.has("defence"):
			if not data.enemies.has(String(def["defence"].get("enemy", ""))):
				errors.append("World event '%s' defence has unknown enemy" % id)
			if (def["defence"].get("effects", {}) as Dictionary).is_empty():
				errors.append("World event '%s' defence needs effects" % id)
	return errors
