class_name Npcs
extends RefCounted
## NPCs: named ones from data/npcs.json and generated ones (Npcs.spawn) with no
## def at all. They reuse CharacterData and live their own lives off-screen:
## aging, cultivating and breaking through month by month. Behavior (region,
## cultivates, diligence) is read from the CharacterData first, falling back
## to the def for NPCs saved before FAM-001.

## NPCs are simulated in steps of at most this many days, so a year of
## seclusion gives them twelve chances to break through, not one.
const STEP_DAYS := Calendar.DAYS_PER_MONTH
## Fraction of their days NPCs spend cultivating, unless their data sets
## "diligence". They have lives, duties and bad habits.
const DEFAULT_DILIGENCE := 0.3
## Prefix of generated NPC ids ("gen_1", "gen_2", ...).
const SPAWN_PREFIX := "gen_"
## Diligence range for generated NPCs.
const SPAWN_DILIGENCE_MIN := 0.15
const SPAWN_DILIGENCE_MAX := 0.6


static func create(def: Dictionary, data: GameData, rng: RandomNumberGenerator) -> CharacterData:
	var c := CharacterData.new()
	c.id = def["id"]
	c.name = def.get("name", c.id)
	c.age_days = int(def.get("age_years", 20)) * Calendar.DAYS_PER_YEAR
	for attr_id in data.attribute_ids():
		c.attributes[attr_id] = int(def.get("attributes", {}).get(attr_id, 10))
	if def.has("roots"):
		for element in def["roots"]:
			c.spiritual_roots[element] = int(def["roots"][element])
	else:
		c.spiritual_roots = SpiritualRoots.roll(data, rng)
	c.realm_index = maxi(0, data.realm_index_of(def.get("realm", "mortal")))
	c.stage = clampi(int(def.get("stage", 0)), 0, data.realms[c.realm_index].stage_count() - 1)
	c.alignment = int(def.get("alignment", 0))
	c.gender = String(def.get("gender", ""))
	c.surname = String(def.get("surname", ""))
	c.given_name = String(def.get("given_name", ""))
	c.home_region = String(def.get("region", ""))
	c.cultivates = bool(def.get("cultivates", false))
	c.diligence = float(def.get("diligence", DEFAULT_DILIGENCE))
	c.bloodline = String(def.get("bloodline", ""))
	Bloodlines.update(c, data)
	return c


## Creates a new NPC without a data/npcs.json def, adds it to `npcs` under a
## unique id and returns it. Every `opts` key is optional:
## gender, surname, given_name, age_years (16-40), region, realm ("mortal"),
## stage, alignment, cultivates (true), diligence (random), roots (rolled),
## attributes (rolled per data/attributes.json).
static func spawn(npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, opts: Dictionary = {}) -> CharacterData:
	var c := CharacterData.new()
	c.id = next_id(npcs)
	c.gender = String(opts.get("gender", ""))
	if not Names.is_gender(data, c.gender):
		c.gender = Names.roll_gender(data, rng)
	var surname := String(opts.get("surname", ""))
	if surname == "":
		surname = Names.roll_surname(data, rng)
	var given := String(opts.get("given_name", ""))
	if given == "":
		given = Names.roll_given_name(data, c.gender, rng)
	Names.apply(c, surname, given)
	var age_years := int(opts.get("age_years", rng.randi_range(16, 40)))
	c.age_days = age_years * Calendar.DAYS_PER_YEAR + rng.randi_range(0, Calendar.DAYS_PER_YEAR - 1)
	var rolled := {}
	for attr in data.attributes:
		rolled[attr["id"]] = rng.randi_range(int(attr["roll_min"]), int(attr["roll_max"]))
	for attr_id in rolled:
		c.attributes[attr_id] = int(opts.get("attributes", {}).get(attr_id, rolled[attr_id]))
	if opts.has("roots"):
		for element in opts["roots"]:
			c.spiritual_roots[element] = int(opts["roots"][element])
	else:
		c.spiritual_roots = SpiritualRoots.roll(data, rng)
	c.realm_index = maxi(0, data.realm_index_of(String(opts.get("realm", "mortal"))))
	c.stage = clampi(int(opts.get("stage", 0)), 0, data.realms[c.realm_index].stage_count() - 1)
	c.alignment = int(opts.get("alignment", 0))
	c.home_region = String(opts.get("region", ""))
	c.cultivates = bool(opts.get("cultivates", true))
	c.diligence = float(opts.get("diligence", rng.randf_range(SPAWN_DILIGENCE_MIN, SPAWN_DILIGENCE_MAX)))
	c.proud = bool(opts.get("proud", false))
	npcs[c.id] = c
	return c


## The first free generated id. Deterministic, stable across saves, and never
## below the highest generated id in use, so ids of pruned NPCs (prune keeps
## the highest) are never handed out again.
static func next_id(npcs: Dictionary) -> String:
	var n := maxi(npcs.size() + 1, highest_generated(npcs) + 1)
	while npcs.has(SPAWN_PREFIX + str(n)):
		n += 1
	return SPAWN_PREFIX + str(n)


## The largest number N of a "gen_N" id in `npcs` (0 if none).
static func highest_generated(npcs: Dictionary) -> int:
	var best := 0
	for npc_id: String in npcs:
		if npc_id.begins_with(SPAWN_PREFIX) and npc_id.substr(SPAWN_PREFIX.length()).is_valid_int():
			best = maxi(best, npc_id.substr(SPAWN_PREFIX.length()).to_int())
	return best


## Removes generated NPCs dead for at least `min_dead_days` who are not in
## `keep` (the player's family, rival, ledgers, favor...) and whom no living
## NPC in `keep` lists as parent, child or spouse: no living family the player
## knows. Strangers keep a pruned parent's or child's id in their lists
## (kinship checks skip ids that are gone); pruned spouses are removed from
## spouse lists, since unknown ids would count as living spouses. The highest generated id always stays so
## ids keep growing (next_id). Returns the pruned ids (FAM-013b).
static func prune(npcs: Dictionary, keep: Dictionary, min_dead_days: int) -> Array[String]:
	var referenced := {}
	for c: CharacterData in npcs.values():
		if not c.alive or not keep.has(c.id):
			continue
		for other_id in c.parents + c.children + c.spouses:
			referenced[other_id] = true
	var anchor := SPAWN_PREFIX + str(highest_generated(npcs))
	var pruned: Array[String] = []
	for npc_id: String in npcs.keys():
		var c: CharacterData = npcs[npc_id]
		if c.alive or not npc_id.begins_with(SPAWN_PREFIX) or npc_id == anchor:
			continue
		if c.dead_days < min_dead_days or keep.has(npc_id) or referenced.has(npc_id):
			continue
		npcs.erase(npc_id)
		pruned.append(npc_id)
	# Unknown ids count as living spouses (Family.is_living), so widows and
	# widowers forget a pruned spouse; parent/child ids stay for kinship checks.
	if not pruned.is_empty():
		for c: CharacterData in npcs.values():
			for npc_id in pruned:
				if c.spouses.has(npc_id):
					c.spouses.erase(npc_id)
					c.spouse_ranks.erase(npc_id)
	return pruned


static func region_of(c: CharacterData, data: GameData) -> String:
	if c.home_region != "":
		return c.home_region
	return String(data.npcs.get(c.id, {}).get("region", ""))


static func is_proud(c: CharacterData, data: GameData) -> bool:
	return c.proud or bool(data.npcs.get(c.id, {}).get("proud", false))


## Whether `c` is a generated courtship candidate: alive, adult, unmarried.
static func is_eligible(c: CharacterData, data: GameData) -> bool:
	return c.id.begins_with(SPAWN_PREFIX) and c.alive and c.spouses.is_empty() and c.age_years() >= int(data.family.get("adult_age", 16))


## Tops every region up to data/family.json eligible_npcs.per_gender eligible
## generated NPCs of each gender, so every region has courtship candidates.
## Realms come from realms_by_danger for the region's danger. NPCs in `exclude`
## (the player's own descendants) are not candidates and do not fill a slot.
## Returns the new NPCs.
static func ensure_eligible(npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, exclude: Array[String] = []) -> Array[CharacterData]:
	var rules: Dictionary = data.family.get("eligible_npcs", {})
	var by_danger: Array = rules.get("realms_by_danger", [])
	var spawned: Array[CharacterData] = []
	if by_danger.is_empty():
		return spawned
	var region_ids: Array = data.regions.keys()
	region_ids.sort()
	for region_id in region_ids:
		var counts := {}
		for c: CharacterData in npcs.values():
			if region_of(c, data) == region_id and is_eligible(c, data) and not exclude.has(c.id):
				counts[c.gender] = int(counts.get(c.gender, 0)) + 1
		var realms: Array = by_danger[clampi(int(data.regions[region_id].get("danger", 0)), 0, by_danger.size() - 1)]
		for gender in Names.genders(data):
			for i in range(int(counts.get(gender, 0)), int(rules.get("per_gender", 0))):
				var c := spawn(npcs, data, rng, {
					"gender": gender,
					"region": region_id,
					"age_years": rng.randi_range(int(rules.get("age_min", 16)), int(rules.get("age_max", 30))),
					"realm": String(realms[rng.randi_range(0, realms.size() - 1)]),
					"proud": rng.randf() < float(rules.get("proud_chance", 0.0)),
				})
				# A rare candidate carries a bloodline, so players can marry into one.
				if rules.has("bloodline_chance") and rng.randf() < float(rules["bloodline_chance"]):
					Bloodlines.grant(c, data, Bloodlines.roll_any(data, rng))
				spawned.append(c)
	return spawned


static func cultivates(c: CharacterData, data: GameData) -> bool:
	return c.cultivates or bool(data.npcs.get(c.id, {}).get("cultivates", false))


static func diligence_of(c: CharacterData, data: GameData) -> float:
	if c.diligence >= 0.0:
		return c.diligence
	return float(data.npcs.get(c.id, {}).get("diligence", DEFAULT_DILIGENCE))


## Creates any NPC in data that `npcs` (id -> CharacterData) does not have yet,
## so old saves pick up newly added NPCs.
static func ensure_all(npcs: Dictionary, data: GameData, rng: RandomNumberGenerator) -> void:
	for def: Dictionary in data.npcs.values():
		if not npcs.has(def["id"]):
			npcs[def["id"]] = create(def, data, rng)


## Lives `days` for every NPC, then their family life (NpcFamilies: marriages,
## children; NPCs in `reserved` never marry off-screen). Returns notable events
## as [{npc_id, text, category}] (family events also carry a "kind").
static func simulate(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator, reserved: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for npc_id in npcs:
		var c: CharacterData = npcs[npc_id]
		if not c.alive:
			c.dead_days += days
			continue
		var remaining := days
		while remaining > 0 and c.alive:
			var step := mini(remaining, STEP_DAYS)
			remaining -= step
			_live(c, data, step, rng, events)
	events.append_array(NpcFamilies.simulate(npcs, data, days, rng, reserved))
	return events


## Marks NPC `c` dead of `cause`. An unborn child dies with its mother: the
## pregnancy ends. Returns true if a pregnancy was lost. Every NPC death goes
## through here.
static func die(c: CharacterData, cause: String) -> bool:
	c.alive = false
	c.cause_of_death = cause
	if not Children.is_pregnant(c):
		return false
	c.pregnancy = {}
	return true


static func _live(c: CharacterData, data: GameData, days: int, rng: RandomNumberGenerator, events: Array[Dictionary]) -> void:
	c.age_days += days
	if c.age_years() >= Cultivation.lifespan_years(c, data):
		var text := "News arrives: %s has died of old age at %d." % [c.name, c.age_years()]
		if die(c, "old age"):
			text += " The unborn child is lost as well."
		events.append({"npc_id": c.id, "text": text, "category": "warning"})
		return
	# Injuries heal with time; adults may get hurt (injuries.json "npc_mishap", per month).
	Injuries.pass_days(c, days)
	if Children.can_cultivate_yet(c, data):
		Injuries.roll(c, data, "npc_mishap", rng, float(days) / STEP_DAYS)
	if not cultivates(c, data) or not Children.can_cultivate_yet(c, data):
		return
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return
	Cultivation.cultivate(c, data, days, Exploration.qi_density(data, region_of(c, data)) * diligence_of(c, data) * Sects.cultivation_bonus(c, data))
	if Cultivation.can_attempt_breakthrough(c, data):
		var result := Cultivation.attempt_breakthrough(c, data, rng, true)
		if result["died"]:
			var text := "Heaven's lightning falls: %s perished in the tribulation of %s." % [c.name, result["realm_name"]]
			if die(c, "heavenly tribulation"):
				text += " The unborn child is lost as well."
			events.append({"npc_id": c.id, "text": text, "category": "warning"})
			return
		# Mortal to Qi Refining is routine; only report real breakthroughs.
		if result["success"] and c.realm_index > 1:
			events.append({"npc_id": c.id, "text": "Rumours spread: %s has broken through to %s!" % [c.name, result["realm_name"]], "category": "info"})
		elif result["success"] and c.realm_index == 1:
			events.append({"npc_id": c.id, "text": "%s has begun Qi Refining." % c.name, "category": "info"})
		if result["success"] and Bloodlines.update(c, data):
			events.append({"npc_id": c.id, "text": "Heaven and earth tremble: the %s of %s has awakened!" % [Bloodlines.bloodline_name(data, c.bloodline), c.name], "category": "progress"})
		if result["success"] and Sects.npc_promote(c, data):
			events.append({"npc_id": c.id, "text": "%s is now %s." % [c.name, Sects.member_text(c, data)], "category": "info"})


## Whether simulate() news about `npc_id` should reach `player`: named NPCs
## always; generated ones only if the player knows them (has favor with them)
## or they are family (spouse, child or parent).
static func is_newsworthy(npc_id: String, player: CharacterData, favor: Dictionary) -> bool:
	if not npc_id.begins_with(SPAWN_PREFIX) or favor.has(npc_id):
		return true
	return player.spouses.has(npc_id) or player.children.has(npc_id) or player.parents.has(npc_id) or player.rival == npc_id


## NPCs whose home is `region_id` and who are still alive.
static func in_region(npcs: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for npc_id in npcs:
		var c: CharacterData = npcs[npc_id]
		if c.alive and region_of(c, data) == region_id:
			result.append(c)
	return result


static func to_dict(npcs: Dictionary) -> Dictionary:
	var out := {}
	for npc_id in npcs:
		out[npc_id] = (npcs[npc_id] as CharacterData).to_dict()
	return out


static func from_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for npc_id in d:
		out[npc_id] = CharacterData.from_dict(d[npc_id])
	return out


## Living generated NPCs (no data/npcs.json def) whose home is `region_id`,
## sorted by id so they keep their spots between visits.
static func generated_in_region(npcs: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for c in in_region(npcs, data, region_id):
		if not data.npcs.has(c.id):
			result.append(c)
	result.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.id.naturalnocasecmp_to(b.id) < 0)
	return result


## World positions for `count` NPCs: the region's npc_spots first, then a ring
## around `center` for any overflow.
static func spot_positions(count: int, spots: Array, center: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		if i < spots.size():
			out.append(Vector2(float(spots[i][0]), float(spots[i][1])))
		else:
			var k := i - spots.size()
			var radius := 140.0 + 50.0 * float(k / 8)
			out.append(center + Vector2.from_angle(TAU * float(k % 8) / 8.0) * radius)
	return out


## Short label shown under a generated NPC's name in the world: their relation
## to `player` (spouse rank, child) or else their realm, "Child" if underage.
static func world_title(c: CharacterData, player: CharacterData, data: GameData) -> String:
	if player != null and player.spouses.has(c.id):
		return "Your %s" % Family.rank_name(data, player.gender, String(player.spouse_ranks.get(c.id, ""))).capitalize()
	if player != null and player.children.has(c.id):
		return "Your %s" % _gender_word(c, "Son", "Daughter", "Child")
	if c.age_years() < int(data.family.get("adult_age", 16)):
		return "Child"
	return Cultivation.realm_label(c, data)


## One sentence describing a generated NPC as the player sees them.
static func describe(c: CharacterData, data: GameData) -> String:
	var adult := c.age_years() >= int(data.family.get("adult_age", 16))
	var who := _gender_word(c, "man", "woman", "person") if adult else _gender_word(c, "boy", "girl", "child")
	var text := "%s, a %s of %d" % [c.name, who, c.age_years()]
	if c.realm_index > 0:
		text += ", cultivating at %s" % Cultivation.realm_label(c, data)
	if not c.spouses.is_empty():
		text += ", married"
	var sect := Sects.member_text(c, data)
	if sect != "":
		text += ", %s" % sect
	# An awakened bloodline shakes heaven and earth; a dormant one is hidden.
	if c.bloodline_awakened and data.bloodlines.has(c.bloodline):
		text += ", bearing the awakened %s" % Bloodlines.bloodline_name(data, c.bloodline)
	return text + "."


static func _gender_word(c: CharacterData, male: String, female: String, other: String) -> String:
	match c.gender:
		"male":
			return male
		"female":
			return female
	return other
