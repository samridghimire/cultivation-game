extends TestCase
## WU-581: heart pips beside a villager's name at folk friendship tiers.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func test_pip_tier_edges() -> void:
	assert_eq(NPC_SCRIPT.pips_for(19, data()), 0)
	assert_eq(NPC_SCRIPT.pips_for(20, data()), 1)
	assert_eq(NPC_SCRIPT.pips_for(40, data()), 2)
	assert_eq(NPC_SCRIPT.pips_for(60, data()), 3)
	assert_eq(NPC_SCRIPT.pips_for(85, data()), 3)


## WU-583: the strip after a name is [pips][2 px][marker]; the marker never starts inside the pips.
func test_strip_layout_marker_after_pips() -> void:
	var lay: Dictionary = NPC_SCRIPT.strip_layout(34.0, 8.0)
	assert_true(float(lay["marker_x"]) - 8.0 >= float(lay["pips_right"]) + NPC_SCRIPT.STRIP_GAP)
	assert_eq(float(lay["width"]), 34.0 + 2.0 + 16.0)
	var none: Dictionary = NPC_SCRIPT.strip_layout(34.0, 0.0)
	assert_true(float(none["marker_x"]) < 0.0)
	assert_eq(float(none["width"]), 34.0)


## WU-583: spread_labels sees the pips: the label rect it uses is widened by the strip.
func test_spread_counts_strip() -> void:
	var n: Interactable = NPC_SCRIPT.new()
	assert_eq(n.strip_extras_width(), 0.0)
	n._pips = 2
	assert_true(n.strip_extras_width() >= 34.0)
	n.free()
