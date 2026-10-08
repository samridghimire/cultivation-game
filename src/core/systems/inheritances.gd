class_name Inheritances
extends RefCounted
## Inheritance grounds (W-006): one-time trials from data/inheritances.json
## where a fallen master left their legacy. Each appears in a region from
## appears_years after the game starts; its stages are passed in order (realm,
## attribute, alignment or fight tests) and the last one grants the reward.
## Only one cultivator can claim each: the player (world flag) or, once
## deadline_years pass, a rival who gets there first.

const TESTS := ["realm", "attribute", "alignment", "fight"]


static func inheritance(data: GameData, id: String) -> Dictionary:
	return data.inheritances.get(id, {})


static func claimed_flag(id: String) -> String:
	return "inheritance_claimed_%s" % id


static func is_claimed(id: String, flags: Dictionary) -> bool:
	return bool(flags.get(claimed_flag(id), false))


static func _appears_day(def: Dictionary) -> int:
	return int(def.get("appears_years", 0)) * Calendar.DAYS_PER_YEAR


static func _deadline_day(def: Dictionary) -> int:
	return int(def.get("deadline_years", 0)) * Calendar.DAYS_PER_YEAR


## Whether a rival has claimed it: the deadline passed before the player did.
static func is_lost(def: Dictionary, total_days: int, flags: Dictionary) -> bool:
	return total_days >= _deadline_day(def) and not is_claimed(String(def.get("id", "")), flags)


## Whether a rival claimed `def` between the two days (for a one-time news line).
static func lost_between(def: Dictionary, before_days: int, after_days: int, flags: Dictionary) -> bool:
	return before_days < _deadline_day(def) and is_lost(def, after_days, flags)


static func stages_cleared(c: CharacterData, id: String) -> int:
	return int(c.trial_progress.get(id, 0))


## The stage `c` faces next ({} when all are cleared).
static func next_stage(c: CharacterData, def: Dictionary) -> Dictionary:
	var stages: Array = def.get("stages", [])
	var cleared := stages_cleared(c, String(def.get("id", "")))
	return stages[cleared] if cleared < stages.size() else {}


## Why `c` does not pass `stage`'s test (fights are only checked for their enemy).
static func check_test(c: CharacterData, data: GameData, stage: Dictionary) -> String:
	match String(stage.get("test", "")):
		"realm":
			var min_index := data.realm_index_of(String(stage.get("min_realm", "mortal")))
			if c.realm_index < min_index:
				return "Only a cultivator of %s or above may pass." % data.realms[min_index].name
		"attribute":
			var attr := String(stage.get("attribute", ""))
			if c.attribute(attr) < int(stage.get("min", 0)):
				return "Your %s is not enough (needs %d)." % [_attribute_name(data, attr), int(stage.get("min", 0))]
		"alignment":
			if c.alignment < int(stage.get("min_alignment", -1000000)) or c.alignment > int(stage.get("max_alignment", 1000000)):
				return "The trial rejects your heart."
	return ""


static func _attribute_name(data: GameData, attr_id: String) -> String:
	for attr: Dictionary in data.attributes:
		if String(attr.get("id", "")) == attr_id:
			return String(attr.get("name", attr_id))
	return attr_id


## Why `c` cannot attempt the next stage of `id` from `region_id` now ("" = can).
static func check_attempt(c: CharacterData, data: GameData, id: String, region_id: String, total_days: int, flags: Dictionary) -> String:
	var def := inheritance(data, id)
	if def.is_empty():
		return "Unknown inheritance."
	if String(def.get("region", "")) != region_id:
		return "The %s is not here." % def["name"]
	if is_claimed(id, flags):
		return "You have already claimed the %s." % def["name"]
	if is_lost(def, total_days, flags):
		return "Someone else claimed the %s before you." % def["name"]
	if total_days < _appears_day(def):
		return "No one has found the %s yet." % def["name"]
	var stage := next_stage(c, def)
	if stage.is_empty():
		return "You have passed every trial of the %s." % def["name"]
	return check_test(c, data, stage)


## Enemy to beat for a fight stage ({} for other tests). Trials never kill.
static func stage_enemy(data: GameData, stage: Dictionary) -> Dictionary:
	if String(stage.get("test", "")) != "fight":
		return {}
	var enemy: Dictionary = data.enemies.get(String(stage.get("enemy", "")), {}).duplicate(true)
	if not enemy.is_empty():
		enemy["lethal"] = false
	return enemy


## Records the next stage as passed; on the last one grants the reward and
## claims the inheritance. Returns {stage_name, days, last, notes}.
static func pass_stage(c: CharacterData, data: GameData, id: String, flags: Dictionary) -> Dictionary:
	var def := inheritance(data, id)
	var stage := next_stage(c, def)
	var cleared := stages_cleared(c, id) + 1
	c.trial_progress[id] = cleared
	var last := cleared >= (def.get("stages", []) as Array).size()
	var notes: PackedStringArray = []
	if last:
		flags[claimed_flag(id)] = true
		LifeStats.add(c, "inheritances_claimed")
		notes = Effects.apply(c, data, def.get("reward", {}), flags)
	return {"stage_name": String(stage.get("name", "")), "days": int(stage.get("days", 1)), "last": last, "notes": notes}


## One line for menus: "Stage 2/4: Hall of Insight" / "Claimed" / "Lost to a rival".
static func status_text(c: CharacterData, data: GameData, id: String, total_days: int, flags: Dictionary) -> String:
	var def := inheritance(data, id)
	if is_claimed(id, flags):
		return "Claimed by you"
	if is_lost(def, total_days, flags):
		return "Claimed by a rival"
	if total_days < _appears_day(def):
		return "Undiscovered"
	var stages: Array = def.get("stages", [])
	var stage := next_stage(c, def)
	return "Trial %d/%d: %s (%s left before rivals arrive)" % [stages_cleared(c, id) + 1, stages.size(), stage.get("name", ""), Calendar.format_duration(_deadline_day(def) - total_days)]


## Inheritance ids whose grounds are in `region_id`, sorted.
static func in_region(data: GameData, region_id: String) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in data.inheritances.values():
		if String(def.get("region", "")) == region_id:
			out.append(String(def["id"]))
	out.sort()
	return out


static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for def: Dictionary in data.inheritances.values():
		var id := String(def.get("id", "?"))
		if not data.regions.has(String(def.get("region", ""))):
			errors.append("Inheritance '%s' has unknown region '%s'" % [id, def.get("region", "")])
		if int(def.get("deadline_years", 0)) <= int(def.get("appears_years", 0)):
			errors.append("Inheritance '%s' needs deadline_years > appears_years" % id)
		var stages: Array = def.get("stages", [])
		if stages.is_empty():
			errors.append("Inheritance '%s' has no stages" % id)
		for stage: Dictionary in stages:
			var test := String(stage.get("test", ""))
			if not TESTS.has(test):
				errors.append("Inheritance '%s' stage '%s' has unknown test '%s'" % [id, stage.get("name", "?"), test])
			if test == "realm" and data.realm_index_of(String(stage.get("min_realm", ""))) < 0:
				errors.append("Inheritance '%s' stage '%s' has unknown min_realm" % [id, stage.get("name", "?")])
			if test == "attribute" and _attribute_name(data, String(stage.get("attribute", ""))) == String(stage.get("attribute", "")):
				errors.append("Inheritance '%s' stage '%s' has unknown attribute '%s'" % [id, stage.get("name", "?"), stage.get("attribute", "")])
			if test == "fight" and not data.enemies.has(String(stage.get("enemy", ""))):
				errors.append("Inheritance '%s' stage '%s' has unknown enemy '%s'" % [id, stage.get("name", "?"), stage.get("enemy", "")])
		var reward: Dictionary = def.get("reward", {})
		if reward.is_empty():
			errors.append("Inheritance '%s' has no reward" % id)
		var tech := String(reward.get("learn_technique", ""))
		if tech != "" and not data.techniques.has(tech):
			errors.append("Inheritance '%s' teaches unknown technique '%s'" % [id, tech])
		for item_id in reward.get("items", {}):
			if not data.items.has(item_id):
				errors.append("Inheritance '%s' rewards unknown item '%s'" % [id, item_id])
	return errors
