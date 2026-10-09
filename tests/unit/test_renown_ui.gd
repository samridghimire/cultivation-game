## WU-084: renown shows on the world map, in the shop header and as a banner.
extends TestCase

const HUD := preload("res://src/ui/hud.gd")


func test_map_note_only_with_a_title() -> void:
	var c := new_character()
	assert_eq(WorldMapScreen.renown_note(c, data(), "misty_forest"), "")
	c.renown["misty_forest"] = 54
	assert_eq(WorldMapScreen.renown_note(c, data(), "misty_forest"), "Your name here: Respected")
	assert_eq(WorldMapScreen.renown_note(c, data(), "qingshi_village"), "")


func test_shop_header_note_at_zero_and_at_a_discount_tier() -> void:
	var c := new_character()
	assert_eq(ShopScreen.renown_note(c, data(), "misty_forest"), "")
	c.renown["misty_forest"] = 54
	assert_eq(ShopScreen.renown_note(c, data(), "misty_forest"), "  Renown: Respected (-6%)")


func test_banner_text() -> void:
	assert_eq(HUD.renown_banner(data(), "misty_forest", "Known"), PackedStringArray(["Known", "Your name is known in Misty Forest"]))


func test_signal_fires_once_when_a_tier_is_crossed() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Renowned", gs.data, seeded_rng(5))
	gs.start_session(c)
	var seen: Array[String] = []
	var on_tier := func(region: String, title: String) -> void: seen.append(region + ":" + title)
	EventBus.renown_tier_reached.connect(on_tier)
	c.renown[gs.current_region] = 19
	gs._gain_renown("bounty")
	gs._gain_renown("bounty")
	EventBus.renown_tier_reached.disconnect(on_tier)
	assert_eq(seen, [gs.current_region + ":Known"])
	gs.end_session()


func test_shop_deal_note_with_and_without_a_deal() -> void:
	var c := new_character()
	assert_eq(ShopScreen.deal_note(c, "misty_forest", 100), "")
	c.shop_deals["misty_forest"] = {"mult": 0.8, "until": 112}
	assert_eq(ShopScreen.deal_note(c, "misty_forest", 100), "  A friend's price: -20% (12 days left)")
	assert_eq(ShopScreen.deal_note(c, "qingshi_village", 100), "")
	assert_eq(ShopScreen.deal_note(c, "misty_forest", 113), "")
