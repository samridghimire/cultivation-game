extends TestCase
## WU-645: Qingshi's world-map badge says what waits at home, and is empty when nothing waits or you are there.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_badge_text() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Homebody", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	assert_eq(Guidance.home_badge(c, gs.data, gs.npcs, 5, SeasonTasks.REGION), "", "at home: no badge")
	var open := 0
	for t: Dictionary in SeasonTasks.list(c, gs.data, 5):
		if not bool(t["done"]):
			open += 1
	var badge := Guidance.home_badge(c, gs.data, gs.npcs, 5, "withered_bone_marsh")
	if open > 0:
		assert_true(badge.contains("task"), badge)
	else:
		assert_eq(badge, "", "nothing waits")
	assert_eq(Guidance.home_badge(null, gs.data, gs.npcs, 5, "x"), "")
