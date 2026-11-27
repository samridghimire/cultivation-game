extends TestCase
## QA-251: the contest tests edit sect contest defs; none may leave the shared GameState data changed.
## The file name sorts last so it runs after the other contest tests.


func test_shared_contest_defs_match_a_fresh_load() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var fresh := GameData.load_from_dir()
	for sect_id: String in fresh.sects:
		var a: SectDef = gs.data.sects[sect_id]
		var b: SectDef = fresh.sects[sect_id]
		assert_eq(a.contest, b.contest, "%s contest def left edited" % sect_id)
		assert_eq(a.inner_contest, b.inner_contest, "%s inner contest def left edited" % sect_id)
