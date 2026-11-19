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


## WU-475: a 7-label cluster keeps the focus, a place and the nearest villager only.
func test_crowd_keep_cluster_keeps_three() -> void:
	var rects: Array[Rect2] = []
	var prio: Array[int] = []
	for i in 7:
		rects.append(Rect2(400 + i * 15, 300 + (i % 2) * 10, 70, 14))
		prio.append(2)
	prio[5] = 1
	var keep := LabelLayout.crowd_keep(rects, prio, 3)
	assert_eq(keep.count(true), 3)
	assert_true(keep[3], "focus kept")
	assert_true(keep[5], "place kept")
	assert_true(keep[0], "nearest kept")


func test_crowd_keep_spread_set_keeps_all() -> void:
	var rects: Array[Rect2] = []
	var prio: Array[int] = []
	for i in 6:
		rects.append(Rect2(i * 400, 100, 70, 14))
		prio.append(2)
	assert_eq(LabelLayout.crowd_keep(rects, prio, -1).count(true), 6)


func test_blocker_at_bottom_pushes_label_up() -> void:
	var bar := Rect2(0, 740, 1280, 60)
	var blockers: Array[Rect2] = [bar]
	var rects: Array[Rect2] = [Rect2(600, 735, 80, 14)]
	var res := LabelLayout.resolve(rects, SCREEN, blockers)
	var moved := Rect2(rects[0].position + Vector2(0, float(res[0]["offset"])), rects[0].size)
	assert_false(moved.intersects(bar))
	assert_true(float(res[0]["offset"]) < 0.0)


func test_label_moves_below_a_building_it_would_sit_on() -> void:
	var rects: Array[Rect2] = [Rect2(100, 100, 80, 16)]
	var roof := Rect2(90, 60, 100, 50)
	var out := LabelLayout.resolve(rects, Rect2(0, 0, 1280, 800), [], {}, {0: [roof]})
	assert_gt(float(out[0]["offset"]), 0.0, "moved down, not up")
	assert_false(bool(out[0]["faded"]))
	var free := LabelLayout.resolve(rects, Rect2(0, 0, 1280, 800), [], {}, {0: [Rect2(600, 600, 50, 50)]})
	assert_eq(float(free[0]["offset"]), 0.0)


func test_place_label_pushed_by_hud_never_lands_on_own_art() -> void:  # WU-562
	var label := Rect2(100, 100, 80, 16)
	var own_art := Rect2(110, 118, 70, 60)  # just below the label
	var hud: Array[Rect2] = [Rect2(80, 90, 120, 20)]  # covers the label, nudging down is the first try
	var out := LabelLayout.resolve([label] as Array[Rect2], Rect2(0, 0, 1280, 800), hud, {}, {0: [own_art]})
	var moved := Rect2(label.position + Vector2(0, float(out[0]["offset"])), label.size)
	assert_false(moved.intersects(own_art), "label stays off its own art")


## WU-511: a person's label that meets a place label drops below their feet, else slides sideways.
func test_person_offset_clear_label_stays() -> void:
	var places: Array[Rect2] = [Rect2(500, 500, 100, 20)]
	assert_eq(LabelLayout.person_offset(Rect2(0, 0, 80, 20), 100.0, places), Vector2.ZERO)


func test_person_offset_lift_is_capped() -> void:  # GFX-206
	var places: Array[Rect2] = [Rect2(90, 40, 100, 30)]  # directly above the head, label under it
	var label := Rect2(100, 70, 80, 20)
	var d := LabelLayout.person_offset(label, 120.0, places)
	assert_true(-d.y <= LabelLayout.PERSON_MAX_LIFT or label.position.y + d.y >= 120.0, "lift %s" % d)
	assert_false(Rect2(label.position + d, label.size).intersects(places[0].grow(2.0)))


func test_person_offset_falls_below_feet() -> void:  # GFX-206
	var places: Array[Rect2] = [Rect2(20, 60, 260, 20)]
	var label := Rect2(100, 70, 80, 20)
	var d := LabelLayout.person_offset(label, 120.0, places)
	assert_true(d.y > 0.0, "below the feet: %s" % d)
	assert_true(label.position.y + d.y >= 122.0 - 0.01)
	assert_false(Rect2(label.position + d, label.size).intersects(places[0].grow(2.0)))


func test_person_offset_boxed_in_gives_zero() -> void:  # GFX-206
	var places: Array[Rect2] = [Rect2(-200, 40, 700, 100)]
	var label := Rect2(100, 70, 80, 20)
	assert_eq(LabelLayout.person_offset(label, 120.0, places), Vector2.ZERO)
	assert_true(LabelLayout.person_blocked(label, places))


func test_covered_label_slides_sideways_clear_of_building() -> void:  # WU-540
	var place_label := Rect2(300, 505, 160, 16)
	var person := Rect2(388, 535, 84, 16)
	var roof := Rect2(335, 533, 90, 80)
	var rects: Array[Rect2] = [place_label, person]
	var res := LabelLayout.resolve(rects, SCREEN, [], {}, {1: [roof, place_label]})
	assert_false(res[1]["faded"])
	var moved := Rect2(person.position + Vector2(res[1]["dx"], res[1]["offset"]), person.size)
	assert_false(moved.intersects(roof))
	assert_false(moved.intersects(place_label))


func test_separate_crowded_case_has_no_overlaps_and_fixed_stay() -> void:
	var rects: Array[Rect2] = [Rect2(100, 100, 120, 16), Rect2(110, 104, 100, 16), Rect2(105, 98, 90, 16), Rect2(300, 300, 50, 16)]
	var fixed: Array[bool] = [true, false, false, false]
	var res := LabelLayout.separate(rects, fixed)
	assert_eq(res[0]["dy"], 0.0)
	assert_eq(res[3]["dy"], 0.0)
	var shown: Array[Rect2] = []
	for i in rects.size():
		if not res[i]["faded"]:
			shown.append(Rect2(rects[i].position + Vector2(0, res[i]["dy"]), rects[i].size))
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			assert_false(shown[i].intersects(shown[j]))


func test_separate_is_deterministic_and_fades_when_stuck() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 16), Rect2(0, -16, 100, 16), Rect2(0, 16, 100, 16), Rect2(0, -32, 100, 16), Rect2(0, 32, 100, 16), Rect2(0, 0, 100, 16)]
	var fixed: Array[bool] = [true, true, true, true, true, false]
	var a := LabelLayout.separate(rects, fixed)
	var b := LabelLayout.separate(rects, fixed)
	assert_eq(a, b)
	assert_true(a[5]["faded"])


## GFX-201: a label that overlaps the player's sprite rect moves above it, or below when above leaves the map.
func test_label_clears_player_sprite() -> void:
	var bounds := Rect2(0, 0, 1600, 1000)
	var player := Rect2(784, 556, 32, 50)
	var label := Rect2(740, 570, 120, 18)  # right at the player's position
	var dy := LabelLayout.clear_of(label, player, bounds)
	assert_true(dy < 0.0, "lifted above the sprite")
	assert_false(Rect2(label.position + Vector2(0, dy), label.size).intersects(player), "clear of the sprite")
	var top_player := Rect2(784, 4, 32, 50)
	var top_label := Rect2(740, 20, 120, 18)
	var dy2 := LabelLayout.clear_of(top_label, top_player, bounds)
	assert_true(dy2 > 0.0, "below the sprite when above leaves the map")
	assert_eq(LabelLayout.clear_of(Rect2(100, 100, 50, 18), player, bounds), 0.0, "far labels stay put")
