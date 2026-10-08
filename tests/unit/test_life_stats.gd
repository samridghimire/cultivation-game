extends TestCase
## STAT-001: the life record.


func test_add_and_get() -> void:
	var c := new_character()
	assert_eq(LifeStats.get_stat(c, "fights_won"), 0)
	LifeStats.add(c, "fights_won")
	LifeStats.add(c, "fights_won", 2)
	LifeStats.add(c, "fights_won", 0)
	LifeStats.add(c, "fights_won", -5)
	assert_eq(LifeStats.get_stat(c, "fights_won"), 3)


func test_lines_skip_zeros_and_keep_order() -> void:
	var c := new_character()
	assert_eq(LifeStats.lines(c).size(), 0)
	LifeStats.add(c, "deeds_done", 4)
	LifeStats.add(c, "fights_won", 12)
	var lines := LifeStats.lines(c)
	assert_eq(lines.size(), 2)
	assert_eq(lines[0], "Fights won: 12")
	assert_eq(lines[1], "Deeds done: 4")


func test_labels_cover_every_key() -> void:
	for key in LifeStats.KEYS:
		assert_true(LifeStats.LABELS.has(key), key)


func test_round_trip_and_old_saves() -> void:
	var c := new_character()
	LifeStats.add(c, "encounters", 7)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(LifeStats.get_stat(back, "encounters"), 7)
	var d := c.to_dict()
	d.erase("life_stats")
	assert_eq(CharacterData.from_dict(d).life_stats, {})


# --- MS-004: backfill ---------------------------------------------------------

func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_backfill_counts_past_realm_progress() -> void:
	var c := new_character()
	c.secret_realms = {"verdant_remnant": {"opening": 0, "floor": 2}}
	c.inheritances.append("verdant_remnant")
	LifeStats.backfill(c, data(), {})
	assert_eq(LifeStats.get_stat(c, "realm_floors_cleared"), 2)
	assert_eq(LifeStats.get_stat(c, "inheritances_claimed"), 1)
	LifeStats.backfill(c, data(), {})
	assert_eq(LifeStats.get_stat(c, "realm_floors_cleared"), 2, "idempotent")
	assert_eq(LifeStats.get_stat(c, "inheritances_claimed"), 1, "idempotent")


func test_backfill_counts_claimed_grounds_and_keeps_higher_values() -> void:
	var c := new_character()
	var ground := String(data().inheritances.keys()[0])
	LifeStats.add(c, "realm_floors_cleared", 5)
	c.secret_realms = {"verdant_remnant": {"opening": 0, "floor": 2}}
	LifeStats.backfill(c, data(), {Inheritances.claimed_flag(ground): true})
	assert_eq(LifeStats.get_stat(c, "realm_floors_cleared"), 5, "never lowers")
	assert_eq(LifeStats.get_stat(c, "inheritances_claimed"), 1)


func test_load_backfills_and_awards_silently() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Veteran", gs.data, seeded_rng())
	gs.start_session(c)
	c.secret_realms = {"verdant_remnant": {"opening": 0, "floor": 1}}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_true(gs.player.milestones.has("into_secret_realm"))
	for line in _root().get_node("EventBus").history:
		assert_false(String(line["text"]).contains("Into the Secret Realm"), "no announcement")
	gs.end_session()


# --- YEAR-001: year in review -------------------------------------------------

func test_year_summary_quiet_year() -> void:
	var s := {"fights_won": 3}
	assert_eq(LifeStats.year_summary(s, s.duplicate(), "Mortal", "Mortal"), PackedStringArray(["A quiet year of cultivation."]))


func test_year_summary_lists_differences() -> void:
	var lines := LifeStats.year_summary({"fights_won": 1}, {"fights_won": 4, "fights_lost": 1, "items_crafted": 2, "deeds_done": 1}, "Mortal", "Qi Refining 1st Layer")
	assert_eq(lines.size(), 4, "capped at 4")
	assert_eq(lines[0], "You rose from Mortal to Qi Refining 1st Layer.")
	assert_eq(lines[1], "You won 3 fights and lost 1.")
	assert_eq(lines[2], "You crafted 2 items.")


func test_year_summary_floors_and_singulars() -> void:
	var lines := LifeStats.year_summary({}, {"realm_floors_cleared": 1, "deeds_done": 1}, "A", "A")
	assert_eq(lines, PackedStringArray(["You did 1 deed.", "You cleared 1 secret realm floor."]))


func test_year_snapshot_round_trip() -> void:
	var c := new_character()
	c.year_start_stats = {"fights_won": 2}
	c.year_start_realm = "Mortal"
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.year_start_stats, {"fights_won": 2})
	assert_eq(back.year_start_realm, "Mortal")
	var d := c.to_dict()
	d.erase("year_start_realm")
	assert_eq(CharacterData.from_dict(d).year_start_realm, "")
