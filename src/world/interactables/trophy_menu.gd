class_name TrophyMenu
extends RefCounted
## WILD-022: the "Hang a trophy" / "Take down" menu entries shared by the Family Home and the abode.


static func options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	if p == null:
		return out
	for id in p.hung_trophies:
		out.append({"label": "Take down the %s" % data.items.get(id, {}).get("name", id), "action": GameState.take_down_trophy.bind(id), "keep_open": true})
	var ids: Array = p.inventory.keys().filter(func(i: String) -> bool: return data.items.get(i, {}).get("tags", []).has("trophy") and not p.hung_trophies.has(i))
	ids.sort()
	for id: String in ids:
		var why := Trophies.check_hang(p, GameState.npcs, data, GameState.current_region, id)
		out.append({"label": "Hang the %s (%d of %d)" % [data.items[id]["name"], p.hung_trophies.size(), Trophies.MAX_HUNG], "action": GameState.hang_trophy.bind(id), "disabled": why != "", "reason": why, "keep_open": true})
	return out
