extends TestCase
## Auction houses, lot rolling and sealed bids (AUC-001).

const HOUSE := "fallen_star_auction"
const REGION := "fallen_star_market"


func _def() -> Dictionary:
	return Auctions.house(data(), HOUSE)


## A day on which the house's first auction is open.
func _open_day() -> int:
	return int(_def()["offset_days"])


func _rich(stones: int = 100000) -> CharacterData:
	var c := new_character()
	c.add_item("spirit_stone", stones - c.item_count("spirit_stone"))
	return c


func test_real_auction_data_is_valid() -> void:
	assert_eq(Auctions.validate(data()).size(), 0, ", ".join(Auctions.validate(data())))
	assert_eq(Auctions.houses_in(data(), REGION), [HOUSE])


func test_validation_catches_bad_houses() -> void:
	var d := GameData.load_from_dir()
	var def: Dictionary = d.auction_houses[HOUSE]
	def["region"] = "nowhere"
	def["bid_spread"] = [2.0, 1.0]
	def["lot_table"] = [{"item": "no_such_item", "base_price": 0, "weight": 1, "rarity": "mythic"}]
	assert_eq(Auctions.validate(d).size(), 6, "region, spread, too few lots, item, price, rarity")


func test_schedule() -> void:
	var def := _def()
	var start := _open_day()
	assert_false(Auctions.is_open(def, 0))
	assert_eq(Auctions.days_until_open(def, 0), start)
	assert_eq(Auctions.opening_index(def, 0), -1)
	assert_true(Auctions.is_open(def, start))
	assert_eq(Auctions.days_until_close(def, start), int(def["open_days"]))
	assert_false(Auctions.is_open(def, start + int(def["open_days"])))
	assert_eq(Auctions.opening_index(def, start + int(def["period_days"])), 1)
	assert_true(Auctions.is_open(def, start + int(def["period_days"])))


func test_generate_lots_are_distinct_and_priced() -> void:
	var lots := Auctions.generate_lots(_def(), seeded_rng())
	assert_eq(lots.size(), int(_def()["lots"]))
	var seen := {}
	for lot in lots:
		assert_false(seen.has(lot["item"]), "lots are distinct")
		seen[lot["item"]] = true
		var spread: Array = _def()["bid_spread"]
		assert_true(lot["npc_max"] >= int(round(lot["base_price"] * float(spread[0]))))
		assert_true(lot["npc_max"] <= int(round(lot["base_price"] * float(spread[1]))))
		assert_eq(lot["sold"], "")


func test_no_bidders_means_no_competition() -> void:
	var def := _def().duplicate(true)
	def["bidders"] = 0
	for lot in Auctions.generate_lots(def, seeded_rng()):
		assert_eq(lot["npc_max"], 0)


func test_lots_are_fixed_per_opening_and_closed_auctions_have_none() -> void:
	var state := {}
	var day := _open_day()
	var lots := Auctions.current_lots(state, data(), HOUSE, day, 99)
	assert_eq(lots.size(), int(_def()["lots"]))
	assert_eq(Auctions.current_lots(state, data(), HOUSE, day + 1, 99), lots, "same opening, same lots")
	var other := {}
	assert_eq(Auctions.current_lots(other, data(), HOUSE, day, 99), lots, "derived from the world seed")
	assert_eq(Auctions.current_lots(state, data(), HOUSE, 0, 99).size(), 0)
	assert_false(state.has(HOUSE), "closed auctions are dropped")


func test_winning_bid_pays_and_delivers() -> void:
	var c := _rich()
	var state := {}
	var lot: Dictionary = Auctions.current_lots(state, data(), HOUSE, _open_day(), 7)[0]
	var amount := int(lot["npc_max"]) + 1
	var count := c.item_count(lot["item"])
	var result := Auctions.bid(c, data(), state, HOUSE, 0, amount, REGION, _open_day(), 7)
	assert_true(result["ok"])
	assert_true(result["won"])
	assert_eq(c.item_count("spirit_stone"), 100000 - amount)
	assert_eq(c.item_count(lot["item"]), count + int(lot["count"]))
	assert_eq(lot["sold"], "player")
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 0, amount, REGION, _open_day(), 7).contains("already been sold"))


func test_losing_bid_costs_nothing_and_sells_to_a_rival() -> void:
	var c := _rich()
	var state := {}
	var lot: Dictionary = Auctions.current_lots(state, data(), HOUSE, _open_day(), 7)[1]
	var amount := int(lot["base_price"])
	if amount > int(lot["npc_max"]):
		return  # this roll has no rival above the opening bid
	var result := Auctions.bid(c, data(), state, HOUSE, 1, amount, REGION, _open_day(), 7)
	assert_true(result["ok"])
	assert_false(result["won"])
	assert_eq(c.item_count("spirit_stone"), 100000)
	assert_eq(lot["sold"], "npc")
	assert_true(result["price"] <= int(lot["npc_max"]))


func test_bid_reasons() -> void:
	var c := _rich(100)
	var state := {}
	var day := _open_day()
	assert_true(Auctions.check_bid(c, data(), state, "nope", 0, 1, REGION, day, 7).contains("No such"))
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 0, 1, "qingshi_village", day, 7).contains("must be at"))
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 0, 1, REGION, 0, 7).contains("No auction"))
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 99, 1, REGION, day, 7).contains("No such lot"))
	var lot: Dictionary = Auctions.current_lots(state, data(), HOUSE, day, 7)[0]
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 0, int(lot["base_price"]) - 1, REGION, day, 7).contains("opening bid"))
	assert_true(Auctions.check_bid(c, data(), state, HOUSE, 0, int(lot["base_price"]) + 100000, REGION, day, 7).contains("do not have"))
