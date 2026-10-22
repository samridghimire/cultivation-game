extends TestCase
## WU-269: world labels are shifted to stay inside the visible screen.


func test_inside_is_unchanged() -> void:
	assert_eq(Interactable.clamp_label_left(100.0, 80.0, 0.0, 1280.0), 100.0)


func test_past_the_right_ends_at_the_margin() -> void:
	var left := Interactable.clamp_label_left(1250.0, 80.0, 0.0, 1280.0)
	assert_eq(left + 80.0, 1276.0)


func test_past_the_left_starts_at_the_margin() -> void:
	assert_eq(Interactable.clamp_label_left(-30.0, 80.0, 0.0, 1280.0), 4.0)


func test_too_wide_starts_at_the_left_margin() -> void:
	assert_eq(Interactable.clamp_label_left(10.0, 2000.0, 0.0, 1280.0), 4.0)
