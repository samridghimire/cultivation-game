extends TestCase
## RealmCard (WU-137): the extra lines under the realm description.


func test_card_lines_skips_empty() -> void:
	var lines := RealmCard.card_lines("desc", "", ["", "New: Alchemy"])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "New: Alchemy")


func test_card_lines_caps_at_three() -> void:
	var lines := RealmCard.card_lines("desc", "Lifespan +50 years", ["a", "b", "c", "d"])
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], "Lifespan +50 years")
	assert_eq(lines[2], "b")


func test_card_lines_empty() -> void:
	assert_eq(RealmCard.card_lines("", "", []).size(), 0)
