extends TestCase
## FOLK-035: lending a hand (Folk.lend_*, GameState.lend_a_hand, Guidance.make_friend_hint).


func _npcs(d: GameData) -> Dictionary:
	var npcs := {}
	Npcs.ensure_all(npcs, d, seeded_rng(3))
	return npcs


func test_verb_falls_back() -> void:
	var d := data()
	assert_eq(Folk.lend_verb(d, "elder_mo"), "sorting scrolls")
	assert_eq(Folk.lend_verb(d, "nobody"), "with their chores")


func test_cooldown_and_cap() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var mo: CharacterData = npcs["elder_mo"]
	var flags := {"lend_elder_mo": 10}
	assert_eq(Folk.lend_check(c, mo, d, {}, 0, 0, "qingshi_village"), "")
	assert_eq(Folk.lend_check(c, mo, d, flags, 16, 0, "qingshi_village"), "Again in 1 day.")
	assert_eq(Folk.lend_check(c, mo, d, flags, 17, 0, "qingshi_village"), "")
	assert_true(Folk.lend_check(c, mo, d, {}, 0, 45, "qingshi_village").contains("glad of the help"))
	assert_true(Folk.lend_check(c, mo, d, {}, 0, 0, "misty_forest").contains("not here"))


func test_gain_and_yield() -> void:
	var d := data()
	var c := new_character()
	var base := Folk.lend_gain(c, d, 0)
	assert_true(base >= 4)
	assert_eq(Folk.lend_gain(c, d, 44), 1, "capped at max_favor")
	assert_true(Folk.lend_yield(d, "elder_mo").is_empty(), "read has no yield")
	d.npcs["elder_mo"]["activity"] = "hoe"
	assert_eq(String(Folk.lend_yield(d, "elder_mo")["item"]), "millet")
	d.npcs["elder_mo"]["activity"] = "read"


func test_validation_rejects_bad_block() -> void:
	var d := data()
	var old: Dictionary = d.family["lend_a_hand"].duplicate(true)
	d.family["lend_a_hand"]["yields"]["hoe"]["item"] = "no_such_item"
	d.family["lend_a_hand"]["verbs"]["dance"] = "dancing"
	d.family["lend_a_hand"]["max_favor"] = 10
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	assert_true(text.contains("unknown item") and text.contains("unknown activity 'dance'") and text.contains("max_favor"))
	d.family["lend_a_hand"] = old
	d.load_errors.clear()


func test_make_friend_hint() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var hint := Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {})
	assert_true(hint.begins_with("Make a friend: lend "), hint)
	var step2 := Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {"elder_mo": 25})
	assert_true(step2.begins_with("Become friends: lend "), step2)
	assert_true(step2.ends_with("/40)."), step2)
	assert_eq(Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {"elder_mo": 41}), "")


func test_make_friend_gift_form() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var flags := {}
	var liked := ""
	for item_id: String in d.items:
		if Family.gift_taste(d, "elder_mo", item_id) == 1 and Family.gift_value(d, item_id) > 0:
			liked = item_id
			break
	assert_true(liked != "", "elder_mo likes some item")
	c.add_item(liked, 1)
	var favor := {"elder_mo": 25}
	for id: String in d.npcs:
		flags["lend_" + id] = 0
	var gift := Guidance.make_friend_hint(c, d, npcs, flags, "qingshi_village", 0, favor)
	assert_true(gift.begins_with("Become friends: give "), gift)
	assert_true(gift.contains(String(d.items[liked].get("name", liked))), gift)
	assert_eq(Guidance.make_friend_hint(new_character(), d, npcs, flags, "qingshi_village", 0, favor), "")


func test_friend_line_in_first_four() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var lines := Guidance.hints(c, d, 1.0, 8, npcs, {}, "qingshi_village", 0, {})
	var idx := -1
	for i in lines.size():
		if lines[i].begins_with("Make a friend: lend "):
			idx = i
	assert_true(idx >= 0 and idx < 4, "friend line index %d in %s" % [idx, lines])
