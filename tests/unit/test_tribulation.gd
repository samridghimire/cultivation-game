extends TestCase
## Heavenly Tribulations (TRIB-001): lightning waves at major breakthroughs.

const TribBalance := preload("res://tests/sim/tribulation_balance.gd")
const CORE := 3  # core_formation, the first realm with a tribulation


## A character at the peak of Foundation Establishment, ready to break into Core Formation.
func _at_peak(c: CharacterData, d: GameData) -> CharacterData:
	c.realm_index = CORE - 1
	c.stage = d.realms[CORE - 1].stage_count() - 1
	c.qi = d.realms[CORE - 1].qi_required(c.stage)
	c.breakthrough_bonus = 1.0
	return c


## Fresh data whose Core Formation tribulation is one overwhelming wave.
func _deadly_data() -> GameData:
	var d := GameData.load_from_dir()
	d.realms[CORE].tribulation = {"waves": 1, "strength": 1000.0, "growth": 1.0, "variance": 0.0}
	return d


func test_only_core_formation_and_up_have_tribulations() -> void:
	assert_false(Tribulation.has_tribulation(data(), CORE - 1))
	for i in range(CORE, data().realms.size()):
		assert_true(Tribulation.has_tribulation(data(), i), data().realms[i].id)


func test_no_tribulation_below_core_formation() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = data().realms[1].stage_count() - 1
	c.qi = data().realms[1].qi_required(c.stage)
	c.breakthrough_bonus = 1.0
	var result := Cultivation.attempt_breakthrough(c, data(), seeded_rng())
	assert_true(result["tribulation"].is_empty())
	assert_false(result["died"])


func test_waves_grow_and_heart_demon_for_demonic() -> void:
	var c := _at_peak(new_character(), data())
	var waves := Tribulation.waves(c, data(), CORE)
	assert_eq(waves.size(), int(data().realms[CORE].tribulation["waves"]))
	assert_gt(waves[1]["attack"], waves[0]["attack"])
	c.alignment = data().alignment_min
	waves = Tribulation.waves(c, data(), CORE)
	assert_eq(waves.size(), int(data().realms[CORE].tribulation["waves"]) + 1)
	assert_eq(waves[waves.size() - 2]["kind"], "heart_demon")
	assert_eq(waves[waves.size() - 1]["kind"], "lightning")
	assert_true(Tribulation.preview(c, data(), CORE)["heart_demon"])


func test_typical_cultivator_usually_survives() -> void:
	var survived := 0
	for i in 200:
		var c := TribBalance.attempter(data(), CORE, "typical")
		if Tribulation.endure(c, data(), CORE, seeded_rng(i))["survived"]:
			survived += 1
	assert_gt(survived, 100, "a typical cultivator should survive more often than not (%d/200)" % survived)
	assert_true(survived < 200, "the tribulation should be a real risk (%d/200)" % survived)


func test_surviving_enters_the_realm() -> void:
	var c := _at_peak(new_character(), data())
	c.attributes["constitution"] = 500
	var result := Cultivation.attempt_breakthrough(c, data(), seeded_rng())
	assert_true(result["success"])
	assert_true(result["tribulation"]["survived"])
	assert_eq(c.realm_index, CORE)


func test_falling_before_final_wave_fails_and_injures() -> void:
	var c := new_character()  # a mortal cannot withstand Core Formation lightning
	var result := Tribulation.endure(c, data(), CORE, seeded_rng())
	assert_false(result["survived"])
	assert_false(result["died"])
	assert_eq(result["waves"].size(), 1)
	assert_true(result["injury"] != "")
	assert_true(c.injuries.has(result["injury"]))


func test_falling_to_final_wave_kills_and_fails_breakthrough() -> void:
	var d := _deadly_data()
	var c := _at_peak(new_character(), d)
	var qi_before := c.qi
	var result := Cultivation.attempt_breakthrough(c, d, seeded_rng())
	assert_false(result["success"])
	assert_true(result["died"])
	assert_eq(c.realm_index, CORE - 1)
	assert_gt(qi_before, c.qi)


func test_shield_talismans_absorb_and_burn() -> void:
	var c := TribBalance.attempter(data(), CORE, "typical")
	c.add_item("earth_wall_talisman", 2)
	assert_eq(CombatTalismans.ready_talisman(c, data(), "earth_wall_talisman"), "")
	var shield := Tribulation.shield_of(c, data())
	assert_gt(shield, 0)
	var with_shield := Tribulation.endure(c, data(), CORE, seeded_rng(7))
	assert_eq(c.item_count("earth_wall_talisman"), 1)
	assert_eq(with_shield["talismans_used"].size(), 1)
	var bare := TribBalance.attempter(data(), CORE, "typical")
	var without := Tribulation.endure(bare, data(), CORE, seeded_rng(7))
	assert_gt(with_shield["hp"], without["hp"])


func test_validation_rejects_bad_tribulation() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Tribulation.validate(d).size(), 0)
	d.realms[CORE].tribulation = {"waves": 0, "strength": 1.0, "growth": 1.0, "variance": 2.0}
	assert_eq(Tribulation.validate(d).size(), 2)


func test_npc_can_perish_in_tribulation() -> void:
	var d := _deadly_data()
	var c := _at_peak(new_character(), d)
	c.id = "npc_test"
	c.cultivates = true
	c.age_days = 30 * Calendar.DAYS_PER_YEAR
	var events := Npcs.simulate({"npc_test": c}, d, 1, seeded_rng())
	assert_false(c.alive)
	assert_eq(c.cause_of_death, "heavenly tribulation")
	assert_gt(events.size(), 0)


func test_game_state_tribulation_death_respawns_player() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var real_data: GameData = gs.data
	var c := CharacterFactory.create("Tribulant", real_data, seeded_rng())
	gs.start_session(c)
	gs.data = _deadly_data()
	_at_peak(c, gs.data)
	var lives := c.artifact_lives
	assert_true(gs.tribulation_preview()["has_tribulation"])
	gs.attempt_breakthrough()
	gs.data = real_data
	assert_true(c.alive)
	assert_eq(c.artifact_lives, lives - 1)
	assert_eq(c.realm_index, CORE - 1)
	gs.end_session()


func test_npcs_face_npc_strength() -> void:
	var c := _at_peak(new_character(), data())
	var player_waves := Tribulation.waves(c, data(), CORE)
	var npc_waves := Tribulation.waves(c, data(), CORE, true)
	var trib: Dictionary = data().realms[CORE].tribulation
	assert_true(abs(float(npc_waves[0]["attack"]) / float(player_waves[0]["attack"]) - float(trib["npc_strength"]) / float(trib["strength"])) < 0.001)
	var d := GameData.load_from_dir()
	d.realms[CORE].tribulation.erase("npc_strength")
	assert_eq(float(Tribulation.waves(c, d, CORE, true)[0]["attack"]), float(Tribulation.waves(c, d, CORE)[0]["attack"]), "npc_strength defaults to strength")
	d.realms[CORE].tribulation["npc_strength"] = 0.0
	assert_eq(Tribulation.validate(d).size(), 1)
