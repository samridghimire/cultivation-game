extends TestCase
## GFX-087: the Founder's Old Well is drawn and labelled by the well project's stage.

func test_variant_per_stage() -> void:
	assert_eq(InheritanceGrounds.well_variant(0), "choked")
	assert_eq(InheritanceGrounds.well_variant(1), "rope")
	assert_eq(InheritanceGrounds.well_variant(2), "roofed")
	assert_eq(InheritanceGrounds.well_variant(3), "ribboned")
	assert_eq(InheritanceGrounds.well_variant(9), "ribboned")


func test_label_per_stage() -> void:
	assert_eq(InheritanceGrounds.well_label("Founder's Old Well", 0, 3), "Founder's Old Well (0/3)")
	assert_eq(InheritanceGrounds.well_label("Founder's Old Well", 2, 3), "Founder's Old Well (2/3)")
	assert_eq(InheritanceGrounds.well_label("Founder's Old Well", 3, 3), "Founder's Old Well")


func test_node_label_follows_progress() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Wellwisher", gs.data, seeded_rng(3))
	gs.start_session(c)
	var node := InheritanceGrounds.new()
	node.display_name = InheritanceGrounds.WELL_NAME
	assert_eq(node.label_text(), "Founder's Old Well (0/3)")
	var shrine_n := (SeasonTasks.restoration(gs.data).get("stages", []) as Array).size()
	var done: Array = []
	for i in shrine_n + 3:
		done.append("s%d" % i)
	c.seasons_completed.assign(done)
	assert_eq(node.label_text(), "Founder's Old Well")
	var other := InheritanceGrounds.new()
	other.display_name = "Mossy Cairn"
	assert_eq(other.label_text(), "Mossy Cairn")
	node.free()
	other.free()
