extends TestCase
## C-395: a fresh mortal has an Easy fight (>= 90 in 100) in every early region in every season,
## and still has one within 7 days of doing the region's chore fight.

const REGIONS: Array[String] = ["qingshi_village", "misty_forest", "fallen_star_market", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _easy(c: CharacterData, gs: Node, region: String, day: int) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in Guidance.fair_fights(c, gs.data, gs.world_flags, day, region, gs.npcs, gs.npc_favor):
		if float(f["chance"]) >= 0.9:
			out.append("%s/%s" % [f["kind"], f["enemy_id"]])
	return out


func test_every_region_has_an_easy_fight_each_season() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Newcomer", gs.data, seeded_rng(9))
	gs.start_session(c)
	for year in 2:
		for s in 4:
			var day := year * Calendar.DAYS_PER_YEAR + s * 90
			for region in REGIONS:
				assert_true(not _easy(c, gs, region, day).is_empty(), "%s has an Easy fight on day %d (%s)" % [region, day, Calendar.season_of(day)])
	gs.end_session()


## After the region's chore fight (18-20 day cooldown), another Easy fight is still on offer within 7 days.
func test_easy_fight_remains_after_the_chore() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Newcomer", gs.data, seeded_rng(9))
	gs.start_session(c)
	for s in 4:
		var day := s * 90
		for region in REGIONS:
			var chores: Array[String] = []
			for f: Dictionary in Guidance.fair_fights(c, gs.data, gs.world_flags, day, region, gs.npcs, gs.npc_favor):
				if f["kind"] == "deed" and float(f["chance"]) >= 0.9:
					chores.append(String(f["enemy_id"]))
			var others := 0
			for e in _easy(c, gs, region, day):
				if not e.begins_with("deed/"):
					others += 1
			var deed_foes := chores.size()
			assert_true(others > 0 or deed_foes > 1, "%s keeps an Easy fight besides one chore (day %d, %s)" % [region, day, Calendar.season_of(day)])
	gs.end_session()
