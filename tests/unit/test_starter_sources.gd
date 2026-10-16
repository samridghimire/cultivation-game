extends TestCase
## C-141: every rank-0 recipe's ingredients (spirit stones aside) can be had
## near Qingshi Village: gathered, sold by a merchant, or dropped by a foe.


func _region_ids() -> Array:
	var out: Array = []
	for rid: String in data().regions:
		if Exploration.is_nearby(data(), "qingshi_village", rid):
			out.append(rid)
	return out


func _gatherable(item_id: String, regions: Array) -> bool:
	for rid: String in regions:
		for place: Dictionary in data().regions[rid].get("places", []):
			for row: Dictionary in place.get("gather_table", []):
				if row.get("item", "") == item_id:
					return true
	return false


func _sold(item_id: String) -> bool:
	for place: Dictionary in data().regions["qingshi_village"].get("places", []):
		if place.get("type", "") == "merchant" and Items.merchant_sells(data(), data().items[item_id], place.get("stock_tags", []), int(place.get("max_price", 0))):
			return true
	return false


func _dropped(item_id: String, regions: Array) -> bool:
	var tags := {}
	for rid: String in regions:
		for t: String in data().regions[rid].get("encounter_tags", []):
			tags[t] = true
	for enc: Dictionary in data().encounters.values():
		var foe: String = enc.get("enemy", "")
		if foe == "" or not data().enemies.has(foe):
			continue
		if data().enemies[foe].get("realm", "") not in ["mortal", "qi_refining"]:
			continue
		var near := false
		for t: String in enc.get("tags", []):
			near = near or tags.has(t)
		if near and data().enemies[foe].get("rewards", {}).get("items", {}).has(item_id):
			return true
	return false


func test_rank_zero_ingredients_are_within_reach_of_the_village() -> void:
	var regions := _region_ids()
	for recipe: Dictionary in data().recipes.values():
		if int(recipe.get("min_rank", 0)) != 0:
			continue
		for item_id: String in recipe["ingredients"]:
			if item_id == "spirit_stone":
				continue
			assert_true(_gatherable(item_id, regions) or _sold(item_id) or _dropped(item_id, regions), "%s needs %s" % [recipe["id"], item_id])
