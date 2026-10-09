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
## Training assigned by a parent (FAM-004): {} or {"assignment": id, "profession": id}. See Training.
var training: Dictionary = {}
## "pointers:<npc_id>" / "spar:<npc_id>" -> GameClock day last done (MENTOR-001).
var npc_action_days: Dictionary = {}
## Bloodline id (data/bloodlines.json, "" = none) and whether it has awakened (FAM-007).
var bloodline := ""
var bloodline_awakened := false
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
## Days since this NPC died (Npcs.simulate counts on; Npcs.prune uses it).
var dead_days := 0
var attributes: Dictionary = {}  # attribute id -> int
var spiritual_roots: Dictionary = {}  # element id -> purity (int)
var realm_index := 0
var stage := 0
var qi := 0.0
## Bonus added to the next breakthrough attempt, then reset (e.g. from pills).
var breakthrough_bonus := 0.0
## Realm id of the breakthrough pill taken for the next attempt, "" if none (herbs don't set it).
var breakthrough_pill := ""
var alignment := 0
var professions: Dictionary = {}  # profession id -> {"rank": int, "xp": float}
## Empty = rogue cultivator. Otherwise {"id": String, "rank": int, "contribution": int, "spent": int (optional)}.
## contribution is lifetime earned (drives rank); spent is what went to the sect shop (Sects.contribution_balance).
var sect: Dictionary = {}
var inventory: Dictionary = {}  # item id -> count
## Equipped artifacts: slot (Equipment.SLOTS) -> item id. Equipped items are not in inventory.
var equipment: Dictionary = {}
var techniques: Dictionary = {}  # technique id -> {"level": int, "xp": float}
## Active main cultivation method (a known "method" technique); "" = the starter method.
var main_method := ""
## Recipe ids learned from scrolls (data/recipes.json "starter" recipes are known without learning).
var known_recipes: Array[String] = []
var injuries: Dictionary = {}  # injury id -> days left to heal
## Temporary combat buffs: buff id -> {"name", "days", "mults": {stat: fraction}} (see Buffs).
var buffs: Dictionary = {}
## Dao insights: insight id -> {"level": int, "progress": float} (see Dao).
var dao: Dictionary = {}
## Combat talisman item ids burned automatically in fights (see CombatTalismans).
var readied_talismans: Array[String] = []
## Tamed spirit beast ids (data/beasts.json), BEAST-001.
var companions: Array[String] = []
## Growth xp per companion beast id (Beasts, BEAST-001d).
var companion_xp: Dictionary = {}
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
## Item ids whose one-time binding cost has been paid (equip
## `alignment_on_first_equip`, LIFE-001g), so it is never charged twice.
var bound_artifacts: Array[String] = []
## Region ids the character has set foot in (TRAV-001), in order of arrival.
var visited_regions: Array[String] = []
## Cultivators whose cultivation this character has devoured (Devouring, DEM-001).
var devoured := 0
## Id of the player's named rival NPC (Rivals, RIV-002), "" if none.
var rival := ""
## Claimed cave abode id (data/regions.json "abodes"), "" if none (Abodes).
var abode := ""
## Items kept in the abode's storage chest: item id -> count.
var abode_storage: Dictionary = {}
## Item id of the array set up at the abode (items.json `array`), "" if none (G-006).
var abode_array := ""
## Creation Artifact energy fed from spirit stones and treasures (ArtifactFunctions).
var artifact_energy := 0
## Unlocked artifact function ids (data/artifact.json "functions").
var artifact_functions: Array[String] = []
## Items kept in the artifact's storage space: item id -> count. Never lost.
var artifact_storage: Dictionary = {}
## Spirit garden plots in the inner world (SpiritGarden, ART-004): [{item, days_left}].
var garden: Array = []
## Sect mission id -> age_days when it may be taken again (Sects missions).
var mission_cooldowns: Dictionary = {}
## Open crafting orders (PROF-001, Commissions): [{profession, recipe, item, count, reward, xp, due_day}].
var commissions: Array = []
var life_stats: Dictionary = {}  # LifeStats key -> count
var year_start_stats: Dictionary = {}  # life_stats at the last new year (YEAR-001)
var year_start_year: int = 0  # the year the snapshot was taken in (YEAR-002); 0 = unknown (old saves)
var year_start_realm: String = ""  # realm label then; "" = no snapshot yet
var milestones: Array[String] = []  # earned Milestones ids
var deed_days: Dictionary = {}  # deed id -> GameClock day it was last done
## Inheritance id -> trial stages passed (W-006, Inheritances).
var trial_progress: Dictionary = {}
## Sect id -> reputation with that sect (Reputation system; missing = start value).
var reputation: Dictionary = {}
## Karma (RIV-001): NPC id -> how much that NPC hates / owes this character (0-100, see Karma).
var grudges: Dictionary = {}
var gratitude: Dictionary = {}
## Secret realm id -> {"opening": int, "floor": int}: floors cleared in that opening (see SecretRealms).
var secret_realms: Dictionary = {}
## Secret realm ids whose inheritance this character received (once per life, W-005d).
var inheritances: Array[String] = []
## Body tempering stages reached (data/body_tempering.json, BodyTempering); 0 = untempered.
var body_stage := 0


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
		"training": training.duplicate(),
		"npc_action_days": npc_action_days.duplicate(),
		"bloodline": bloodline,
		"bloodline_awakened": bloodline_awakened,
		"home_region": home_region,
		"cultivates": cultivates,
		"diligence": diligence,
		"proud": proud,
		"age_days": age_days,
		"alive": alive,
		"cause_of_death": cause_of_death,
		"dead_days": dead_days,
		"attributes": attributes.duplicate(),
		"spiritual_roots": spiritual_roots.duplicate(),
		"realm_index": realm_index,
		"stage": stage,
		"qi": qi,
		"breakthrough_bonus": breakthrough_bonus,
		"breakthrough_pill": breakthrough_pill,
		"alignment": alignment,
		"professions": professions.duplicate(true),
		"sect": sect.duplicate(),
		"inventory": inventory.duplicate(),
		"equipment": equipment.duplicate(),
		"techniques": techniques.duplicate(true),
		"main_method": main_method,
		"known_recipes": known_recipes.duplicate(),
		"injuries": injuries.duplicate(),
		"buffs": buffs.duplicate(true),
		"dao": dao.duplicate(true),
		"readied_talismans": readied_talismans.duplicate(),
		"companions": companions.duplicate(),
		"companion_xp": companion_xp.duplicate(),
		"lifespan_spent_years": lifespan_spent_years,
		"lifespan_bonus_years": lifespan_bonus_years,
		"artifact_lives": artifact_lives,
		"artifact_recharges": artifact_recharges,
		"anchors": anchors.duplicate(),
		"artifact_energy": artifact_energy,
		"artifact_functions": artifact_functions.duplicate(),
		"artifact_storage": artifact_storage.duplicate(),
		"garden": garden.duplicate(true),
		"mission_cooldowns": mission_cooldowns.duplicate(),
		"deed_days": deed_days.duplicate(),
		"life_stats": life_stats.duplicate(),
		"year_start_stats": year_start_stats.duplicate(),
		"year_start_year": year_start_year,
		"year_start_realm": year_start_realm,
		"commissions": commissions.duplicate(true),
		"milestones": milestones.duplicate(),
		"trial_progress": trial_progress.duplicate(),
		"reputation": reputation.duplicate(),
		"bound_artifacts": bound_artifacts.duplicate(),
		"visited_regions": visited_regions.duplicate(),
		"devoured": devoured,
		"rival": rival,
		"abode": abode,
		"abode_storage": abode_storage.duplicate(),
		"grudges": grudges.duplicate(),
		"gratitude": gratitude.duplicate(),
		"secret_realms": secret_realms.duplicate(true),
		"inheritances": inheritances.duplicate(),
		"body_stage": body_stage,
		"abode_array": abode_array,
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
	var saved_training: Dictionary = d.get("training", {})
	for key in saved_training:
		c.training[String(key)] = String(saved_training[key])
	var saved_actions: Dictionary = d.get("npc_action_days", {})
	for key in saved_actions:
		c.npc_action_days[String(key)] = int(saved_actions[key])
	c.bloodline = String(d.get("bloodline", ""))
	c.bloodline_awakened = bool(d.get("bloodline_awakened", false))
	c.home_region = String(d.get("home_region", ""))
	c.cultivates = bool(d.get("cultivates", false))
	c.diligence = float(d.get("diligence", -1.0))
	c.proud = bool(d.get("proud", false))
	c.age_days = int(d.get("age_days", 0))
	c.alive = bool(d.get("alive", true))
	c.cause_of_death = d.get("cause_of_death", "")
	c.dead_days = int(d.get("dead_days", 0))
	c.attributes = _int_values(d.get("attributes", {}))
	c.spiritual_roots = _int_values(d.get("spiritual_roots", {}))
	c.realm_index = int(d.get("realm_index", 0))
	c.stage = int(d.get("stage", 0))
	c.qi = float(d.get("qi", 0))
	c.breakthrough_bonus = float(d.get("breakthrough_bonus", 0))
	c.breakthrough_pill = String(d.get("breakthrough_pill", ""))
	c.alignment = int(d.get("alignment", 0))
	var profs: Dictionary = d.get("professions", {})
	for prof_id in profs:
		c.professions[prof_id] = {"rank": int(profs[prof_id].get("rank", 0)), "xp": float(profs[prof_id].get("xp", 0))}
	var s: Dictionary = d.get("sect", {})
	if not s.is_empty():
		c.sect = {"id": String(s.get("id", "")), "rank": int(s.get("rank", 0)), "contribution": int(s.get("contribution", 0))}
		if s.has("spent"):
			c.sect["spent"] = int(s["spent"])
		if s.has("month_earned"):
			c.sect["month_earned"] = int(s["month_earned"])
		if s.has("lecture_month"):
			c.sect["lecture_month"] = int(s["lecture_month"])
		if s.has("duty_grace"):
			c.sect["duty_grace"] = bool(s["duty_grace"])
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
	c.companions = _strings(d.get("companions", []))
	c.companion_xp = _int_values(d.get("companion_xp", {}))
	c.lifespan_spent_years = int(d.get("lifespan_spent_years", 0))
	c.lifespan_bonus_years = int(d.get("lifespan_bonus_years", 0))
	c.artifact_lives = int(d.get("artifact_lives", -1))
	c.artifact_recharges = int(d.get("artifact_recharges", 0))
	c.artifact_energy = int(d.get("artifact_energy", 0))
	c.artifact_functions = _strings(d.get("artifact_functions", []))
	c.artifact_storage = _int_values(d.get("artifact_storage", {}))
	for plot in d.get("garden", []):
		if plot is Dictionary:
			c.garden.append({"item": String(plot.get("item", "")), "days_left": int(plot.get("days_left", 0))})
	c.mission_cooldowns = _int_values(d.get("mission_cooldowns", {}))
	c.deed_days = _int_values(d.get("deed_days", {}))
	c.life_stats = _int_values(d.get("life_stats", {}))
	c.year_start_stats = _int_values(d.get("year_start_stats", {}))
	c.year_start_year = int(d.get("year_start_year", 0))
	c.year_start_realm = String(d.get("year_start_realm", ""))
	for order in d.get("commissions", []):
		if order is Dictionary:
			c.commissions.append({"profession": String(order.get("profession", "")), "recipe": String(order.get("recipe", "")),
				"item": String(order.get("item", "")), "count": int(order.get("count", 1)), "reward": int(order.get("reward", 1)),
				"xp": float(order.get("xp", 0.0)), "due_day": int(order.get("due_day", 0))})
	c.milestones = _strings(d.get("milestones", []))
	c.trial_progress = _int_values(d.get("trial_progress", {}))
	c.reputation = _int_values(d.get("reputation", {}))
	for item_id in d.get("bound_artifacts", []):
		c.bound_artifacts.append(String(item_id))
	for region_id in d.get("visited_regions", []):
		c.visited_regions.append(String(region_id))
	c.devoured = int(d.get("devoured", 0))
	c.rival = String(d.get("rival", ""))
	c.abode = String(d.get("abode", ""))
	c.abode_storage = _int_values(d.get("abode_storage", {}))
	c.grudges = _int_values(d.get("grudges", {}))
	c.gratitude = _int_values(d.get("gratitude", {}))
	c.body_stage = int(d.get("body_stage", 0))
	var delves: Dictionary = d.get("secret_realms", {})
	for realm_id in delves:
		c.secret_realms[String(realm_id)] = {"opening": int(delves[realm_id].get("opening", -1)), "floor": int(delves[realm_id].get("floor", 0))}
	for realm_id in d.get("inheritances", []):
		c.inheritances.append(String(realm_id))
	c.abode_array = String(d.get("abode_array", ""))
	for anchor_id in d.get("anchors", []):
		c.anchors.append(String(anchor_id))
	for recipe_id in d.get("known_recipes", []):
		c.known_recipes.append(String(recipe_id))
	var saved_dao: Dictionary = d.get("dao", {})
	for insight_id in saved_dao:
		c.dao[String(insight_id)] = {"level": int(saved_dao[insight_id].get("level", 0)), "progress": float(saved_dao[insight_id].get("progress", 0))}
	c.main_method = String(d.get("main_method", ""))
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
