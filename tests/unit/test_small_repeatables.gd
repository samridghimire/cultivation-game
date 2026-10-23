extends TestCase
## C-234: small-change repeatables fade out; a pocket-change find does not loop forever past its realm.


func test_small_change_repeatables_have_a_realm_ceiling() -> void:
	for e: Dictionary in data().encounters.values():
		if not e.get("repeatable", false) or e.has("max_realm"):
			continue
		if e.has("choices") or e.has("enemy") or e.has("set_flag"):
			continue
		var items: Dictionary = e.get("effects", {}).get("items", {})
		var only_stones := not items.is_empty() and items.keys() == ["spirit_stone"]
		if only_stones:
			assert_true(int(items["spirit_stone"]) > 10, "%s pays <= 10 stones forever" % e["id"])
		assert_false(items.keys() == ["spirit_herb"], "%s gives only a common herb forever" % e["id"])
