extends TestCase
## FH-020: a newcomer in Qingshi Village can earn and craft without leaving, and every sect has a safe rank-0 mission.


func _region_places(region_id: String) -> Array:
	return data().regions.get(region_id, {}).get("places", [])


func test_some_qingshi_alchemy_recipe_is_fully_obtainable_in_village() -> void:
	var places := _region_places("qingshi_village")
	assert_gt(places.size(), 0, "qingshi_village places found")
	var obtainable := {}
	for place: Dictionary in places:
		if place.get("type", "") == "merchant":
			for id: String in Items.shop_stock(data(), int(place.get("max_price", 0)), place.get("stock_tags", [])):
				obtainable[id] = true
		elif place.get("type", "") == "gather":
			for entry: Dictionary in place.get("gather_table", []):
				if entry.get("item", "") != "" and not entry.has("min_realm"):
					obtainable[entry["item"]] = true
	var found := false
	for recipe: Variant in data().recipes.values():
		if recipe["profession"] != "alchemist" or int(recipe["min_rank"]) > 0 or not recipe.get("starter", false):
			continue
		var all_ok := true
		for ing: String in recipe["ingredients"]:
			if not obtainable.has(ing):
				all_ok = false
		found = found or all_ok
	assert_true(found, "a rank-0 starter alchemy recipe has all ingredients available in Qingshi")


func test_every_sect_has_safe_rank0_mission() -> void:
	for sect_id: String in data().sects:
		var ok := false
		for m: Variant in data().sect_missions.values():
			var sects: Array = m.get("sects", [])
			if (sects.is_empty() or sects.has(sect_id)) and int(m.get("min_rank", 0)) == 0:
				var enemy: String = m.get("enemy", "")
				if enemy == "" or not data().enemies[enemy].get("lethal", true):
					ok = true
		assert_true(ok, "%s has a safe rank-0 mission" % sect_id)
