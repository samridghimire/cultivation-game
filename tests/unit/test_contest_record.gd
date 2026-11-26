extends TestCase
## SECT-048: a champion's record (life stats, milestone, summary line, contest_record).


func _sect_char() -> CharacterData:
	var c := new_character()
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	return c


func test_rounds_and_wins_increment() -> void:
	var c := _sect_char()
	assert_false(Sects.record_contest(c, data(), 1, 3, 400))
	assert_eq(LifeStats.get_stat(c, "contest_rounds_won"), 1)
	assert_eq(LifeStats.get_stat(c, "contest_wins"), 0)
	assert_true(Sects.record_contest(c, data(), 3, 3, 800))
	assert_eq(LifeStats.get_stat(c, "contest_rounds_won"), 4)
	assert_eq(LifeStats.get_stat(c, "contest_wins"), 1)


func test_no_rounds_won_records_nothing() -> void:
	var c := _sect_char()
	assert_false(Sects.record_contest(c, data(), 0, 3, 400))
	assert_eq(Sects.contest_record(c, data()), {"best_round": 0, "wins": 0, "last_year": -1})
	assert_eq(Sects.contest_win_line(c, data()), "")


func test_record_after_two_contests() -> void:
	var c := _sect_char()
	Sects.record_contest(c, data(), 3, 3, 400)
	var first_year := Calendar.year_of(400)
	Sects.record_contest(c, data(), 2, 3, 800)
	var rec := Sects.contest_record(c, data())
	assert_eq(rec["best_round"], 3)
	assert_eq(rec["wins"], 1)
	assert_eq(rec["last_year"], first_year, "a partial run does not move the last win")
	Sects.record_contest(c, data(), 3, 3, 1200)
	assert_eq(Sects.contest_record(c, data())["wins"], 2)
	assert_eq(Sects.contest_record(c, data())["last_year"], Calendar.year_of(1200))


func test_win_line_and_epilogue_survive_leaving() -> void:
	var c := _sect_char()
	Sects.record_contest(c, data(), 3, 3, 400)
	c.sect = {}
	var line := Sects.contest_win_line(c, data())
	assert_true(line.begins_with("Won the ") and line.ends_with("contest in year %d" % Calendar.year_of(400)), line)
	assert_true("\n".join(LifeStats.epilogue(c, data())).contains(line))


func test_milestone_on_full_win_only() -> void:
	var c := _sect_char()
	Sects.record_contest(c, data(), 2, 3, 400)
	assert_false(Milestones.newly_reached(c, data(), {}).has("sect_champion"))
	Sects.record_contest(c, data(), 3, 3, 800)
	assert_true(Milestones.newly_reached(c, data(), {}).has("sect_champion"))


func test_record_round_trips_and_old_saves_load() -> void:
	var c := _sect_char()
	Sects.record_contest(c, data(), 3, 3, 400)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.contest_record, c.contest_record)
	var d := c.to_dict()
	d.erase("contest_record")
	assert_eq(CharacterData.from_dict(d).contest_record, {})


func _inner_char() -> CharacterData:
	var c := new_character()
	c.realm_index = 2
	Sects.join(c, data(), "azure_cloud_sect")
	c.sect["reported"] = true
	return c


## REVIEW (WU-633): each kind counts its own wins, so the inner line never repeats an outer champion's wins.
func test_wins_kept_per_kind() -> void:
	var c := _inner_char()
	c.sect["rank"] = 1
	var outer_rounds := int(Sects.contest_def(c, data()).get("rounds", 3))
	assert_true(Sects.record_contest(c, data(), outer_rounds, outer_rounds, 100))
	c.sect["rank"] = 2
	assert_true(Sects.is_inner_contest(c, data()))
	Sects.record_contest(c, data(), 1, 3, 500)
	assert_eq(Sects.kind_wins(c, "outer"), 1)
	assert_eq(Sects.kind_wins(c, "inner"), 0)
	assert_eq(Sects.contest_record(c, data())["wins"], 0)
	assert_false(Sects.contest_record_line(c, data()).contains("champion"), Sects.contest_record_line(c, data()))
	assert_eq(Sects.outer_record_line(c, data()), "Outer contest: best round %d, champion 1 time" % outer_rounds)
	assert_eq(LifeStats.get_stat(c, "contest_wins"), 1, "the life stat stays the total")


func test_outer_line_only_in_inner_ranks() -> void:
	var c := _inner_char()
	c.sect["rank"] = 1
	Sects.record_contest(c, data(), 1, 3, 100)
	assert_eq(Sects.outer_record_line(c, data()), "", "outer ranks see the main record line")
	c.sect["rank"] = 2
	assert_eq(Sects.outer_record_line(c, data()), "Outer contest: best round 1")


## A pre-WU-633 record has no `wins`: an outer-only history keeps the life-stat total, and the next entry seeds it.
func test_legacy_record_keeps_its_wins() -> void:
	var c := _inner_char()
	c.sect["rank"] = 2
	c.contest_record = {"outer": {"best_round": 3, "last_year": 1}}
	LifeStats.add(c, "contest_wins", 2)
	assert_eq(Sects.kind_wins(c, "outer"), 2)
	assert_eq(Sects.kind_wins(c, "inner"), 0)
	Sects.record_contest(c, data(), 1, 3, 500)
	assert_eq(Sects.kind_wins(c, "inner"), 0)
	assert_eq(int(c.contest_record["inner"]["wins"]), 0)
	assert_eq(Sects.kind_wins(c, "outer"), 2, "the outer total survives the first inner entry")


func test_per_kind_wins_survive_a_save() -> void:
	var c := _inner_char()
	c.sect["rank"] = 1
	Sects.record_contest(c, data(), 3, 3, 100)
	Sects.record_contest(c, data(), 1, 3, 500)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(int(back.contest_record["outer"]["wins"]), 1)
	assert_eq(Sects.kind_wins(back, "outer"), 1)
