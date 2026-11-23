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


## GFX-206: a named villager's label stays within 24 px (vertically) of their sprite, above or below.
func _named_label_gaps(region: String, npc: String) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	gs.current_region = region
	var world: Node = load("res://src/world/world.tscn").instantiate()
	tree.root.add_child(world)
	for i in 4:
		await tree.process_frame
	var out: Array = []
	for node in world.get_children():
		if node is Interactable and node.get("npc_id") == npc:
			var n := node as Interactable
			var body := Rect2(n.position - n.size / 2.0, n.size)
			var r := n.label_rect()
			out.append(maxf(body.position.y - r.end.y, r.position.y - body.end.y))
	world.queue_free()
	gs.end_session()
	return out


func test_elder_mo_label_hugs_him() -> void:
	var gaps := await _named_label_gaps("qingshi_village", "elder_mo")
	for g: float in gaps:
		assert_true(g <= 24.0, "Elder Mo's label is %s px from him" % g)


## GFX-244: a place's name label stays off other places' sprites (Blossom Crack vs the Workshop, Ma vs the bounty board).
func _label_hits_sprite(region: String, label_of: String, sprite_of: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	gs.current_region = region
	var world: Node = load("res://src/world/world.tscn").instantiate()
	tree.root.add_child(world)
	for i in 4:
		await tree.process_frame
	world.call("_spread_on_screen")
	var label: Rect2
	var body: Rect2
	for node in world.get_children():
		if node is Interactable:
			var n := node as Interactable
			if n.display_name.begins_with(label_of):
				label = n.label_rect()
			if n.display_name.begins_with(sprite_of):
				body = Rect2(n.position - n.size / 2.0, n.size)
	world.queue_free()
	gs.end_session()
	return label.intersects(body)


func test_blossom_crack_label_clears_the_workshop() -> void:
	assert_false(await _label_hits_sprite("qingshi_village", "Blossom Crack", "Village Workshop"))


func test_hunter_ma_label_clears_the_bounty_board() -> void:
	assert_false(await _label_hits_sprite("qingshi_village", "Hunter Ma", "Hunters' Bounty Board"))
