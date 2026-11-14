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
const NAME_REROLLS := 10
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
		# Re-roll while a living NPC already has this full name.
		for _try in NAME_REROLLS:
			if not _living_has_name(npcs, Names.full_name(surname, given)):
				break
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


static func _living_has_name(npcs: Dictionary, full_name: String) -> bool:
	for other: CharacterData in npcs.values():
		if other.alive and other.name == full_name:
			return true
	return false


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
static func simulate(npcs: Dictionary, data: GameData, days: int, rng: RandomNumberGenerator, reserved: Dictionary = {}, flags: Dictionary = {}) -> Array[Dictionary]:
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
			_live(c, data, step, rng, events, flags)
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


static func _live(c: CharacterData, data: GameData, days: int, rng: RandomNumberGenerator, events: Array[Dictionary], flags: Dictionary = {}) -> void:
	c.age_days += days
	if c.age_years() >= Cultivation.lifespan_years(c, data):
		var text := "News arrives: %s has died of old age at %d." % [c.name, c.age_years()]
		if die(c, "old age"):
			text += " The unborn child is lost as well."
		events.append({"npc_id": c.id, "text": text, "category": "warning", "kind": "death"})
		return
	# Injuries heal with time; adults may get hurt (injuries.json "npc_mishap", per month).
	Injuries.pass_days(c, days)
	if Children.can_cultivate_yet(c, data):
		Injuries.roll(c, data, "npc_mishap", rng, float(days) / STEP_DAYS)
	if not cultivates(c, data) or not Children.can_cultivate_yet(c, data):
		return
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return
	Cultivation.cultivate(c, data, days, Exploration.qi_density(data, region_of(c, data), flags) * diligence_of(c, data) * Sects.cultivation_bonus(c, data))
	if Cultivation.can_attempt_breakthrough(c, data):
		var result := Cultivation.attempt_breakthrough(c, data, rng, true)
		if result["died"]:
			var text := "Heaven's lightning falls: %s perished in the tribulation of %s." % [c.name, result["realm_name"]]
			if die(c, "heavenly tribulation"):
				text += " The unborn child is lost as well."
			events.append({"npc_id": c.id, "text": text, "category": "warning", "kind": "death"})
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


## Ring positions closer than this to a place (or another NPC) are skipped.
const SPOT_CLEARANCE := 90.0
const SPOT_SEARCH_CAP := 64


## World positions for `count` NPCs: the region's npc_spots first, then a ring
## around `center` for any overflow. Ring candidates within SPOT_CLEARANCE of an
## `avoid` point or an already chosen spot are skipped (after SPOT_SEARCH_CAP
## candidates the next one is accepted anyway), so labels stay readable.
static func spot_positions(count: int, spots: Array, center: Vector2, avoid: Array[Vector2] = []) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var candidate := 0
	for i in count:
		if i < spots.size():
			var sp := Vector2(float(spots[i][0]), float(spots[i][1]))
			var gap_ok := true
			for q in out:
				if sp.distance_to(q) < SPOT_MIN_GAP:
					gap_ok = false
			for q in avoid:
				if sp.distance_to(q) < SPOT_MIN_GAP:
					gap_ok = false
			if gap_ok:
				out.append(sp)
				continue
		var pos := center
		for tries in SPOT_SEARCH_CAP:
			var radius := 140.0 + 50.0 * float(candidate / 8)
			pos = center + Vector2.from_angle(TAU * float(candidate % 8) / 8.0) * radius
			candidate += 1
			if _spot_clear(pos, avoid, out):
				break
		out.append(pos)
	return out


## How far outside a place or landmark rect a villager stands, and the keep-out
## margin around every place and solid landmark (WORLD-001).
const HAUNT_STAND_OFF := 55.0
const HAUNT_KEEP_OUT := 40.0
const HAUNT_ADULT_PLACES: PackedStringArray = ["merchant", "workshop", "clinic", "gather", "meditation", "bounty_board"]
const HAUNT_CHILD_PLACES: PackedStringArray = ["orphanage"]
## Weather that sends villagers indoors, the places they leave, and where they go (WORLD-004).
const HAUNT_STORMY: PackedStringArray = ["rain", "snow"]
const HAUNT_OUTDOOR: PackedStringArray = ["gather", "field", "well", "pond", "stall", "landmark", "meditation", "explore", "travel", "bounty_board"]
const HAUNT_SHELTER_PLACES: PackedStringArray = ["merchant", "workshop", "clinic", "sect_hall", "orphanage", "auction"]
## Villagers at one place stand at least this far apart.
const HAUNT_SPACING := 40.0
## SPOT-001: at most this many adults stand at one place on a day.
const HAUNT_MAX_PER_PLACE := 2
## SPOT-001: spot_positions keeps this far between any two returned spots.
const SPOT_MIN_GAP := 56.0


## Where `npc` stands on `day` (WORLD-001, pure): each villager keeps a daily round
## between 2-3 haunts of the region picked by hash(npc.id) (merchants, workshops,
## fields, the well; children the Family Home or the orphanage) and moves to the
## next one as days pass. Never inside a solid landmark or a place.
static func haunt(npc: CharacterData, region: Dictionary, day: int, adult: bool = true, weather: String = "") -> Vector2:
	return _haunt_at(npc, region, day, adult, weather, [])


## Positions for `people` (all living in one region, any order) on `day`: like
## `haunt`, but villagers sharing a place stand at least HAUNT_SPACING apart
## (placed in id order, so the result is stable). Returns id -> Vector2 (WORLD-004).
static func haunt_positions(people: Array[CharacterData], region: Dictionary, day: int, adult_age: int, weather: String = "", visitor_id: String = "", visit_place: Dictionary = {}, shared: Dictionary = {}) -> Dictionary:
	var sorted := _by_id(people)
	var places := _round_places(sorted, region, day, adult_age, weather, visitor_id, visit_place, shared)
	var placed: Array[Vector2] = []
	var out := {}
	for c: CharacterData in sorted:
		var pos := _haunt_at(c, region, day, c.age_years() >= adult_age, weather, placed, places[c.id])
		placed.append(pos)
		out[c.id] = pos
	return out


## SPOT-001: the place each of `people` stands at on `day` (id -> place dict, {} for an npc_spots fallback),
## with at most HAUNT_MAX_PER_PLACE adults per place. Same arguments and rules as `haunt_positions`, so the
## "browsing the stalls at X" line names the place the villager really stands at.
static func haunt_places(people: Array[CharacterData], region: Dictionary, day: int, adult_age: int, weather: String = "", visitor_id: String = "", visit_place: Dictionary = {}, shared: Dictionary = {}) -> Dictionary:
	var raw := _round_places(_by_id(people), region, day, adult_age, weather, visitor_id, visit_place, shared)
	var out := {}
	for id: String in raw:
		out[id] = {} if (raw[id] as Dictionary).has("none") else raw[id]
	return out


static func _by_id(people: Array[CharacterData]) -> Array[CharacterData]:
	var sorted := people.duplicate()
	sorted.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.id.naturalnocasecmp_to(b.id) < 0)
	return sorted


## id -> place (a visit or shared place as given, else the capped haunt; {"none": true} = npc_spots fallback).
static func _round_places(sorted: Array[CharacterData], region: Dictionary, day: int, adult_age: int, weather: String, visitor_id: String, visit_place: Dictionary, shared: Dictionary) -> Dictionary:
	var counts := {}
	var out := {}
	for c: CharacterData in sorted:
		var place: Dictionary = visit_place if c.id == visitor_id else shared.get(c.id, {})
		if place.is_empty():
			place = _capped_place(c, region, day, c.age_years() >= adult_age, weather, counts)
		out[c.id] = place
	return out


static func _place_key(place: Dictionary) -> String:
	return "%s@%s" % [String(place.get("type", "")), str(place.get("pos", []))]


## The villager's usual haunt place, or the nearest other allowed place with room when it is full; {} (the
## npc_spots fallback) when every place is full. Children are not capped.
static func _capped_place(c: CharacterData, region: Dictionary, day: int, adult: bool, weather: String, counts: Dictionary) -> Dictionary:
	var place := haunt_place(c, region, day, adult, weather)
	if place.is_empty() or not adult:
		return place if not place.is_empty() else {"none": true}
	var key := _place_key(place)
	if int(counts.get(key, 0)) < HAUNT_MAX_PER_PLACE:
		counts[key] = int(counts.get(key, 0)) + 1
		return place
	var from := _rect_of(place).get_center()
	var pool: Array[Dictionary] = _shelters(region) if HAUNT_STORMY.has(weather) and HAUNT_OUTDOOR.has(String(place.get("type", ""))) else _haunt_anchors(region, true)
	var best: Dictionary = {}
	var best_d := INF
	for cand: Dictionary in pool:
		var ck := _place_key(cand)
		if int(counts.get(ck, 0)) >= HAUNT_MAX_PER_PLACE:
			continue
		var d := _rect_of(cand).get_center().distance_to(from)
		if d < best_d:
			best_d = d
			best = cand
	if best.is_empty():
		return {"none": true}
	counts[_place_key(best)] = int(counts.get(_place_key(best), 0)) + 1
	return best


const STOP_TRAVEL_CLEAR := 40.0
const STOP_PLACE_CLEAR := 24.0


## WU-484: place types drawn as buildings (bigger than their rect, with a roof and a label band).
const BUILDING_TYPES: Array[String] = ["merchant", "shop", "workshop", "clinic", "orphanage", "family_home", "sect_hall", "auction"]


## WU-484: the area nobody may stand in around a place: the drawn building (about 1.3x its rect, 22 px up,
## 12 px clearance) for building kinds, `rect.grow(24)` for the rest.
static func place_keepout(place: Dictionary) -> Rect2:
	if not String(place.get("type", "")) in BUILDING_TYPES:
		return _rect_of(place).grow(STOP_PLACE_CLEAR)
	return building_footprint(place)


## WU-489: the drawn building of any place: about 1.3x its rect, 22 px up for the label band, 12 px clearance.
## The one owner of these numbers (SectCourt.place_footprint calls it).
static func building_footprint(place: Dictionary) -> Rect2:
	var r := _rect_of(place)
	var big := Rect2(r.get_center() - r.size * 0.65, r.size * 1.3)
	big.position.y -= 22.0
	big.size.y += 22.0
	return big.grow(12.0)


## WU-484: where a person who keeps the place stands: at its door, just south of the building.
static func door_of(place: Dictionary) -> Vector2:
	var k := place_keepout(place)
	return Vector2(k.get_center().x, k.end.y + 10.0)


## WU-484: true when `pos` is 40 px from every travel point and outside every place keepout.
static func stop_is_clear(pos: Vector2, region: Dictionary) -> bool:
	for p: Dictionary in region.get("places", []):
		var rect := _rect_of(p)
		if place_keepout(p).has_point(pos):
			return false
		if String(p.get("type", "")) == "travel" and rect.get_center().distance_to(pos) < STOP_TRAVEL_CLEAR:
			return false
	return true


## WU-484: final position for a person at `pos`. A named person inside a wide building's keepout (a shop or
## healer they keep) stands at its door; stalls narrower than 110 px keep their spot on purpose; anyone else
## inside a keepout is nudged out.
static func settle_stand(pos: Vector2, region: Dictionary, named: bool) -> Vector2:
	if named:
		for p: Dictionary in region.get("places", []):
			var rect := _rect_of(p)
			if place_keepout(p).has_point(pos) and String(p.get("type", "")) in BUILDING_TYPES:
				if rect.size.x < 110.0:
					return pos
				var door := door_of(p)
				return door if stop_is_clear_except(door, region, p) else nudge_stop(door, region)
		return pos  # named people may stand at a meditation spot or a board on purpose
	return nudge_arrival(nudge_stop(pos, region), region)


## SPOT-002: named folk keep this far from the arrival point and every region entrance, and stay off road crossings.
const NAMED_ARRIVAL_CLEAR := 48.0
const NAMED_CROSSING_MARGIN := 24.0


## SPOT-002: the road crossings of `region` (every overlap of two `map.paths` rects), grown by NAMED_CROSSING_MARGIN.
static func road_crossings(region: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var paths: Array = region.get("map", {}).get("paths", [])
	for i in paths.size():
		for j in range(i + 1, paths.size()):
			var a: Array = paths[i]
			var b: Array = paths[j]
			var ra := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
			var rb := Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
			if ra.intersects(rb):
				out.append(ra.intersection(rb).grow(NAMED_CROSSING_MARGIN))
	return out


static func _named_ok(pos: Vector2, region: Dictionary, crossings: Array[Rect2], arrivals: Array[Vector2], placed: Array[Vector2]) -> bool:
	for r in crossings:
		if r.has_point(pos):
			return false
	for a in arrivals:
		if pos.distance_to(a) < NAMED_ARRIVAL_CLEAR:
			return false
	for q in placed:
		if pos.distance_to(q) < HAUNT_SPACING:
			return false
	return true


## SPOT-002: settles hand-placed named people (id -> position, already through settle_stand). Someone whose spot
## is legal (not on a road crossing, 48 px from the arrival point and region entrances, 40 px from the figures
## placed before them in id order, `others` included) keeps it; the rest take the nearest free spot of a ring search.
static func settle_named(stands: Dictionary, region: Dictionary, others: Array[Vector2] = []) -> Dictionary:
	var crossings := road_crossings(region)
	var arrivals := arrival_points(region)
	var placed: Array[Vector2] = others.duplicate()
	var ids: Array = stands.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var out := {}
	for id: String in ids:
		var pos: Vector2 = stands[id]
		if not _named_ok(pos, region, crossings, arrivals, placed):
			var found := false
			for step in range(1, 40):
				for k in 16:
					var cand := pos + Vector2.from_angle(TAU * float(k) / 16.0) * (8.0 * float(step))
					if stop_is_clear(cand, region) and _named_ok(cand, region, crossings, arrivals, placed):
						pos = cand
						found = true
						break
				if found:
					break
		out[id] = pos
		placed.append(pos)
	return out


## FOLK-032: generated villagers keep this far from every travel place (signpost) and the region's arrival point.
const ARRIVAL_CLEAR := 120.0


## FOLK-032: the points a newcomer arrives at: every travel place centre plus the region spawn.
static func arrival_points(region: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) == "travel":
			out.append(_rect_of(p).get_center())
	if region.has("spawn"):
		var s: Array = region["spawn"]
		out.append(Vector2(float(s[0]), float(s[1])))
	return out


## FOLK-032: `pos` moved outward (away from the nearest arrival point, 8 px steps, then the usual
## nudge_stop) until it is ARRIVAL_CLEAR from every arrival point; unchanged when already clear.
static func nudge_arrival(pos: Vector2, region: Dictionary) -> Vector2:
	var points := arrival_points(region)
	var cur := pos
	for step in 24:
		var near := Vector2.ZERO
		var best := INF
		for a in points:
			var d := cur.distance_to(a)
			if d < best:
				best = d
				near = a
		if best >= ARRIVAL_CLEAR:
			return cur
		var dir := (cur - near).normalized() if best > 0.01 else Vector2.RIGHT
		cur = nudge_stop(near + dir * (best + 8.0), region)
	# SPOT-001: a building blocks the way out; take the nearest clear point of a ring search instead.
	var origin := pos
	for step in range(0, 30):
		for k in 16:
			var cand := origin + Vector2.from_angle(TAU * float(k) / 16.0) * (8.0 * float(step))
			if stop_is_clear(cand, region) and _arrival_ok(cand, points):
				return cand
	return cur


static func _arrival_ok(pos: Vector2, points: Array[Vector2]) -> bool:
	for a in points:
		if pos.distance_to(a) < ARRIVAL_CLEAR:
			return false
	return true


## FOLK-032: after settling, a generated villager standing within HAUNT_SPACING of an earlier one in `stands`
## is moved outward from the nearest arrival point (or away from that neighbour) until clear.
static func spread_stands(stands: Array[Vector2], region: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for pos in stands:
		var cur := pos
		for step in 12:
			var crowd := Vector2.ZERO
			var found := false
			for q in out:
				if cur.distance_to(q) < HAUNT_SPACING:
					crowd = q
					found = true
					break
			if not found:
				break
			var dir := (cur - crowd).normalized() if cur.distance_to(crowd) > 0.01 else Vector2.DOWN
			cur = nudge_arrival(nudge_stop(crowd + dir * (HAUNT_SPACING + 4.0), region), region)
		out.append(nudge_arrival(cur, region))  # SPOT-001: never end inside the entrance clearance
	return out


## True when `pos` is outside every place keepout except `own`'s.
static func stop_is_clear_except(pos: Vector2, region: Dictionary, own: Dictionary) -> bool:
	for p: Dictionary in region.get("places", []):
		if p != own and place_keepout(p).has_point(pos):
			return false
	return true


## WU-483: `pos` moved (deterministically, outward along 16 directions, 8 px steps) to the nearest stop_is_clear
## point; unchanged when already clear.
static func nudge_stop(pos: Vector2, region: Dictionary) -> Vector2:
	if stop_is_clear(pos, region):
		return pos
	for step in range(1, 40):
		for k in 16:
			var cand := pos + Vector2.from_angle(TAU * float(k) / 16.0) * (8.0 * float(step))
			if stop_is_clear(cand, region):
				return cand
	return pos


static func _haunt_at(npc: CharacterData, region: Dictionary, day: int, adult: bool, weather: String, placed: Array[Vector2], visit_place: Dictionary = {}) -> Vector2:
	var pos := _haunt_raw(npc, region, day, adult, weather, placed, visit_place)
	return pos if pos == Vector2.ZERO else nudge_stop(pos, region)


static func _haunt_raw(npc: CharacterData, region: Dictionary, day: int, adult: bool, weather: String, placed: Array[Vector2], visit_place: Dictionary = {}) -> Vector2:
	var h := absi(hash(npc.id))
	var place := {} if visit_place.has("none") else haunt_place(npc, region, day, adult, weather, visit_place)
	if place.is_empty():
		var spots: Array = region.get("npc_spots", [])
		if spots.is_empty():
			return Vector2.ZERO
		return Vector2(float(spots[h % spots.size()][0]), float(spots[h % spots.size()][1]))
	var rect := _rect_of(place)
	var blocked := _haunt_blocked(region)
	var centre := rect.get_center()
	var base_radius := maxf(rect.size.x, rect.size.y) / 2.0 + HAUNT_STAND_OFF
	var fallback := centre + Vector2(base_radius, 0)
	# Ring around the place; if a neighbour crowds every point, try wider rings.
	for ring in 4:
		var radius := base_radius + HAUNT_SPACING * float(ring)
		for t in 24:
			var angle := TAU * float((h / 3 + t * 5) % 24) / 24.0
			var pos := centre + Vector2.from_angle(angle) * radius
			if _haunt_clear(pos, blocked) and _spaced(pos, placed):
				return pos
	return fallback


static func _spaced(pos: Vector2, placed: Array[Vector2]) -> bool:
	for p in placed:
		if pos.distance_to(p) < HAUNT_SPACING:
			return false
	return true


## The place dict (a region place, landmark or family home, with a normalized
## `type`) the villager stands by today, {} when they fall back to `npc_spots` (WORLD-002).
## A non-empty `visit_place` (see `visit_place_of`) is where a visiting friend stands instead (WORLD-007).
## On a rain or snow day (`weather`) an outdoor pick is swapped for a sheltered
## place of the region, if it has one (WORLD-004).
static func haunt_place(npc: CharacterData, region: Dictionary, day: int, adult: bool = true, weather: String = "", visit_place: Dictionary = {}) -> Dictionary:
	if not visit_place.is_empty():
		return visit_place
	var h := absi(hash(npc.id))
	var anchors := _haunt_anchors(region, adult)
	if anchors.is_empty():
		return {}
	var n := mini(anchors.size(), 2 + h % 2)
	var picked: Array[Dictionary] = []
	for k in n:
		picked.append(anchors[(h / 7 + k * (1 + h % 3)) % anchors.size()])
	var place := picked[posmod(day + h, n)]
	if HAUNT_STORMY.has(weather) and HAUNT_OUTDOOR.has(String(place.get("type", ""))):
		var shelters := _shelters(region)
		if not shelters.is_empty():
			return shelters[posmod(h / 5 + day, shelters.size())]
	return place


## WORLD-007: where a friend who drops by stands: the Family Home spot when `has_home` and the region draws one, else the
## meditation place nearest the spawn. {} when the region has neither.
static func visit_place_of(region: Dictionary, has_home: bool) -> Dictionary:
	if has_home and region.has("family_home"):
		var home: Dictionary = (region["family_home"] as Dictionary).duplicate()
		home["type"] = "family_home"
		home["display_name"] = "your home"
		home["visit"] = true
		return home
	var spawn: Array = region.get("spawn", [0, 0])
	var spawn_pos := Vector2(float(spawn[0]), float(spawn[1]))
	var best: Dictionary = {}
	var best_dist := INF
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) != "meditation":
			continue
		var d := _rect_of(p).get_center().distance_to(spawn_pos)
		if d < best_dist:
			best = p
			best_dist = d
	if not best.is_empty():
		best = best.duplicate()
		best["visit"] = true
	return best


## Whether the villager is indoors today only because of the weather (WORLD-004).
static func is_sheltering(npc: CharacterData, region: Dictionary, day: int, adult: bool, weather: String) -> bool:
	return HAUNT_STORMY.has(weather) and haunt_place(npc, region, day, adult) != haunt_place(npc, region, day, adult, weather)


## Whether `npc` keeps a WORLD-001 daily round in `region_id`: a generated villager of that region
## who is not part of `player`'s household there (the family keeps its spots by the Family Home).
## Named NPCs stand where data/npcs.json puts them.
static func keeps_round(npc: CharacterData, player: CharacterData, people: Dictionary, data: GameData, region_id: String) -> bool:
	if data.npcs.has(npc.id) or region_of(npc, data) != region_id:
		return false
	if player != null and (player.spouses.has(npc.id) or player.children.has(npc.id)):
		return not FamilyHome.has_home(player, people, data, region_id)
	return true


## What a villager is up to at `place` (from `haunt_place`), "" for no place.
static func activity_line(_npc: CharacterData, place: Dictionary, sheltering: String = "") -> String:
	if place.is_empty():
		return ""
	if String(place.get("type", "")) == "family_home" or bool(place.get("visit", false)):
		return "visiting"
	var what := String(place.get("display_name", String(place.get("type", "place")).replace("_", " ")))
	if sheltering == "rain":
		return "sheltering from the rain at the %s" % what
	if sheltering == "snow":
		return "waiting out the snow at the %s" % what
	match String(place.get("type", "")):
		"merchant", "stall":
			return "browsing the stalls at the %s" % what
		"workshop":
			return "lending a hand at the %s" % what
		"gather", "field":
			return "picking herbs on the %s" % what
		"meditation":
			return "sitting quietly by the %s" % what
		"clinic":
			return "waiting at the %s" % what
		"landmark", "well", "pond":
			return "drawing water at the %s" % what
		"orphanage", "family_home":
			return "playing near the %s" % what
	return "about the %s" % what


static func _shelters(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in region.get("places", []):
		if HAUNT_SHELTER_PLACES.has(String(p.get("type", ""))) and not p.has("festival_only"):
			out.append(p)
	return out


static func _haunt_anchors(region: Dictionary, adult: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if adult:
		for p: Dictionary in region.get("places", []):
			if HAUNT_ADULT_PLACES.has(String(p.get("type", ""))) and not p.has("festival_only"):  # FEST-012: not there off-festival
				out.append(p)
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if ["field", "well", "pond", "stall"].has(String(lm.get("kind", ""))):
				var d: Dictionary = lm.duplicate()
				d["type"] = String(lm["kind"])
				out.append(d)
	else:
		if region.has("family_home"):
			var home: Dictionary = (region["family_home"] as Dictionary).duplicate()
			home["type"] = "family_home"
			out.append(home)
		for p: Dictionary in region.get("places", []):
			if HAUNT_CHILD_PLACES.has(String(p.get("type", ""))):
				out.append(p)
	return out


static func _rect_of(d: Dictionary) -> Rect2:
	var pos: Array = d.get("pos", [0, 0])
	var sz: Array = d.get("size", [64, 64])
	var size := Vector2(float(sz[0]), float(sz[1]))
	return Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size)


static func _haunt_blocked(region: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in Scenery.landmark_rects(region, true):
		out.append(r.grow(HAUNT_KEEP_OUT))
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		out.append(_rect_of(p).grow(HAUNT_KEEP_OUT))
	if region.has("family_home"):
		out.append(_rect_of(region["family_home"]).grow(HAUNT_KEEP_OUT))
	return out


static func _haunt_clear(pos: Vector2, blocked: Array[Rect2]) -> bool:
	for r in blocked:
		if r.has_point(pos):
			return false
	return true


static func _spot_clear(pos: Vector2, avoid: Array[Vector2], chosen: Array[Vector2]) -> bool:
	for p in avoid:
		if pos.distance_to(p) < SPOT_MIN_GAP:
			return false
	for p in chosen:
		if pos.distance_to(p) < SPOT_CLEARANCE:
			return false
	return true


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


## WU-520: the label seen from afar: the name, plus a short realm tag ("Cheng Ping · Foundation") only for a
## cultivator at or above the player's realm, or a family title. At most LABEL_MAX characters; the tag is trimmed first.
const LABEL_MAX := 26


static func world_title_short(c: CharacterData, player: CharacterData, data: GameData) -> String:
	var tag := ""
	if player != null and (player.spouses.has(c.id) or player.children.has(c.id)):
		tag = world_title(c, player, data)
	elif c.age_years() >= int(data.family.get("adult_age", 16)) and c.realm_index > 0 \
			and (player == null or c.realm_index >= player.realm_index):
		tag = String(data.realms[c.realm_index].name).get_slice(" ", 0)
	if tag == "":
		return c.name
	var text := "%s · %s" % [c.name, tag]
	if text.length() > LABEL_MAX:
		text = c.name
	return text.substr(0, LABEL_MAX)


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
