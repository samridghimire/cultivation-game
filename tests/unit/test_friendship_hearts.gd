extends TestCase
## WU-418: friendship hearts, the Look sentence, Folk.friends_line and the portrait banner.


func _village(npcs: Dictionary, count: int) -> void:
	for i in count:
		Npcs.spawn(npcs, data(), seeded_rng(30 + i), {"age_years": 20 + i, "region": "qingshi_village", "realm": "mortal"})


func test_hearts_texture_size() -> void:
	var n: int = data().family["folk_tiers"].size()
	assert_eq(n, 4)
	var tex := HudIcons.hearts(n, 2, 2)
	assert_eq(tex.get_width(), (n * 6 - 1) * 2)
	assert_eq(tex.get_height(), 10)
	assert_eq(HudIcons.hearts(n, 2, 1).get_width(), 23)
	# Filled and empty hearts differ.
	assert_true(HudIcons.hearts(n, 1, 1).get_image().get_pixel(2, 1) != HudIcons.hearts(n, 1, 1).get_image().get_pixel(8, 1))


func test_friends_line_counts_and_order() -> void:
	var npcs := {}
	_village(npcs, 5)
	var ids: Array = npcs.keys()
	ids.sort()
	assert_eq(Folk.friends_line(npcs, data(), "qingshi_village", {}), "")
	var favor := {ids[0]: 25}
	assert_eq(Folk.friends_line(npcs, data(), "qingshi_village", favor), "Friends: " + npcs[ids[0]].name)
	favor = {ids[0]: 25, ids[1]: 90, ids[2]: 45}
	var line := Folk.friends_line(npcs, data(), "qingshi_village", favor)
	assert_eq(line, "Friends: %s, %s, %s" % [npcs[ids[1]].name, npcs[ids[2]].name, npcs[ids[0]].name])
	for id in ids:
		favor[id] = 25
	favor[ids[1]] = 90
	line = Folk.friends_line(npcs, data(), "qingshi_village", favor)
	assert_true(line.begins_with("Friends: " + npcs[ids[1]].name + ", "))
	assert_true(line.ends_with("(+2 more)"))
	assert_eq(Folk.friends_line(npcs, data(), "other_region", favor), "")


func test_counts_you_line() -> void:
	assert_eq(Folk.counts_you_line(data(), "Wei", 10), "")
	assert_eq(Folk.counts_you_line(data(), "Wei", 45), "Wei counts you a friend.")
	assert_eq(Folk.counts_you_line(data(), "Wei", 25), "Wei counts you an acquaintance.")


func test_menu_header_hidden_at_zero_favor() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	node.npc_id = npc.id
	assert_true(node.menu_header().is_empty())
	gs.npc_favor[npc.id] = 65
	var header: Dictionary = node.menu_header()
	assert_eq(header["label"], "Close friend")
	assert_eq(gs.friendship_hearts(npc.id), 3)
	var menu := ChoiceMenu.new()
	menu._set_header(header)
	assert_true(menu.hearts_visible())
	assert_eq(menu.friendship_text(), "Close friend")
	menu._set_header({})
	assert_false(menu.hearts_visible())
	menu.free()
	node.free()


func test_tier_up_emits_signal_with_banner_portrait() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.check_friendships()  # seeds
	gs.npc_favor[npc.id] = 45
	var got: Array = []
	var cb := func(id: String, text: String) -> void: got.append([id, text])
	EventBus.friendship_reached.connect(cb)
	gs.check_friendships()
	EventBus.friendship_reached.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], npc.id)
	var b := Banner.new()
	b.announce("New friend", String(got[0][1]), Color.WHITE, 1.0, false, PixelFigure.frame({"robe": Color.RED, "sash": Color.WHITE}, "down", 0))
	assert_true(b.portrait_shown())
	b.announce("Next", "x", Color.WHITE)
	b.finish_current()
	assert_false(b.portrait_shown())
	b.free()
