extends TestCase
## SECT-035: the new disciple's first goals (Guidance.sect_goals).


func _azure() -> Array:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Goals", d, seeded_rng(3))
	c.realm_index = 1
	c.alignment = 50
	Sects.join(c, d, "azure_cloud_sect")
	return [c, d]


func test_fresh_member_rows() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	var rows := Guidance.sect_goals(c, d, {})
	assert_eq(rows.size(), 4)
	assert_true(String(rows[0]["text"]).begins_with("Report at "))
	assert_true(String(rows[0]["text"]).contains("Azure Peak"))
	assert_false(rows[0]["done"])
	assert_true(String(rows[1]["text"]).begins_with("Attend "))
	assert_true(String(rows[2]["text"]).begins_with("Finish a sect mission"))
	assert_true(String(rows[3]["text"]).begins_with("Rise to "))
	assert_true(Guidance.sect_goals_active(c, d, {}))


func test_all_done_is_inactive() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	c.sect["reported"] = true
	LifeStats.add(c, "lectures_attended")
	LifeStats.add(c, "missions_done")
	c.sect["rank"] = 1
	assert_false(Guidance.sect_goals_active(c, d, {}))
	for row in Guidance.sect_goals(c, d, {}):
		assert_true(row["done"])


func test_rogue_and_foundation() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	c.realm_index = 2
	assert_false(Guidance.sect_goals_active(c, d, {}))
	var rogue := CharacterFactory.create("Rogue", d, seeded_rng(4))
	assert_eq(Guidance.sect_goals(rogue, d, {}).size(), 0)
	assert_false(Guidance.sect_goals_active(rogue, d, {}))


func test_old_save_shape() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	c.sect.erase("reported")
	c.sect["contribution"] = 50
	var rows := Guidance.sect_goals(c, d, {})
	assert_true(rows[0]["done"])
	assert_true(rows[2]["done"])
	assert_false(rows[3]["done"])


func test_ladder_id_and_lookup() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	assert_eq(Guidance.goal_ladder("sect", c, d, {}).size(), 4)
	# first goals still open for a newcomer: the first ladder keeps the row
	assert_eq(Guidance.goal_ladder_id(c, d, {}), "first")
