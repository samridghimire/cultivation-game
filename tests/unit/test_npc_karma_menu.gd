extends TestCase
## RIV-001d: hostile acts (behind "Turn hostile...") and Make amends in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _start(gs: Node) -> CharacterData:
	var c := CharacterFactory.create("Bully", gs.data, seeded_rng())
	gs.start_session(c)
	return c


func _npc_menu(npc_id: String) -> Node:
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = npc_id
	return npc


func _find(options: Array[Dictionary], prefix: String) -> Dictionary:
	for o in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func _adult(gs: Node) -> CharacterData:
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(11), {"gender": "male", "region": gs.current_region})
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	return npc


func test_hostile_entries_hide_behind_toggle() -> void:
	var gs: Node = _root().get_node("GameState")
	var p := _start(gs)
	var npc := _adult(gs)
	npc.realm_index = 0
	p.realm_index = 1
	var menu := _npc_menu(npc.id)
	var options: Array[Dictionary] = menu.get_options()
	assert_true(_find(options, "Kill").is_empty(), "no kill entry on the first page")
	var toggle := _find(options, "Turn hostile")
	assert_false(toggle.is_empty(), "turn hostile offered for adults")
	assert_true(toggle["keep_open"], "toggle keeps the menu open")
	(toggle["action"] as Callable).call()
	options = menu.get_options()
	for act_id in Karma.act_ids(gs.data):
		var name := String(Karma.act(gs.data, act_id)["name"])
		assert_false(_find(options, name + " " + npc.name).is_empty(), "%s entry: %s" % [name, str(options)])
	var rob := _find(options, "Rob ")
	assert_true(String(rob["label"]).contains("fight: "), "fights show danger: %s" % rob["label"])
	assert_true(String(rob["label"]).contains("alignment -"), "alignment cost shown: %s" % rob["label"])
	var back := _find(options, "Back")
	(back["action"] as Callable).call()
	assert_false(_find(menu.get_options(), "Turn hostile").is_empty(), "back returns to the normal menu")
	menu.free()
	gs.end_session()


func test_humiliate_disabled_against_equal_and_works_against_weaker() -> void:
	var gs: Node = _root().get_node("GameState")
	var p := _start(gs)
	var npc := _adult(gs)
	npc.realm_index = p.realm_index
	var menu := _npc_menu(npc.id)
	(_find(menu.get_options(), "Turn hostile")["action"] as Callable).call()
	var humiliate := _find(menu.get_options(), "Humiliate")
	assert_true(humiliate["disabled"], "not weaker: %s" % humiliate["label"])
	assert_true(String(humiliate["reason"]).contains("not weaker"), humiliate["reason"])
	p.realm_index = npc.realm_index + 1
	humiliate = _find(menu.get_options(), "Humiliate")
	assert_false(humiliate["disabled"], humiliate["label"])
	(humiliate["action"] as Callable).call()
	assert_gt(Karma.grudge(p, npc.id), 0, "humiliation earns a grudge")
	assert_false(_find(menu.get_options(), "Turn hostile").is_empty(), "acting leaves hostile mode")
	menu.free()
	gs.end_session()


func test_make_amends_entry_follows_grudge_and_stones() -> void:
	var gs: Node = _root().get_node("GameState")
	var p := _start(gs)
	var npc := _adult(gs)
	var menu := _npc_menu(npc.id)
	assert_true(_find(menu.get_options(), "Make amends").is_empty(), "no grudge, no amends")
	Karma.add_grudge(p, gs.data, npc.id, 30)
	p.add_item("spirit_stone", -p.item_count("spirit_stone"))
	var amends := _find(menu.get_options(), "Make amends")
	assert_true(amends["disabled"], "too poor: %s" % amends["label"])
	p.add_item("spirit_stone", Karma.amends_cost(p, npc.id, gs.data))
	amends = _find(menu.get_options(), "Make amends")
	assert_false(amends["disabled"], amends["label"])
	(amends["action"] as Callable).call()
	assert_eq(Karma.grudge(p, npc.id), 0, "grudge settled")
	assert_true(_find(menu.get_options(), "Make amends").is_empty(), "entry gone after amends")
	menu.free()
	gs.end_session()


func test_children_and_family_get_no_hostile_entry() -> void:
	var gs: Node = _root().get_node("GameState")
	var p := _start(gs)
	var npc := _adult(gs)
	npc.age_days = 5 * Calendar.DAYS_PER_YEAR
	var menu := _npc_menu(npc.id)
	assert_true(_find(menu.get_options(), "Turn hostile").is_empty(), "children are off limits")
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	p.parents.append(npc.id)
	assert_true(_find(menu.get_options(), "Turn hostile").is_empty(), "family is off limits")
	menu.free()
	gs.end_session()
