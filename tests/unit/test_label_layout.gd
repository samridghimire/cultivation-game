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


func test_offsets_three_stacked_rects_apart_and_stable() -> void:
	var rects: Array[Rect2] = [Rect2(4, 300, 120, 16), Rect2(4, 302, 140, 16), Rect2(4, 304, 100, 16)]
	var anchors: Array[Vector2] = [Vector2(60, 330), Vector2(60, 332), Vector2(60, 334)]
	var offs := LabelLayout.offsets(rects, anchors)
	for i in 3:
		for j in range(i + 1, 3):
			var a := Rect2(rects[i].position + offs[i], rects[i].size)
			var b := Rect2(rects[j].position + offs[j], rects[j].size)
			assert_false(a.intersects(b), "labels %d and %d overlap" % [i, j])
	assert_eq(offs[0], Vector2.ZERO)
	assert_eq(LabelLayout.offsets(rects, anchors), offs)


## GFX-071: a great beast's body blocks other labels but not its own.
func test_figure_blocker_moves_other_labels_not_its_own() -> void:
	var figure := Rect2(400, 300, 48, 40)
	var rects: Array[Rect2] = [Rect2(396, 304, 70, 14), Rect2(396, 322, 70, 14)]
	var blockers: Array[Rect2] = [figure]
	var res := LabelLayout.resolve(rects, SCREEN, blockers, {0: 0})
	assert_eq(res[0]["offset"], 0.0, "own label stays")
	assert_false(res[0]["faded"], "own label visible")
	var moved: Rect2 = Rect2(rects[1].position + Vector2(0, float(res[1]["offset"])), rects[1].size)
	assert_true(bool(res[1]["faded"]) or not moved.intersects(figure), "other label leaves the figure or fades")
