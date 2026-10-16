extends TestCase
## WU-087: NPC labels do not overlap, show the realm only up close; inventory and fight log shrink to content.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func _npc(label: String, pos: Vector2) -> Interactable:
	var n: Interactable = NPC_SCRIPT.new()
	n.display_name = label
	n.position = pos
	n.size = Vector2(28, 28)
	return n


func test_close_npc_labels_are_lifted_apart() -> void:
	var a := _npc("Hooded Stranger (Qi Refining, 1st Layer)", Vector2(300, 300))
	var b := _npc("Ren Longyuan (Qi Refining, 2nd Layer)", Vector2(320, 304))
	Interactable.spread_labels([a, b])
	assert_false(a.label_rect().intersects(b.label_rect()), "labels overlap")
	assert_eq(a.label_offset, Vector2.ZERO)
	assert_true(b.label_offset.y < 0.0)


func test_distant_labels_stay_put() -> void:
	var a := _npc("Aa", Vector2(100, 100))
	var b := _npc("Bb", Vector2(600, 400))
	Interactable.spread_labels([a, b])
	assert_eq(b.label_offset, Vector2.ZERO)


func test_realm_suffix_only_when_near() -> void:
	var n := _npc("Zhao Huanyue (Qi Refining, 1st Layer)", Vector2.ZERO)
	assert_eq(n.label_text(), "Zhao Huanyue")
	n._near = true
	assert_eq(n.label_text(), "Zhao Huanyue (Qi Refining, 1st Layer)")


func test_inventory_list_shrinks_for_few_stacks() -> void:
	assert_true(InventoryScreen.list_height(1) < InventoryScreen.LIST_MAX_HEIGHT)
	assert_eq(InventoryScreen.list_height(100), InventoryScreen.LIST_MAX_HEIGHT)


func test_fight_log_shrinks_for_short_fights() -> void:
	assert_true(CombatReport.log_height(3) < 360.0)
	assert_eq(CombatReport.log_height(60), 360.0)


func test_is_rival_needs_the_first_meeting_and_a_living_rival() -> void:
	var d := data()
	var c := new_character()
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var other := new_character()
	other.id = "someone_else"
	people[other.id] = other
	assert_false(NPC_SCRIPT.is_rival(c, people, {}, rival.id), "before the first meeting")
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	assert_true(NPC_SCRIPT.is_rival(c, people, flags, rival.id))
	assert_false(NPC_SCRIPT.is_rival(c, people, flags, other.id), "another NPC")
	rival.alive = false
	assert_false(NPC_SCRIPT.is_rival(c, people, flags, rival.id), "dead rival")


func test_rival_look_prefix_says_where_they_stand() -> void:
	var c := new_character()
	var rival := new_character()
	rival.realm_index = c.realm_index + 1
	assert_eq(NPC_SCRIPT.rival_look_prefix(c, rival), "Your rival, far ahead of you. ")
	rival.realm_index = c.realm_index
	rival.stage = c.stage - 1
	assert_eq(NPC_SCRIPT.rival_look_prefix(c, rival), "Your rival, behind you. ")


func test_rival_label_stays_liftable() -> void:
	var a := _npc("Ren Longyuan (Qi Refining, 2nd Layer)", Vector2(300, 300))
	var b := _npc("Hooded Stranger (Qi Refining, 1st Layer)", Vector2(320, 304))
	a._near = true
	Interactable.spread_labels([a, b])
	assert_false(a.label_rect().intersects(b.label_rect()), "labels overlap")


func test_rival_look_prefix_adds_the_attitude() -> void:
	var c := new_character()
	var rival := new_character()
	rival.realm_index = c.realm_index + 1
	assert_eq(NPC_SCRIPT.rival_look_prefix(c, rival, "bitter"), "Your rival, far ahead of you; they hold a grudge. ")
	assert_eq(NPC_SCRIPT.rival_look_prefix(c, rival, "friendly"), "Your rival, far ahead of you; a friendly rivalry. ")
	assert_eq(NPC_SCRIPT.rival_look_prefix(c, rival, "proud"), "Your rival, far ahead of you. ")


func test_clamp_labels_pulls_edge_labels_inside() -> void:
	var bounds := Rect2(0, 0, 1000, 800)
	var right := _npc("Founder's Old Pavilion Keeper", Vector2(980, 300))
	var left := _npc("Far Left Person Here", Vector2(10, 300))
	var mid := _npc("Mid", Vector2(500, 300))
	Interactable.clamp_labels([right, left, mid], bounds)
	assert_true(right.label_rect().end.x <= bounds.end.x, "right label inside")
	assert_true(left.label_rect().position.x >= bounds.position.x, "left label inside")
	assert_eq(mid.label_offset, Vector2.ZERO)


func test_first_hour_region_labels_lie_inside_the_map() -> void:
	var d := data()
	for region_id: String in d.regions:
		var region: Dictionary = d.regions[region_id]
		var sz: Array = region.get("map", {}).get("size", [1600, 1000])
		var bounds := Rect2(0, 0, float(sz[0]), float(sz[1]))
		var nodes: Array = []
		for place: Dictionary in region.get("places", []):
			var n: Interactable = Interactable.new()
			n.display_name = String(place.get("display_name", place.get("id", "")))
			var p: Array = place.get("pos", [0, 0])
			n.position = Vector2(float(p[0]), float(p[1]))
			var s: Array = place.get("size", [60, 60])
			n.size = Vector2(float(s[0]), float(s[1]))
			nodes.append(n)
		Interactable.clamp_labels(nodes, bounds)
		for n: Interactable in nodes:
			assert_true(bounds.encloses(n.label_rect()), "%s: %s inside" % [region_id, n.display_name])


func test_target_label_hidden_while_prompt_names_it() -> void:
	assert_false(Interactable.label_visible(true, true))
	assert_true(Interactable.label_visible(true, false))
	assert_true(Interactable.label_visible(false, true))
	assert_true(Interactable.label_visible(false, false))
	var n := _npc("Lin", Vector2.ZERO)
	n.highlighted = true
	assert_false(Interactable.label_visible(n.highlighted, n.highlighted))
