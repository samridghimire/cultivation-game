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
	var gift: Dictionary = Folk.drop_by_gift(gs.player, gs.npcs["hunter_ma"], gs.data, gs.world_flags, 100, seeded_rng(1), 60)
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
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 100, seeded_rng(1), 40).is_empty(), "a Friend (40) does not")
	assert_false(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 100, seeded_rng(1), 60).is_empty())
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 120, seeded_rng(1), 60).is_empty(), "within 30 days")
	assert_false(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 130, seeded_rng(1), 60).is_empty(), "cooldown over")
	gs.player.spouses.append("hunter_ma")
	assert_true(Folk.drop_by_gift(gs.player, ma, gs.data, gs.world_flags, 400, seeded_rng(1), 90).is_empty(), "family excluded")
	gs.end_session()


func test_seeded_rng_reproducible() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	var ma: CharacterData = gs.npcs["hunter_ma"]
	var a: Dictionary = Folk.drop_by_gift(gs.player, ma, gs.data, {}, 100, seeded_rng(5), 70)
	var b: Dictionary = Folk.drop_by_gift(gs.player, ma, gs.data, {}, 100, seeded_rng(5), 70)
	assert_eq(a, b)
	gs.end_session()


func test_arrival_hook_gives_once() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	_always(gs)
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 70
	var before: int = gs.player.inventory.size()
	gs.receive_drop_by_gifts()
	var flag: int = int(gs.world_flags.get("drop_by_hunter_ma", -1))
	assert_true(flag >= 0)
	var snapshot: Dictionary = gs.player.inventory.duplicate()
	gs.receive_drop_by_gifts()
	assert_eq(gs.player.inventory, snapshot, "no second gift within the cooldown")
	assert_true(gs.player.inventory.size() >= before)
	gs.end_session()
