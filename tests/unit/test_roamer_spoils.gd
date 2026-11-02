extends TestCase
## C-292: map-roamer item drops sit in the 2-12 stone band (spirit stones themselves are cash).

const BAND_MIN: int = 2
const BAND_MAX: int = 12
const WHITELIST: Dictionary = {}


func test_roamer_item_rewards_are_in_band() -> void:
	var d: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	var ids := {}
	for rid in d.regions:
		var ro: Dictionary = d.regions[rid].get("roamers", {})
		for e in ro.get("enemies", []):
			ids[String(e["enemy"])] = true
	assert_true(ids.size() >= 9, "found roamer enemies")
	for eid in ids:
		var rewards: Dictionary = d.enemies[eid].rewards
		for item_id in rewards.get("items", {}):
			if item_id == "spirit_stone" or WHITELIST.has(item_id):
				continue
			var price: int = d.items[item_id].price
			assert_true(price >= BAND_MIN and price <= BAND_MAX, "%s drops %s priced %d" % [eid, item_id, price])
