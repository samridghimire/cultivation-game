extends TestCase
## WU-532: Items.shop_order puts the hinted item and items useful now first, the rest in today's order.


func _ids() -> Array:
	return Items.shop_stock(data(), 0, [])


func test_hinted_item_comes_first() -> void:
	var c := new_character()
	var ids := _ids()
	var last: String = ids[ids.size() - 1]
	assert_eq(Items.shop_order(c, data(), ids, last)[0], last)


func test_unknown_manual_before_a_snack() -> void:
	var c := new_character()
	var manual := ""
	for id: Variant in _ids():
		if Items.manual_technique(data(), String(id)) != "" and Items.useful_now(c, data(), String(id)):
			manual = String(id)
			break
	assert_true(manual != "", "a general store sells a learnable manual")
	var ids := _ids()
	var out := Items.shop_order(c, data(), ids, "")
	assert_true(out.find(manual) <= ids.find(manual))
	assert_eq(out.size(), ids.size())


func test_known_manual_not_boosted() -> void:
	var c := new_character()
	for id: Variant in _ids():
		var tech := Items.manual_technique(data(), String(id))
		if tech != "":
			Techniques.learn(c, data(), tech)
			assert_false(Items.useful_now(c, data(), String(id)))
			return
	assert_true(false, "no manual in stock")


func test_pill_for_higher_realm_not_boosted() -> void:
	var c := new_character()
	assert_false(Items.useful_now(c, data(), "foundation_establishment_pill"))
	assert_true(Items.useful_now(c, data(), "qi_gathering_pill"))


func test_rest_keeps_stable_order_and_is_deterministic() -> void:
	var c := new_character()
	var ids := _ids()
	var out := Items.shop_order(c, data(), ids, "")
	assert_eq(out, Items.shop_order(c, data(), ids, ""))
	var rest := out.filter(func(id): return not Items.useful_now(c, data(), String(id)))
	var expected := ids.filter(func(id): return not Items.useful_now(c, data(), String(id)))
	assert_eq(rest, expected)


func test_empty_ids() -> void:
	assert_eq(Items.shop_order(new_character(), data(), [], "x"), [])
