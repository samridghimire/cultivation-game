extends TestCase
## G-009b: sect reputation on the character sheet and tier prices at faction merchants.

const FACTION := "myriad_treasure_pavilion"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_faction_shop_shows_reputation_price() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Trader", gs.data, seeded_rng()))
	var screen := ShopScreen.new()
	_root().add_child(screen)
	screen.open("Pavilion", 0, [], FACTION)
	assert_false(screen._title.text.contains(" price)"), "neutral standing has no note: %s" % screen._title.text)
	var item_id: String = screen.item_ids()[-1]  # priciest, so the discount survives rounding
	var list_price := ShopScreen.unit_price(gs.player, gs.data, item_id, false, FACTION)
	assert_eq(list_price, int(gs.data.items[item_id]["price"]))
	Reputation.change(gs.player, gs.data, FACTION, 350)
	screen.open("Pavilion", 0, [], FACTION)
	assert_true(screen._title.text.ends_with("(Honored price)"), screen._title.text)
	assert_true(ShopScreen.unit_price(gs.player, gs.data, item_id, false, FACTION) < list_price, "honored customers pay less")
	screen.open("Pavilion", 0, [], "")
	assert_false(screen._title.text.contains(" price)"), "unaffiliated merchants ignore reputation")
	screen.free()
	gs.end_session()


func test_character_sheet_lists_sect_reputation() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Known", gs.data, seeded_rng()))
	Reputation.change(gs.player, gs.data, FACTION, 350)
	var sheet := CharacterSheet.new()
	sheet._rebuild()
	var text := String(sheet._text.text)
	assert_true(text.contains("Sect Reputation"), text)
	for line in Reputation.describe(gs.player, gs.data):
		assert_true(text.contains(line), line)
	sheet.free()
	gs.end_session()


func test_character_sheet_shows_rival() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Foe", gs.data, seeded_rng()))
	var sheet := CharacterSheet.new()
	sheet._rebuild()
	var rival: CharacterData = gs.npcs[gs.player.rival]
	assert_true(String(sheet._text.text).contains("Rival[/color]"))
	assert_eq(CharacterSheet.rival_line(CharacterData.new(), gs.data, gs.npcs, {}), "", "no rival, no line")
	rival.realm_index = gs.player.realm_index + 1
	gs.player.grudges[rival.id] = 3
	sheet._rebuild()
	var text := String(sheet._text.text)
	assert_true(text.contains(rival.name), text)
	assert_true(text.contains("ahead of you"), text)
	assert_true(text.contains("grudge 3"), text)
	rival.realm_index = gs.player.realm_index
	assert_true(CharacterSheet.rival_line(gs.player, gs.data, gs.npcs, {}).contains("your equal"))
	rival.alive = false
	assert_eq(CharacterSheet.rival_line(gs.player, gs.data, gs.npcs, {}), "%s has died." % rival.name)
	sheet.free()
	gs.end_session()


## WU-105: the highest-favor living non-family NPCs, in order.
func test_people_lines_rank_by_favor_and_skip_family_and_dead() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Foe", gs.data, seeded_rng()))
	var ids: Array = gs.npcs.keys().slice(0, 4)
	var favor := {ids[0]: 5, ids[1]: 50, ids[2]: 90, ids[3]: 0}
	gs.player.spouses.append(ids[2])
	var lines := CharacterSheet.people_lines(gs.player, gs.data, gs.npcs, favor)
	assert_eq(lines.size(), 2, "family and strangers left out")
	assert_true(lines[0].begins_with(gs.npcs[ids[1]].name), lines[0])
	assert_true(lines[1].begins_with(gs.npcs[ids[0]].name), lines[1])
	assert_true(lines[1].ends_with("acquainted"), lines[1])
	gs.npcs[ids[1]].alive = false
	assert_eq(CharacterSheet.people_lines(gs.player, gs.data, gs.npcs, favor).size(), 1, "dead left out")
	assert_eq(CharacterSheet.people_lines(gs.player, gs.data, gs.npcs, favor, 0).size(), 0)
	gs.end_session()


## WU-106: "(likes N known)" on the People list.
func test_people_lines_known_likes() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Foe", gs.data, seeded_rng()))
	var id: String = gs.npcs.keys()[0]
	var items: Array = gs.data.items.keys()
	items.sort()
	var favor := {id: 50}
	var flags := {"taste_%s_%s" % [id, items[0]]: 1, "taste_%s_%s" % [id, items[1]]: 1}
	assert_true(CharacterSheet.people_lines(gs.player, gs.data, gs.npcs, favor, 6, flags)[0].ends_with("(likes 2 known)"))
	flags = {"taste_%s_%s" % [id, items[0]]: -1}
	assert_false(CharacterSheet.people_lines(gs.player, gs.data, gs.npcs, favor, 6, flags)[0].contains("likes"))
	gs.end_session()
