extends TestCase
## LETTER-001: letters from friends (Letters).


func _friend(id: String = "friend") -> Dictionary:
	var npc := new_character(77)
	npc.id = id
	npc.name = "Friend " + id
	return {id: npc}


func _only(kind_id: String) -> void:
	var rules: Dictionary = data().family["letters"]
	rules["monthly_chance"] = 1.0
	var kinds: Array = []
	for kind: Dictionary in rules["kinds"]:
		if kind["id"] == kind_id:
			kinds.append(kind)
	rules["kinds"] = kinds


func test_data_validates() -> void:
	assert_eq(Letters.validate(data()).size(), 0)
	var d := GameData.load_from_dir()
	d.family["letters"]["monthly_chance"] = 2.0
	assert_eq(Letters.validate(d).size(), 1)


func test_no_letter_below_min_favor() -> void:
	var d := GameData.load_from_dir()
	d.family["letters"]["monthly_chance"] = 1.0
	var c := new_character()
	var min_favor := int(d.family["letters"]["min_favor"])
	assert_eq(Letters.writer(c, _friend(), {"friend": min_favor - 1}, d), "")
	assert_true(Letters.monthly(c, _friend(), {"friend": min_favor - 1}, d, seeded_rng(), {}).is_empty())


func test_writer_skips_family_dead_and_unknown() -> void:
	var d := data()
	var c := new_character()
	var people := _friend("a")
	people.merge(_friend("b"))
	people.merge(_friend("c"))
	people["b"].alive = false
	c.spouses.append("c")
	assert_eq(Letters.writer(c, people, {"a": 50, "b": 90, "c": 95, "ghost": 99}, d), "a")


func test_best_friend_writes_ties_by_id() -> void:
	var c := new_character()
	var people := _friend("a")
	people.merge(_friend("b"))
	assert_eq(Letters.writer(c, people, {"b": 60, "a": 60}, data()), "a")
	assert_eq(Letters.writer(c, people, {"b": 70, "a": 60}, data()), "b")


func test_gift_lands_in_inventory() -> void:
	var d := GameData.load_from_dir()
	d.family["letters"]["monthly_chance"] = 1.0
	d.family["letters"]["kinds"] = [d.family["letters"]["kinds"][0]]
	var c := new_character()
	var before := c.item_count("spirit_herb")
	var letter := Letters.monthly(c, _friend(), {"friend": 50}, d, seeded_rng(), {})
	assert_eq(letter["npc_id"], "friend")
	assert_true(String(letter["text"]).contains("Friend friend"))
	assert_eq(c.item_count("spirit_herb"), before + 1)


func test_deterministic_with_seed() -> void:
	var d := GameData.load_from_dir()
	d.family["letters"]["monthly_chance"] = 1.0
	var a := Letters.monthly(new_character(), _friend(), {"friend": 50}, d, seeded_rng(5), {})
	var b := Letters.monthly(new_character(), _friend(), {"friend": 50}, d, seeded_rng(5), {})
	assert_eq(a["text"], b["text"])


func test_invitation_sets_flag_and_bonus_applies_once() -> void:
	var d := GameData.load_from_dir()
	d.family["letters"]["monthly_chance"] = 1.0
	d.family["letters"]["kinds"] = [d.family["letters"]["kinds"][2]]
	var flags := {}
	var letter := Letters.monthly(new_character(), _friend(), {"friend": 50}, d, seeded_rng(), flags)
	assert_false(letter.is_empty())
	assert_true(flags.has("letter_visit_friend"))
	assert_eq(Letters.take_visit_bonus("friend", d, flags), int(d.family["letters"]["visit_favor"]))
	assert_eq(Letters.take_visit_bonus("friend", d, flags), 0, "consumed")


func test_remember_keeps_the_last_few() -> void:
	var c := new_character()
	var max_kept := int(data().family["letters"]["max_kept"])
	for i in max_kept + 3:
		Letters.remember(c, data(), "n%d" % i)
	assert_eq(c.letters.size(), max_kept)
	assert_eq(c.letters.back(), "n%d" % (max_kept + 2))


func test_save_round_trip_and_old_saves() -> void:
	var c := new_character()
	Letters.remember(c, data(), "hello")
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.letters.size(), 1)
	assert_eq(back.letters[0], "hello")
	var old := c.to_dict()
	old.erase("letters")
	assert_eq(CharacterData.from_dict(old).letters.size(), 0)


func test_journal_lists_letters_newest_first() -> void:
	var c := new_character()
	assert_eq(Letters.journal_lines(c).size(), 0)
	var d := data()
	var none := Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Letters")
	assert_eq(none.size(), 0, "hidden when empty")
	for i in 7:
		Letters.remember(c, d, "A letter from Pen %d: hello" % i)
	var lines := Letters.journal_lines(c)
	assert_eq(lines.size(), 5)
	assert_eq(lines[0], "Pen 6: hello")
	var entries := Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Letters")
	assert_eq(entries.size(), 5)
	assert_eq(entries[0]["text"], "Pen 6: hello")


func test_letter_banner_text() -> void:
	assert_eq(load("res://src/ui/hud.gd").letter_banner("Lu"), PackedStringArray(["A letter", "from Lu"]))


func test_every_letter_kind_formats_and_applies() -> void:
	var d := GameData.load_from_dir()
	var friend := _friend()
	for kind: Dictionary in d.family["letters"]["kinds"]:
		var all: Dictionary = d.family["letters"]
		var keep: Array = all["kinds"]
		all["monthly_chance"] = 1.0
		all["kinds"] = [kind]
		var c := new_character()
		var letter := Letters.monthly(c, friend, {"friend": 100}, d, seeded_rng(), {})
		all["kinds"] = keep
		assert_false(letter.is_empty(), "kind %s sends" % kind["id"])
		var text := String(letter["text"])
		if String(kind["text"]).contains("{name}"):
			assert_true(text.contains("Friend friend"), "kind %s names the writer" % kind["id"])
		assert_false(text.contains("{"), "kind %s leaves no placeholder" % kind["id"])


func test_pill_request_creates_one_request() -> void:
	_only("pill_request")
	var c := new_character()
	var letter := Letters.monthly(c, _friend(), {"friend": 50}, data(), seeded_rng(), {}, 100)
	assert_true(letter["request"])
	assert_eq(c.letter_requests.size(), 1)
	assert_eq(int(c.letter_requests[0]["until"]), 190)
	var again := Letters.monthly(c, _friend(), {"friend": 50}, data(), seeded_rng(), {}, 110)
	assert_false(again["request"], "no duplicate")
	assert_eq(c.letter_requests.size(), 1)


func test_answer_request() -> void:
	_only("pill_request")
	var c := new_character()
	Letters.monthly(c, _friend(), {"friend": 50}, data(), seeded_rng(), {}, 100)
	assert_eq(Letters.check_answer(c, data(), "nobody", 100), "No letter from them is waiting for an answer.")
	assert_true(Letters.check_answer(c, data(), "friend", 100).begins_with("They asked for 1 Qi Gathering Pill; you have 0."))
	assert_eq(Letters.request_lines(c, data(), _friend(), 100).size(), 1)
	c.add_item("qi_gathering_pill", 2)
	var align := c.alignment
	var res := Letters.answer(c, data(), "friend", 100, {})
	assert_true(res["ok"])
	assert_eq(res["favor"], 10)
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.letter_requests.size(), 0)
	assert_gt(c.alignment, align)


func test_expire_requests() -> void:
	var c := new_character()
	c.letter_requests.append({"npc_id": "a", "item": "qi_gathering_pill", "count": 1, "until": 50, "favor": 1, "effects": {}})
	c.letter_requests.append({"npc_id": "b", "item": "qi_gathering_pill", "count": 1, "until": 150, "favor": 1, "effects": {}})
	assert_eq(Letters.expire_requests(c, 100), ["a"] as Array[String])
	assert_eq(c.letter_requests.size(), 1)


func test_request_validation_and_save() -> void:
	var d := GameData.load_from_dir()
	for kind: Dictionary in d.family["letters"]["kinds"]:
		if kind["id"] == "pill_request":
			kind["request"]["item"] = "nope"
	assert_eq(Letters.validate(d).size(), 1)
	for kind: Dictionary in d.family["letters"]["kinds"]:
		if kind["id"] == "pill_request":
			kind["request"] = {"item": "qi_gathering_pill", "count": 0, "days": 1, "favor": 0}
	assert_eq(Letters.validate(d).size(), 1)
	var c := new_character()
	c.letter_requests.append({"npc_id": "a", "item": "qi_gathering_pill", "count": 1, "until": 50, "favor": 1, "effects": {}})
	assert_eq(CharacterData.from_dict(c.to_dict()).letter_requests.size(), 1)
	var old := c.to_dict()
	old.erase("letter_requests")
	assert_eq(CharacterData.from_dict(old).letter_requests.size(), 0)
