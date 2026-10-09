extends TestCase
## QA-004: every item and recipe in the data can actually be obtained in play.
## Sources: merchant stock (regions.json merchants, stock_tags, max_price),
## sect contribution shops (sects.json shop),
## gather tables, positive `items` grants in effects/rewards (encounters,
## deeds, enemies, sect missions, dialogue, secret realm treasures), the starting inventory, and
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
	for sect: SectDef in gd.sects.values():
		for entry: Dictionary in sect.shop:
			items[String(entry["item_id"])] = true
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
	return Items.sources(data(), item["id"]).any(func(line: String) -> bool: return line.begins_with("Sold at"))


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
		"secret_realms.json": gd.secret_realms,
		"inheritances.json": gd.inheritances,
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


# --- ITEM-002: has_known_source -------------------------------------------------

## Items nothing in the data hands out today. Keep this list honest: a new
## entry is a content hole (the item is unobtainable), a removed one a fix.
const KNOWN_UNOBTAINABLE: Array[String] = []


func test_has_known_source_kinds() -> void:
	var d := data()
	assert_true(Items.has_known_source(d, "spirit_herb"), "gathered")
	var crafted := ""
	for recipe: Dictionary in d.recipes.values():
		crafted = String(recipe["output"]["item"])
		break
	assert_true(Items.has_known_source(d, crafted), "crafted")
	assert_true(Items.sources(d, crafted).has("Crafted"))
	assert_false(Items.has_known_source(d, "no_such_item"))
	assert_eq(Items.sources(d, "no_such_item"), ["Found exploring"] as Array[String])


func test_has_known_source_for_a_sold_item() -> void:
	var d := data()
	var sold := ""
	for item: Dictionary in d.items.values():
		if _sold_by_a_merchant(item):
			sold = String(item["id"])
			break
	assert_true(sold != "")
	assert_true(Items.has_known_source(d, sold))


func test_unsourced_test_item_is_unobtainable() -> void:
	var d := data()
	d.items["orphan_item"] = {"id": "orphan_item", "name": "Orphan", "tags": [], "price": 0, "effects": {}}
	assert_false(Items.has_known_source(d, "orphan_item"))
	d.items.erase("orphan_item")


func test_every_manual_and_breakthrough_pill_has_a_source() -> void:
	var d := data()
	var missing: Array[String] = []
	for item: Dictionary in d.items.values():
		var id := String(item["id"])
		var effects: Dictionary = item.get("effects", {})
		if (effects.has("learn_technique") or effects.has("learn_recipe") or effects.has("breakthrough_realm") or effects.has("breakthrough_bonus")) and not Items.has_known_source(d, id) and not KNOWN_UNOBTAINABLE.has(id):
			missing.append(id)
	assert_eq(missing, [] as Array[String], "no known source: " + str(missing))


func test_every_recipe_has_a_scroll_with_a_source() -> void:
	var d := data()
	var taught := {}
	for item: Dictionary in d.items.values():
		var recipe_id: String = item.get("effects", {}).get("learn_recipe", "")
		if recipe_id != "":
			taught[recipe_id] = taught.get(recipe_id, []) + [String(item["id"])]
	var missing: Array[String] = []
	for recipe_id: String in d.recipes:
		if bool(d.recipes[recipe_id].get("starter", false)) or KNOWN_UNOBTAINABLE.has(recipe_id):
			continue
		var found := false
		for scroll_id: String in taught.get(recipe_id, []):
			found = found or Items.has_known_source(d, scroll_id)
		if not found:
			missing.append(recipe_id)
	assert_eq(missing, [] as Array[String], "recipes with no scroll source: " + str(missing))

