extends TestCase
## QA-004: every item and recipe in the data can actually be obtained in play.
## Sources: merchant stock (regions.json merchants, stock_tags, max_price),
## gather tables, positive `items` grants in effects/rewards (encounters,
## deeds, enemies, sect missions, dialogue), the starting inventory, and
## recipe outputs whose recipe is known (starter or taught by an obtainable
## item) and whose ingredients are obtainable.

## Items or recipes that are intentionally unobtainable for now:
## id -> task id that will make them obtainable. Keep this empty if you can.
const ALLOWLIST := {}


func test_every_item_is_obtainable() -> void:
	var result := _audit()
	for item_id: String in data().items:
		if not ALLOWLIST.has(item_id):
			assert_true(result["items"].has(item_id), "Item '%s' cannot be obtained (no merchant, loot, gathering or known recipe)" % item_id)


func test_every_recipe_can_be_learned() -> void:
	var result := _audit()
	for recipe_id: String in data().recipes:
		if not ALLOWLIST.has(recipe_id):
			assert_true(result["recipes"].has(recipe_id), "Recipe '%s' is not a starter and no obtainable item teaches it" % recipe_id)


func test_item_grants_reference_known_items() -> void:
	var granted := {}
	_collect_grants(granted)
	assert_gt(granted.size(), 20, "the audit should find loot, rewards and gather tables")
	for item_id: String in granted:
		assert_true(data().items.has(item_id), "'%s' grants unknown item '%s'" % [granted[item_id], item_id])


func test_allowlist_entries_are_still_unobtainable() -> void:
	# Remove an entry once its task lands, so the audit guards it again.
	var result := _audit()
	for id: String in ALLOWLIST:
		assert_false(result["items"].has(id) or result["recipes"].has(id), "'%s' is obtainable now; drop it from ALLOWLIST (%s)" % [id, ALLOWLIST[id]])


## Returns {"items": {id: true}, "recipes": {id: true}} reachable in play.
func _audit() -> Dictionary:
	var gd := data()
	var granted := {}
	_collect_grants(granted)
	var items := {"spirit_stone": true}
	for item_id: String in granted:
		items[item_id] = true
	for item_id: String in gd.items:
		if _sold_by_a_merchant(gd.items[item_id]):
			items[item_id] = true
	for item_id: String in new_character().inventory:
		items[item_id] = true
	var recipes := {}
	for recipe: Dictionary in gd.recipes.values():
		if recipe.get("starter", false):
			recipes[recipe["id"]] = true
	var changed := true
	while changed:
		changed = false
		for item_id: String in items.keys():
			var taught: String = gd.items.get(item_id, {}).get("effects", {}).get("learn_recipe", "")
			if taught != "" and not recipes.has(taught):
				recipes[taught] = true
				changed = true
		for recipe_id: String in recipes.keys():
			var recipe: Dictionary = gd.recipes.get(recipe_id, {})
			if not _all_obtainable(recipe.get("ingredients", {}), items):
				continue
			for key in ["output", "great_output"]:
				var output: String = recipe.get(key, {}).get("item", "")
				if output != "" and not items.has(output):
					items[output] = true
					changed = true
	return {"items": items, "recipes": recipes}


func _all_obtainable(ingredients: Dictionary, items: Dictionary) -> bool:
	for item_id: String in ingredients:
		if not items.has(item_id):
			return false
	return true


func _sold_by_a_merchant(item: Dictionary) -> bool:
	var price := int(item.get("price", 0))
	if price <= 0:
		return false
	var tags: Array = item.get("tags", [])
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") != "merchant":
				continue
			var max_price := int(place.get("max_price", 0))
			if max_price > 0 and price > max_price:
				continue
			var stock_tags: Array = place.get("stock_tags", [])
			if stock_tags.is_empty() and tags.is_empty():
				return true
			for tag in tags:
				if stock_tags.has(tag):
					return true
	return false


## Fills granted with item_id -> source label for every positive `items` grant
## and gather-table entry in the content data.
func _collect_grants(granted: Dictionary) -> void:
	var gd := data()
	var sources := {
		"encounters.json": gd.encounters,
		"deeds.json": gd.deeds,
		"enemies.json": gd.enemies,
		"sect_missions.json": gd.sect_missions,
		"dialogue": gd.dialogues,
	}
	for label: String in sources:
		_walk(sources[label], label, "", granted)
	for region: Dictionary in gd.regions.values():
		for place: Dictionary in region.get("places", []):
			for entry: Dictionary in place.get("gather_table", []):
				var item_id: String = entry.get("item", "")
				if item_id != "":
					granted[item_id] = "regions.json gather_table"


## Positive counts under an `items` key are grants; `requires.items` are costs.
func _walk(value: Variant, label: String, parent: String, granted: Dictionary) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: Variant = value[key]
			if key == "items" and child is Dictionary and parent != "requires":
				for item_id: String in child:
					if (child[item_id] is int or child[item_id] is float) and child[item_id] > 0:
						granted[item_id] = label
			else:
				_walk(child, label, str(key), granted)
	elif value is Array:
		for entry: Variant in value:
			_walk(entry, label, parent, granted)
