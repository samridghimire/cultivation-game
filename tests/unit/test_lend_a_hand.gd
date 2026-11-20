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
	assert_eq(Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {"elder_mo": 20}), "")
