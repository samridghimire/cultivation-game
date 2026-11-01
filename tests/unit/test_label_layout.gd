extends TestCase
## WU-421: LabelLayout keeps overlapping labels apart or fades them.

const SCREEN := Rect2(0, 0, 1280, 800)


func _overlap_free(rects: Array[Rect2], res: Array[Dictionary]) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a := Rect2(rects[i].position + Vector2(0, res[i]["offset"]), rects[i].size)
			var b := Rect2(rects[j].position + Vector2(0, res[j]["offset"]), rects[j].size)
			if a.intersects(b) and not res[i]["faded"] and not res[j]["faded"]:
				return false
	return true


func test_three_overlapping_rects_end_apart_or_faded() -> void:
	var rects: Array[Rect2] = [Rect2(4, 300, 120, 16), Rect2(4, 302, 140, 16), Rect2(4, 304, 100, 16)]
	var res := LabelLayout.resolve(rects, SCREEN)
	assert_eq(res.size(), 3)
	assert_true(_overlap_free(rects, res))


func test_priority_rect_never_moves() -> void:
	var rects: Array[Rect2] = [Rect2(4, 300, 120, 16), Rect2(4, 300, 120, 16)]
	var res := LabelLayout.resolve(rects, SCREEN)
	assert_eq(res[0]["offset"], 0.0)
	assert_false(res[0]["faded"])
	assert_true(res[1]["offset"] != 0.0 or res[1]["faded"])


func test_lone_rect_is_untouched() -> void:
	var rects: Array[Rect2] = [Rect2(600, 400, 80, 16)]
	var res := LabelLayout.resolve(rects, SCREEN)
	assert_eq(res[0]["offset"], 0.0)
	assert_false(res[0]["faded"])


func test_unresolvable_rect_fades_in_place() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 500, 500), Rect2(10, 10, 50, 16)]
	var res := LabelLayout.resolve(rects, SCREEN)
	assert_eq(res[1]["offset"], 0.0)
	assert_true(res[1]["faded"])


func test_blockers_push_a_rect_clear() -> void:
	var rects: Array[Rect2] = [Rect2(10, 100, 80, 16)]
	var block: Array[Rect2] = [Rect2(0, 90, 200, 20)]
	var res := LabelLayout.resolve(rects, SCREEN, block)
	assert_false(res[0]["faded"])
	assert_true(res[0]["offset"] != 0.0)
