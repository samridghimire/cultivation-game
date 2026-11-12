extends TestCase
## SEASON-018: every year-1 season task set is finishable by a fresh mortal.

const MAX_THREAT := "Dangerous"


func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func test_year_one_hunts_are_not_deadly() -> void:
	var gd := _gd()
	var c := new_character()
	var bound := Wildlife.THREAT_ORDER.find(MAX_THREAT)
	for s in SeasonTasks.SEASONS:
		var day := 90 * SeasonTasks.SEASONS.find(s) + 1
		assert_eq(SeasonTasks.season_name(day), s)
		for t: Dictionary in SeasonTasks.tasks_for(gd, day):
			if String(t["kind"]) != "hunt":
				continue
			var label := Wildlife.threat(c, gd, String(t["target"]))
			print("SEASON-018 ", t["id"], " ", t["target"], " ", label)
			assert_true(Wildlife.THREAT_ORDER.find(label) <= bound, "%s (%s) is %s for a newcomer" % [t["id"], t["target"], label])

