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


## Plays `months` months. `fight_threats` answers every sensed threat with a fight instead of slipping away
## (QA-045). Returns {won, lost, fled, evaded, injuries, lives_spent, stones, stage, alive, odds, stage_m3,
## stage_m6}; `odds` is the rated win chance of every fight actually fought, `evaded` counts foes the
## player slipped past without being asked (overwhelming killing intent).
static func play(gs: Node, seed_value: int, realm_index: int, region_id: String, sect: bool, months: int = 12, fight_threats: bool = false) -> Dictionary:
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
	var saves: Node = gs.get_node("/root/SaveManager")
	var autosave_was: bool = saves.autosave_enabled
	saves.autosave_enabled = false  # a sim month must not write the autosave slot (QA-137)
	gs.start_session(c)
	gs.pending_event = ""
	if sect:
		for sect_id: String in Sects.accepting_sects(c, gs.data):
			gs.join_sect(sect_id)
			break
	gs.current_region = region_id
	gs.world_flags["discovered_" + region_id] = true  # measure the random encounter pool, not the one-off discovery
	var lives_start: int = c.artifact_lives
	var stones_start: int = c.item_count("spirit_stone")
	var density := Exploration.qi_density(gs.data, region_id)
	var odds: Array[float] = []
	var evaded := [0]
	var bus: Node = gs.get_node("/root/EventBus")
	var on_fight := func(enemy: Dictionary) -> void: odds.append(Combat.win_chance(c, gs.data, enemy))
	var on_message := func(text: String, _category: String) -> void:
		if text.contains("slip away before the"):
			evaded[0] += 1
	bus.combat_started.connect(on_fight)
	bus.message_posted.connect(on_message)
	var stage_m3 := 0
	var stage_m6 := 0
	for month in months:
		if month == 3:
			stage_m3 = c.stage
		elif month == 6:
			stage_m6 = c.stage
		if not c.alive:
			break
		if sect and not c.is_rogue() and c.alive:
			# MISSION-001: a player collects the month's mission at the sect's home region (the board is always there), then heads out.
			gs.current_region = Sects.home_region(gs.data, String(c.sect["id"]))
			for mission_id in Sects.available_missions(c, gs.data, gs.world_flags):
				if Sects.check_mission(c, gs.data, mission_id, gs.world_flags, gs.current_region) == "":
					gs.take_mission(mission_id)
					break
			_come_home(gs, region_id)
		for week in WEEKS_EXPLORED:
			gs.explore_many(7)
			if gs.pending_encounter != "":
				gs.choose_encounter(0)
			if gs.pending_threat != "":
				gs.face_threat(fight_threats)
			if not c.alive:
				break
			_come_home(gs, region_id)
		if not c.alive:
			break
		gs.cultivate(maxi(1, Calendar.DAYS_PER_MONTH - WEEKS_EXPLORED * 7), density)
		if c.alive and Cultivation.can_attempt_breakthrough(c, gs.data):
			gs.attempt_breakthrough()
	bus.combat_started.disconnect(on_fight)
	bus.message_posted.disconnect(on_message)
	var out := {
		"evaded": evaded[0],
		"odds": odds,
		"stage_m3": stage_m3 if months > 3 else c.stage,
		"stage_m6": stage_m6 if months > 6 else c.stage,
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
	saves.autosave_enabled = autosave_was
	return out


## A respawn drops the player at an anchor; walk them back to the test region.
static func _come_home(gs: Node, region_id: String) -> void:
	gs.pending_respawn = {}
	gs.current_region = region_id
