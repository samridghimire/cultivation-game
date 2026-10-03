class_name GameData
extends RefCounted
## All static game definitions, loaded from res://data/*.json.
## Gameplay code reads content from here and never hardcodes it, so new realms,
## sects, professions, items and deeds can be added by editing JSON only.

const DEFAULT_DIR := "res://data"

var realms: Array[RealmDef] = []
var attributes: Array[Dictionary] = []
var root_elements: Array[Dictionary] = []
var root_grades: Array[Dictionary] = []
var root_purity_min := 20
var root_purity_max := 100
var alignment_min := -1000
var alignment_max := 1000
var alignment_tiers: Array[Dictionary] = []
var profession_rank_names: PackedStringArray = []
var professions: Dictionary = {}  # id -> ProfessionDef
var sects: Dictionary = {}  # id -> SectDef
## sects.json top-level "reputation" rules (Reputation system).
var sect_reputation: Dictionary = {}
var items: Dictionary = {}  # id -> Dictionary
var deeds: Dictionary = {}  # id -> Dictionary
var regions: Dictionary = {}  # id -> Dictionary
var start_region := ""
var encounters: Dictionary = {}  # id -> Dictionary
var npcs: Dictionary = {}  # id -> Dictionary (definitions; live NPCs are in GameState.npcs)
var names: Dictionary = {}  # data/names.json: {"surnames": [...], "given_names": {gender: [...]}}
var dialogues: Dictionary = {}  # id -> Dictionary, one per data/dialogue/*.json
var techniques: Dictionary = {}  # id -> TechniqueDef
var technique_affinity_bonus := 0.5
var technique_mismatch_penalty := 0.5
var enemies: Dictionary = {}  # id -> Dictionary
var enemy_technique_level := 3
## Fraction of spirit stones lost when beaten by a non-lethal enemy.
var defeat_stone_loss := 0.2
var injuries: Dictionary = {}  # id -> Dictionary
## Source name (e.g. "combat_defeat") -> {"chance": float, "table": [{"id", "weight"}]}.
var injury_sources: Dictionary = {}
var injury_fortune_step := 0.02
## Doctor tunables (see Medicine).
var medicine: Dictionary = {}
## Creation Artifact tunables (data/artifact.json, see CreationArtifact).
var artifact: Dictionary = {}
var family: Dictionary = {}  # data/family.json (Family system)
## Anchor id -> {"region": String, "name": String}, from places with an anchor_id.
var anchors: Dictionary = {}
var recipes: Dictionary = {}  # id -> Dictionary (data/recipes.json)
## Alchemy tunables (see Alchemy).
var alchemy: Dictionary = {}
var sect_missions: Dictionary = {}  # id -> Dictionary (data/sect_missions.json)
## Problems found while loading. Empty when all data files are valid.
var load_errors: PackedStringArray = []


static func load_from_dir(dir: String = DEFAULT_DIR) -> GameData:
	var data := GameData.new()
	data._load(dir)
	return data


func realm_index_of(realm_id: String) -> int:
	for i in realms.size():
		if realms[i].id == realm_id:
			return i
	return -1


func attribute_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for a in attributes:
		ids.append(a["id"])
	return ids


func _load(dir: String) -> void:
	for r in _read(dir, "realms.json").get("realms", []):
		realms.append(RealmDef.from_dict(r))

	attributes.assign(_read(dir, "attributes.json").get("attributes", []))

	var roots := _read(dir, "spiritual_roots.json")
	root_elements.assign(roots.get("elements", []))
	root_grades.assign(roots.get("grades", []))
	root_purity_min = int(roots.get("purity_min", root_purity_min))
	root_purity_max = int(roots.get("purity_max", root_purity_max))

	var align := _read(dir, "alignment.json")
	alignment_min = int(align.get("min", alignment_min))
	alignment_max = int(align.get("max", alignment_max))
	alignment_tiers.assign(align.get("tiers", []))
	alignment_tiers.sort_custom(func(a, b): return a["min"] < b["min"])

	var prof := _read(dir, "professions.json")
	profession_rank_names = PackedStringArray(prof.get("rank_names", []))
	for p in prof.get("professions", []):
		var def := ProfessionDef.from_dict(p)
		professions[def.id] = def

	var sect_file := _read(dir, "sects.json")
	sect_reputation = sect_file.get("reputation", {})
	for s in sect_file.get("sects", []):
		var def := SectDef.from_dict(s)
		sects[def.id] = def

	for item in _read(dir, "items.json").get("items", []):
		items[item["id"]] = item

	for mission in _read(dir, "sect_missions.json").get("missions", []):
		sect_missions[mission["id"]] = mission

	for deed in _read(dir, "deeds.json").get("deeds", []):
		deeds[deed["id"]] = deed

	var world := _read(dir, "regions.json")
	start_region = world.get("start_region", "")
	for region in world.get("regions", []):
		regions[region["id"]] = region
		for place: Dictionary in region.get("places", []):
			var anchor_id: String = place.get("anchor_id", "")
			if anchor_id == "":
				continue
			if anchors.has(anchor_id):
				load_errors.append("Duplicate anchor_id '%s'" % anchor_id)
			anchors[anchor_id] = {"region": region["id"], "name": place.get("display_name", anchor_id)}

	artifact = _read(dir, "artifact.json")

	for encounter in _read(dir, "encounters.json").get("encounters", []):
		encounters[encounter["id"]] = encounter

	for npc in _read(dir, "npcs.json").get("npcs", []):
		npcs[npc["id"]] = npc

	names = _read(dir, "names.json")
	family = _read(dir, "family.json")

	var dialogue_dir := dir.path_join("dialogue")
	for file_name in DirAccess.get_files_at(dialogue_dir):
		if file_name.ends_with(".json"):
			var dialogue := _read(dialogue_dir, file_name)
			dialogues[dialogue.get("id", file_name.get_basename())] = dialogue

	var tech := _read(dir, "techniques.json")
	technique_affinity_bonus = float(tech.get("element_affinity_bonus", technique_affinity_bonus))
	technique_mismatch_penalty = float(tech.get("element_mismatch_penalty", technique_mismatch_penalty))
	for t in tech.get("techniques", []):
		var def := TechniqueDef.from_dict(t)
		techniques[def.id] = def

	var foes := _read(dir, "enemies.json")
	enemy_technique_level = int(foes.get("enemy_technique_level", enemy_technique_level))
	defeat_stone_loss = float(foes.get("defeat_stone_loss", defeat_stone_loss))
	for enemy in foes.get("enemies", []):
		enemies[enemy["id"]] = enemy

	var hurt := _read(dir, "injuries.json")
	injury_fortune_step = float(hurt.get("fortune_step", injury_fortune_step))
	injury_sources = hurt.get("sources", {})
	medicine = hurt.get("medicine", {})
	for injury in hurt.get("injuries", []):
		injuries[injury["id"]] = injury

	var crafting := _read(dir, "recipes.json")
	alchemy = crafting.get("alchemy", {})
	for recipe in crafting.get("recipes", []):
		recipes[recipe["id"]] = recipe

	_validate()


func _read(dir: String, file_name: String) -> Dictionary:
	var path := dir.path_join(file_name)
	if not FileAccess.file_exists(path):
		load_errors.append("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		load_errors.append("Invalid JSON (expected an object): %s" % path)
		return {}
	return parsed


## Cross-reference checks so broken content fails loudly in tests.
func _validate() -> void:
	if realms.is_empty():
		load_errors.append("No realms defined")
	var attr_ids := attribute_ids()
	for def: ProfessionDef in professions.values():
		if not attr_ids.has(def.primary_attribute):
			load_errors.append("Profession '%s' has unknown primary_attribute '%s'" % [def.id, def.primary_attribute])
	for def: SectDef in sects.values():
		if realm_index_of(def.min_realm) < 0:
			load_errors.append("Sect '%s' has unknown min_realm '%s'" % [def.id, def.min_realm])
		if def.ranks.is_empty():
			load_errors.append("Sect '%s' has no ranks" % def.id)
		for prof_id in def.favored_professions:
			if not professions.has(prof_id):
				load_errors.append("Sect '%s' favors unknown profession '%s'" % [def.id, prof_id])
	for deed: Dictionary in deeds.values():
		for item_id in deed.get("effects", {}).get("items", {}):
			if not items.has(item_id):
				load_errors.append("Deed '%s' references unknown item '%s'" % [deed["id"], item_id])
	_validate_world()
	_validate_combat()
	_validate_artifact()
	_validate_recipes()
	load_errors.append_array(Equipment.validate(self))
	load_errors.append_array(CombatTalismans.validate(self))
	load_errors.append_array(Family.validate(self))
	load_errors.append_array(Children.validate(self))
	load_errors.append_array(Sects.validate_missions(self))
	load_errors.append_array(Reputation.validate(self))
	load_errors.append_array(Exploration.validate_choices(self))
	for item: Dictionary in items.values():
		if item.get("effects", {}).has("buff"):
			for error in Buffs.validate_effect(item["effects"]["buff"]):
				load_errors.append("Item '%s': %s" % [item["id"], error])
		for key in ["burn_lifespan", "extend_lifespan"]:
			if item.get("effects", {}).has(key) and int(item["effects"][key]) <= 0:
				load_errors.append("Item '%s' needs a positive %s" % [item["id"], key])
	var counts := {}
	for g in root_grades:
		counts[int(g["element_count"])] = true
	for n in range(1, root_elements.size() + 1):
		if not counts.has(n):
			load_errors.append("No spiritual root grade for element_count %d" % n)


func _validate_world() -> void:
	if not regions.has(start_region):
		load_errors.append("start_region '%s' is not a region" % start_region)
	var place_types := ["meditation", "merchant", "sect_hall", "workshop", "deed_giver", "explore", "travel", "gather"]
	for region: Dictionary in regions.values():
		for route: Dictionary in region.get("routes", []):
			if not regions.has(route.get("to", "")):
				load_errors.append("Region '%s' has a route to unknown region '%s'" % [region["id"], route.get("to", "")])
			if route.has("min_realm") and realm_index_of(route["min_realm"]) < 0:
				load_errors.append("Region '%s' route has unknown min_realm '%s'" % [region["id"], route["min_realm"]])
		for spot in region.get("npc_spots", []):
			if not (spot is Array and (spot as Array).size() == 2):
				load_errors.append("Region '%s' has an npc_spot that is not [x, y]: %s" % [region["id"], spot])
		for place: Dictionary in region.get("places", []):
			for entry: Dictionary in place.get("gather_table", []):
				if entry.get("item", "") != "" and not items.has(entry["item"]):
					load_errors.append("Region '%s' gathers unknown item '%s'" % [region["id"], entry["item"]])
			if not place_types.has(place.get("type", "")):
				load_errors.append("Region '%s' has a place of unknown type '%s'" % [region["id"], place.get("type", "")])
			if place.has("faction") and not sects.has(place["faction"]):
				load_errors.append("Region '%s' place has unknown faction '%s'" % [region["id"], place["faction"]])
	for e: Dictionary in encounters.values():
		for key in ["min_realm", "max_realm"]:
			if e.has(key) and realm_index_of(e[key]) < 0:
				load_errors.append("Encounter '%s' has unknown %s '%s'" % [e["id"], key, e[key]])
		for item_id in e.get("effects", {}).get("items", {}):
			if not items.has(item_id):
				load_errors.append("Encounter '%s' references unknown item '%s'" % [e["id"], item_id])
		if e.has("enemy") and not enemies.has(e["enemy"]):
			load_errors.append("Encounter '%s' references unknown enemy '%s'" % [e["id"], e["enemy"]])
	if (names.get("surnames", []) as Array).is_empty():
		load_errors.append("names.json has no surnames")
	var given: Dictionary = names.get("given_names", {})
	if given.is_empty():
		load_errors.append("names.json has no given_names")
	for gender in given:
		if (given[gender] as Array).is_empty():
			load_errors.append("names.json has no given names for gender '%s'" % gender)
	for npc: Dictionary in npcs.values():
		if npc.has("gender") and not given.has(npc["gender"]):
			load_errors.append("NPC '%s' has unknown gender '%s'" % [npc["id"], npc["gender"]])
		if not regions.has(npc.get("region", "")):
			load_errors.append("NPC '%s' is in unknown region '%s'" % [npc["id"], npc.get("region", "")])
		if realm_index_of(npc.get("realm", "mortal")) < 0:
			load_errors.append("NPC '%s' has unknown realm '%s'" % [npc["id"], npc.get("realm", "")])
		if npc.has("dialogue") and not dialogues.has(npc["dialogue"]):
			load_errors.append("NPC '%s' has unknown dialogue '%s'" % [npc["id"], npc["dialogue"]])
	for dialogue: Dictionary in dialogues.values():
		load_errors.append_array(Dialogue.validate(dialogue, self))


func _validate_combat() -> void:
	var element_ids: Array = root_elements.map(func(e): return e["id"])
	for def: TechniqueDef in techniques.values():
		if realm_index_of(def.min_realm) < 0:
			load_errors.append("Technique '%s' has unknown min_realm '%s'" % [def.id, def.min_realm])
		if def.element != "" and not element_ids.has(def.element):
			load_errors.append("Technique '%s' has unknown element '%s'" % [def.id, def.element])
		if def.manual_item != "" and not items.has(def.manual_item):
			load_errors.append("Technique '%s' has unknown manual_item '%s'" % [def.id, def.manual_item])
		for key in def.bonuses:
			if not TechniqueDef.BONUS_KEYS.has(key):
				load_errors.append("Technique '%s' has unknown bonus '%s'" % [def.id, key])
		if not def.activation.is_empty():
			if int(def.activation.get("days", 0)) <= 0:
				load_errors.append("Technique '%s' activation needs days > 0" % def.id)
			if int(def.activation.get("lifespan_cost", 0)) < 0:
				load_errors.append("Technique '%s' activation has a negative lifespan_cost" % def.id)
			var buff: Dictionary = def.activation.get("buff", {})
			if buff.is_empty():
				load_errors.append("Technique '%s' activation has no buff" % def.id)
			for key in buff:
				if not Buffs.STAT_KEYS.has(key):
					load_errors.append("Technique '%s' activation buffs unknown stat '%s'" % [def.id, key])
	for item: Dictionary in items.values():
		var tech_id: String = item.get("effects", {}).get("learn_technique", "")
		if tech_id != "" and not techniques.has(tech_id):
			load_errors.append("Item '%s' teaches unknown technique '%s'" % [item["id"], tech_id])
	for source in injury_sources:
		for entry in injury_sources[source].get("table", []):
			if not injuries.has(entry.get("id", "")):
				load_errors.append("Injury source '%s' references unknown injury '%s'" % [source, entry.get("id", "")])
	for injury: Dictionary in injuries.values():
		if int(injury.get("heal_days", 0)) <= 0:
			load_errors.append("Injury '%s' needs heal_days > 0" % injury["id"])
		if int(injury.get("treatment_cost", 0)) <= 0:
			load_errors.append("Injury '%s' needs treatment_cost > 0" % injury["id"])
	for item: Dictionary in items.values():
		var injury_id: String = item.get("effects", {}).get("heal_injury", "")
		if injury_id != "" and injury_id != "all" and not injuries.has(injury_id):
			load_errors.append("Item '%s' heals unknown injury '%s'" % [item["id"], injury_id])
	for enemy: Dictionary in enemies.values():
		if realm_index_of(enemy.get("realm", "")) < 0:
			load_errors.append("Enemy '%s' has unknown realm '%s'" % [enemy["id"], enemy.get("realm", "")])
		for tech_id in enemy.get("techniques", []):
			if not techniques.has(tech_id):
				load_errors.append("Enemy '%s' knows unknown technique '%s'" % [enemy["id"], tech_id])
		for item_id in enemy.get("rewards", {}).get("items", {}):
			if not items.has(item_id):
				load_errors.append("Enemy '%s' rewards unknown item '%s'" % [enemy["id"], item_id])


func _validate_artifact() -> void:
	if int(artifact.get("starting_lives", 0)) < 0 or int(artifact.get("max_lives", 0)) < int(artifact.get("starting_lives", 0)):
		load_errors.append("artifact.json needs 0 <= starting_lives <= max_lives")
	var start: String = artifact.get("start_anchor", "")
	if start != "" and not anchors.has(start):
		load_errors.append("artifact.json start_anchor '%s' is not an anchor" % start)
	for realm_id in artifact.get("anchor_slots", {}):
		if realm_index_of(realm_id) < 0:
			load_errors.append("artifact.json anchor_slots has unknown realm '%s'" % realm_id)


func _validate_recipes() -> void:
	for recipe: Dictionary in recipes.values():
		var id: String = recipe["id"]
		if not professions.has(recipe.get("profession", "")):
			load_errors.append("Recipe '%s' has unknown profession '%s'" % [id, recipe.get("profession", "")])
		var min_rank := int(recipe.get("min_rank", 0))
		if min_rank < 0 or min_rank >= profession_rank_names.size():
			load_errors.append("Recipe '%s' has invalid min_rank %d" % [id, min_rank])
		if int(recipe.get("days", 0)) <= 0:
			load_errors.append("Recipe '%s' needs days > 0" % id)
		var ingredients: Dictionary = recipe.get("ingredients", {})
		if ingredients.is_empty():
			load_errors.append("Recipe '%s' has no ingredients" % id)
		for item_id in ingredients:
			if not items.has(item_id):
				load_errors.append("Recipe '%s' uses unknown item '%s'" % [id, item_id])
			if int(ingredients[item_id]) <= 0:
				load_errors.append("Recipe '%s' needs a positive count of '%s'" % [id, item_id])
		var output: Dictionary = recipe.get("output", {})
		if not items.has(output.get("item", "")):
			load_errors.append("Recipe '%s' outputs unknown item '%s'" % [id, output.get("item", "")])
		if int(output.get("count", 1)) <= 0:
			load_errors.append("Recipe '%s' needs output count > 0" % id)
		if recipe.has("great_output"):
			var great: Dictionary = recipe["great_output"]
			if not items.has(great.get("item", "")):
				load_errors.append("Recipe '%s' great_output is unknown item '%s'" % [id, great.get("item", "")])
			if int(great.get("count", 1)) <= 0:
				load_errors.append("Recipe '%s' needs great_output count > 0" % id)
		if recipe.has("starter") and typeof(recipe["starter"]) != TYPE_BOOL:
			load_errors.append("Recipe '%s' starter must be true or false" % id)
	for item: Dictionary in items.values():
		var recipe_id: String = item.get("effects", {}).get("learn_recipe", "")
		if recipe_id != "" and not recipes.has(recipe_id):
			load_errors.append("Item '%s' teaches unknown recipe '%s'" % [item["id"], recipe_id])
