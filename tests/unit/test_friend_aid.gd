extends TestCase
## FOLK-054: a friend at the gate asks for help.


func _root() -> Node:
	return Engine.get_main_loop().root


func _start() -> Node:
	var gs := _root().get_node("GameState")
	var p := new_character()
	gs.start_session(p)
	gs.current_region = "qingshi_village"
	return gs


## Puts `id` at the Foundation bottleneck (realm 1 -> 2).
func _gate(gs: Node, id: String, favor: int) -> CharacterData:
	var npc: CharacterData = gs.npcs[id]
	npc.realm_index = 1
	npc.stage = gs.data.realms[1].stage_count() - 1
	npc.qi = gs.data.realms[1].qi_required(npc.stage) + 1.0
	gs.npc_favor[id] = favor
	return npc


func test_friend_waits_and_asks_once_at_favor() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	var holds := FriendAid.hold_ids(gs.npcs, gs.data, gs.npc_favor, {}, 1000)
	assert_true(holds.has("xiao_ling"))
	var events := Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, holds)
	var asks := events.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "aid_ask" and e["npc_id"] == "xiao_ling")
	assert_eq(asks.size(), 1)
	assert_eq(npc.realm_index, 1, "still waiting at the gate")
	Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, holds)
	events = Npcs.simulate(gs.npcs, gs.data, 60, seeded_rng(), {}, {}, holds)
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "aid_ask" and e["npc_id"] == "xiao_ling").size(), 0, "no second ask")
	assert_eq(npc.aid_wait, 0, "the wait is over")
	gs.end_session()


func test_no_ask_below_favor_or_on_cooldown() -> void:
	var gs := _start()
	_gate(gs, "xiao_ling", 39)
	assert_false(FriendAid.hold_ids(gs.npcs, gs.data, gs.npc_favor, {}, 1000).has("xiao_ling"))
	gs.npc_favor["xiao_ling"] = 40
	assert_true(FriendAid.hold_ids(gs.npcs, gs.data, gs.npc_favor, {}, 1000).has("xiao_ling"))
	assert_false(FriendAid.hold_ids(gs.npcs, gs.data, gs.npc_favor, {"friend_aid_xiao_ling": 950}, 1000).has("xiao_ling"))
	assert_true(FriendAid.hold_ids(gs.npcs, gs.data, gs.npc_favor, {"friend_aid_xiao_ling": 900}, 1000).has("xiao_ling"))
	var plain := Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, {})
	assert_eq(plain.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "aid_ask").size(), 0)
	gs.end_session()


func test_give_consumes_boosts_once_and_expires() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	var item := FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, 1000)
	assert_true(["foundation_establishment_pill", "spirit_gathering_pill", "meridian_mending_pill"].has(item), "ask is one of the realm's aid items")
	assert_true(FriendAid.give_block(gs.player, gs.data, npc, 1000).begins_with("You have no"))
	gs.player.add_item(item, 1)
	assert_eq(FriendAid.give_block(gs.player, gs.data, npc, 1000), "")
	assert_true(FriendAid.give_block(gs.player, gs.data, npc, 1061) != "", "expired after 60 days")
	assert_eq(FriendAid.give(gs.player, gs.data, npc, 1030), 8)
	assert_eq(gs.player.item_count(item), 0)
	assert_eq(npc.aid_bonus, 0.15)
	assert_eq(FriendAid.give(gs.player, gs.data, npc, 1030), 0, "once")
	var before := Cultivation.breakthrough_chance(npc, gs.data)
	npc.breakthrough_bonus += npc.aid_bonus
	assert_true(Cultivation.breakthrough_chance(npc, gs.data) > before)
	gs.end_session()


func test_aid_bonus_is_spent_on_the_next_breakthrough() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	npc.aid_bonus = 0.15
	Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, {"xiao_ling": true})
	assert_eq(npc.aid_bonus, 0.0)
	gs.end_session()


func test_prune_drops_expired_and_passed_asks() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, 1000)
	FriendAid.prune(gs.player, gs.data, gs.npcs, 1050)
	assert_true(gs.player.friend_aid.has("xiao_ling"))
	assert_eq(FriendAid.journal_rows(gs.player, gs.data, gs.npcs, 1050).size(), 1)
	FriendAid.prune(gs.player, gs.data, gs.npcs, 1061)
	assert_true(gs.player.friend_aid.is_empty())
	FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, 1100)
	npc.realm_index = 2
	npc.stage = 0
	npc.qi = 0.0
	FriendAid.prune(gs.player, gs.data, gs.npcs, 1101)
	assert_true(gs.player.friend_aid.is_empty(), "no longer at the gate")
	gs.end_session()


func test_save_round_trip() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, 1000)
	npc.aid_bonus = 0.15
	npc.aid_wait = 30
	var p2 := CharacterData.from_dict(gs.player.to_dict())
	assert_eq(p2.friend_aid, gs.player.friend_aid)
	var n2 := CharacterData.from_dict(npc.to_dict())
	assert_eq(n2.aid_bonus, 0.15)
	assert_eq(n2.aid_wait, 30)
	assert_eq(CharacterData.from_dict({}).friend_aid.size(), 0, "old saves default")
	gs.end_session()


func test_give_action_integration() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	var item := FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, GameClock.total_days)
	assert_false(gs.can_give_aid("xiao_ling"), "no item yet")
	gs.player.add_item(item, 1)
	assert_true(gs.can_give_aid("xiao_ling"))
	gs.give_friend_aid("xiao_ling")
	assert_eq(gs.player.item_count(item), 0)
	assert_eq(int(gs.npc_favor["xiao_ling"]), 58)
	assert_eq(npc.aid_bonus, 0.15)
	assert_false(gs.can_give_aid("xiao_ling"))
	gs.end_session()


func test_data_validation_rejects_bad_block() -> void:
	var gd := GameData.load_from_dir()
	assert_true(gd.load_errors.is_empty(), "shipped data is valid")
	gd.load_errors.clear()
	gd.family["friend_aid"]["aid_items"]["2"] = ["no_such_item"]
	gd._validate_friend_aid()
	assert_false(gd.load_errors.is_empty())


## C-428: aid items cost 60+ stones at Foundation; each thanks item exists and costs 0.3x-0.7x of its realm's median aid item.
func test_thanks_items_fit_the_aid() -> void:
	var gd := GameData.load_from_dir()
	var fa: Dictionary = gd.family["friend_aid"]
	for realm: String in fa["aid_items"]:
		var prices: Array[int] = []
		for id: String in fa["aid_items"][realm]:
			prices.append(int(gd.items[id].price))
		prices.sort()
		var median := float(prices[prices.size() / 2])
		if realm == "2":
			assert_true(prices[0] >= 60, "Foundation aid items cost at least 60")
		assert_eq(fa["thanks_items"][realm].size(), 2, "two thanks items for realm " + realm)
		for id: String in fa["thanks_items"][realm]:
			assert_true(gd.items.has(id), id + " exists")
			var ratio := float(gd.items[id].price) / median
			assert_true(ratio >= 0.3 and ratio <= 0.7, "%s is %.2fx the median aid item" % [id, ratio])


## WU-637: the card shows once per ask, focus follows holding the item, "I have it" gives, "Later" keeps the ask.
func test_card_once_per_ask_and_buttons() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	var item := FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, gs.get_node("/root/GameClock").total_days)
	assert_true(FriendAid.card_pending(gs.player, gs.data, npc, gs.world_flags, gs.get_node("/root/GameClock").total_days))
	assert_true(FriendAidCard.focus_give(true))
	assert_false(FriendAidCard.focus_give(false))
	assert_true(FriendAid.card_line("Xiao Ling", "Pill", false).ends_with("You have none yet."))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: FriendAidCard = hud.get("_friend_aid_card")
	hud.get("_dialogue").visible = false  # review: the opening dialogue of a new session
	assert_false(hud.call("_is_blocking"))
	assert_true(gs.request_friend_aid_card("xiao_ling"))
	assert_true(card.visible)
	assert_true(hud.call("_is_blocking"), "review: the card is modal (the player cannot walk or open a menu under it)")
	assert_true(card.give_button().disabled, "none held")
	assert_false(gs.request_friend_aid_card("xiao_ling"), "once per ask")
	card.close()
	assert_false(hud.call("_is_blocking"))
	assert_true(gs.player.friend_aid.has("xiao_ling"), "Later keeps the ask")
	gs.player.add_item(item, 1)
	gs.world_flags.erase("friend_aid_card_xiao_ling")
	assert_true(gs.request_friend_aid_card("xiao_ling"))
	assert_false(card.give_button().disabled)
	card.give_button().pressed.emit()
	assert_false(card.visible)
	assert_eq(gs.player.item_count(item), 0, "given")
	assert_false(gs.player.friend_aid.has("xiao_ling"))
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


## FOLK-056: a friend's thanks gift.
func test_thanks_queue_picks_from_new_realm_pool() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	npc.realm_index = 2
	var gift := FriendAid.queue_thanks(gs.player, gs.data, npc, "meridian_mending_pill", seeded_rng(), 1000)
	assert_true(["superior_qi_gathering_pill", "clear_heart_pill"].has(gift))
	assert_eq(gs.player.friend_thanks.size(), 1)
	npc.realm_index = 1
	assert_eq(FriendAid.queue_thanks(gs.player, gs.data, npc, "x", seeded_rng(), 1000), "", "no pool for that realm")
	var p2 := CharacterData.from_dict(gs.player.to_dict())
	assert_eq(p2.friend_thanks, gs.player.friend_thanks, "save round-trip")
	assert_eq(CharacterData.from_dict({}).friend_thanks.size(), 0, "old saves default")
	gs.end_session()


func test_thanks_due_by_region_or_week() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	npc.realm_index = 2
	FriendAid.queue_thanks(gs.player, gs.data, npc, "x", seeded_rng(), 1000)
	var home := Npcs.region_of(npc, gs.data)
	assert_eq(FriendAid.thanks_due(gs.player, gs.data, gs.npcs, "nowhere", 1003).size(), 0)
	assert_eq(FriendAid.thanks_due(gs.player, gs.data, gs.npcs, home, 1003).size(), 1, "in their region")
	assert_eq(FriendAid.thanks_due(gs.player, gs.data, gs.npcs, "nowhere", 1007).size(), 1, "a week anywhere")
	gs.end_session()


func test_aided_success_sends_one_gift_failure_none() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	npc.aid_bonus = 0.15
	npc.breakthrough_bonus = 10.0
	var events := Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, {})
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "aid_thanks").size(), 1)
	var other := _gate(gs, "elder_mo", 50)
	other.breakthrough_bonus = 10.0
	events = Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(), {}, {}, {})
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "aid_thanks").size(), 0, "no aid, no thanks")
	gs.end_session()


func test_thanks_delivery_integration() -> void:
	var gs := _start()
	var npc := _gate(gs, "xiao_ling", 50)
	var item := FriendAid.open_ask(gs.player, gs.data, npc, gs.world_flags, GameClock.total_days)
	gs.player.add_item(item, 1)
	gs.give_friend_aid("xiao_ling")
	npc.breakthrough_bonus = 10.0
	var favor := int(gs.npc_favor["xiao_ling"])
	gs.current_region = "somewhere_else"
	gs._pass_time(30)
	assert_eq(npc.realm_index, 2, "broke through")
	assert_eq(gs.player.friend_thanks.size(), 1, "queued")
	gs._pass_time(8)
	assert_true(gs.player.friend_thanks.is_empty(), "delivered after a week away")
	assert_eq(int(gs.npc_favor["xiao_ling"]), favor + 3)
	var held := 0
	for gift: String in gs.data.family["friend_aid"]["thanks_items"]["2"]:
		held += gs.player.item_count(gift)
	assert_true(held >= 1, "the gift arrived")
	gs.end_session()


## WU-642: the thanks card opens on the signal, is modal, queues behind another moment, and closes with cancel/Continue.
func test_thanks_card_modal_and_queued() -> void:
	var gs := _start()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: FriendThanksCard = hud.get("_friend_thanks_card")
	hud.get("_dialogue").visible = false
	assert_eq(FriendThanksCard.line_for(gs.data, "no_such_npc"), FriendThanksCard.FALLBACK_LINE)
	assert_true(FriendThanksCard.line_for(gs.data, "xiao_ling") != FriendThanksCard.FALLBACK_LINE, "own line")
	assert_false(hud.call("_is_blocking"))
	gs.get_node("/root/EventBus").friend_thanks.emit("xiao_ling", "Xiao Ling", "spirit_herb")
	assert_true(card.visible)
	assert_true(hud.call("_is_blocking"))
	assert_true(card.item_text() != "")
	card.continue_button().pressed.emit()
	assert_false(card.visible)
	assert_false(hud.call("_is_blocking"))
	# queued while another moment is up
	hud.get("_friend_aid_card").open("xiao_ling", "Xiao Ling", "Pill", false)
	gs.get_node("/root/EventBus").friend_thanks.emit("xiao_ling", "Xiao Ling", "spirit_herb")
	assert_false(card.visible, "waits")
	assert_eq(hud.get("_pending_moments").size(), 1)
	hud.get("_friend_aid_card").close()
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(card.visible, "plays after")
	card.close()
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


## WU-643: a letter opens the LetterCard (modal, with its text), a request letter shows the item line, and it queues.
func test_letter_card() -> void:
	var gs := _start()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: LetterCard = hud.get("_letter_card")
	hud.get("_dialogue").visible = false
	var bus: Node = gs.get_node("/root/EventBus")
	assert_false(hud.call("_is_blocking"))
	bus.letter_arrived.emit("Xiao Ling", "Come see me.", "xiao_ling")
	assert_true(card.visible)
	assert_true(hud.call("_is_blocking"))
	assert_eq(card.text_value(), "Come see me.")
	assert_eq(card.ask_text(), "", "no request, no item line")
	card.later_button().pressed.emit()
	assert_false(card.visible)
	assert_false(hud.call("_is_blocking"))
	gs.player.letter_requests.append({"npc_id": "xiao_ling", "item": "spirit_herb", "count": 2, "until": GameClock.total_days + 5, "favor": 1, "effects": {}})
	bus.letter_arrived.emit("Xiao Ling", "I need herbs.", "xiao_ling")
	assert_true(card.ask_text().contains("5 days"), card.ask_text())
	# queued behind another moment
	card.close()
	hud.get("_friend_aid_card").open("xiao_ling", "Xiao Ling", "Pill", false)
	bus.letter_arrived.emit("Xiao Ling", "Later.", "xiao_ling")
	assert_false(card.visible, "waits")
	hud.get("_friend_aid_card").close()
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(card.visible, "plays after")
	card.close()
	assert_eq(LetterCard.ask_line("Herb", 1, 1), "Hopes for Herb within 1 day.")
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


## WU-646: with letters_quiet on, a letter only banners; no card opens.
func test_letter_quiet_setting_skips_card() -> void:
	var gs := _start()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: LetterCard = hud.get("_letter_card")
	hud.get("_dialogue").visible = false
	var bus: Node = gs.get_node("/root/EventBus")
	var was: Variant = Settings.get_value("letters_quiet")
	Settings.set_value("letters_quiet", true)
	bus.letter_arrived.emit("Xiao Ling", "Come see me.", "xiao_ling")
	assert_false(card.visible, "quiet: no card")
	assert_false(hud.call("_is_blocking"))
	Settings.set_value("letters_quiet", false)
	bus.letter_arrived.emit("Xiao Ling", "Come see me.", "xiao_ling")
	assert_true(card.visible, "default: card")
	card.close()
	Settings.set_value("letters_quiet", was)
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


## REVIEW: the slide-in ends where the CenterContainer puts the card (it once parked at y=0 on the first open).
func test_letter_card_slides_to_center() -> void:
	var gs := _start()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: LetterCard = hud.get("_letter_card")
	assert_true(LetterCard.slides(), "default settings slide")
	card.open("xiao_ling", "Xiao Ling", "Come see me when the sect lets you go; the pond is high and the herbs are in.")
	await (Engine.get_main_loop() as SceneTree).create_timer(LetterCard.SLIDE_SECONDS + 0.3).timeout
	var parent := card.get_parent() as Control
	var want := (parent.size.y - card.size.y) / 2.0
	assert_true(absf(card.position.y - want) <= 1.0, "card at y=%s, centered is %s" % [card.position.y, want])
	card.close()
	_root().remove_child(hud)
	hud.free()
	gs.end_session()


func test_dead_friend_thanks_pruned_at_month_end() -> void:
	var gs := _start()
	gs.player.friend_thanks["xiao_ling"] = {"gift": "spirit_herb", "aid_item": "qi_gathering_pill", "day": GameClock.total_days}
	gs.npcs["xiao_ling"].alive = false
	gs._deliver_friend_thanks()
	assert_true(gs.player.friend_thanks.is_empty(), "dead friend's thanks pruned")
