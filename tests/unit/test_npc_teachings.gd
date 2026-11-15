extends TestCase
## TEACH-001: Npcs.teachings lists what a villager can teach.


func test_hunter_ma_lists_iron_fist_and_lessons() -> void:
	var c := CharacterData.new()
	var list := Npcs.teachings("hunter_ma", c, data(), 0)
	var fist := list.filter(func(t: Dictionary) -> bool: return t["kind"] == "technique")
	assert_eq(fist.size(), 1)
	assert_eq(int(fist[0]["need_favor"]), 15)
	assert_false(bool(fist[0]["known"]))
	assert_eq(String(fist[0]["text"]), "Iron Fist (favor 0/15)")
	var lessons := list.filter(func(t: Dictionary) -> bool: return t["kind"] == "lesson")
	assert_eq(lessons.size(), 2)
	assert_eq(int(list[0]["need_favor"]), 15, "sorted by need")
	for i in range(1, list.size()):
		assert_true(int(list[i]["need_favor"]) >= int(list[i - 1]["need_favor"]))
	for t in list:
		assert_true(String(t["text"]).length() <= 60)


func test_known_technique_and_lesson_flagged() -> void:
	var c := CharacterData.new()
	c.techniques["iron_fist"] = 1
	c.lessons_taught["hunter_ma:0"] = 3
	var list := Npcs.teachings("hunter_ma", c, data(), 0)
	for t in list:
		if t["kind"] == "technique":
			assert_true(bool(t["known"]))
	var known_lessons := list.filter(func(t: Dictionary) -> bool: return t["kind"] == "lesson" and t["known"])
	assert_eq(known_lessons.size(), 1)


func test_no_teaching_returns_empty() -> void:
	var c := CharacterData.new()
	for id: String in data().npcs:
		if not data().npcs[id].has("lessons") and not data().dialogues.has(String(data().npcs[id].get("dialogue", ""))):
			assert_eq(Npcs.teachings(id, c, data(), 0).size(), 0)
	assert_eq(Npcs.teachings("nobody", c, data(), 0).size(), 0)


## WU-539: a locked technique shows progress; once reachable it shows the plain need.
func test_teaching_text_shows_progress() -> void:
	var c := CharacterData.new()
	var fist := Npcs.teachings("hunter_ma", c, data(), 4).filter(func(t: Dictionary) -> bool: return t["kind"] == "technique")
	assert_eq(String(fist[0]["text"]), "Iron Fist (favor 4/15)")
	fist = Npcs.teachings("hunter_ma", c, data(), 20).filter(func(t: Dictionary) -> bool: return t["kind"] == "technique")
	assert_eq(String(fist[0]["text"]), "Iron Fist - ready, ask when you Talk")


## WU-541: ready lessons read "ready", locked ones keep their favor text, and Talk is marked only for a ready dialogue lesson.
func test_ready_technique_and_lesson_text() -> void:
	var c := CharacterData.new()
	var list := Npcs.teachings("hunter_ma", c, data(), 100)
	var fist: Dictionary = list.filter(func(t: Dictionary) -> bool: return t["kind"] == "technique")[0]
	assert_true(bool(fist["ready"]))
	assert_eq(String(fist["text"]), "Iron Fist - ready, ask when you Talk")
	assert_true(Npcs.talk_lesson_ready(list))
	for t in list:
		if t["kind"] == "lesson" and bool(t["ready"]):
			assert_true(String(t["text"]).ends_with("lesson - ready"))


func test_locked_text_unchanged_and_no_talk_marker() -> void:
	var c := CharacterData.new()
	var list := Npcs.teachings("hunter_ma", c, data(), 0)
	for t in list:
		assert_false(bool(t["ready"]))
	assert_eq(String(list[0]["text"]), "Iron Fist (favor 0/15)")
	assert_false(Npcs.talk_lesson_ready(list))
	c.techniques["iron_fist"] = 1
	assert_false(Npcs.talk_lesson_ready(Npcs.teachings("hunter_ma", c, data(), 100)), "known technique is not ready")


func test_likes_line_helper() -> void:
	assert_eq(Npcs.likes_line({}, data(), "hunter_ma"), "")
