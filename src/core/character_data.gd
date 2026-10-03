class_name CharacterData
extends RefCounted
## The full state of one character (the player, and later NPCs). Plain data:
## all rules that change it live in src/core/systems.

var id := "player"
var name := ""
## Identity (FAM-001). gender is a key of data/names.json "given_names" ("" = unknown, e.g. old saves).
var gender := ""
var surname := ""
var given_name := ""
## Family links: character ids (the player is "player", NPCs use their GameState.npcs id).
var parents: Array[String] = []
var children: Array[String] = []
var spouses: Array[String] = []
## Spouse id -> rank id of that marriage (data/family.json, e.g. "wife", "concubine", "dao_companion").
var spouse_ranks: Dictionary = {}
## Ongoing pregnancy (FAM-003): {} or {"partner": other parent id, "days_left": int}. See Children.
var pregnancy: Dictionary = {}
## The mother's spousal rank to the father at birth ("" = unknown or adopted); used for heir priority.
var birth_rank := ""
## Bloodline id (data/bloodlines.json, "" = none) and whether it has awakened (FAM-007).
var bloodline := ""
var bloodline_awakened := false
## Training assigned by a parent (FAM-004): {} or {"assignment": id, "profession": id}. See Training.
var training: Dictionary = {}
## NPC behavior. Empty/negative values fall back to the data/npcs.json def (see Npcs).
var home_region := ""
var cultivates := false
## Fraction of days spent cultivating; < 0 = unset.
var diligence := -1.0
## Proud NPCs refuse to become concubines (named NPCs can also set it in data/npcs.json).
var proud := false
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
## Empty = rogue cultivator. Otherwise {"id": String, "rank": int, "contribution": int, "spent": int (optional)}.
## contribution is lifetime earned (drives rank); spent is what went to the sect shop (Sects.contribution_balance).
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
## Combat talisman item ids burned automatically in fights (see CombatTalismans).
var readied_talismans: Array[String] = []
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
## Claimed cave abode id (data/regions.json "abodes"), "" if none (Abodes).
var abode := ""
## Items kept in the abode's storage chest: item id -> count.
var abode_storage: Dictionary = {}
## Creation Artifact energy fed from spirit stones and treasures (ArtifactFunctions).
var artifact_energy := 0
## Unlocked artifact function ids (data/artifact.json "functions").
var artifact_functions: Array[String] = []
## Items kept in the artifact's storage space: item id -> count. Never lost.
var artifact_storage: Dictionary = {}
## Sect mission id -> age_days when it may be taken again (Sects missions).
var mission_cooldowns: Dictionary = {}
## Sect id -> reputation with that sect (Reputation system; missing = start value).
var reputation: Dictionary = {}


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
		"gender": gender,
		"surname": surname,
		"given_name": given_name,
		"parents": parents.duplicate(),
		"children": children.duplicate(),
		"spouses": spouses.duplicate(),
		"spouse_ranks": spouse_ranks.duplicate(),
		"pregnancy": pregnancy.duplicate(),
		"birth_rank": birth_rank,
		"bloodline": bloodline,
		"bloodline_awakened": bloodline_awakened,
		"training": training.duplicate(),
		"home_region": home_region,
		"cultivates": cultivates,
		"diligence": diligence,
		"proud": proud,
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
		"readied_talismans": readied_talismans.duplicate(),
		"lifespan_spent_years": lifespan_spent_years,
		"lifespan_bonus_years": lifespan_bonus_years,
		"artifact_lives": artifact_lives,
		"artifact_recharges": artifact_recharges,
		"anchors": anchors.duplicate(),
		"artifact_energy": artifact_energy,
		"artifact_functions": artifact_functions.duplicate(),
		"artifact_storage": artifact_storage.duplicate(),
		"mission_cooldowns": mission_cooldowns.duplicate(),
		"reputation": reputation.duplicate(),
		"abode": abode,
		"abode_storage": abode_storage.duplicate(),
	}


static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d.get("id", "player")
	c.name = d.get("name", "")
	c.gender = String(d.get("gender", ""))
	c.surname = String(d.get("surname", ""))
	c.given_name = String(d.get("given_name", ""))
	c.parents = _strings(d.get("parents", []))
	c.children = _strings(d.get("children", []))
	c.spouses = _strings(d.get("spouses", []))
	var saved_ranks: Dictionary = d.get("spouse_ranks", {})
	for spouse_id in saved_ranks:
		c.spouse_ranks[String(spouse_id)] = String(saved_ranks[spouse_id])
	var saved_pregnancy: Dictionary = d.get("pregnancy", {})
	if not saved_pregnancy.is_empty():
		c.pregnancy = {"partner": String(saved_pregnancy.get("partner", "")), "days_left": int(saved_pregnancy.get("days_left", 0))}
	c.birth_rank = String(d.get("birth_rank", ""))
	c.bloodline = String(d.get("bloodline", ""))
	c.bloodline_awakened = bool(d.get("bloodline_awakened", false))
	var saved_training: Dictionary = d.get("training", {})
	for key in saved_training:
		c.training[String(key)] = String(saved_training[key])
	c.home_region = String(d.get("home_region", ""))
	c.cultivates = bool(d.get("cultivates", false))
	c.diligence = float(d.get("diligence", -1.0))
	c.proud = bool(d.get("proud", false))
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
		if s.has("spent"):
			c.sect["spent"] = int(s["spent"])
	c.inventory = _int_values(d.get("inventory", {}))
	c.injuries = _int_values(d.get("injuries", {}))
	var equipped: Dictionary = d.get("equipment", {})
	for slot in equipped:
		c.equipment[String(slot)] = String(equipped[slot])
	var saved_buffs: Dictionary = d.get("buffs", {})
	for buff_id in saved_buffs:
		var b: Dictionary = saved_buffs[buff_id]
		Buffs.add(c, String(buff_id), String(b.get("name", buff_id)), int(b.get("days", 0)), b.get("mults", {}))
	c.readied_talismans = _strings(d.get("readied_talismans", []))
	c.lifespan_spent_years = int(d.get("lifespan_spent_years", 0))
	c.lifespan_bonus_years = int(d.get("lifespan_bonus_years", 0))
	c.artifact_lives = int(d.get("artifact_lives", -1))
	c.artifact_recharges = int(d.get("artifact_recharges", 0))
	c.artifact_energy = int(d.get("artifact_energy", 0))
	c.artifact_functions = _strings(d.get("artifact_functions", []))
	c.artifact_storage = _int_values(d.get("artifact_storage", {}))
	c.mission_cooldowns = _int_values(d.get("mission_cooldowns", {}))
	c.reputation = _int_values(d.get("reputation", {}))
	c.abode = String(d.get("abode", ""))
	c.abode_storage = _int_values(d.get("abode_storage", {}))
	for anchor_id in d.get("anchors", []):
		c.anchors.append(String(anchor_id))
	for recipe_id in d.get("known_recipes", []):
		c.known_recipes.append(String(recipe_id))
	var techs: Dictionary = d.get("techniques", {})
	for tech_id in techs:
		c.techniques[tech_id] = {"level": int(techs[tech_id].get("level", 1)), "xp": float(techs[tech_id].get("xp", 0))}
	return c


static func _strings(a: Array) -> Array[String]:
	var out: Array[String] = []
	for v in a:
		out.append(String(v))
	return out


## JSON turns every number into a float; restore ints for integer maps.
static func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[key] = int(d[key])
	return out
