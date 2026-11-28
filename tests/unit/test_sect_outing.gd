extends TestCase
## SECT-055: the sect's yearly autumn outing.


func _disciple(sect_id: String = "azure_cloud_sect") -> CharacterData:
	var c := new_character()
	c.spiritual_roots = {"fire": 80}
	c.realm_index = 1
	Sects.join(c, data(), sect_id)
	return c


func test_rogue_has_no_outing() -> void:
	var c := new_character()
	assert_eq(Sects.outing_phase(c, data(), 250), "")
	assert_true(Sects.check_outing(c, data(), 250, "azure_peak") != "")
	assert_eq(Sects.outing_line(c, data(), 250), "")


func test_window_phases() -> void:
	var c := _disciple()
	var o := Sects.outing_def(c, data())
	assert_eq(Sects.outing_phase(c, data(), 100), "wait")
	assert_eq(Sects.outing_phase(c, data(), int(o["day_min"]) - 10), "notice")
	assert_eq(Sects.outing_phase(c, data(), int(o["day_min"])), "open")
	assert_eq(Sects.outing_phase(c, data(), int(o["day_max"]) + 1), "done")
	assert_true(Sects.outing_line(c, data(), int(o["day_min"]) - 10).contains("in 10 days"))


func test_once_a_year_and_home_region_only() -> void:
	var c := _disciple()
	var day := 250
	assert_true(Sects.check_outing(c, data(), day, "qingshi_village") != "", "leaves from the home region")
	assert_eq(Sects.check_outing(c, data(), day, "azure_peak"), "")
	var pay := Sects.take_outing(c, data(), day)
	assert_eq(pay, int(Sects.outing_def(c, data())["contribution"]))
	assert_eq(int(c.sect["contribution"]), pay)
	assert_true(Sects.check_outing(c, data(), day, "azure_peak") != "")
	var next_year := day + Calendar.DAYS_PER_YEAR
	assert_eq(Sects.check_outing(c, data(), next_year, "azure_peak"), "", "next year it is open again")


func test_region_pick_is_stable_and_in_pool() -> void:
	var c := _disciple()
	var pool: Array = Sects.outing_def(c, data())["region_pool"]
	assert_true(pool.has(Sects.outing_region(c, data(), 250)))
	assert_eq(Sects.outing_region(c, data(), 250), Sects.outing_region(c, data(), 255))


func test_pays_less_than_a_month_of_duty() -> void:
	for sect_id: String in data().sects:
		var sect: SectDef = data().sects[sect_id]
		if sect.outing.is_empty():
			continue
		assert_gt(int(sect.ranks[1]["monthly_duty"]), int(sect.outing["contribution"]))


func test_save_roundtrip_keeps_outing_year() -> void:
	var c := _disciple()
	Sects.take_outing(c, data(), 250)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(int(back.sect["outing_year"]), 1)
