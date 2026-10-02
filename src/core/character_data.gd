class_name CharacterData
extends RefCounted
## The full state of one character (the player, and later NPCs). Plain data:
## all rules that change it live in src/core/systems.

var id := "player"
var name := ""
var age_days := 0
var alive := true
var cause_of_death := ""
var attributes: Dictionary = {}  # attribute id -> int
var spiritual_roots: Dictionary = {}  # element id -> purity (int)
var realm_index := 0
var stage := 0
var qi := 0.0
## Bonus added to the next breakthrough attempt, then reset (e.g. from pills).
var breakthrough_bonus := 0.0
var alignment := 0
var professions: Dictionary = {}  # profession id -> {"rank": int, "xp": float}
## Empty = rogue cultivator. Otherwise {"id": String, "rank": int, "contribution": int}.
var sect: Dictionary = {}
var inventory: Dictionary = {}  # item id -> count
## Equipped artifacts: slot (Equipment.SLOTS) -> item id. Equipped items are not in inventory.
var equipment: Dictionary = {}
var techniques: Dictionary = {}  # technique id -> {"level": int, "xp": float}
## Recipe ids learned from scrolls (data/recipes.json "starter" recipes are known without learning).
var known_recipes: Array[String] = []
var injuries: Dictionary = {}  # injury id -> days left to heal
## Temporary combat buffs: buff id -> {"name", "days", "mults": {stat: fraction}} (see Buffs).
var buffs: Dictionary = {}
## Years of lifespan burned for power (forbidden arts, demonic pills); see Cultivation.lifespan_years.
var lifespan_spent_years := 0
## Years of lifespan gained from longevity pills and treasures.
var lifespan_bonus_years := 0
## Creation Artifact lives left (-1 = not yet initialised, see CreationArtifact.ensure).
var artifact_lives := -1
## Lives bought with spirit stones so far (raises the next recharge cost).
var artifact_recharges := 0
## Bound anchor ids (data/regions.json "anchor_id"), most recently bound last.
var anchors: Array[String] = []


func attribute(attr_id: String) -> int:
	return int(attributes.get(attr_id, 0))


@warning_ignore("integer_division")
func age_years() -> int:
	return age_days / Calendar.DAYS_PER_YEAR


func is_rogue() -> bool:
	return sect.is_empty()


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, amount: int) -> void:
	var total := item_count(item_id) + amount
	if total <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = total


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"age_days": age_days,
		"alive": alive,
		"cause_of_death": cause_of_death,
		"attributes": attributes.duplicate(),
		"spiritual_roots": spiritual_roots.duplicate(),
		"realm_index": realm_index,
		"stage": stage,
		"qi": qi,
		"breakthrough_bonus": breakthrough_bonus,
		"alignment": alignment,
		"professions": professions.duplicate(true),
		"sect": sect.duplicate(),
		"inventory": inventory.duplicate(),
		"equipment": equipment.duplicate(),
		"techniques": techniques.duplicate(true),
		"known_recipes": known_recipes.duplicate(),
		"injuries": injuries.duplicate(),
		"buffs": buffs.duplicate(true),
		"lifespan_spent_years": lifespan_spent_years,
		"lifespan_bonus_years": lifespan_bonus_years,
		"artifact_lives": artifact_lives,
		"artifact_recharges": artifact_recharges,
		"anchors": anchors.duplicate(),
	}


static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d.get("id", "player")
	c.name = d.get("name", "")
	c.age_days = int(d.get("age_days", 0))
	c.alive = bool(d.get("alive", true))
	c.cause_of_death = d.get("cause_of_death", "")
	c.attributes = _int_values(d.get("attributes", {}))
	c.spiritual_roots = _int_values(d.get("spiritual_roots", {}))
	c.realm_index = int(d.get("realm_index", 0))
	c.stage = int(d.get("stage", 0))
	c.qi = float(d.get("qi", 0))
	c.breakthrough_bonus = float(d.get("breakthrough_bonus", 0))
	c.alignment = int(d.get("alignment", 0))
	var profs: Dictionary = d.get("professions", {})
	for prof_id in profs:
		c.professions[prof_id] = {"rank": int(profs[prof_id].get("rank", 0)), "xp": float(profs[prof_id].get("xp", 0))}
	var s: Dictionary = d.get("sect", {})
	if not s.is_empty():
		c.sect = {"id": String(s.get("id", "")), "rank": int(s.get("rank", 0)), "contribution": int(s.get("contribution", 0))}
	c.inventory = _int_values(d.get("inventory", {}))
	c.injuries = _int_values(d.get("injuries", {}))
	var equipped: Dictionary = d.get("equipment", {})
	for slot in equipped:
		c.equipment[String(slot)] = String(equipped[slot])
	var saved_buffs: Dictionary = d.get("buffs", {})
	for buff_id in saved_buffs:
		var b: Dictionary = saved_buffs[buff_id]
		Buffs.add(c, String(buff_id), String(b.get("name", buff_id)), int(b.get("days", 0)), b.get("mults", {}))
	c.lifespan_spent_years = int(d.get("lifespan_spent_years", 0))
	c.lifespan_bonus_years = int(d.get("lifespan_bonus_years", 0))
	c.artifact_lives = int(d.get("artifact_lives", -1))
	c.artifact_recharges = int(d.get("artifact_recharges", 0))
	for anchor_id in d.get("anchors", []):
		c.anchors.append(String(anchor_id))
	for recipe_id in d.get("known_recipes", []):
		c.known_recipes.append(String(recipe_id))
	var techs: Dictionary = d.get("techniques", {})
	for tech_id in techs:
		c.techniques[tech_id] = {"level": int(techs[tech_id].get("level", 1)), "xp": float(techs[tech_id].get("xp", 0))}
	return c


## JSON turns every number into a float; restore ints for integer maps.
static func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[key] = int(d[key])
	return out
