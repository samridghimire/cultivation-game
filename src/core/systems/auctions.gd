class_name Auctions
extends RefCounted
## Auctions (AUC-001): houses from data/auctions.json hold an auction every
## period_days for open_days. Each auction's lots (and the hidden maximum bid
## of the NPC bidders) are rolled from the world seed when it opens; the player
## places one sealed bid per lot and wins it by beating the NPC maximum.
## Auction state lives in GameState (house_id -> {opening, lots}).

const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]


static func house(data: GameData, house_id: String) -> Dictionary:
	return data.auction_houses.get(house_id, {})


## Ids of the auction houses in `region_id`, in data order.
static func houses_in(data: GameData, region_id: String) -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in data.auction_houses.values():
		if String(def.get("region", "")) == region_id:
			out.append(String(def["id"]))
	return out


static func _period(def: Dictionary) -> int:
	return maxi(1, int(def.get("period_days", 1)))


## Which auction `total_days` falls in (0 = the first), or -1 before the first.
@warning_ignore("integer_division")
static func opening_index(def: Dictionary, total_days: int) -> int:
	var since := total_days - int(def.get("offset_days", 0))
	return -1 if since < 0 else since / _period(def)


static func is_open(def: Dictionary, total_days: int) -> bool:
	var since := total_days - int(def.get("offset_days", 0))
	return since >= 0 and since % _period(def) < int(def.get("open_days", 0))


## Days until the next auction opens (0 while one is open).
static func days_until_open(def: Dictionary, total_days: int) -> int:
	if is_open(def, total_days):
		return 0
	var since := total_days - int(def.get("offset_days", 0))
	return -since if since < 0 else _period(def) - since % _period(def)


## Days left before the open auction closes (0 when closed).
static func days_until_close(def: Dictionary, total_days: int) -> int:
	if not is_open(def, total_days):
		return 0
	var since := total_days - int(def.get("offset_days", 0))
	return int(def.get("open_days", 0)) - since % _period(def)


## Rolls the lots of one auction: `lots` distinct lot_table entries by weight,
## each {item, count, base_price, rarity, npc_max, sold: "" | "player" | "npc", price}.
static func generate_lots(def: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array = (def.get("lot_table", []) as Array).duplicate()
	var spread: Array = def.get("bid_spread", [1.0, 1.0])
	var out: Array[Dictionary] = []
	for i in mini(int(def.get("lots", 0)), pool.size()):
		var total := 0.0
		for entry: Dictionary in pool:
			total += float(entry.get("weight", 1))
		var roll := rng.randf() * total
		var pick := pool.size() - 1
		for j in pool.size():
			roll -= float(pool[j].get("weight", 1))
			if roll < 0.0:
				pick = j
				break
		var entry: Dictionary = pool[pick]
		pool.remove_at(pick)
		var base := int(entry.get("base_price", 1))
		var npc_max := 0
		for b in int(def.get("bidders", 0)):
			npc_max = maxi(npc_max, int(round(base * rng.randf_range(float(spread[0]), float(spread[1])))))
		out.append({"item": String(entry["item"]), "count": int(entry.get("count", 1)), "base_price": base,
			"rarity": String(entry.get("rarity", "common")), "npc_max": npc_max, "sold": "", "price": 0})
	return out


## A private rng for one auction, derived from the world seed so rolling lots
## never disturbs the game rng and the same opening always rolls the same lots.
static func lot_rng(world_seed: int, house_id: String, opening: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, house_id, opening])
	return rng


## The lots of `house_id`'s open auction (rolled into `state` the first time it
## is asked for), or [] when no auction is open. Drops stale auctions.
static func current_lots(state: Dictionary, data: GameData, house_id: String, total_days: int, world_seed: int) -> Array:
	var def := house(data, house_id)
	if def.is_empty() or not is_open(def, total_days):
		state.erase(house_id)
		return []
	var opening := opening_index(def, total_days)
	var current: Dictionary = state.get(house_id, {})
	if current.is_empty() or int(current.get("opening", -1)) != opening:
		current = {"opening": opening, "lots": generate_lots(def, lot_rng(world_seed, house_id, opening))}
		state[house_id] = current
	return current["lots"]


## Why `c` cannot bid `amount` on lot `lot_index` now ("" = allowed).
static func check_bid(c: CharacterData, data: GameData, state: Dictionary, house_id: String, lot_index: int, amount: int, region_id: String, total_days: int, world_seed: int) -> String:
	var def := house(data, house_id)
	if def.is_empty():
		return "No such auction house."
	if String(def.get("region", "")) != region_id:
		return "You must be at the %s to bid." % def.get("name", house_id)
	var lots := current_lots(state, data, house_id, total_days, world_seed)
	if lots.is_empty():
		return "No auction is being held. The next opens in %s." % Calendar.format_duration(days_until_open(def, total_days))
	if lot_index < 0 or lot_index >= lots.size():
		return "No such lot."
	var lot: Dictionary = lots[lot_index]
	if String(lot.get("sold", "")) != "":
		return "That lot has already been sold."
	if amount < int(lot["base_price"]):
		return "The opening bid is %d spirit stones." % int(lot["base_price"])
	if c.item_count("spirit_stone") < amount:
		return "You do not have %d spirit stones." % amount
	return ""


## Places a sealed bid. Above the NPC maximum the player wins, pays `amount`
## and receives the item; otherwise a rival takes the lot just above the bid
## (no cost to the player). Returns {ok, reason, won, item, count, price}.
static func bid(c: CharacterData, data: GameData, state: Dictionary, house_id: String, lot_index: int, amount: int, region_id: String, total_days: int, world_seed: int) -> Dictionary:
	var reason := check_bid(c, data, state, house_id, lot_index, amount, region_id, total_days, world_seed)
	if reason != "":
		return {"ok": false, "reason": reason, "won": false, "item": "", "count": 0, "price": 0}
	var lot: Dictionary = current_lots(state, data, house_id, total_days, world_seed)[lot_index]
	var won := amount > int(lot["npc_max"])
	if won:
		c.add_item("spirit_stone", -amount)
		c.add_item(String(lot["item"]), int(lot["count"]))
		lot["sold"] = "player"
		lot["price"] = amount
	else:
		lot["sold"] = "npc"
		lot["price"] = mini(int(lot["npc_max"]), amount + maxi(1, int(int(lot["base_price"]) * 0.05)))
	return {"ok": true, "reason": "", "won": won, "item": String(lot["item"]), "count": int(lot["count"]), "price": int(lot["price"])}


## Load errors for data/auctions.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for def: Dictionary in data.auction_houses.values():
		var id := String(def["id"])
		if not data.regions.has(String(def.get("region", ""))):
			errors.append("Auction house '%s' has unknown region '%s'" % [id, def.get("region", "")])
		if int(def.get("period_days", 0)) < 1 or int(def.get("open_days", 0)) < 1 or int(def.get("open_days", 0)) > int(def.get("period_days", 0)):
			errors.append("Auction house '%s' needs 1 <= open_days <= period_days" % id)
		if int(def.get("offset_days", 0)) < 0 or int(def.get("bidders", 0)) < 0 or int(def.get("lots", 0)) < 1:
			errors.append("Auction house '%s' needs offset_days >= 0, bidders >= 0 and lots >= 1" % id)
		var spread: Array = def.get("bid_spread", [1.0, 1.0])
		if spread.size() != 2 or float(spread[0]) <= 0.0 or float(spread[0]) > float(spread[1]):
			errors.append("Auction house '%s' bid_spread must be [low, high] with 0 < low <= high" % id)
		var table: Array = def.get("lot_table", [])
		if table.size() < int(def.get("lots", 0)):
			errors.append("Auction house '%s' lot_table has fewer entries than lots" % id)
		for entry: Dictionary in table:
			var item_id := String(entry.get("item", ""))
			if not data.items.has(item_id):
				errors.append("Auction house '%s' sells unknown item '%s'" % [id, item_id])
			if int(entry.get("count", 1)) < 1 or int(entry.get("base_price", 0)) < 1 or float(entry.get("weight", 0)) <= 0.0:
				errors.append("Auction house '%s' lot '%s' needs count >= 1, base_price >= 1 and weight > 0" % [id, item_id])
			if not RARITIES.has(String(entry.get("rarity", ""))):
				errors.append("Auction house '%s' lot '%s' has unknown rarity '%s'" % [id, item_id, entry.get("rarity", "")])
	return errors
