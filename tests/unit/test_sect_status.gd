extends TestCase
## SECT-033: Sects.ladder and Sects.month_status, the sect at a glance as data.


func _azure() -> Array:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Glance", d, seeded_rng(3))
	c.realm_index = 1
	c.alignment = 50
	Sects.join(c, d, "azure_cloud_sect")
	return [c, d]


func test_fresh_disciple_ladder() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	var rows := Sects.ladder(c, d)
	assert_true(rows.size() >= 3)
	assert_true(rows[0]["current"])
	assert_true(rows[0]["reached"])
	assert_eq(rows[0]["needs"].size(), 0)
	assert_false(rows[1]["current"])
	assert_false(rows[1]["reached"])
	assert_true(rows[1]["needs"].size() >= 2)
	assert_true(" ".join(rows[1]["needs"]).contains("trial vs"))
	assert_true(" ".join(rows[1]["needs"]).contains("500 contribution"))


func test_month_status_fresh_and_duty() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	var st := Sects.month_status(c, d, 0)
	assert_eq(st["duty"], 0)
	assert_eq(st["missions_total"] >= st["missions_ready"], true)
	assert_true(String(st["lecture"]).ends_with("open this month (30d left)"))
	c.sect["rank"] = 1
	c.sect["month_earned"] = 15
	c.age_days = 10
	st = Sects.month_status(c, d, 0)
	assert_eq(st["duty"], 30)
	assert_eq(st["progress"], 15)
	assert_eq(st["days_left"], 20)


func test_claimable_cheapest_first_max_three() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	c.sect["contribution"] = 120
	var claim: PackedStringArray = Sects.month_status(c, d, 0)["claimable"]
	assert_true(claim.size() >= 1 and claim.size() <= 3)
	assert_eq(st_balance(c, d), 120)
	c.sect["lecture_month"] = Sects._month_index(0)
	assert_true(String(Sects.month_status(c, d, 0)["lecture"]).ends_with("attended"))


func st_balance(c: CharacterData, d: GameData) -> int:
	return Sects.month_status(c, d, 0)["balance"]


func test_rogue_gets_nothing() -> void:
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("Rogue", d, seeded_rng(1))
	assert_eq(Sects.ladder(c, d).size(), 0)
	assert_true(Sects.month_status(c, d, 0).is_empty())


func test_lecture_days_left_and_summary() -> void:
	var p := _azure()
	var c: CharacterData = p[0]
	var d: GameData = p[1]
	assert_true(String(Sects.month_status(c, d, 3)["lecture"]).ends_with("open this month (27d left)"))
	assert_eq(Sects.days_left_in_month(29), 1)
	# SECT-034: promotion_summary lists the rank's perks and the trial foe.
	c.sect["rank"] = 1
	var s := Sects.promotion_summary(c, d)
	var rows := Sects.ladder(c, d)
	assert_eq(s["perks_new"], rows[1]["perks"])
	if Sects.needs_trial(c, d):
		var foe: String = d.enemies[Sects.trial_enemy(c, d)]["name"]
		assert_true(String(s["next_needs"]).contains("win a trial against " + foe))
	c.sect["rank"] = (d.sects[c.sect["id"]] as SectDef).ranks.size() - 1
	assert_eq(Sects.promotion_summary(c, d)["next_needs"], "")
