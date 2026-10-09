extends TestCase
## FAM-002i: Chat and Give a gift entries in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _start(gs: Node) -> CharacterData:
	var c := CharacterFactory.create("Friend", gs.data, seeded_rng())
	c.gender = "male"
	gs.start_session(c)
	return c


func _npc_menu(npc_id: String) -> Node:
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = npc_id
	return npc


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func test_chat_raises_favor_with_generated_npc() -> void:
	var gs: Node = _root().get_node("GameState")
	_start(gs)
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"gender": "female", "region": gs.current_region})
	npc.age_days = 20 * Calendar.DAYS_PER_YEAR
	var menu := _npc_menu(npc.id)
	var chat := _find(menu.get_options(), "Chat with ")
	assert_false(chat.is_empty(), "generated NPCs can be chatted with")
	assert_false(chat["disabled"], chat["label"])
	(chat["action"] as Callable).call()
	assert_gt(int(gs.npc_favor.get(npc.id, 0)), 0, "chatting raises favor")
	gs.npc_favor[npc.id] = int(gs.data.family["acquaintance"]["chat_max_favor"])
	chat = _find(menu.get_options(), "Chat with ")
	assert_true(chat["disabled"], "small talk tops out")
	assert_true(String(chat["label"]).contains("("), "disabled chat shows the reason")
	menu.free()
	gs.end_session()


func test_named_npc_with_dialogue_has_no_chat_but_takes_gifts() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := _start(gs)
	var menu := _npc_menu("xiao_ling")
	assert_true(_find(menu.get_options(), "Chat with ").is_empty(), "dialogue NPCs are talked to instead")
	c.inventory.clear()
	assert_true(_find(menu.get_options(), "Give ")["disabled"], "nothing to give")
	c.add_item("golden_bell_talisman", 2)
	var give := _find(menu.get_options(), "Give ")
	assert_false(give["disabled"], give["label"])
	(give["action"] as Callable).call()
	var picker: Array = menu.get_options()
	assert_eq(picker.size(), 2, "one item + Back: %s" % str(picker))
	var value := Family.gift_value(gs.data, "golden_bell_talisman")
	assert_true(String(picker[0]["label"]).contains("+%d favor" % value), picker[0]["label"])
	(picker[0]["action"] as Callable).call()
	assert_eq(int(gs.npc_favor.get("xiao_ling", 0)), value, "gift favor")
	assert_eq(c.item_count("golden_bell_talisman"), 1, "gift removed from inventory")
	assert_false(_find(menu.get_options(), "Golden Bell").is_empty(), "picker stays open for another gift")
	menu.on_menu_closed()
	assert_false(_find(menu.get_options(), "Give ").is_empty(), "closing the menu leaves the picker")
	(_find(menu.get_options(), "Give ")["action"] as Callable).call()
	(_find(menu.get_options(), "Back")["action"] as Callable).call()
	assert_false(_find(menu.get_options(), "Give ").is_empty(), "Back returns to the main entries")
	menu.free()
	gs.end_session()


## WU-089: learned tastes label, color and sort the gift picker.
func test_gift_picker_shows_learned_tastes() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := _start(gs)
	var menu := _npc_menu("xiao_ling")
	c.inventory.clear()
	c.add_item("golden_bell_talisman", 1)
	c.add_item("qi_gathering_pill", 1)
	c.add_item("bone_setting_salve", 1)
	gs.world_flags["taste_xiao_ling_bone_setting_salve"] = -1
	gs.world_flags["taste_xiao_ling_qi_gathering_pill"] = 1
	(_find(menu.get_options(), "Give ")["action"] as Callable).call()
	var picker: Array = menu.get_options()
	assert_true(String(picker[0]["label"]).contains("(liked)"), picker[0]["label"])
	assert_eq(picker[0]["color"], UIStyle.ACCENT)
	assert_true(String(picker[0]["description"]).contains("favor"), "favor line")
	assert_false(picker[1].has("color"), "unknown taste shows nothing")
	assert_false(String(picker[1]["label"]).contains("liked"), picker[1]["label"])
	assert_true(String(picker[2]["label"]).contains("(disliked)"), picker[2]["label"])
	assert_eq(picker[2]["color"], UIStyle.CATEGORY_COLORS["danger"])
	assert_true(String(picker[2]["label"]).contains("-3 favor"), picker[2]["label"])
	menu.free()
	gs.end_session()


## WU-108: a taste told in chat hints the first like in the gift picker.
func test_gift_picker_shows_told_hint() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := _start(gs)
	var menu := _npc_menu("xiao_ling")
	c.inventory.clear()
	c.add_item("golden_bell_talisman", 1)
	c.add_item("moon_cake", 1)
	(_find(menu.get_options(), "Give ")["action"] as Callable).call()
	for opt: Dictionary in menu.get_options():
		assert_false(String(opt["label"]).contains("fond of"), "no hint before being told")
	gs.world_flags["taste_told_xiao_ling"] = true
	var picker: Array = menu.get_options()
	assert_true(String(picker[0]["label"]).contains("Moon Cake") and String(picker[0]["label"]).contains("(they are fond of these)"), picker[0]["label"])
	assert_eq(picker[0]["color"], UIStyle.HINT)
	assert_false(String(picker[1]["label"]).contains("fond of"), picker[1]["label"])
	gs.world_flags["taste_xiao_ling_moon_cake"] = -1
	picker = menu.get_options()
	for opt: Dictionary in picker:
		assert_false(String(opt["label"]).contains("fond of"), "a learned dislike beats the hint")
	menu.free()
	gs.end_session()


func test_matches_first_like() -> void:
	var d: GameData = data()
	assert_true(Family.matches_first_like(d, "xiao_ling", "moon_cake"), "item id")
	assert_false(Family.matches_first_like(d, "xiao_ling", "paper_lantern"), "second like only")
	var herb_id := ""
	for id: String in d.items:
		if (d.items[id].get("tags", []) as Array).has("herb"):
			herb_id = id
			break
	assert_true(Family.matches_first_like(d, "herbalist_lan", herb_id), "tag like")
	assert_false(Family.matches_first_like(d, "herbalist_lan", "moon_cake"))
	assert_false(Family.matches_first_like(d, "nobody", "moon_cake"))
