extends TestCase
## WU-401: who greets the player now.


func _c(id: String, x: float) -> Dictionary:
	return {"id": id, "pos": Vector2(x, 0)}


func test_nearest_within_radius() -> void:
	var people := [_c("a", 50), _c("b", 20), _c("c", 200)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, false, false), "b")


func test_out_of_range_is_silent() -> void:
	assert_eq(VillagerGreeting.pick([_c("a", 61)], Vector2.ZERO, {}, 5, false, false), "")
	assert_eq(VillagerGreeting.pick([_c("a", 60)], Vector2.ZERO, {}, 5, false, false), "a")


func test_already_greeted_today() -> void:
	var people := [_c("a", 10), _c("b", 40)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {"a": 5}, 5, false, false), "b")
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {"a": 4}, 5, false, false), "a")


func test_modal_or_active_bubble_blocks() -> void:
	var people := [_c("a", 10)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, true, false), "")
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, false, true), "")
