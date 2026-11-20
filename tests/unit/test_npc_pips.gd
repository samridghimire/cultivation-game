extends TestCase
## WU-581: heart pips beside a villager's name at folk friendship tiers.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func test_pip_tier_edges() -> void:
	assert_eq(NPC_SCRIPT.pips_for(19, data()), 0)
	assert_eq(NPC_SCRIPT.pips_for(20, data()), 1)
	assert_eq(NPC_SCRIPT.pips_for(40, data()), 2)
	assert_eq(NPC_SCRIPT.pips_for(60, data()), 3)
	assert_eq(NPC_SCRIPT.pips_for(85, data()), 3)
