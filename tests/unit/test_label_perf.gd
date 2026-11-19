extends TestCase
## PERF-019: label measuring is cached and the walking re-spread is throttled.


func test_text_size_is_cached_and_matches_label_rect() -> void:
	var a := Interactable.label_text_size("Elder Mo")
	var b := Interactable.label_text_size("Elder Mo")
	assert_eq(a, b)
	assert_true(a.x > 0.0 and a.y > 0.0)
	var n := Interactable.new()
	n.display_name = "Elder Mo"
	var r := n.label_rect()
	assert_almost_eq(r.size.x, a.x, 0.001)
	assert_almost_eq(r.size.y, a.y, 0.001)
	n.free()


func test_walk_respread_interval_is_a_few_times_a_second() -> void:
	var every: float = load("res://src/world/world.gd").WALK_RESPREAD_INTERVAL
	assert_true(every >= 0.1 and every <= 0.35)

