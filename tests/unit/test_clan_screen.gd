extends TestCase
## FAM-005b: the clan screen (found a clan, deposit, ranks, recruit).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _founder() -> CharacterData:
	var c := new_character()
	c.gender = "male"
	c.surname = "Lin"
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.inventory = {"spirit_stone": 1000}
	c.abode = "waterfall_cave"  # a clan needs a seat (FAM-005c)
	return c


func _buttons(screen: Control) -> Array:
	return screen.find_children("*", "Button", true, false)


func _button(screen: Control, text_prefix: String) -> Button:
	for b: Button in _buttons(screen):
		if b.text.begins_with(text_prefix):
			return b
	return null


func test_founding_text_names_realm_cost_and_time() -> void:
	var text := ClanScreen.founding_text(data())
	var r := Clans.rules(data())
	assert_true(text.contains(data().realms[data().realm_index_of(String(r["min_realm"]))].name), text)
	assert_true(text.contains("%d spirit stones" % int(r["found_cost"])), text)


func test_found_button_disabled_with_reason_then_founds() -> void:
	var gs := _root().get_node("GameState")
	var weak := _founder()
	weak.realm_index = 1
	gs.start_session(weak)
	var screen := ClanScreen.new()
	screen._rebuild()
	assert_true(screen._found_button.disabled)
	assert_true(screen._found_status.text.contains("realm"), screen._found_status.text)
	gs.start_session(_founder())
	screen._rebuild()
	assert_false(screen._found_button.disabled)
	assert_eq(screen._found_button.text, "Found the Lin Clan")
	screen._found()
	assert_true(gs.clan != null, "clan founded")
	screen._rebuild()
	assert_false(screen._found_box.visible)
	assert_eq(screen._title.text, "Lin Clan")
	assert_eq(screen._selected, "m:" + gs.player.id, "the head is listed first")
	screen.free()


func test_deposit_moves_stones_into_treasury() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	gs.found_clan()
	var carried: int = gs.player.item_count("spirit_stone")
	var screen := ClanScreen.new()
	screen._rebuild()
	screen._deposit(100)
	assert_eq(gs.clan.treasury, 100)
	assert_eq(gs.player.item_count("spirit_stone"), carried - 100)
	screen.free()


func test_members_sorted_by_rank_and_rank_change() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	gs.found_clan()
	var wife := new_character(7)
	wife.id = "gen_test_wife"
	wife.name = "Su Mei"
	wife.gender = "female"
	wife.age_days = 20 * Calendar.DAYS_PER_YEAR
	wife.realm_index = data().realm_index_of("foundation_establishment")
	gs.npcs[wife.id] = wife
	gs.clan.members[wife.id] = "core"
	var people: Dictionary = gs.npcs.duplicate()
	people[gs.player.id] = gs.player
	var order := ClanScreen.sorted_members(gs.clan, people, data())
	assert_eq(order, [gs.player.id, wife.id] as Array[String])
	var screen := ClanScreen.new()
	screen._rebuild()
	screen._select("m:" + wife.id)
	var make_elder := _button(screen, "Make Elder")
	assert_true(make_elder != null, "rank buttons for a member")
	assert_false(make_elder.disabled)
	make_elder.pressed.emit()
	assert_eq(String(gs.clan.members[wife.id]), "elder")
	screen.free()


func test_recruit_candidates_show_reason_and_recruit() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	gs.found_clan()
	var screen := ClanScreen.new()
	var candidates := ClanScreen.recruit_candidates(gs.clan, gs.npcs, data(), gs.current_region)
	var adult: CharacterData = null
	for c: CharacterData in candidates:
		assert_false(gs.clan.members.has(c.id))
		if adult == null and c.age_years() >= int(data().family.get("adult_age", 16)):
			adult = c
	assert_true(adult != null, "someone to recruit in the start region")
	gs.npc_favor[adult.id] = 0
	screen._rebuild()
	screen._select("r:" + adult.id)
	var recruit := _button(screen, "Recruit")
	assert_true(recruit.disabled)
	assert_true(screen._status.text.contains("trust"), screen._status.text)
	gs.npc_favor[adult.id] = 100
	screen._rebuild()
	screen._select("m:" + gs.player.id)
	screen._select("r:" + adult.id)
	recruit = _button(screen, "Recruit")
	assert_false(recruit.disabled)
	recruit.pressed.emit()
	assert_true(gs.clan.members.has(adult.id), "recruited")
	screen.free()


func test_hud_registers_clan_screen_on_its_action() -> void:
	assert_true(InputMap.has_action("toggle_clan"))
	var hud: Node = load("res://src/ui/hud.tscn").instantiate()
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	_root().add_child(hud)
	assert_true(hud._screens.get("toggle_clan") is ClanScreen)
	hud.free()


## FAM-008b: the heir is named in the summary and marked in the list, and a
## descendant member can be named heir.
func test_heir_shown_and_designated() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	gs.found_clan()
	var kids: Array = []
	for i in 2:
		var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(30 + i), {"age_years": 18 - i * 4, "region": gs.current_region, "gender": "male"})
		kid.parents = [gs.player.id] as Array[String]
		gs.player.children.append(kid.id)
		gs.clan.members[kid.id] = "core"
		kids.append(kid)
	var screen := ClanScreen.new()
	screen.open()
	var eldest: CharacterData = kids[0]
	var younger: CharacterData = kids[1]
	assert_true(screen._summary.text.contains("%s: %s" % [Clans.heir_title(gs.data), eldest.name]), screen._summary.text)
	assert_true((screen._list.get_node("m_" + eldest.id) as Button).text.contains("(%s)" % Clans.heir_title(gs.data, "male")))
	screen._select("m:" + younger.id)
	var name_heir := _button(screen, "Name as")
	assert_true(name_heir != null and not name_heir.disabled, "a descendant can be named heir")
	name_heir.pressed.emit()
	assert_eq(gs.clan.heir, younger.id)
	assert_true(screen._summary.text.contains(younger.name), screen._summary.text)
	screen._select("m:" + younger.id)
	assert_true(_button(screen, "Name as").disabled, "already the heir")
	screen.free()
	gs.end_session()


## FAM-006b: the Estate section lists buildings and starts construction.
func test_estate_section_builds() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(_founder())
	gs.found_clan()
	var screen := ClanScreen.new()
	screen.open()
	var building_id: String = ClanEstate.building_ids(gs.data)[0]
	var row := screen._list.get_node("b_" + building_id) as Button
	assert_true(row != null and row.text.contains("(not built)"), row.text if row != null else "no row")
	screen._select("b:" + building_id)
	assert_true(screen._info.text.contains("Costs "), screen._info.text)
	var build := _button(screen, "Build")
	assert_true(build != null and build.disabled, "the treasury is empty")
	gs.clan.treasury = 100000
	screen._rebuild()
	screen._select("b:" + building_id)
	build = _button(screen, "Build")
	assert_false(build.disabled, screen._status.text)
	build.pressed.emit()
	assert_eq(String(gs.clan.construction.get("building", "")), building_id)
	assert_true(screen._summary.text.contains("Builders: "), screen._summary.text)
	assert_true((screen._list.get_node("b_" + building_id) as Button).text.contains("[building]"))
	screen.free()
	gs.end_session()
