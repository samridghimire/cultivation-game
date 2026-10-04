class_name GameData
extends RefCounted
## All static game definitions, loaded from res://data/*.json.
## Gameplay code reads content from here and never hardcodes it, so new realms,
## sects, professions, items and deeds can be added by editing JSON only.

const DEFAULT_DIR := "res://data"

var realms: Array[RealmDef] = []
## realms.json heart_demon: {max_alignment, hp_fraction} (see Tribulation); {} = none.
var heart_demon: Dictionary = {}
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
## items.json "restricted_tags": only merchants that stock these tags explicitly sell such items.
var restricted_item_tags: PackedStringArray = []
var deeds: Dictionary = {}  # id -> Dictionary
var regions: Dictionary = {}  # id -> Dictionary
var start_region := ""
var encounters: Dictionary = {}  # id -> Dictionary
var npcs: Dictionary = {}  # id -> Dictionary (definitions; live NPCs are in GameState.npcs)
var names: Dictionary = {}  # data/names.json: {"surnames": [...], "given_names": {gender: [...]}}
var dialogues: Dictionary = {}  # id -> Dictionary, one per data/dialogue/*.json
var techniques: Dictionary = {}  # id -> TechniqueDef
## data/dao.json tunables (see Dao) and its insights by id.
var dao: Dictionary = {}
var dao_insights: Dictionary = {}  # id -> Dictionary
var technique_affinity_bonus := 0.5
var technique_mismatch_penalty := 0.5
## Cultivation methods (techniques.json): the method everyone uses until they set
## another, days it takes to switch, and the qi rate of a method past its max_realm.
var starter_method := ""
var method_switch_days := 7
var method_over_cap_rate := 1.0
var enemies: Dictionary = {}  # id -> Dictionary
var enemy_technique_level := 3
## Per realm index: flat {attack, defense, max_hp, speed} bonuses every enemy of
## that realm gets on top of realm power (scaled like technique bonuses). The
## last entry applies to higher realms. Stands in for the techniques and gear
## a same-realm player has (QA-007d).
var enemy_realm_training: Array = []
## Each side's attack in a fight is multiplied by a random form in
## [1 - spread, 1 + spread], so close fights are not foregone conclusions.
var combat_form_spread := 0.0
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
var bloodlines: Dictionary = {}  # id -> Dictionary (data/bloodlines.json)
var beasts: Dictionary = {}  # id -> Dictionary (data/beasts.json)
## data/beasts.json top-level rules (max_companions, tame, rank_scale, outgrown_scale).
var beast_rules: Dictionary = {}
## data/bloodlines.json top-level rules (inherit chances).
var bloodline_rules: Dictionary = {}
## Grudge/gratitude rules (data/karma.json, Karma). "acts" is keyed by id after loading.
var karma: Dictionary = {}
## data/clan_buildings.json (ClanEstate): top-level rules plus "buildings".
var clan_estate: Dictionary = {}
var clan_buildings: Dictionary = {}  # id -> Dictionary (data/clan_buildings.json)
var npc_clans: Dictionary = {}  # id -> Dictionary (data/clans.json, NpcClans)
## Anchor id -> {"region": String, "name": String}, from places with an anchor_id.
var anchors: Dictionary = {}
## Claimable cave abodes: abode id -> regions.json abode def plus "region" (Abodes).
var abodes: Dictionary = {}
var recipes: Dictionary = {}  # id -> Dictionary (data/recipes.json)
## Alchemy tunables (see Alchemy).
var alchemy: Dictionary = {}
var sect_missions: Dictionary = {}  # id -> Dictionary (data/sect_missions.json)
## Help screen pages, in order: [{id, title, body: [paragraph]}] (data/help.json).
var help_pages: Array = []
## Input action id -> display name for the help screen's Controls page.
var help_action_names: Dictionary = {}
var secret_realms: Dictionary = {}  # id -> Dictionary (data/secret_realms.json, SecretRealms)
var auction_houses: Dictionary = {}  # id -> Dictionary (data/auctions.json, Auctions)
var inheritances: Dictionary = {}  # id -> Dictionary (data/inheritances.json, Inheritances)
## data/body_tempering.json: rules and ordered "stages" (BodyTempering).
var body_tempering: Dictionary = {}
## data/demonic_arts.json: demonic art rules, e.g. "devouring" (Devouring).
var demonic_arts: Dictionary = {}
var world_events: Dictionary = {}  # id -> Dictionary (data/world_events.json, WorldEvents)
## Problems found while loading. Empty when all data files are valid.
var load_errors: PackedStringArray = []


static func load_from_dir(dir: String = DEFAULT_DIR) -> GameData:
	var data := GameData.new()
	data._load(dir)
	return data


## A place's display name without its trailing map hint, for use in sentences:
## "Cloud-Sea Cliff (2x qi)" -> "Cloud-Sea Cliff", "Waterfall Cave (abode)" -> "Waterfall Cave".
static func plain_name(display_name: String) -> String:
	var cut := display_name.rfind(" (")
	return display_name.left(cut) if cut > 0 and display_name.ends_with(")") else display_name


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
	var realm_file := _read(dir, "realms.json")
	for r in realm_file.get("realms", []):
		realms.append(RealmDef.from_dict(r))
	heart_demon = realm_file.get("heart_demon", {})

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

	var item_file := _read(dir, "items.json")
	restricted_item_tags = PackedStringArray(item_file.get("restricted_tags", []))
	for item in item_file.get("items", []):
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
			anchors[anchor_id] = {"region": region["id"], "name": plain_name(String(place.get("display_name", anchor_id)))}
		for abode: Dictionary in region.get("abodes", []):
			if abodes.has(abode.get("id", "")):
				load_errors.append("Duplicate abode id '%s'" % abode.get("id", ""))
			abodes[String(abode.get("id", ""))] = abode.merged({"region": region["id"]})
			var abode_anchor: String = abode.get("anchor_id", "")
			if abode_anchor == "":
				continue
			if anchors.has(abode_anchor):
				load_errors.append("Duplicate anchor_id '%s'" % abode_anchor)
			anchors[abode_anchor] = {"region": region["id"], "name": plain_name(String(abode.get("display_name", abode_anchor)))}

	artifact = _read(dir, "artifact.json")

	for encounter in _read(dir, "encounters.json").get("encounters", []):
		encounters[encounter["id"]] = encounter

	for npc in _read(dir, "npcs.json").get("npcs", []):
		npcs[npc["id"]] = npc

	names = _read(dir, "names.json")
	family = _read(dir, "family.json")
	bloodline_rules = _read(dir, "bloodlines.json")
	for bloodline in bloodline_rules.get("bloodlines", []):
		bloodlines[bloodline["id"]] = bloodline
	karma = _read(dir, "karma.json")
	var karma_acts := {}
	for act in karma.get("acts", []):
		karma_acts[act["id"]] = act
	karma["acts"] = karma_acts
	clan_estate = _read(dir, "clan_buildings.json")
	for building in clan_estate.get("buildings", []):
		clan_buildings[building["id"]] = building
	for npc_clan in _read(dir, "clans.json").get("clans", []):
		npc_clans[npc_clan["id"]] = npc_clan
	beast_rules = _read(dir, "beasts.json")
	for beast in beast_rules.get("beasts", []):
		beasts[beast["id"]] = beast

	var dialogue_dir := dir.path_join("dialogue")
	for file_name in DirAccess.get_files_at(dialogue_dir):
		if file_name.ends_with(".json"):
			var dialogue := _read(dialogue_dir, file_name)
			dialogues[dialogue.get("id", file_name.get_basename())] = dialogue

	var tech := _read(dir, "techniques.json")
	technique_affinity_bonus = float(tech.get("element_affinity_bonus", technique_affinity_bonus))
	technique_mismatch_penalty = float(tech.get("element_mismatch_penalty", technique_mismatch_penalty))
	starter_method = tech.get("starter_method", starter_method)
	method_switch_days = int(tech.get("method_switch_days", method_switch_days))
	method_over_cap_rate = float(tech.get("method_over_cap_rate", method_over_cap_rate))
	for t in tech.get("techniques", []):
		var def := TechniqueDef.from_dict(t)
		techniques[def.id] = def

	dao = _read(dir, "dao.json")
	for insight: Dictionary in dao.get("insights", []):
		dao_insights[insight["id"]] = insight

	var foes := _read(dir, "enemies.json")
	enemy_technique_level = int(foes.get("enemy_technique_level", enemy_technique_level))
	enemy_realm_training = foes.get("realm_training", [])
	combat_form_spread = float(foes.get("form_spread", combat_form_spread))
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

	var help := _read(dir, "help.json")
	help_pages = help.get("pages", [])
	help_action_names = help.get("action_names", {})

	for secret_realm in _read(dir, "secret_realms.json").get("realms", []):
		secret_realms[secret_realm["id"]] = secret_realm
	for auction_house in _read(dir, "auctions.json").get("houses", []):
		auction_houses[auction_house["id"]] = auction_house
	for legacy in _read(dir, "inheritances.json").get("inheritances", []):
		inheritances[legacy["id"]] = legacy
	body_tempering = _read(dir, "body_tempering.json")
	demonic_arts = _read(dir, "demonic_arts.json")
	for world_event in _read(dir, "world_events.json").get("events", []):
		world_events[world_event["id"]] = world_event
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
	load_errors.append_array(Tribulation.validate(self))
	load_errors.append_array(Dao.validate(self))
	var attr_ids := attribute_ids()
	for def: ProfessionDef in professions.values():
		if not attr_ids.has(def.primary_attribute):
			load_errors.append("Profession '%s' has unknown primary_attribute '%s'" % [def.id, def.primary_attribute])
	for def: SectDef in sects.values():
		if realm_index_of(def.min_realm) < 0:
			load_errors.append("Sect '%s' has unknown min_realm '%s'" % [def.id, def.min_realm])
		if def.ranks.is_empty():
			load_errors.append("Sect '%s' has no ranks" % def.id)
		if def.robe_color != "" and not Color.html_is_valid(def.robe_color):
			load_errors.append("Sect '%s' has an invalid robe_color '%s'" % [def.id, def.robe_color])
		for prof_id in def.favored_professions:
			if not professions.has(prof_id):
				load_errors.append("Sect '%s' favors unknown profession '%s'" % [def.id, prof_id])
	load_errors.append_array(Deeds.validate(self))
	_validate_world()
	_validate_combat()
	_validate_artifact()
	_validate_recipes()
	_validate_help()
	load_errors.append_array(Equipment.validate(self))
	load_errors.append_array(CombatTalismans.validate(self))
	load_errors.append_array(Family.validate(self))
	load_errors.append_array(Abodes.validate(self))
	load_errors.append_array(ArtifactFunctions.validate(self))
	load_errors.append_array(Karma.validate(self))
	load_errors.append_array(SecretRealms.validate(self))
	load_errors.append_array(Inheritances.validate(self))
	load_errors.append_array(Children.validate(self))
	load_errors.append_array(NpcFamilies.validate(self))
	load_errors.append_array(Training.validate(self))
	load_errors.append_array(Clans.validate(self))
	load_errors.append_array(ClanEstate.validate(self))
	load_errors.append_array(NpcClans.validate(self))
	load_errors.append_array(Bloodlines.validate(self))
	load_errors.append_array(Beasts.validate(self))
	load_errors.append_array(Sects.validate_missions(self))
	load_errors.append_array(Reputation.validate(self))
	load_errors.append_array(Exploration.validate_choices(self))
	load_errors.append_array(Scenery.validate(self))
	load_errors.append_array(Adoption.validate(self))
	load_errors.append_array(Sects.validate_shops(self))
	load_errors.append_array(Sects.validate_ranks(self))
	load_errors.append_array(Auctions.validate(self))
	load_errors.append_array(BodyTempering.validate(self))
	load_errors.append_array(Devouring.validate(self))
	load_errors.append_array(WorldEvents.validate(self))
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
	var place_types := ["meditation", "merchant", "sect_hall", "workshop", "clinic", "orphanage", "deed_giver", "explore", "travel", "gather", "secret_realm", "auction"]
	for region: Dictionary in regions.values():
		for route: Dictionary in region.get("routes", []):
			if not regions.has(route.get("to", "")):
				load_errors.append("Region '%s' has a route to unknown region '%s'" % [region["id"], route.get("to", "")])
			if route.has("min_realm") and realm_index_of(route["min_realm"]) < 0:
				load_errors.append("Region '%s' route has unknown min_realm '%s'" % [region["id"], route["min_realm"]])
		if region.has("map_pos"):
			var map_pos: Variant = region["map_pos"]
			if not (map_pos is Array and (map_pos as Array).size() == 2 and (map_pos as Array).all(func(v): return (v is float or v is int) and v >= 0.0 and v <= 1.0)):
				load_errors.append("Region '%s' map_pos must be [x, y] with values in 0..1" % region["id"])
		for spot in region.get("npc_spots", []):
			if not (spot is Array and (spot as Array).size() == 2):
				load_errors.append("Region '%s' has an npc_spot that is not [x, y]: %s" % [region["id"], spot])
		for place: Dictionary in region.get("places", []):
			for entry: Dictionary in place.get("gather_table", []):
				if entry.get("item", "") != "" and not items.has(entry["item"]):
					load_errors.append("Region '%s' gathers unknown item '%s'" % [region["id"], entry["item"]])
				if entry.has("min_realm") and realm_index_of(String(entry["min_realm"])) < 0:
					load_errors.append("Region '%s' gather entry '%s' has unknown min_realm '%s'" % [region["id"], entry.get("item", ""), entry["min_realm"]])
			if not place_types.has(place.get("type", "")):
				load_errors.append("Region '%s' has a place of unknown type '%s'" % [region["id"], place.get("type", "")])
			if place.get("type", "") == "auction" and not auction_houses.has(String(place.get("house_id", ""))):
				load_errors.append("Region '%s' auction place has unknown house_id '%s'" % [region["id"], place.get("house_id", "")])
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
	if combat_form_spread < 0.0 or combat_form_spread >= 1.0:
		load_errors.append("enemies.json form_spread must be in [0, 1)")
	for entry in enemy_realm_training:
		if not entry is Dictionary:
			load_errors.append("enemies.json realm_training entries must be objects")
			continue
		for key in entry:
			if not key in ["attack", "defense", "max_hp", "speed"]:
				load_errors.append("enemies.json realm_training has unknown stat '%s'" % key)
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
		if def.is_method():
			if def.qi_rate <= 0.0:
				load_errors.append("Method '%s' needs qi_rate > 0" % def.id)
			if def.max_realm != "" and realm_index_of(def.max_realm) < realm_index_of(def.min_realm):
				load_errors.append("Method '%s' has unknown or too-low max_realm '%s'" % [def.id, def.max_realm])
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
	if starter_method != "":
		var starter: TechniqueDef = techniques.get(starter_method)
		if starter == null or not starter.is_method():
			load_errors.append("starter_method '%s' is not a method in techniques.json" % starter_method)
		elif starter.min_realm != "mortal" or starter.max_realm != "":
			load_errors.append("starter_method '%s' must be usable from mortal with no max_realm" % starter_method)
	if method_switch_days < 0 or method_over_cap_rate <= 0.0:
		load_errors.append("techniques.json method_switch_days must be >= 0 and method_over_cap_rate > 0")
	for item: Dictionary in items.values():
		var tech_id: String = item.get("effects", {}).get("learn_technique", "")
		if tech_id != "" and not techniques.has(tech_id):
			load_errors.append("Item '%s' teaches unknown technique '%s'" % [item["id"], tech_id])
	for source in injury_sources:
		for entry in injury_sources[source].get("table", []):
			if not injuries.has(entry.get("id", "")):
				load_errors.append("Injury source '%s' references unknown injury '%s'" % [source, entry.get("id", "")])
			if entry.has("min_realm") and realm_index_of(String(entry["min_realm"])) < 0:
				load_errors.append("Injury source '%s' entry '%s' has unknown min_realm '%s'" % [source, entry.get("id", ""), entry["min_realm"]])
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


func _validate_help() -> void:
	var ids := {}
	for page in help_pages:
		if not page is Dictionary or String(page.get("id", "")) == "" or String(page.get("title", "")) == "":
			load_errors.append("help.json page needs an id and a title: %s" % [page])
			continue
		if ids.has(page["id"]):
			load_errors.append("help.json has a duplicate page id '%s'" % page["id"])
		ids[page["id"]] = true
		var body: Variant = page.get("body", [])
		if not body is Array or (body as Array).is_empty() or (body as Array).any(func(p): return not p is String):
			load_errors.append("help.json page '%s' needs a non-empty body of strings" % page["id"])
	for action in help_action_names:
		if not help_action_names[action] is String:
			load_errors.append("help.json action_names['%s'] must be a string" % action)


func _validate_artifact() -> void:
	if int(artifact.get("starting_lives", 0)) < 0 or int(artifact.get("max_lives", 0)) < int(artifact.get("starting_lives", 0)):
		load_errors.append("artifact.json needs 0 <= starting_lives <= max_lives")
	var intro: String = artifact.get("intro_event", "")
	if intro != "" and not dialogues.has(intro):
		load_errors.append("artifact.json intro_event '%s' is not a dialogue" % intro)
	var start: String = artifact.get("start_anchor", "")
	if start != "" and not anchors.has(start):
		load_errors.append("artifact.json start_anchor '%s' is not an anchor" % start)
	for realm_id in artifact.get("anchor_slots", {}):
		if realm_index_of(realm_id) < 0:
			load_errors.append("artifact.json anchor_slots has unknown realm '%s'" % realm_id)


func _validate_recipes() -> void:
	var markup: Variant = alchemy.get("crafted_sell_markup", 1.3)
	if not (markup is float or markup is int) or float(markup) < 1.0:
		load_errors.append("recipes.json alchemy.crafted_sell_markup must be a number >= 1")
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
