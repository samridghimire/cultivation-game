extends Interactable
## An auction house (data/auctions.json, AUC-001b): opens the AuctionScreen,
## which shows the next auction date or the open auction's lots and takes
## sealed bids (GameState.bid).

@export var house_id := ""


func get_options() -> Array[Dictionary]:
	var def := Auctions.house(GameState.data, house_id)
	if def.is_empty():
		return []
	var label := "Enter the auction hall (%s)" % AuctionScreen.status_text(def, GameClock.total_days)
	return [{"label": label, "action": EventBus.auction_requested.emit.bind(house_id)}]
