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
