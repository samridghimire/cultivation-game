extends TestCase
## FOLK-052: meditate beside a friend.


func _root() -> Node:
	return Engine.get_main_loop().root


func _start() -> Node:
	var gs := _root().get_node("GameState")
	var p := new_character()
	p.spiritual_roots = {"fire": 80}
	p.realm_index = 1
	gs.start_session(p)
	gs.current_region = "qingshi_village"
	return gs


func _friend(gs: Node, id: String, realm: int, favor: int) -> CharacterData:
	var npc: CharacterData = gs.npcs[id]
	npc.realm_index = realm
	gs.npc_favor[id] = favor
	return npc


func test_eligibility_reasons() -> void:
	var gs := _start()
	var npc := _friend(gs, "xiao_ling", 0, 60)
	var region := "qingshi_village"
	assert_eq(Folk.meditation_block(gs.player, gs.data, npc, 60, {}, region, 100), "Xiao Ling does not cultivate yet.".replace("Xiao Ling", npc.name))
	npc.realm_index = 1
	assert_eq(Folk.meditation_block(gs.player, gs.data, npc, 31, {}, region, 100), "%s needs to know you better (favor 31/40)." % npc.name)
	assert_eq(Folk.meditation_block(gs.player, gs.data, npc, 60, {}, "azure_peak", 100), "%s is not here." % npc.name)
	assert_eq(Folk.meditation_block(gs.player, gs.data, npc, 60, {}, region, 100), "")
	gs.player.spouses.append("xiao_ling")
	assert_true(Folk.meditation_block(gs.player, gs.data, npc, 60, {}, region, 100) != "", "spouses have dual cultivation")
	gs.player.spouses.erase("xiao_ling")
	var flags := {"friend_med_xiao_ling": 100}
	assert_true(Folk.meditation_block(gs.player, gs.data, npc, 60, flags, region, 105).contains("again in 9 days"))
	assert_eq(Folk.meditation_block(gs.player, gs.data, npc, 60, flags, region, 114), "")
	gs.end_session()


func test_friends_sorted_by_favor_then_id() -> void:
	var gs := _start()
	for id: String in gs.data.npcs:
		gs.npc_favor[id] = 0
	_friend(gs, "xiao_ling", 1, 50)
	_friend(gs, "hunter_ma", 1, 70)
	_friend(gs, "elder_mo", 1, 50)
	var ids := Folk.meditation_friends(gs.player, gs.data, gs.npcs, gs.npc_favor, {}, "qingshi_village", 100)
	assert_eq(ids.slice(0, 3), ["hunter_ma", "elder_mo", "xiao_ling"])
	gs.end_session()


func test_meditate_with_friend_gives_more_qi_favor_and_cooldown() -> void:
	var gs := _start()
	var clock := _root().get_node("GameClock")
	_friend(gs, "xiao_ling", 1, 50)
	var before: float = gs.player.qi
	gs.cultivate(7, 1.0)
	var plain: float = gs.player.qi - before
	gs.end_session()
	gs = _start()
	_friend(gs, "xiao_ling", 1, 50)
	before = gs.player.qi
	var day: int = clock.total_days
	gs.meditate_with_friend("xiao_ling", 1.0)
	assert_gt(gs.player.qi - before, plain, "qi x 1.1")
	assert_eq(gs.npc_favor["xiao_ling"], 52)
	assert_eq(gs.world_flags["friend_med_xiao_ling"], day)
	var after_day: int = clock.total_days
	gs.meditate_with_friend("xiao_ling", 1.0)
	assert_eq(clock.total_days, after_day, "inside the cooldown nothing happens")
	assert_eq(gs.npc_favor["xiao_ling"], 52)
	gs.end_session()


func test_missing_friend_meditation_block_fails_validation() -> void:
	var d := GameData.load_from_dir()
	d.load_errors.clear()
	d.family.erase("friend_meditation")
	d._validate()
	assert_true("\n".join(d.load_errors).contains("friend_meditation"))
	d.load_errors.clear()
	d.family["friend_meditation"] = {"min_favor": 40, "days": 0, "qi_mult": 1.1, "favor": 2, "cooldown_days": 14}
	d._validate()
	assert_true("\n".join(d.load_errors).contains("friend_meditation.days"))


## [REVIEW]: at a bottleneck cultivate() refuses, so no favor or cooldown may be spent either.
func test_no_free_favor_at_a_bottleneck() -> void:
	var gs := _start()
	var clock := _root().get_node("GameClock")
	_friend(gs, "xiao_ling", 1, 50)
	gs.player.stage = (gs.data.realms[gs.player.realm_index] as RealmDef).stage_count() - 1
	gs.player.qi = 1.0e12
	assert_true(Cultivation.is_at_bottleneck(gs.player, gs.data))
	assert_true(Folk.meditation_block(gs.player, gs.data, gs.npcs["xiao_ling"], 50, {}, "qingshi_village", clock.total_days) != "")
	var day: int = clock.total_days
	gs.meditate_with_friend("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), 50, "no favor")
	assert_false(gs.world_flags.has("friend_med_xiao_ling"), "no cooldown")
	assert_eq(clock.total_days, day)
	gs.end_session()


## WU-635: the staged card comes before the time skip; closing it runs the meditation.
func test_staged_card_then_meditation() -> void:
	var gs := _start()
	var clock := _root().get_node("GameClock")
	_friend(gs, "xiao_ling", 1, 50)
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: FriendMeditationCard = hud.get("_friend_med_card")
	hud.get("_dialogue").visible = false  # review: the opening dialogue of a new session
	var day: int = clock.total_days
	gs.request_friend_meditation("xiao_ling", 1.0)
	assert_true(card.visible, "card shown first")
	assert_true(hud.call("_is_blocking"), "review: the card is modal")
	assert_eq(clock.total_days, day, "no time passes yet")
	assert_eq(card.line_text(), "You and Xiao Ling sit together in quiet cultivation.")
	card.close()
	assert_false(card.visible)
	assert_false(hud.call("_is_blocking"))
	assert_gt(clock.total_days, day, "the meditation ran on close")
	assert_eq(gs.npc_favor["xiao_ling"], 52)
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


func test_request_without_hud_meditates_at_once() -> void:
	var gs := _start()
	var clock := _root().get_node("GameClock")
	_friend(gs, "xiao_ling", 1, 50)
	var day: int = clock.total_days
	gs.request_friend_meditation("xiao_ling", 1.0)
	assert_gt(clock.total_days, day)
	gs.end_session()


func test_motes_still_when_reduced() -> void:
	assert_false(FriendMeditationCard.motes_move(true))
	assert_true(FriendMeditationCard.motes_move(false))
	for i in FriendMeditationCard.MOTES:
		var p := FriendMeditationCard.mote_pos(i, 3.0)
		assert_true(p.x >= FriendMeditationCard.SEAT_L and p.x <= FriendMeditationCard.SEAT_R)
