extends TestCase
## GFX-202: on day 0 at 1280x800, no two visible name labels of a starting region intersect.

const REGIONS := ["qingshi_village", "withered_bone_marsh", "azure_peak", "misty_forest", "myriad_peaks_ridge", "fallen_star_market"]
const MIN_ALPHA := 0.35  ## faded labels (covered/far) may touch


func _collisions(region: String) -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	gs.current_region = region
	var world: Node = load("res://src/world/world.tscn").instantiate()
	tree.root.add_child(world)
	for i in 4:
		await tree.process_frame
	world.call("_spread_on_screen")
	var view: Rect2 = world.get_canvas_transform().affine_inverse() * world.get_viewport_rect()
	var items: Array = []
	for node in world.get_children():
		if node is Interactable:
			var n := node as Interactable
			if not n.label_drawn() or n.label_covered:
				continue
			if float(n.get("label_fade")) < MIN_ALPHA:
				continue
			var r := n.drawn_label_rect(view).grow(Interactable.PLATE_PAD)
			if view.intersects(r):
				items.append([n.label_text(), r])
	var out: Array[String] = []
	for i in items.size():
		for j in range(i + 1, items.size()):
			if (items[i][1] as Rect2).intersects(items[j][1]):
				out.append("%s: '%s' x '%s'" % [region, items[i][0], items[j][0]])
	world.queue_free()
	gs.end_session()
	return out


func test_no_label_collisions_in_starting_regions() -> void:
	var all: Array[String] = []
	for region: String in REGIONS:
		all.append_array(await _collisions(region))
	assert_true(all.is_empty(), "label collisions: %s" % ["; ".join(all)])
