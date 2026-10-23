extends TestCase
## C-238: the shepherd's fold beast is a Foundation-tier, non-lethal foe a typical Foundation Early player beats most of the time.

const Balance := preload("res://tests/sim/combat_balance.gd")


func test_moon_ridge_elk_is_a_fair_foundation_fight() -> void:
	var elk: Dictionary = data().enemies["moon_ridge_elk"]
	assert_eq(String(elk["realm"]), "foundation_establishment")
	assert_false(elk["lethal"])
	var odds := Combat.win_chance(Balance.typical_player(data(), 2, 0), data(), elk, 200)
	print("C-238 moon_ridge_elk typical Foundation Early odds: %.2f" % odds)
	assert_true(odds >= 0.70 and odds <= 0.95, "odds %.2f" % odds)


func test_fold_encounter_fights_the_elk_and_rewards_exist() -> void:
	var keep: Dictionary = data().encounters["village_beast_at_the_fold"]["choices"][0]
	assert_eq(String(keep["enemy"]), "moon_ridge_elk")
	for item_id: String in data().enemies["moon_ridge_elk"]["rewards"]["items"]:
		assert_true(data().items.has(item_id), item_id)
