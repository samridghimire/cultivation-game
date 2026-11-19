extends TestCase
## C-399: every early region has a rank-0 meal a newcomer can cook in the first week from what that
## region gives (its forage, its day-1 gathering and fishing, or a <= 5-stone buy at its own merchant).

const REGIONS: Array[String] = ["qingshi_village", "misty_forest", "fallen_star_market", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]
const MAX_BUY := 5


## Items a fresh mortal can get in `region_id` in a week, whatever the season or weather.
func _local(region_id: String) -> Dictionary:
	var out := {}
	var region: Dictionary = data().regions[region_id]
	for e: Dictionary in region["forage"]["items"]:
		if not e.has("seasons") and not e.has("weather"):
			out[String(e["item"])] = true
	for p: Dictionary in region["places"]:
		for row_key in ["gather_table", "catch_table"]:
			for row: Dictionary in p.get(row_key, []):
				if String(row.get("item", "")) != "" and not row.has("min_realm") and not row.has("seasons") and not row.has("weather"):
					out[String(row["item"])] = true
		if p.get("type", "") == "merchant" and not p.has("festival_only") and not p.has("faction") and not p.has("max_alignment"):
			for item_id: String in Items.shop_stock(data(), MAX_BUY, p.get("stock_tags", [])):
				out[item_id] = true
	return out


func _known_at_start(recipe: Dictionary) -> bool:
	return not bool(recipe.get("taught", false))


func test_each_early_region_has_a_first_meal() -> void:
	for region_id in REGIONS:
		var local := _local(region_id)
		var found: Array[String] = []
		for recipe: Dictionary in data().home_meals:
			if not _known_at_start(recipe):
				continue
			var ok := true
			for ing: String in recipe["ingredients"]:
				if not local.has(ing):
					ok = false
			if ok:
				var item: Dictionary = data().items[String(recipe["output"]["item"])]
				if item.get("effects", {}).has("buff"):
					found.append(String(recipe["id"]))
		assert_true(not found.is_empty(), "%s has a buffing first meal cookable from local ingredients" % region_id)


func test_meal_descriptions_fit_the_card() -> void:
	for recipe: Dictionary in data().home_meals:
		var item: Dictionary = data().items[String(recipe["output"]["item"])]
		assert_true(String(item["description"]).length() <= 140, "%s description <= 140 chars" % recipe["id"])
