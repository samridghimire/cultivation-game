extends TestCase
## Item effect descriptions (WU-033).


## WU-033: every effect any item uses is described, and never as raw ids.
func test_describe_effects_covers_every_item_effect() -> void:
	var d := data()
	for id: String in d.items:
		var effects: Dictionary = d.items[id].get("effects", {})
		var lines := Items.describe_effects(effects, d)
		var describable := effects.keys().filter(func(k: String) -> bool: return k != "breakthrough_realm" and k != "set_flag" and k != "clear_flag" and k != "witnessed")
		if not describable.is_empty():
			assert_true(lines.size() > 0, "%s: %s has no description line" % [id, str(effects)])
		for line in lines:
			assert_false(line.contains("_") or line.contains("%s") or line.contains("%d") or line.contains("{"), "%s: raw text in '%s'" % [id, line])


func test_describe_effects_new_kinds() -> void:
	var d := data()
	var recipe_id: String = d.recipes.keys()[0]
	assert_eq(Items.describe_effects({"learn_recipe": recipe_id}, d)[0], "Teaches the recipe: %s" % d.recipes[recipe_id]["name"])
	assert_true(Items.describe_effects({"dao_insight": "dao_of_slaughter"}, d)[0].begins_with("A glimpse of the"))
	assert_eq(Items.describe_effects({"attributes": {"comprehension": 2}}, d)[0], "+2 Comprehension")
	assert_eq(Items.describe_effects({"buff": {"id": "x", "name": "X", "days": 7, "mults": {"max_hp": 0.2, "attack": 0.6}}}, d)[0], "+20% max hp, +60% attack for 7 days")
	var sect_id: String = d.sects.keys()[0]
	assert_eq(Items.describe_effects({"reputation": {sect_id: 5}}, d)[0], "+5 standing with %s" % d.sects[sect_id].name)


## C-023: every beast material drops from an enemy and sells to a merchant.
func test_beast_materials_are_dropped_and_bought() -> void:
	var d := data()
	var bought: Array = []
	for region: Dictionary in d.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "merchant" and (place.get("buy_tags", []) as Array).has("beast_material"):
				bought.append(place)
	assert_true(bought.size() >= 4, "beast materials need buyers")
	var count := 0
	for id: String in d.items:
		if not (d.items[id].get("tags", []) as Array).has("beast_material"):
			continue
		count += 1
		var dropped := false
		for enemy: Dictionary in d.enemies.values():
			if enemy.get("rewards", {}).get("items", {}).has(id):
				dropped = true
		assert_true(dropped, "%s is dropped by no enemy" % id)
	assert_eq(count, 8)


## RV-011: "sell all loot" keeps talismans readied for the next fight.
func test_bulk_sell_keeps_readied_talismans() -> void:
	var c := new_character()
	c.inventory = {"fire_strike_talisman": 3, "swift_wind_talisman": 2}
	c.readied_talismans = ["fire_strike_talisman"]
	var ids := Items.bulk_sell_ids(c, data(), ["talisman"])
	assert_true(ids.has("swift_wind_talisman"))
	assert_false(ids.has("fire_strike_talisman"), "readied")
	assert_eq(Items.bulk_sell_total(c, data(), ids), 2 * Items.sell_price(data(), "swift_wind_talisman"))
