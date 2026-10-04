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
