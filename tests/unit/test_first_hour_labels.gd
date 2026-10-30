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
	assert_false(Interactable.label_visible(true))
	assert_true(Interactable.label_visible(false))
	var n := _npc("Lin", Vector2.ZERO)
	n.highlighted = true
	assert_false(Interactable.label_visible(n.highlighted))


func test_place_and_npc_labels_spread_together() -> void:
	var place := _npc("Founder's Old Well", Vector2(300, 300))
	var npc := _npc("Xiong Muxue", Vector2(310, 302))
	Interactable.spread_labels([place, npc])
	assert_false(place.label_rect().intersects(npc.label_rect()), "place and NPC labels overlap")


func test_label_layer_sits_above_buildings() -> void:
	var n := _npc("Sect Recruitment Hall", Vector2(100, 100))
	(Engine.get_main_loop() as SceneTree).root.add_child(n)
	assert_true(n._label_node.z_index > 0, "label node must draw above siblings")
	n.queue_free()


func test_hinted_names_finds_names_in_the_hint() -> void:
	var hint := "The Village Clinic treats it for 10 stones."
	assert_eq(Interactable.hinted_names(hint, ["Village Clinic", "Village Herb Seller"]), ["Village Clinic"])
	assert_eq(Interactable.hinted_names("", ["Village Clinic"]), [])


func test_hinted_names_prefers_the_longer_name() -> void:
	var hint := "The Village Clinic treats it."
	assert_eq(Interactable.hinted_names(hint, ["Clinic", "Village Clinic"]), ["Village Clinic"])
	assert_eq(Interactable.hinted_names("Try the Clinic.", ["Clinic", "Village Clinic"]), ["Clinic"])


func test_set_hinted_only_changes_on_a_new_value() -> void:
	var n := _npc("Aa", Vector2(10, 10))
	n.set_hinted(true)
	assert_true(n.hinted)
	n.set_hinted(false)
	assert_false(n.hinted)
	n.free()


func test_spread_on_screen_lifts_labels_the_edge_clamp_pushed_together() -> void:
	var view := Rect2(0, 0, 400, 400)
	var a := _npc("Founder's Old Well Keeper", Vector2(395, 200))
	var b := _npc("Dongfang Beichen", Vector2(190, 200))
	assert_false(a.label_rect().intersects(b.label_rect()), "world rects start apart")
	a.label_offset.x = 0.0
	Interactable.spread_on_screen([a, b], view)
	assert_false(a.drawn_label_rect(view).intersects(b.drawn_label_rect(view)), "drawn rects overlap")
	assert_true(b.screen_lift < 0.0 or a.screen_lift < 0.0)
	a.free()
	b.free()


func test_spread_on_screen_leaves_central_labels_alone() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var a := _npc("Aa", Vector2(300, 300))
	var b := _npc("Bb", Vector2(600, 300))
	Interactable.spread_on_screen([a, b], view)
	assert_eq(a.screen_lift, 0.0)
	assert_eq(b.screen_lift, 0.0)
	a.free()
	b.free()



func test_hinted_targets_picks_the_road_for_a_hint_naming_another_region() -> void:
	var data := data()
	var road: Interactable = load("res://src/world/interactables/travel_point.gd").new()
	road.display_name = "Village Gate"
	var npc := _npc("Aa", Vector2(10, 10))
	var other := Exploration.region_name(data, "misty_forest")
	assert_eq(Interactable.hinted_targets("Try the market in %s." % other, [road, npc], data, "qingshi_village"), [road])
	assert_eq(Interactable.hinted_targets("Talk to Aa.", [road, npc], data, "qingshi_village"), [npc])
	assert_eq(Interactable.hinted_targets("Rest.", [road, npc], data, "qingshi_village"), [])
	road.free()
	npc.free()


func test_travel_point_marks_the_first_hop_route() -> void:
	var gs = Engine.get_main_loop().root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Hop", gs.data, seeded_rng(1), "male"))
	gs.current_region = "qingshi_village"
	var road: Interactable = load("res://src/world/interactables/travel_point.gd").new()
	road.hint_region = "misty_forest"
	var marked := 0
	for o: Dictionary in road.get_options():
		if String(o.get("description", "")).begins_with("The hint points this way. "):
			marked += 1
			assert_true(String(o["label"]).contains(Exploration.region_name(gs.data, "misty_forest")))
	assert_eq(marked, 1)
	road.free()


func test_spread_on_screen_skips_labels_that_are_not_drawn() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var hidden := _npc("Same Name", Vector2(300, 300))
	var shown := _npc("Same Name", Vector2(300, 300))
	hidden.visible = false
	Interactable.spread_on_screen([hidden, shown], view)
	assert_eq(shown.screen_lift, 0.0, "a hidden label must not push a drawn one")
	hidden.free()
	shown.free()


func test_spread_on_screen_zeroes_the_lift_of_a_label_that_gets_hidden() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var n := _npc("Aa", Vector2(300, 300))
	n.screen_lift = -30.0
	n.visible = false
	Interactable.spread_on_screen([n], view)
	n.visible = true
	Interactable.spread_on_screen([n], view)
	assert_eq(n.screen_lift, 0.0, "a stale lift must not come back")
	n.free()


func test_drawn_label_rect_includes_the_hinted_badge() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var n := _npc("Aa", Vector2(300, 300))
	var plain := n.drawn_label_rect(view)
	n.hinted = true
	var badged := n.drawn_label_rect(view)
	assert_true(badged.size.y > plain.size.y + 10.0, "badge adds height")
	assert_true(badged.end.y <= plain.end.y + 0.01 and badged.position.y < plain.position.y)
	n.free()


func test_hinted_targets_skips_a_region_no_route_reaches() -> void:
	var data := data()
	var c := CharacterData.new()
	var road: Interactable = load("res://src/world/interactables/travel_point.gd").new()
	road.display_name = "Village Gate"
	var reachable := ""
	var cut_off := ""
	for id: String in data.regions.keys():
		if id == "qingshi_village":
			continue
		var hop := Guidance.first_hop(c, data, "qingshi_village", id)
		if hop != "" and reachable == "":
			reachable = id
		if hop == "" and cut_off == "":
			cut_off = id
	assert_true(reachable != "" and cut_off != "", "data has a reachable and an unreachable region")
	var near := "Try the market in %s." % Exploration.region_name(data, reachable)
	var far := "Try the market in %s." % Exploration.region_name(data, cut_off)
	assert_eq(Interactable.hinted_targets(near, [road], data, "qingshi_village", c), [road])
	assert_eq(Interactable.hinted_targets(far, [road], data, "qingshi_village", c), [])
	assert_eq(Interactable.hinted_targets(far, [road], data, "qingshi_village"), [road])
	road.free()


func test_proximity_alpha_fades_between_near_and_far() -> void:
	assert_eq(Interactable.proximity_alpha(0.0, 140.0, 200.0), 1.0)
	assert_eq(Interactable.proximity_alpha(140.0, 140.0, 200.0), 1.0)
	assert_true(absf(Interactable.proximity_alpha(170.0, 140.0, 200.0) - 0.5) < 0.001)
	assert_eq(Interactable.proximity_alpha(200.0, 140.0, 200.0), 0.0)
	assert_eq(Interactable.proximity_alpha(500.0, 140.0, 200.0), 0.0)


func test_generated_villager_label_fades_but_hinted_one_stays() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Label", gs.data, seeded_rng(7)))
	var n := _npc("Villager (Farmer)", Vector2(0, 0))
	n.npc_id = "nobody_generated"
	assert_eq(n.label_alpha(Vector2(50, 0)), 1.0)
	assert_eq(n.label_alpha(Vector2(300, 0)), 0.0)
	n.set_hinted(true)
	assert_eq(n.label_alpha(Vector2(300, 0)), 1.0)
	n.free()


func test_spread_on_screen_ignores_labels_faded_to_nothing() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var hidden := _npc("Same Name", Vector2(300, 300))
	var shown := _npc("Same Name", Vector2(300, 300))
	hidden.label_fade = 0.0
	Interactable.spread_on_screen([hidden, shown], view)
	assert_eq(shown.screen_lift, 0.0, "a faded-out name must not push a place label up")
	hidden.free()
	shown.free()


## GFX-025: places fade with distance unless hinted, highlighted or "Show all place names" is on.
func test_place_label_alpha_near_far_hinted_and_toggle() -> void:
	var place := Interactable.new()
	place.display_name = "Village Clinic"
	place.position = Vector2.ZERO
	assert_eq(place.label_alpha(Vector2(Interactable.PLACE_NEAR - 1.0, 0)), 1.0)
	assert_true(is_equal_approx(place.label_alpha(Vector2(Interactable.PLACE_FAR + 50.0, 0)), Interactable.PLACE_FAR_ALPHA))
	var mid := place.label_alpha(Vector2(320, 0))
	assert_true(mid > Interactable.PLACE_FAR_ALPHA and mid < 1.0, str(mid))
	place.hinted = true
	assert_eq(place.label_alpha(Vector2(900, 0)), 1.0)
	place.hinted = false
	Settings.set_value("show_all_labels", true)
	assert_eq(place.label_alpha(Vector2(900, 0)), 1.0)
	Settings.set_value("show_all_labels", false)
	assert_true(place.label_alpha(Vector2(900, 0)) < 1.0)
	place.free()


func test_spread_on_screen_moves_a_label_out_of_a_hud_rect() -> void:
	var view := Rect2(0, 0, 1000, 800)
	var a := _npc("Village Clinic Keeper", Vector2(300, 300))
	var panel := a.drawn_label_rect(view).grow(4.0)
	var occupied: Array[Rect2] = [panel]
	Interactable.spread_on_screen([a], view, occupied)
	assert_true(a.screen_lift < 0.0, "lifted")
	assert_false(a.drawn_label_rect(view).intersects(panel), "clear of the panel")
	assert_false(a.label_covered)
	a.free()
