extends TestCase
## WU-600: the "From <Name>" gift card queue.


func test_item_text() -> void:
	assert_eq(GiftLeftCard.item_text("Honey", 1), "Honey")
	assert_eq(GiftLeftCard.item_text("Honey", 3), "Honey x3")


func test_queue_keeps_order_and_empties_after_skips() -> void:
	var c := GiftLeftCard.new()
	c.enqueue("Ma", "x", 1, "first")
	c.enqueue("Ling", "x", 2, "second")
	c.enqueue("Tian", "x", 1, "third")
	assert_true(c.visible)
	assert_eq(c._title.text, "From Ma")
	assert_eq(c.queued_count(), 2)
	c.skip()
	assert_eq(c._title.text, "From Ling")
	assert_eq(c._line.text, "second")
	c.skip()
	assert_eq(c._title.text, "From Tian")
	c.skip()
	assert_false(c.visible)
	assert_eq(c.queued_count(), 0)
	c.free()


func test_hold_runs_out_to_next() -> void:
	var c := GiftLeftCard.new()
	c.enqueue("Ma", "x", 1, "a")
	c.enqueue("Ling", "x", 1, "b")
	c._process(GiftLeftCard.HOLD_SECONDS + 0.1)
	assert_eq(c._title.text, "From Ling")
	c._process(GiftLeftCard.HOLD_SECONDS + 0.1)
	assert_false(c.visible)
	c.free()
