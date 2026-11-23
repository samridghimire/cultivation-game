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


## REVIEW: the goal that flips the HUD onto or off the sect ladder is still announced (from the old ladder).
func test_hud_announces_across_the_sect_ladder() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := CharacterFactory.create("Goals", gs.data, seeded_rng(3))
	gs.start_session(c)
	c.techniques = {"basic_breathing": {"level": 1}, "iron_fist": {"level": 1, "xp": 0.0}}
	c.realm_index = 1
	c.stage = 1
	c.cooked_meals["x"] = 1
	LifeStats.add(c, "fights_won")
	LifeStats.add(c, "foraged")
	LifeStats.add(c, "harvests")
	c.alignment = 50
	Sects.join(c, gs.data, "azure_cloud_sect")
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var banner: Banner = hud.get("_banner")
	hud.call("_sync_goals_done")
	assert_eq(hud.get("_goals_ladder"), "first")
	banner.visible = false
	banner.set("_queue", [])
	c.stage = 2  # the last first goal: the HUD moves to the sect ladder
	hud.call("_announce_goals_done")
	assert_eq(hud.get("_goals_ladder"), "sect")
	var texts := _banner_texts(banner)
	assert_true(texts.contains("Reach the 3rd Layer"), "last first goal announced: " + texts)
	banner.visible = false
	banner.set("_queue", [])
	c.sect["reported"] = true
	LifeStats.add(c, "lectures_attended")
	LifeStats.add(c, "missions_done")
	hud.call("_sync_goals_done")
	c.sect["rank"] = 1  # the last sect goal: the HUD leaves the sect ladder
	hud.call("_announce_goals_done")
	assert_eq(hud.get("_goals_ladder"), "first")
	texts = _banner_texts(banner)
	assert_true(texts.contains("Rise to"), "last sect goal announced: " + texts)
	assert_true(texts.contains("sect goals are done"), texts)
	hud.free()
	gs.end_session()


func _banner_texts(banner: Banner) -> String:
	var out := banner.subtitle_text() if banner.visible else ""
	for q: Array in banner.get("_queue"):
		out += " | " + String(q[1])
	return out
