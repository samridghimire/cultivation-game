extends TestCase
## G-009b: sect reputation on the character sheet and tier prices at faction merchants.

const FACTION := "myriad_treasure_pavilion"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _buy_labels(merchant: Node) -> Array:
	return merchant.get_options().map(func(o: Dictionary) -> String: return o["label"]).filter(func(l: String) -> bool: return l.begins_with("Buy "))


func test_faction_merchant_labels_show_reputation_price() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Trader", gs.data, seeded_rng()))
	var merchant: Node = load("res://src/world/interactables/merchant.gd").new()
	merchant.faction = FACTION
	var labels := _buy_labels(merchant)
	assert_gt(labels.size(), 0)
	for label: String in labels:
		assert_false(label.contains(" price)"), "neutral standing has no note: %s" % label)
	Reputation.change(gs.player, gs.data, FACTION, 350)
	labels = _buy_labels(merchant)
	assert_true(String(labels[0]).ends_with("(Honored price)"), labels[0])
	merchant.faction = ""
	assert_false(String(_buy_labels(merchant)[0]).contains(" price)"), "unaffiliated merchants ignore reputation")
	merchant.free()
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
