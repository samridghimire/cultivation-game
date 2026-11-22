extends TestCase
## WU-599: the "<Name> tends your wounds" card text and its overlay behaviour.


func test_card_text() -> void:
	var c := Folk.tend_card("Hunter Ma", 12, "He binds your ribs.", "hunter_ma")
	assert_eq(c["card_title"], "Hunter Ma tends your wounds")
	assert_eq(c["lines"], ["He binds your ribs.", "12 days of healing"])
	assert_eq(c["tea_npc"], "hunter_ma")


func test_card_singular_and_no_line() -> void:
	var c := Folk.tend_card("Xiao Ling", 1, "", "xiao_ling")
	assert_eq(c["lines"], ["1 day of healing"])


func test_overlay_shows_title_without_duration_and_hides_bar() -> void:
	var o := TimeSkipOverlay.new()
	o.show_skip(Folk.tend_card("Hunter Ma", 5, "A line.", "hunter_ma"))
	assert_true(o.visible)
	assert_eq(o.summary_text(), "A line.\n5 days of healing")
	assert_false(o._bar.visible)
	assert_eq(o._title.text, "Hunter Ma tends your wounds")
	o.close()
	o.free()
