extends TestCase
## GUIDE-259: the quick first rating stage must not change which fights fair_fights shows, nor their odds.


func _build(d: GameData, realm: String, stage: int) -> CharacterData:
	var c := CharacterFactory.create("Quick", d, seeded_rng(3), "male")
	c.spiritual_roots = {"fire": 70, "wood": 50}
	c.realm_index = d.realm_index_of(realm)
	c.stage = stage
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}, "stone_skin": {"level": 2, "xp": 0.0}}
	return c


func test_quick_stage_keeps_the_shown_fights() -> void:
	var d := data()
	var builds: Array = [["mortal", 0], ["qi_refining", 5], ["foundation_establishment", 3]]
	var saved := Guidance.fair_quick_margin
	for b: Array in builds:
		var c := _build(d, String(b[0]), int(b[1]))
		for region_id: String in d.regions:
			Combat._chance_cache.clear()
			Guidance.fair_quick_margin = 2.0  # quick stage off: every rating is the full one
			var full := Guidance.fair_fights(c, d, {}, 100, region_id)
			Combat._chance_cache.clear()
			Guidance.fair_quick_margin = saved
			var quick := Guidance.fair_fights(c, d, {}, 100, region_id)
			assert_eq(quick, full, "%s %d in %s: same fights and odds" % [b[0], b[1], region_id])
	Guidance.fair_quick_margin = saved
