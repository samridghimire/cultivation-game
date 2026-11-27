class_name FriendAid
extends RefCounted
## FOLK-054: a friend at the gate asks for help. A named friend (favor >= family.friend_aid.min_favor) who reaches the
## bottleneck of a realm listed in friend_aid.items waits there (up to expire_days), and asks the player once for one
## aid item. Giving it adds favor and a one-use odds bonus on their next breakthrough (Npcs._live). Pure rules, no rng.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("friend_aid", {})


## Item ids a friend entering `target_realm` may ask for ([] when none).
static func items_for(data: GameData, target_realm: int) -> Array:
	var pool: Variant = rules(data).get("aid_items", {}).get(str(target_realm), [])
	return pool if pool is Array else []


## The one item `npc` asks for at its gate (stable pick by id, never the session rng); "" when there is none.
static func item_for(data: GameData, npc: CharacterData) -> String:
	var pool := items_for(data, npc.realm_index + 1)
	if pool.is_empty():
		return ""
	return String(pool[absi(hash(npc.id)) % pool.size()])


## Friends allowed to wait at their gate and ask: {npc_id: true}. Pure.
static func hold_ids(npcs: Dictionary, data: GameData, favor: Dictionary, flags: Dictionary, today: int) -> Dictionary:
	var out := {}
	var need := int(rules(data).get("min_favor", 40))
	var cool := int(rules(data).get("cooldown_days", 90))
	for id: String in data.npcs:
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive or int(favor.get(id, 0)) < need or npc.realm_index < 1:
			continue
		if today - int(flags.get("friend_aid_" + id, -100000)) < cool:
			continue
		out[id] = true
	return out


## Stores the ask for `npc` (called when Npcs.simulate reports kind "aid_ask"). Returns the item id, "" if none.
static func open_ask(player: CharacterData, data: GameData, npc: CharacterData, flags: Dictionary, today: int) -> String:
	var item := item_for(data, npc)
	if item == "":
		return ""
	player.friend_aid[npc.id] = {"realm": npc.realm_index + 1, "item": item, "day": today}
	flags["friend_aid_" + npc.id] = today
	return item


## Drops asks that ran out or whose friend is no longer at the gate.
static func prune(player: CharacterData, data: GameData, npcs: Dictionary, today: int) -> void:
	var life := int(rules(data).get("expire_days", 60))
	for id: String in player.friend_aid.keys():
		var npc: CharacterData = npcs.get(id)
		var e: Dictionary = player.friend_aid[id]
		if npc == null or not npc.alive or today - int(e.get("day", 0)) > life or not Cultivation.can_attempt_breakthrough(npc, data):
			player.friend_aid.erase(id)


## "" when the player can give `npc` their asked item now, else the reason.
static func give_block(player: CharacterData, data: GameData, npc: CharacterData, today: int) -> String:
	if not player.friend_aid.has(npc.id):
		return "%s asks nothing of you." % npc.name
	var e: Dictionary = player.friend_aid[npc.id]
	if today - int(e.get("day", 0)) > int(rules(data).get("expire_days", 60)) or not Cultivation.can_attempt_breakthrough(npc, data):
		return "%s no longer needs it." % npc.name
	var item := String(e.get("item", ""))
	if player.item_count(item) < 1:
		return "You have no %s." % String(data.items.get(item, {}).get("name", item))
	return ""


## Hands the item over: consumes it, sets the friend's one-use bonus, clears the ask. Returns the favor gained (0 if blocked).
static func give(player: CharacterData, data: GameData, npc: CharacterData, today: int) -> int:
	if give_block(player, data, npc, today) != "":
		return 0
	player.add_item(String(player.friend_aid[npc.id]["item"]), -1)
	player.friend_aid.erase(npc.id)
	npc.aid_bonus = float(rules(data).get("odds_bonus", 0.15))
	return int(rules(data).get("favor", 8))


## FOLK-056: a friend whose aided breakthrough succeeded sends one gift from friend_aid.thanks_items[new realm index].
## Returns the gift id queued ("" when none: no pool for that realm). The rng picks the gift.
static func queue_thanks(player: CharacterData, data: GameData, npc: CharacterData, aid_item: String, rng: RandomNumberGenerator, today: int) -> String:
	var pool: Variant = rules(data).get("thanks_items", {}).get(str(npc.realm_index), [])
	if not pool is Array or (pool as Array).is_empty():
		return ""
	var gift := String(pool[rng.randi_range(0, (pool as Array).size() - 1)])
	player.friend_thanks[npc.id] = {"gift": gift, "aid_item": aid_item, "day": today}
	return gift


## FOLK-058: drops queued thanks whose friend is dead or gone. Returns how many were removed.
static func prune_thanks(player: CharacterData, npcs: Dictionary) -> int:
	var gone: Array[String] = []
	for id: String in player.friend_thanks:
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive:
			gone.append(id)
	for id in gone:
		player.friend_thanks.erase(id)
	return gone.size()


## FOLK-056: ids of queued thanks ready now: the player is in the friend's region, or thanks_days have passed.
static func thanks_due(player: CharacterData, data: GameData, npcs: Dictionary, region: String, today: int) -> Array[String]:
	var out: Array[String] = []
	var wait := int(rules(data).get("thanks_days", 7))
	for id: String in player.friend_thanks:
		var npc: CharacterData = npcs.get(id)
		if npc == null or not npc.alive:
			continue
		if Npcs.region_of(npc, data) == region or today - int(player.friend_thanks[id].get("day", 0)) >= wait:
			out.append(id)
	out.sort()
	return out


## FOLK-056: hands over the queued gift; returns {gift, aid_item, favor} (gift "" when nothing was queued).
static func deliver_thanks(player: CharacterData, data: GameData, npc_id: String) -> Dictionary:
	if not player.friend_thanks.has(npc_id):
		return {"gift": "", "aid_item": "", "favor": 0}
	var e: Dictionary = player.friend_thanks[npc_id]
	player.friend_thanks.erase(npc_id)
	player.add_item(String(e["gift"]), 1)
	return {"gift": String(e["gift"]), "aid_item": String(e.get("aid_item", "")), "favor": int(rules(data).get("thanks_favor", 3))}


## Journal rows for open asks: [{npc_id, name, region, days_left, text}], fewest days left first.
static func journal_rows(player: CharacterData, data: GameData, npcs: Dictionary, today: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if player == null:
		return rows
	var life := int(rules(data).get("expire_days", 60))
	for id: String in player.friend_aid:
		var npc: CharacterData = npcs.get(id)
		if npc == null:
			continue
		var e: Dictionary = player.friend_aid[id]
		var left := life - (today - int(e.get("day", 0)))
		if left < 0:
			continue
		var item := String(data.items.get(String(e.get("item", "")), {}).get("name", e.get("item", "")))
		rows.append({"npc_id": id, "name": npc.name, "region": Npcs.region_of(npc, data), "days_left": maxi(1, left),
			"text": "%s awaits a %s at the gate of a new realm: give it (%d days left)" % [npc.name, item, maxi(1, left)]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["days_left"]) < int(b["days_left"]) or (int(a["days_left"]) == int(b["days_left"]) and String(a["npc_id"]) < String(b["npc_id"])))
	return rows


## WU-637: true when `npc`'s open ask has not yet been put to the player on a card (once per ask, keyed by its day).
static func card_pending(player: CharacterData, data: GameData, npc: CharacterData, flags: Dictionary, today: int) -> bool:
	if player == null or not player.friend_aid.has(npc.id):
		return false
	var e: Dictionary = player.friend_aid[npc.id]
	if today - int(e.get("day", 0)) > int(rules(data).get("expire_days", 60)) or not Cultivation.can_attempt_breakthrough(npc, data):
		return false
	return int(flags.get("friend_aid_card_" + npc.id, -1)) != int(e.get("day", 0))


## WU-637: the line on the card.
static func card_line(npc_name: String, item_name: String, held: bool) -> String:
	var line := "%s sits at the gate of a new realm and needs a %s." % [npc_name, item_name]
	return line + (" You have one." if held else " You have none yet.")
