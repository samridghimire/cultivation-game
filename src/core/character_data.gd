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
var techniques: Dictionary = {}  # technique id -> {"level": int, "xp": float}
var injuries: Dictionary = {}  # injury id -> days left to heal


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
		"techniques": techniques.duplicate(true),
		"injuries": injuries.duplicate(),
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
