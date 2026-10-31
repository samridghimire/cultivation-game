extends TestCase
## GFX-037: seasonal looks for trees, fields and roofs are pure and distinct.

const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]


func test_tree_look_differs_per_season() -> void:
	var seen := {}
	for s: String in SEASONS:
		var look := Scenery.tree_look(s, 42)
		seen[str(look)] = true
	assert_eq(seen.size(), 4)


func test_tree_look_deterministic() -> void:
	for s: String in SEASONS:
		assert_eq(Scenery.tree_look(s, 77), Scenery.tree_look(s, 77))


func test_winter_trees_bare_and_snowy_others_leafy() -> void:
	assert_true(Scenery.tree_look("Winter", 1)["bare"])
	assert_true(Scenery.tree_look("Winter", 1)["snow"])
	assert_false(Scenery.tree_look("Summer", 1)["bare"])
	assert_true(int(Scenery.tree_look("Spring", 1)["blossoms"]) > 0)
	assert_true(int(Scenery.tree_look("Autumn", 1)["leaves"]) > 0)


func test_field_crops_by_season() -> void:
	assert_true(Scenery.crop_color("Spring") != Scenery.crop_color("Autumn"))
	assert_eq(Scenery.crop_color("Winter").a, 0.0)
	assert_true(Scenery.is_snowy("Winter"))
	assert_false(Scenery.is_snowy("Autumn"))


func test_winter_tint_is_light() -> void:
	assert_true(Calendar.season_tint("Winter").r >= 0.93)
