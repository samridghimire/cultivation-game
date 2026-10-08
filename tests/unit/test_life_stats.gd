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
