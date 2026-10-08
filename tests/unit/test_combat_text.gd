extends TestCase
## QA-037: every combat log line, for every enemy, is clean prose (no raw
## placeholders or ids) and the HP trace stays aligned with the log.

const Balance := preload("res://tests/sim/combat_balance.gd")


func _check_lines(label: String, result: Dictionary) -> void:
	var lines: PackedStringArray = result["log"]
	assert_eq(result["trace"].size(), lines.size(), "%s: trace matches log" % label)
	for line in lines:
		assert_true(line.length() > 0, "%s: empty line" % label)
		for bad in ["{", "}", "%d", "%s", "  ", "null", "<null>"]:
			assert_false(line.contains(bad), "%s: '%s' in \"%s\"" % [label, bad, line])
		var upper := line.left(1) == line.left(1).to_upper() and line.left(1) != line.left(1).to_lower()
		var starts_ok := upper or line.left(1).is_valid_int() or line.left(1) in ["(", "\"", "'"]
		assert_true(starts_ok, "%s: lower-case start \"%s\"" % [label, line])
		var plain := line.replace("hp)", "").replace("(You:", "")
		for word in plain.split(" ", false):
			assert_false(word.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix(")").contains("_"), "%s: raw id '%s' in \"%s\"" % [label, word, line])


func test_all_enemy_fights_read_cleanly() -> void:
	var allies: Array = [{"name": "Old Wen", "damage": 7}]
	for enemy_id: String in data().enemies:
		var enemy: Dictionary = data().enemies[enemy_id]
		var realm := maxi(0, data().realm_index_of(String(enemy.get("realm", "mortal"))))
		for tal in [false, true]:
			var c := Balance.typical_player(data(), realm, 0, tal)
			for seed_value in 3:
				var result := Combat.resolve(c, data(), enemy, seeded_rng(seed_value + 3), allies if tal else [])
				_check_lines("%s/tal=%s/seed=%d" % [enemy_id, tal, seed_value], result)


func test_opener_lines_are_exercised() -> void:
	var c := Balance.typical_player(data(), 1, 0, true)
	var result := Combat.resolve(c, data(), data().enemies["mist_wolf"], seeded_rng(3), [{"name": "Old Wen", "damage": 7}])
	var text := "\n".join(result["log"])
	assert_true(text.contains("Old Wen"), "ally opener present")
	assert_true(text.contains("You hurl") or text.contains("You burn"), "talisman opener present")
