extends TestCase
## SECT-044: the sect contest's last round is fought against a same-sect rival.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _setup(rival_sect: String, rival_realm: int = 0) -> Array:
	var gs := _gs()
	var c := CharacterFactory.create("Contender", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var rival := Rivals.spawn(c, gs.npcs, gs.data, seeded_rng(6), "qingshi_village")
	rival.realm_index = rival_realm
	rival.sect = {} if rival_sect == "" else {"id": rival_sect, "rank": 0, "contribution": 0}
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": true}
	var def: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest
	def["foes"] = ["wild_boar", "wild_boar"]
	def["rounds"] = 2
	def["power_mults"] = [1.0, 1.0]
	GameClock.total_days = (int(def["month"]) - 1) * Calendar.DAYS_PER_MONTH
	return [c, rival]


func test_rival_in_sect_is_last_foe() -> void:
	var gs := _gs()
	var saved: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var pair := _setup("azure_cloud_sect")
	var rival: CharacterData = pair[1]
	var round_def := Sects.contest_round(pair[0], gs.data, 1)
	assert_eq(String(gs.call("_contest_foe", 1, round_def).get("name", "")), rival.name)
	assert_eq(String(gs.call("_contest_foe", 0, Sects.contest_round(pair[0], gs.data, 0)).get("name", "")), String(gs.data.enemies["wild_boar"]["name"]))
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest = saved
	gs.end_session()


func test_rival_elsewhere_or_far_uses_listed_foe() -> void:
	var gs := _gs()
	var saved: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var pair := _setup("blood_lotus_sect")
	var round_def := Sects.contest_round(pair[0], gs.data, 1)
	assert_eq(String(gs.call("_contest_foe", 1, round_def).get("name", "")), String(gs.data.enemies["wild_boar"]["name"]))
	(pair[1] as CharacterData).sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	(pair[1] as CharacterData).realm_index = 3
	assert_false(Rivals.contest_rival(pair[0], pair[1], gs.data), "two realms apart")
	(pair[1] as CharacterData).realm_index = 0
	(pair[1] as CharacterData).alive = false
	assert_false(Rivals.contest_rival(pair[0], pair[1], gs.data), "dead rival")
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest = saved
	gs.end_session()


func test_contest_bout_with_rival_posts_line_and_tallies() -> void:
	var gs := _gs()
	var saved: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var pair := _setup("azure_cloud_sect")
	var seen: Array[String] = []
	var grab := func(text: String, _cat: String) -> void: seen.append(text)
	EventBus.message_posted.connect(grab)
	gs.enter_sect_contest()
	EventBus.message_posted.disconnect(grab)
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest = saved
	var rival: CharacterData = pair[1]
	var talked := seen.filter(func(t: String) -> bool: return t.begins_with(rival.name) and (t.contains("yields") or t.contains("takes the last round")))
	var fought: bool = int(gs.world_flags.get("rival_bouts_won", 0)) + int(gs.world_flags.get("rival_bouts_lost", 0)) > 0
	assert_eq(talked.size(), 1 if fought else 0, "one rival line when the last round was reached")
	gs.end_session()


func test_rival_follows_player_into_sect() -> void:
	var gs := _gs()
	var rival := CharacterData.new()
	rival.realm_index = 1  # the Azure Cloud takes Qi Refining and above
	var joined := 0
	for i in 40:
		rival.sect = {}
		if Rivals.follow_into_sect(rival, "azure_cloud_sect", gs.data, seeded_rng(i)):
			joined += 1
			assert_eq(String(rival.sect["id"]), "azure_cloud_sect")
	assert_true(joined > 5 and joined < 35, "about half join: %d" % joined)
	rival.sect = {"id": "blood_lotus_sect"}
	assert_false(Rivals.follow_into_sect(rival, "azure_cloud_sect", gs.data, seeded_rng(1)), "already in a sect")
	assert_false(Rivals.follow_into_sect(null, "azure_cloud_sect", gs.data, seeded_rng(1)))


func test_rival_follows_only_into_a_sect_that_accepts_them() -> void:
	var gs := _gs()
	var rival := CharacterData.new()
	rival.realm_index = 1
	rival.alignment = 60  # too soft-hearted for the Blood Lotus (max_alignment 0)
	for i in 20:
		assert_false(Rivals.follow_into_sect(rival, "blood_lotus_sect", gs.data, seeded_rng(i)), "a righteous rival never joins the Blood Lotus")
	rival.realm_index = 0  # a mortal is below the Azure Cloud's min_realm
	for i in 20:
		assert_false(Rivals.follow_into_sect(rival, "azure_cloud_sect", gs.data, seeded_rng(i)), "a mortal rival is turned away")
