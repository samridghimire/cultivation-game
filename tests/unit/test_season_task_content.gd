extends TestCase
## C-311: season task content: two sets per season, and every target is available in its season near Qingshi.


func test_two_sets_per_season_unique_ids() -> void:
	var gd: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	var ids := {}
	for s: String in SeasonTasks.SEASONS:
		var sets := SeasonTasks.sets_of(gd.season_tasks["seasons"][s])
		assert_true(sets.size() >= 2, "%s has two sets" % s)
		for set: Array in sets:
			assert_eq(set.size(), 3, "%s set of three" % s)
			for t: Dictionary in set:
				assert_false(ids.has(t["id"]), "unique id %s" % t["id"])
				ids[t["id"]] = true
		assert_true(gd.items.has(String(gd.season_tasks["seasons"][s]["payout"].get("item", "")) ), "%s keepsake exists" % s)


func test_targets_occur_in_season() -> void:
	var gd: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	for s: String in SeasonTasks.SEASONS:
		for set: Array in SeasonTasks.sets_of(gd.season_tasks["seasons"][s]):
			for t: Dictionary in set:
				var c := CharacterData.new()
				var day := {"spring": 5, "summer": 95, "autumn": 185, "winter": 275}[s] as int
				assert_eq(Calendar.season_of(day).to_lower(), s, "day fits season")
				var kind := String(t["kind"])
				if kind in ["catch", "gather", "hunt"]:
					assert_true(SeasonTasks.where(t, c, gd, day) != "", "%s doable in %s" % [t["id"], s])
				elif kind == "contest":
					var ev: Dictionary = gd.world_events.get(String(t["target"]), {})
					var months: Array = ev.get("months", [])
					assert_true(months.size() > 0 and Calendar.season_of(day).to_lower() == SeasonTasks.season_name((int(months[0]) - 1) * 30 + 1), "%s festival in %s" % [t["id"], s])
