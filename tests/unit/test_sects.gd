extends TestCase


func test_new_character_is_rogue() -> void:
	assert_true(new_character().is_rogue())


func test_righteous_sect_requires_qi_refining() -> void:
	var c := new_character()
	assert_false(Sects.check_join(c, data(), "azure_cloud_sect")["ok"])
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	assert_eq(c.sect["id"], "azure_cloud_sect")


func test_righteous_sect_rejects_evil() -> void:
	var c := new_character()
	c.realm_index = 1
	c.alignment = -500
	assert_false(Sects.check_join(c, data(), "azure_cloud_sect")["ok"])


func test_demonic_sect_rejects_the_virtuous() -> void:
	var c := new_character()
	c.alignment = 300
	assert_false(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])
	c.alignment = -300
	assert_true(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])


func test_cannot_join_two_sects() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	assert_false(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])


func test_contribution_promotes() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	c.realm_index = data().realm_index_of("core_formation")  # high ranks have realm minimums
	var promoted := Sects.add_contribution(c, data(), 100000)
	assert_true(promoted)
	assert_eq(c.sect["rank"], data().sects["blood_lotus_sect"].ranks.size() - 1)


func test_leave_returns_to_rogue() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	assert_eq(Sects.leave(c), "blood_lotus_sect")
	assert_true(c.is_rogue())
	assert_eq(Sects.cultivation_bonus(c, data()), 1.0)
