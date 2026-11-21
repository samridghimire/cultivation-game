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


## WU-537: a teacher's menu lists what they teach; a non-teacher's has no line.
func test_menu_teaches_lines() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	node.npc_id = "hunter_ma"
	var lines: Array = node.menu_teaches()
	assert_true(lines.size() >= 1 and lines.size() <= 3)
	var menu := ChoiceMenu.new()
	menu._set_teaches(lines)
	var texts := menu.teaches_texts()
	assert_eq(texts[0], "Teaches:")
	assert_eq(texts.size(), lines.size() + 1)
	menu._set_teaches([{"text": "Iron Fist (favor 40)", "known": true}])
	assert_true(menu.teaches_texts()[1].contains("✓"))
	node.npc_id = "nobody_here"
	assert_true(node.menu_teaches().is_empty())
	menu._set_teaches(node.menu_teaches())
	assert_true(menu.teaches_texts().is_empty())
	menu.free()
	node.free()


## WU-539: a named villager's menu header shows favor and the tastes the player has learned.
func test_named_villager_header() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	node.npc_id = "hunter_ma"
	var header: Dictionary = node.menu_header()
	assert_eq(header["label"], "Favor 0")
	assert_eq(header["likes"], "")
	var menu := ChoiceMenu.new()
	menu._set_header(header)
	assert_true(menu.hearts_visible())
	assert_eq(menu.likes_text(), "")
	var item_id := String(gs.data.items.keys()[0])
	gs.world_flags["taste_hunter_ma_" + item_id] = 1
	gs.npc_favor["hunter_ma"] = 25
	header = node.menu_header()
	assert_true(String(header["label"]).begins_with("Favor 25 · "))
	assert_eq(header["likes"], "Likes: " + String(gs.data.items[item_id].get("name", item_id)))
	menu._set_header(header)
	assert_true(menu.likes_text().begins_with("Likes: "))
	menu._set_header({})
	assert_eq(menu.likes_text(), "")
	menu.free()
	node.free()


## WU-542: after Hunter Ma's lesson the card's Teaches line says the practice day is ready.
func test_teaches_line_practice_day_ready() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.npc_favor["hunter_ma"] = 100
	Techniques.learn(gs.player, gs.data, "iron_fist")
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	node.npc_id = "hunter_ma"
	var found := false
	for l: Dictionary in node.menu_teaches():
		if String(l["text"]).contains("practice day ready"):
			found = true
			assert_true(bool(l["ready"]))
	assert_true(found, "practice day ready line")
	node.free()


## GFX-225: crossing a tier emits one friend_tier_up with the npc and tier; no crossing, no signal.
func test_tier_up_signal_once_per_crossing() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.check_friendships()  # seeds
	var got: Array = []
	var cb := func(id: String, tier: int) -> void: got.append([id, tier])
	EventBus.friend_tier_up.connect(cb)
	gs.check_friendships()
	assert_eq(got.size(), 0)
	gs.npc_favor[npc.id] = 20
	gs.check_friendships()
	gs.check_friendships()
	EventBus.friend_tier_up.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], npc.id)
	assert_eq(got[0][1], 0)


## GFX-225: the hearts wait for a card to close, play ~1.2 s, and sit still (0.6 s) with reduce_motion.
func test_hearts_wait_for_card_then_play() -> void:
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	node.npc_id = "hunter_ma"
	node.size = Vector2(32, 32)
	node._on_friend_tier_up("someone_else", 0)
	assert_false(node.hearts_pending())
	node._on_friend_tier_up("hunter_ma", 1)
	assert_true(node.hearts_pending())
	node._on_modal_changed(true)
	node.hearts_tick(1.0)
	assert_true(node.hearts_pending())  # the card is up: queued
	assert_false(node.hearts_playing())
	node._on_modal_changed(false)
	node.hearts_tick(0.1)
	assert_false(node.hearts_playing())  # a short grace so the card can appear first
	node.hearts_tick(0.3)
	assert_true(node.hearts_playing())
	node.hearts_tick(0.5)
	assert_true(node.hearts_playing())
	node.hearts_tick(1.0)
	assert_false(node.hearts_playing())
	node.free()


## GFX-225: the lend row names the next tier and the favor still needed.
func test_lend_favor_text_names_next_tier() -> void:
	var NpcScript: GDScript = load("res://src/world/interactables/npc.gd")
	assert_eq(NpcScript.lend_favor_text(data(), 36), "favor 36/40 Friend")
	assert_eq(NpcScript.lend_favor_text(data(), 0), "favor 0/20 Acquaintance")
	assert_eq(NpcScript.lend_favor_text(data(), 90), "favor 90")


## GFX-227: the heart is 7 x 6 with an outline and one highlight; reduce_motion shows one still row for 0.8 s.
func test_heart_shape_and_still_row() -> void:
	var node: Node = load("res://src/world/interactables/npc.gd").new()
	assert_eq(node.HEART_ROWS.size(), 6)
	var highlights := 0
	for row: String in node.HEART_ROWS:
		assert_eq(row.length(), 7)
		highlights += row.count("H")
	assert_eq(highlights, 1)
	assert_true(node.HEART_TOP < -30.0)  # above the name strip
	assert_eq(node.HEARTS_STILL, 0.8)
	node.npc_id = "hunter_ma"
	node.size = Vector2(32, 32)
	node._on_friend_tier_up("hunter_ma", 1)
	node.hearts_tick(0.4)
	assert_true(node.hearts_playing())
	node.hearts_tick(2.0)
	assert_false(node.hearts_playing())  # the effect ends by itself
	node.free()


## WU-589: a named villager crossing a tier raises hearts and the banner signal (no parcel); a first sighting is silent.
func test_named_villager_tier_up() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.check_friendships()  # seeds
	var ups: Array = []
	var banners: Array = []
	var cb := func(id: String, tier: int) -> void: ups.append([id, tier])
	var cb2 := func(id: String, text: String) -> void: banners.append([id, text])
	EventBus.friend_tier_up.connect(cb)
	EventBus.friendship_reached.connect(cb2)
	gs.player.folk_tier_seen.erase("hunter_ma")
	gs.npc_favor["hunter_ma"] = 45
	gs.check_friendships()  # first sighting: recorded, silent
	assert_eq(ups.size(), 0)
	gs.npc_favor["hunter_ma"] = 62
	var bag_before: int = gs.player.inventory.size()
	gs.check_friendships()
	gs.check_friendships()
	EventBus.friend_tier_up.disconnect(cb)
	EventBus.friendship_reached.disconnect(cb2)
	assert_eq(ups.size(), 1)
	assert_eq(ups[0], ["hunter_ma", 2])
	assert_eq(banners.size(), 1)
	assert_true(String(banners[0][1]).begins_with("Hunter Ma: "))
	assert_eq(gs.player.inventory.size(), bag_before)
