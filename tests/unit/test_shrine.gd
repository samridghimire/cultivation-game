extends TestCase
## GFX-081: the old shrine landmark follows SeasonTasks.restoration_stage.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_variant_follows_stage() -> void:
	var seen := {}
	for s in 5:
		seen[Shrine.variant(s)] = true
	assert_eq(seen.size(), 5, "five distinct drawings")
	assert_eq(Shrine.variant(0), "broken")
	assert_eq(Shrine.variant(4), "lit")
	assert_eq(Shrine.variant(9), "lit", "clamped")


func test_need_line() -> void:
	assert_eq(Shrine.need_line(2, 4), "Finish this season's three village tasks to repair the roof.")
	assert_true(Shrine.need_line(4, 4).begins_with("The shrine stands whole"))


func test_place_is_in_qingshi_and_label_counts() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Pilgrim", gs.data, seeded_rng(5))
	gs.start_session(c)
	var found := false
	for p: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		if p["type"] == "shrine":
			found = true
	assert_true(found, "shrine place in qingshi_village")
	var node := Shrine.new()
	node.display_name = "Old Shrine"
	assert_eq(node.label_text(), "Old Shrine (0/4)")
	c.seasons_completed.assign(["a", "b"])
	assert_eq(Shrine.stage_now(), 2)
	assert_eq(node.label_text(), "Old Shrine (2/4)")
	assert_eq(node.get_options().size(), 1)
	assert_true(node.get_options()[0]["disabled"])
	c.seasons_completed.assign(["a", "b", "c", "d"])
	assert_eq(node.label_text(), "Old Shrine")
	node.free()
