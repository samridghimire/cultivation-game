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
var items: Dictionary = {}  # id -> Dictionary
var deeds: Dictionary = {}  # id -> Dictionary
var regions: Dictionary = {}  # id -> Dictionary
var start_region := ""
var encounters: Dictionary = {}  # id -> Dictionary
var techniques: Dictionary = {}  # id -> TechniqueDef
var technique_affinity_bonus := 0.5
var technique_mismatch_penalty := 0.5
var enemies: Dictionary = {}  # id -> Dictionary
var enemy_technique_level := 3
## Fraction of spirit stones lost when beaten by a non-lethal enemy.
var defeat_stone_loss := 0.2
var recovery_days := 30
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

	for s in _read(dir, "sects.json").get("sects", []):
		var def := SectDef.from_dict(s)
		sects[def.id] = def

	for item in _read(dir, "items.json").get("items", []):
		items[item["id"]] = item

	for deed in _read(dir, "deeds.json").get("deeds", []):
		deeds[deed["id"]] = deed

	var world := _read(dir, "regions.json")
	start_region = world.get("start_region", "")
	for region in world.get("regions", []):
		regions[region["id"]] = region

	for encounter in _read(dir, "encounters.json").get("encounters", []):
		encounters[encounter["id"]] = encounter

	var tech := _read(dir, "techniques.json")
	technique_affinity_bonus = float(tech.get("element_affinity_bonus", technique_affinity_bonus))
	technique_mismatch_penalty = float(tech.get("element_mismatch_penalty", technique_mismatch_penalty))
	for t in tech.get("techniques", []):
		var def := TechniqueDef.from_dict(t)
		techniques[def.id] = def

	var foes := _read(dir, "enemies.json")
	enemy_technique_level = int(foes.get("enemy_technique_level", enemy_technique_level))
	defeat_stone_loss = float(foes.get("defeat_stone_loss", defeat_stone_loss))
	recovery_days = int(foes.get("recovery_days", recovery_days))
	for enemy in foes.get("enemies", []):
		enemies[enemy["id"]] = enemy

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
	var counts := {}
	for g in root_grades:
		counts[int(g["element_count"])] = true
	for n in range(1, root_elements.size() + 1):
		if not counts.has(n):
			load_errors.append("No spiritual root grade for element_count %d" % n)


func _validate_world() -> void:
	if not regions.has(start_region):
		load_errors.append("start_region '%s' is not a region" % start_region)
	var place_types := ["meditation", "merchant", "sect_hall", "workshop", "deed_giver", "explore", "travel"]
	for region: Dictionary in regions.values():
		for route: Dictionary in region.get("routes", []):
			if not regions.has(route.get("to", "")):
				load_errors.append("Region '%s' has a route to unknown region '%s'" % [region["id"], route.get("to", "")])
			if route.has("min_realm") and realm_index_of(route["min_realm"]) < 0:
				load_errors.append("Region '%s' route has unknown min_realm '%s'" % [region["id"], route["min_realm"]])
		for place: Dictionary in region.get("places", []):
			if not place_types.has(place.get("type", "")):
				load_errors.append("Region '%s' has a place of unknown type '%s'" % [region["id"], place.get("type", "")])
	for e: Dictionary in encounters.values():
		for key in ["min_realm", "max_realm"]:
			if e.has(key) and realm_index_of(e[key]) < 0:
				load_errors.append("Encounter '%s' has unknown %s '%s'" % [e["id"], key, e[key]])
		for item_id in e.get("effects", {}).get("items", {}):
			if not items.has(item_id):
				load_errors.append("Encounter '%s' references unknown item '%s'" % [e["id"], item_id])
		if e.has("enemy") and not enemies.has(e["enemy"]):
			load_errors.append("Encounter '%s' references unknown enemy '%s'" % [e["id"], e["enemy"]])


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
	for item: Dictionary in items.values():
		var tech_id: String = item.get("effects", {}).get("learn_technique", "")
		if tech_id != "" and not techniques.has(tech_id):
			load_errors.append("Item '%s' teaches unknown technique '%s'" % [item["id"], tech_id])
	for enemy: Dictionary in enemies.values():
		if realm_index_of(enemy.get("realm", "")) < 0:
			load_errors.append("Enemy '%s' has unknown realm '%s'" % [enemy["id"], enemy.get("realm", "")])
		for tech_id in enemy.get("techniques", []):
			if not techniques.has(tech_id):
				load_errors.append("Enemy '%s' knows unknown technique '%s'" % [enemy["id"], tech_id])
		for item_id in enemy.get("rewards", {}).get("items", {}):
			if not items.has(item_id):
				load_errors.append("Enemy '%s' rewards unknown item '%s'" % [enemy["id"], item_id])
