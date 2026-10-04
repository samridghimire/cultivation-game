extends TestCase
## AUC-001b: the auction house place and its screen.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_status_and_lot_labels() -> void:
	var def := Auctions.house(data(), "fallen_star_auction")
	var offset := int(def["offset_days"])
	assert_true(AuctionScreen.status_text(def, 0).begins_with("next auction opens in"), AuctionScreen.status_text(def, 0))
	assert_true(AuctionScreen.status_text(def, offset).begins_with("auction open, closes in"))
	var lot := {"item": "star_silver", "count": 2, "base_price": 300, "rarity": "uncommon", "sold": ""}
	assert_eq(AuctionScreen.lot_label(data(), lot), "%s x2  [uncommon]  from 300" % data().items["star_silver"]["name"])
	lot["sold"] = "npc"
	lot["price"] = 420
	assert_true(AuctionScreen.lot_label(data(), lot).ends_with("(sold to a rival, 420)"))
	assert_eq(AuctionScreen.bid_step(lot), 15)
	assert_eq(AuctionScreen.rarity_color("epic"), AuctionScreen.RARITY_COLORS["epic"])


func test_place_opens_screen_and_bids() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var c := new_character()
	gs.start_session(c)
	gs.current_region = "fallen_star_market"
	var def := Auctions.house(gs.data, "fallen_star_auction")
	var place: Node = load("res://src/world/interactables/auction_house.gd").new()
	place.house_id = "fallen_star_auction"
	var opened: Array = []
	var cb := func(house_id: String) -> void: opened.append(house_id)
	bus.auction_requested.connect(cb)
	var options: Array = place.get_options()
	assert_eq(options.size(), 1)
	(options[0]["action"] as Callable).call()
	bus.auction_requested.disconnect(cb)
	assert_eq(opened, ["fallen_star_auction"])
	place.free()
	var screen := AuctionScreen.new()
	screen.open("fallen_star_auction")
	if not Auctions.is_open(def, clock.total_days):
		assert_false(screen._bid_button.visible, "no lots while the hall is closed")
		clock.total_days = int(def["offset_days"])
		screen._rebuild()
	var lots: Array = gs.auction_lots("fallen_star_auction")
	assert_eq(lots.size(), int(def["lots"]))
	assert_eq(screen._selected, 0)
	var lot: Dictionary = lots[0]
	assert_eq(screen._amount, int(lot["base_price"]))
	assert_true(screen._bid_button.disabled, "a mortal with no stones cannot bid")
	screen._step(-1)
	assert_eq(screen._amount, int(lot["base_price"]), "never below the opening bid")
	screen._step(2)
	assert_eq(screen._amount, int(lot["base_price"]) + 2 * AuctionScreen.bid_step(lot))
	c.inventory = {"spirit_stone": int(lot["npc_max"]) + 1000}
	screen._amount = int(lot["npc_max"]) + 1
	screen._show_details()
	assert_false(screen._bid_button.disabled, screen._reason.text)
	screen._bid()
	assert_eq(String(lot["sold"]), "player")
	assert_true(c.item_count(String(lot["item"])) >= 1)
	assert_true((screen._list.get_node("lot_0") as Button).text.contains("(yours,"))
	screen._select(0)
	assert_true(screen._bid_button.disabled and screen._reason.text.contains("already been sold"))
	screen.free()
	gs.end_session()


func test_fallen_star_market_has_the_auction_house() -> void:
	var places: Array = data().regions["fallen_star_market"]["places"].filter(func(p: Dictionary) -> bool: return p["type"] == "auction")
	assert_eq(places.size(), 1)
	assert_eq(String(places[0]["house_id"]), "fallen_star_auction")
