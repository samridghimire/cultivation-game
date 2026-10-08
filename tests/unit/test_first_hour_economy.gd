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


## FH-024: missions are always fought, so a rank-0 mission with an enemy must not
## be a likely death for the first-hour player (starter technique, Qingshi iron sword and scale armor) at
## the mission's own min_realm / min_stage.
func test_rank0_mission_fights_are_weak_or_even_for_newcomers() -> void:
	for m: Variant in data().sect_missions.values():
		if int(m.get("min_rank", 0)) != 0 or String(m.get("enemy", "")) == "":
			continue
		var c := new_character(31)
		c.realm_index = maxi(0, data().realm_index_of(String(m.get("min_realm", "mortal"))))
		c.stage = int(m.get("min_stage", 0))
		c.techniques["basic_breathing"] = {"level": 1, "xp": 0.0}
		c.equipment = {"weapon": "iron_sword", "armor": "iron_scale_armor"}
		var label := Combat.danger_label(c, data(), data().enemies[String(m["enemy"])])
		assert_true(label == "Weak" or label == "Even", "%s is %s for a newcomer at its min stage" % [m["id"], label])
