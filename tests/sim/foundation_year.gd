extends RefCounted
## QA-039: a typical player's first year in a realm, shared by the sim
## (tests/sim/simulate_foundation_year.gd) and its guard (tests/unit/test_foundation_year.gd).
## The player is combat_balance.gd's typical_player at layer 0 of `realm_index` with qi 0,
## a rogue or a sect disciple, in one region. Each month: explore three weeks (slip away from every
## sensed threat, take the first choice), meditate the rest, one sect mission if in a sect.

const CombatBalance := preload("res://tests/sim/combat_balance.gd")
const WEEKS_EXPLORED := 3


## Regions with at least one encounter this character may meet.
static func friendly_regions(data: GameData, realm_index: int) -> Array[String]:
	var probe := CombatBalance.typical_player(data, realm_index, 0)
	var out: Array[String] = []
	for region_id: String in data.regions:
		var tags: Array = data.regions[region_id].get("encounter_tags", [])
		if not Exploration.eligible_encounters(probe, data, tags, {}).is_empty():
			out.append(region_id)
	return out


## Plays `months` months. Returns {won, lost, fled, injuries, lives_spent, stones, stage, alive}.
static func play(gs: Node, seed_value: int, realm_index: int, region_id: String, sect: bool, months: int = 12) -> Dictionary:
	gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Disciple", gs.data, rng)
	var model := CombatBalance.typical_player(gs.data, realm_index, 0)
	c.attributes = model.attributes.duplicate()
	c.techniques = model.techniques.duplicate(true)
	c.equipment = model.equipment.duplicate()
	c.realm_index = realm_index
	c.stage = 0
	c.qi = 0.0
	gs.start_session(c)
	gs.pending_event = ""
	if sect:
		for sect_id: String in Sects.accepting_sects(c, gs.data):
			gs.join_sect(sect_id)
			break
	gs.current_region = region_id
	var lives_start: int = c.artifact_lives
	var stones_start: int = c.item_count("spirit_stone")
	var density := Exploration.qi_density(gs.data, region_id)
	for month in months:
		if not c.alive:
			break
		for week in WEEKS_EXPLORED:
			gs.explore_many(7)
			if gs.pending_encounter != "":
				gs.choose_encounter(0)
			if gs.pending_threat != "":
				gs.face_threat(false)
			if not c.alive:
				break
			_come_home(gs, region_id)
		if not c.alive:
			break
		gs.cultivate(maxi(1, Calendar.DAYS_PER_MONTH - WEEKS_EXPLORED * 7), density)
		if c.alive and Cultivation.can_attempt_breakthrough(c, gs.data):
			gs.attempt_breakthrough()
		if sect and not c.is_rogue() and c.alive:
			for mission_id in Sects.available_missions(c, gs.data, gs.world_flags):
				if Sects.check_mission(c, gs.data, mission_id, gs.world_flags) == "":
					gs.take_mission(mission_id)
					break
			_come_home(gs, region_id)
	var out := {
		"won": LifeStats.get_stat(c, "fights_won"),
		"lost": LifeStats.get_stat(c, "fights_lost"),
		"fled": LifeStats.get_stat(c, "threats_fled"),
		"injuries": c.injuries.size(),
		"lives_spent": lives_start - c.artifact_lives,
		"stones": c.item_count("spirit_stone") - stones_start,
		"stage": c.stage,
		"alive": c.alive,
	}
	gs.end_session()
	return out


## A respawn drops the player at an anchor; walk them back to the test region.
static func _come_home(gs: Node, region_id: String) -> void:
	gs.pending_respawn = {}
	gs.current_region = region_id
