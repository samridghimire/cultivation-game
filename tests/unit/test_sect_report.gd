extends TestCase
## SECT-032: reporting at the sect hall (Sects.report, GameState.report_to_sect, Guidance.report_hint).

var _reports: Array = []


func _on_reported(id: String, items: Dictionary) -> void:
	_reports.append([id, items])


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Reporter", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	c.alignment = 0
	gs.start_session(c)
	return c


func test_join_needs_report() -> void:
	var d := _gs().data as GameData
	var c := CharacterFactory.create("R", d, seeded_rng(1))
	c.realm_index = 1
	c.alignment = 50
	assert_true(Sects.join(c, d, "azure_cloud_sect")["ok"])
	assert_true(Sects.needs_report(c))
	c.sect.erase("reported")
	assert_false(Sects.needs_report(c))


func test_report_home_only_once_and_rejoin() -> void:
	var d := _gs().data as GameData
	var c := CharacterFactory.create("R", d, seeded_rng(1))
	c.realm_index = 1
	c.alignment = 50
	Sects.join(c, d, "azure_cloud_sect")
	var away := Sects.report(c, d, "qingshi_village")
	assert_false(away["ok"])
	assert_true(String(away["reason"]).begins_with("Report at the"))
	var before := c.item_count("qi_gathering_pill")
	var ok := Sects.report(c, d, "azure_peak")
	assert_true(ok["ok"])
	assert_eq(c.item_count("qi_gathering_pill"), before + 2)
	assert_true(String(ok["line"]).contains("R"))
	assert_false(Sects.report(c, d, "azure_peak")["ok"])
	Sects.leave(c)
	Sects.join(c, d, "azure_cloud_sect")
	assert_true(Sects.needs_report(c))


func test_game_state_report_and_hint() -> void:
	var c := _start()
	var gs := _gs()
	c.realm_index = 1
	gs.join_sect("azure_cloud_sect")
	var d := gs.data as GameData
	assert_true(Guidance.report_hint(c, d, "qingshi_village").contains("(") and Guidance.report_hint(c, d, "qingshi_village").begins_with("Report at the"))
	assert_true(Guidance.report_hint(c, d, "azure_peak").ends_with("get their issue there."))
	_reports.clear()
	_bus().sect_reported.connect(_on_reported)
	gs.current_region = "azure_peak"
	var day: int = gs.get_node("/root/GameClock").total_days
	gs.report_to_sect()
	assert_eq(_reports.size(), 1)
	assert_eq(_reports[0][0], "azure_cloud_sect")
	assert_eq(int(_reports[0][1]["qi_gathering_pill"]), 2)
	assert_eq(gs.get_node("/root/GameClock").total_days, day)
	gs.report_to_sect()
	assert_eq(_reports.size(), 1)
	assert_eq(Guidance.report_hint(c, d, "azure_peak"), "")
	_bus().sect_reported.disconnect(_on_reported)


func test_validate_rejects_bad_item() -> void:
	var d := GameData.new()
	d.items = data().items
	var def := SectDef.new()
	def.id = "test_sect"
	def.welcome = {"line": "Hi", "items": {"no_such_item": 1}}
	d._validate_welcome(def)
	assert_eq(d.load_errors.size(), 1)


## SECT-034: the hall's lecture row says it is open all month; the report line leads the sect's lines.
func test_lecture_row_and_report_first() -> void:
	var c := _start()
	var gs := _gs()
	c.realm_index = 1
	gs.join_sect("azure_cloud_sect")
	var d := gs.data as GameData
	var rows := Guidance.hall_services(c, d, "qingshi_village", 3, {})
	var found := false
	for r in rows:
		if String(r).begins_with("Lecture:"):
			found = true
			assert_true(String(r).contains("open this month (27d left)"), r)
	assert_true(found)
	var hints := Guidance.hints(c, d, 1.0, 10, {}, {}, "qingshi_village", 3)
	assert_true(hints.size() > 0 and String(hints[0]).begins_with("Report at the"), str(hints))
