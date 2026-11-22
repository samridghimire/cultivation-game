## C-413: every start-region named villager who can leave a gift (a lend-a-hand yield or a cheap like) has >= 2 valid drop_by_lines of their own.
extends TestCase

const START_REGIONS: Array = ["qingshi_village", "misty_forest", "withered_bone_marsh", "fallen_star_market", "azure_peak", "myriad_peaks_ridge"]
## Bai Qingwu's sect forbids gifts, so she leaves none and keeps the shared lines.
const NO_GIFTS: Array = ["disciple_bai"]


func test_gift_givers_have_their_own_lines() -> void:
	var max_price: int = int(Folk.visit_rules(data()).get("drop_by", {}).get("max_price", 10))
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		if not START_REGIONS.has(String(def.get("region", ""))) or NO_GIFTS.has(npc_id):
			continue
		var can_gift: bool = not Folk.lend_yield(data(), npc_id).is_empty()
		for like: Variant in def.get("likes", []):
			if int(data().items.get(String(like), {}).get("price", 99)) <= max_price:
				can_gift = true
		if not can_gift:
			continue
		var lines: Array = def.get("drop_by_lines", [])
		assert_true(lines.size() >= 2 and lines.size() <= 3, "%s needs 2-3 drop_by_lines" % npc_id)
		for l: Variant in lines:
			assert_true(l is String and String(l).length() >= 1 and String(l).length() <= 140, "%s has a bad drop_by line" % npc_id)


func test_every_gift_giver_can_actually_give() -> void:
	var max_price: int = int(Folk.visit_rules(data()).get("drop_by", {}).get("max_price", 10))
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		if not START_REGIONS.has(String(def.get("region", ""))) or NO_GIFTS.has(npc_id):
			continue
		if def.get("drop_by_lines", []).is_empty():
			continue
		var can_gift: bool = not Folk.lend_yield(data(), npc_id).is_empty()
		for like: Variant in def.get("likes", []):
			if int(data().items.get(String(like), {}).get("price", 99)) <= max_price:
				can_gift = true
		assert_true(can_gift, "%s has drop_by_lines but nothing to give" % npc_id)
