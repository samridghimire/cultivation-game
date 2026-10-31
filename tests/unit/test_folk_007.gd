extends TestCase
## FOLK-007: friendship tiers (Folk.tier_index / new_tiers / validate_tiers).


func test_tier_index_edges() -> void:
	assert_eq(Folk.tier_index(data(), 19), -1)
	assert_eq(Folk.tier_index(data(), 20), 0)
	assert_eq(Folk.tier_index(data(), 100), data().family["folk_tiers"].size() - 1)
	assert_eq(Folk.tier_name(data(), 10), "")
	assert_eq(Folk.tier_name(data(), 45), "Friend")


func test_new_tiers_fires_highest_only() -> void:
	var r := Folk.new_tiers(data(), {}, {"a": 65}, ["a"])
	assert_eq(r.size(), 1)
	assert_eq(r[0]["tier"], 2)
	assert_true(Folk.new_tiers(data(), {"a": 2}, {"a": 65}, ["a"]).is_empty())
	assert_eq(Folk.new_tiers(data(), {"a": 1}, {"a": 65, "b": 45}, ["a", "b"]).size(), 2)


func test_validation_rejects_bad_tiers() -> void:
	var d := data()
	var saved: Array = d.family["folk_tiers"]
	d.family["folk_tiers"] = [{"min": 40, "name": "A"}, {"min": 40, "name": "B"}]
	assert_false(Folk.validate_tiers(d).is_empty())
	d.family["folk_tiers"] = [{"min": 40, "name": "A", "gift": {"item": "no_such_item", "count": 1}}]
	assert_false(Folk.validate_tiers(d).is_empty())
	d.family["folk_tiers"] = saved
	assert_true(Folk.validate_tiers(d).is_empty())
