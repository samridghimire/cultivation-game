extends TestCase
## RV-002: banners queue instead of replacing each other.

func test_second_announce_waits_for_first() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	b.announce("Milestone", "a", Color.WHITE)
	assert_eq(b.title_text(), "Breakthrough!")
	assert_eq(b.queued_count(), 1)
	b.finish_current()
	assert_eq(b.title_text(), "Milestone")
	b.finish_current()
	assert_false(b.visible)
	b.free()


func test_queue_capped_dropping_milestones_first() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	for i in 5:
		b.announce("Milestone", str(i), Color.WHITE)
	assert_eq(b.queued_count(), Banner.MAX_QUEUE)
	b.finish_current()
	assert_eq(b.subtitle_text(), "1")
	b.free()
