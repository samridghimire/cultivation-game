extends TestCase
## GFX-264: the aura under a friend who cultivates.

func test_mortal_has_none() -> void:
	assert_eq(float(FriendAura.aura_for(0)["alpha"]), 0.0)
	assert_eq(float(FriendAura.alpha_at(0, 1.0, false)), 0.0)


func test_qi_refining_aura_no_rim_foundation_rim() -> void:
	var q := FriendAura.aura_for(1)
	assert_true(float(q["alpha"]) > 0.0 and float(q["alpha"]) <= 0.35)
	assert_false(bool(q["rim"]))
	assert_true(bool(FriendAura.aura_for(2)["rim"]))
	assert_true(float(FriendAura.aura_for(2)["radius"]) > float(q["radius"]))


func test_alpha_cap_and_calm() -> void:
	for r in [1, 2, 3, 6]:
		for step in 30:
			assert_true(FriendAura.alpha_at(r, float(step) * 0.1, false) <= 0.35)
		assert_eq(FriendAura.alpha_at(r, 0.7, true), FriendAura.alpha_at(r, 2.2, true), "still with reduce_motion")
	assert_true(absf(FriendAura.alpha_at(1, 0.75, false) - FriendAura.alpha_at(1, 2.25, false)) > 0.01, "pulses")


func test_color_for_main_root() -> void:
	var c := CharacterData.new()
	c.spiritual_roots = {"fire": 20, "water": 60}
	assert_eq(FriendAura.color_for(c), CharacterSheet.ELEMENT_COLORS["water"])
	assert_eq(FriendAura.color_for(CharacterData.new()), FriendAura.FALLBACK)
