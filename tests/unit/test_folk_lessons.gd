extends TestCase
## FOLK-020: friends who teach (Folk.due_lessons / validate_lessons).


func test_due_lessons_by_tier() -> void:
	var d := data()
	var taught := {}
	assert_eq(Folk.due_lessons(d, "hunter_ma", 1, taught).size(), 0, "below the tier")
	var due := Folk.due_lessons(d, "hunter_ma", 2, taught)
	assert_eq(due.size(), 1, "at the tier")
	taught[String(due[0]["key"])] = 5
	assert_eq(Folk.due_lessons(d, "hunter_ma", 3, taught).size(), 0, "once taught")
	assert_eq(Folk.due_lessons(d, "nobody", 3, {}).size(), 0)


func test_validation_rejects_bad_lessons() -> void:
	var d := data()
	assert_eq(Folk.validate_lessons(d).size(), 0)
	var original: Variant = d.npcs["hunter_ma"].get("lessons")
	var cases: Array = [
		[{"tier": 0, "text": "x", "effects": {"practice_days": 2}}],
		[{"tier": 2, "text": "x", "effects": {"qi": 5}}],
		[{"tier": 2, "text": "x", "effects": {"attributes": {"fortune": 3}}}],
		[{"tier": 2, "text": "x".repeat(300), "effects": {"practice_days": 2}}],
		[{"tier": 3, "text": "a", "effects": {"practice_days": 2}}, {"tier": 2, "text": "b", "effects": {"practice_days": 2}}],
	]
	for bad: Array in cases:
		d.npcs["hunter_ma"]["lessons"] = bad
		assert_true(Folk.validate_lessons(d).size() > 0, "rejected: " + str(bad))
	d.npcs["hunter_ma"]["lessons"] = original
	assert_eq(Folk.validate_lessons(d).size(), 0)
