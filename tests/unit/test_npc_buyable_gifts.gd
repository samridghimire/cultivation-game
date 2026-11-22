## C-407: every named start-region villager likes at least one item a newcomer can buy (<= 15 stones) or gather in their own region.
extends TestCase

const START_REGIONS: Array = ["qingshi_village", "misty_forest", "withered_bone_marsh", "fallen_star_market", "azure_peak", "myriad_peaks_ridge"]


## Item ids a newcomer can get in `region`: merchant stock (always-open or market stalls), rotating pools, catches, gathers, forage.
func _reachable(region: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var entries: Array = []
	for place: Dictionary in region.get("places", []):
		if place.get("festival_only", "") != "":
			continue
		if String(place.get("type", "")) == "merchant":
			for item_id: String in data().items:
				var item: Dictionary = data().items[item_id]
				if int(item.get("price", 0)) <= 15 and Items.merchant_sells(data(), item, place.get("stock_tags", []), int(place.get("max_price", 0))):
					ids[item_id] = true
		for e: Dictionary in place.get("rotating_stock", {}).get("pool", []):
			if int(data().items.get(String(e["item"]), {}).get("price", 99)) <= 15:
				ids[String(e["item"])] = true
		for table: String in ["catch_table", "gather_table"]:
			for e: Dictionary in place.get(table, []):
				if String(e["item"]) != "":
					ids[String(e["item"])] = true
	for e: Dictionary in region.get("forage", {}).get("items", []):
		ids[String(e["item"])] = true
	return ids


func test_every_start_villager_has_a_buyable_or_gatherable_like() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var regions: Array = raw["regions"] if raw is Dictionary and raw.has("regions") else raw
	var by_id: Dictionary = {}
	for r: Dictionary in regions:
		by_id[String(r["id"])] = _reachable(r)
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		var rid := String(def.get("region", ""))
		if not START_REGIONS.has(rid):
			continue
		var ok := false
		for item_id: String in by_id.get(rid, {}):
			if Family.gift_taste(data(), npc_id, item_id) == 1:
				ok = true
				break
		assert_true(ok, "%s (%s) likes nothing a newcomer can buy or gather there" % [npc_id, rid])
