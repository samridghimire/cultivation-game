extends TestCase
## FOLK-041: Close friends who live where you arrive may leave a gift once a month.


func _root() -> Node:
	return Engine.get_main_loop().root


func _always(gs: Node) -> void:
	gs.data.family["folk_visits"]["drop_by"]["chance"] = 1.0


func test_close_friend_gives_item_and_sets_flag() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 60
	var gift: Dictionary = Folk.drop_by_gift(gs.player, gs.npcs["hunter_ma"], gs.data, gs.world_flags, 100, 60)
	assert_false(gift.is_empty())
	assert_true(gs.data.items.has(gift["item"]))
	assert_true(String(gift["line"]) != "")
	assert_eq(int(gs.world_flags["drop_by_hunter_ma"]), 100)
	gs.end_session()


func test_friend_below_bar_cooldown_and_family() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	var ma: CharacterData = gs.npcs["hunter_ma"]
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 100, 40).is_empty(), "a Friend (40) does not")
	assert_false(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 100, 60).is_empty())
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 120, 60).is_empty(), "within 30 days")
	assert_false(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 130, 60).is_empty(), "cooldown over")
	gs.player.spouses.append("hunter_ma")
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 400, 90).is_empty(), "family excluded")
	gs.end_session()


func test_seeded_rng_reproducible() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	var ma: CharacterData = gs.npcs["hunter_ma"]
	var a: Dictionary = Folk.drop_by_gift(gs.player, ma, gs.data, {}, 100, 70)
	var b: Dictionary = Folk.drop_by_gift(gs.player, ma, gs.data, {}, 100, 70)
	assert_eq(a, b)
	gs.end_session()


func test_arrival_hook_leaves_rng_untouched() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 70
	var state: int = gs.rng.state
	gs.receive_drop_by_gifts()
	assert_eq(gs.rng.state, state, "no rng draws")
	gs.end_session()


func test_arrival_hook_gives_once() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 70
	var before: int = gs.player.inventory.size()
	var before_inv: Dictionary = gs.player.inventory.duplicate()
	gs.receive_drop_by_gifts()
	var flag: int = int(gs.world_flags.get("drop_by_hunter_ma", -1))
	assert_true(flag >= 0)
	# REVIEW: the log line names the gift.
	var got := ""
	for id: String in gs.player.inventory:
		if not before_inv.has(id) or int(gs.player.inventory[id]) > int(before_inv[id]):
			got = String(gs.data.items[id].get("name", id))
	assert_true(got != "", "a gift arrived")
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("(" + got)), "the line names the gift")
	var snapshot: Dictionary = gs.player.inventory.duplicate()
	gs.receive_drop_by_gifts()
	assert_eq(gs.player.inventory, snapshot, "no second gift within the cooldown")
	assert_true(gs.player.inventory.size() >= before)
	gs.end_session()


func test_item_token_and_yield_first() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	var lan: CharacterData = gs.npcs["herbalist_lan"]
	gs.data.npcs["herbalist_lan"]["activity"] = "hoe"
	var y := Folk.lend_yield(gs.data, "herbalist_lan")
	assert_false(y.is_empty(), "Lan has a work yield")
	gs.data.npcs["herbalist_lan"]["drop_by_lines"] = ["Lan leaves {item} for you."]
	var rng_state: int = gs.rng.state
	var gift: Dictionary = Folk.drop_by_gift(gs.player, lan, gs.data, gs.world_flags, 100, 60)
	assert_eq(String(gift["item"]), String(y["item"]), "the gift is their yield")
	assert_eq(String(gift["line"]), "Lan leaves %s for you." % gs.data.items[y["item"]]["name"])
	assert_eq(gs.rng.state, rng_state, "rng untouched")
	gs.end_session()


func test_like_fallback_without_yield() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	var ma: CharacterData = gs.npcs["hunter_ma"]
	gs.data.family["lend_a_hand"]["yields"].erase(String(gs.data.npcs["hunter_ma"]["activity"]))
	var gift: Dictionary = Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 100, 60)
	assert_false(gift.is_empty())
	assert_true((gs.data.npcs["hunter_ma"]["likes"] as Array).has(gift["item"]), "falls back to a like")
	gs.end_session()


func test_item_token_rejected_outside_drop_by() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	assert_true(Folk.validate_item_token(gs.data).is_empty())
	gs.data.npcs["hunter_ma"]["tend_lines"] = ["{item} here"]
	assert_false(Folk.validate_item_token(gs.data).is_empty())
	gs.end_session()
