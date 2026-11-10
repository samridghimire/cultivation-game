extends TestCase
## C-321: the named villagers' real lessons exist, validate and stay small.


func test_friends_have_lessons() -> void:
	var d := GameData.load_from_dir()
	for id in ["elder_mo", "xiao_ling", "hunter_ma", "herbalist_lan", "alchemist_hua"]:
		var lessons := Folk.lessons_of(d, id)
		assert_true(lessons.size() >= 1 and lessons.size() <= 2, "%s has 1-2 lessons" % id)
		assert_eq(int(lessons[0]["tier"]), 2, "%s first lesson at Close friend" % id)
		for lesson: Dictionary in lessons:
			for key: Variant in lesson["effects"]:
				assert_false(["qi", "attributes"].has(String(key)), "%s: no qi or attributes" % id)
			assert_false(lesson["effects"].has("items") and lesson["effects"]["items"].has("spirit_stone"), "no stones")
	assert_eq(Folk.validate_lessons(d).size(), 0)
