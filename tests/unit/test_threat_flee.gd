extends TestCase
## FH-004: lethal foes rated Dangerous are sensed and the player chooses.

var _signalled: Array[String] = []


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Threat", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	return c


## Registers a mist-wolf clone whose attack and hp are tuned until it earns `label`.
func _foe(gs: Node, c: CharacterData, id: String, label: String, lethal: bool) -> void:
	for atk in range(-10, 120, 2):
		for hp in range(-30, 200, 10):
			var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
			foe["id"] = id
			foe["realm"] = "mortal"
			foe["attack"] = atk
			foe["hp"] = hp
			foe["lethal"] = lethal
			if Combat.danger_label(c, gs.data, foe) == label:
				gs.data.enemies[id] = foe
				return
	assert_true(false, "no foe found rated " + label)


func _on_threat(enemy_id: String) -> void:
	_signalled.append(enemy_id)


func test_dangerous_lethal_foe_is_sensed_not_forced() -> void:
	var gs := _gs()
	var c := _start()
	_foe(gs, c, "t_danger", "Dangerous", true)
	_signalled.clear()
	EventBus.threat_sensed.connect(_on_threat)
	var qi := c.qi
	gs._resolve_explore_enemy("t_danger")
	EventBus.threat_sensed.disconnect(_on_threat)
	assert_eq(gs.pending_threat, "t_danger")
	assert_eq(_signalled, ["t_danger"] as Array[String])
	assert_eq(c.qi, qi)
	gs.data.enemies.erase("t_danger")


func test_fleeing_costs_a_day_and_clears_threat() -> void:
	var gs := _gs()
	var c := _start()
	_foe(gs, c, "t_danger", "Dangerous", true)
	gs._resolve_explore_enemy("t_danger")
	var day := GameClock.total_days
	var qi := c.qi
	gs.face_threat(false)
	assert_eq(gs.pending_threat, "")
	assert_eq(GameClock.total_days, day + 1)
	assert_true(c.alive)
	assert_eq(c.qi, qi)
	gs.data.enemies.erase("t_danger")


func test_facing_the_threat_fights() -> void:
	var gs := _gs()
	var c := _start()
	_foe(gs, c, "t_danger", "Dangerous", true)
	gs._resolve_explore_enemy("t_danger")
	var posted := EventBus.posted_count
	gs.face_threat(true)
	assert_eq(gs.pending_threat, "")
	assert_true(EventBus.posted_count > posted, "a fight report was posted")
	gs.data.enemies.erase("t_danger")


func test_face_threat_without_threat_is_a_noop() -> void:
	var gs := _gs()
	_start()
	var day := GameClock.total_days
	gs.face_threat(false)
	assert_eq(GameClock.total_days, day)


func test_deadly_evaded_and_non_lethal_dangerous_forced() -> void:
	var gs := _gs()
	var c := _start()
	_foe(gs, c, "t_deadly", "Deadly", true)
	assert_false(Exploration.should_offer_flee(c, gs.data, "t_deadly"))
	assert_true(Exploration.should_evade(c, gs.data, "t_deadly"))
	gs._resolve_explore_enemy("t_deadly")
	assert_eq(gs.pending_threat, "")
	_foe(gs, c, "t_soft", "Dangerous", false)
	assert_false(Exploration.should_offer_flee(c, gs.data, "t_soft"))
	gs.data.enemies.erase("t_deadly")
	gs.data.enemies.erase("t_soft")


## Registers a non-lethal clone of the mist wolf whose win chance falls in [lo, hi).
func _chance_foe(gs: Node, c: CharacterData, id: String, lo: float, hi: float) -> void:
	for atk in range(-10, 400, 2):
		var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
		foe["id"] = id
		foe["realm"] = "mortal"
		foe["attack"] = atk
		foe["lethal"] = false
		var p := Combat.win_chance(c, gs.data, foe)
		if p >= lo and p < hi:
			gs.data.enemies[id] = foe
			return
	assert_true(false, "no foe found with chance in [%s, %s)" % [lo, hi])


## ENC-009: a non-lethal foe the player would very likely lose to is sensed, not forced.
func test_non_lethal_unwinnable_foe_is_sensed() -> void:
	var gs := _gs()
	var c := _start()
	_chance_foe(gs, c, "t_bully", 0.0, 0.19)
	assert_true(Exploration.should_offer_flee(c, gs.data, "t_bully"))
	_signalled.clear()
	EventBus.threat_sensed.connect(_on_threat)
	var qi := c.qi
	gs._resolve_explore_enemy("t_bully")
	EventBus.threat_sensed.disconnect(_on_threat)
	assert_eq(gs.pending_threat, "t_bully")
	assert_eq(_signalled, ["t_bully"] as Array[String])
	assert_eq(c.qi, qi)
	gs.pending_threat = ""
	gs.data.enemies.erase("t_bully")


func test_non_lethal_fair_foe_is_still_fought() -> void:
	var gs := _gs()
	var c := _start()
	_chance_foe(gs, c, "t_fair", 0.25, 1.01)
	assert_false(Exploration.should_offer_flee(c, gs.data, "t_fair"))
	gs._resolve_explore_enemy("t_fair")
	assert_eq(gs.pending_threat, "")
	gs.data.enemies.erase("t_fair")


func test_sense_below_chance_is_loaded_and_validated() -> void:
	var gs := _gs()
	assert_eq(gs.data.encounter_sense_below_chance, 0.2)
	var saved: float = gs.data.encounter_sense_below_chance
	gs.data.encounter_sense_below_chance = 1.5
	gs.data.load_errors.clear()
	gs.data._validate()
	var found := false
	for e: String in gs.data.load_errors:
		found = found or e.contains("sense_below_chance")
	gs.data.encounter_sense_below_chance = saved
	gs.data.load_errors.clear()
	assert_true(found)
