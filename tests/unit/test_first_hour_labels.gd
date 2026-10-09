extends TestCase
## WU-087: NPC labels do not overlap, show the realm only up close; inventory and fight log shrink to content.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func _npc(label: String, pos: Vector2) -> Interactable:
	var n: Interactable = NPC_SCRIPT.new()
	n.display_name = label
	n.position = pos
	n.size = Vector2(28, 28)
	return n


func test_close_npc_labels_are_lifted_apart() -> void:
	var a := _npc("Hooded Stranger (Qi Refining, 1st Layer)", Vector2(300, 300))
	var b := _npc("Ren Longyuan (Qi Refining, 2nd Layer)", Vector2(320, 304))
	Interactable.spread_labels([a, b])
	assert_false(a.label_rect().intersects(b.label_rect()), "labels overlap")
	assert_eq(a.label_offset, Vector2.ZERO)
	assert_true(b.label_offset.y < 0.0)


func test_distant_labels_stay_put() -> void:
	var a := _npc("Aa", Vector2(100, 100))
	var b := _npc("Bb", Vector2(600, 400))
	Interactable.spread_labels([a, b])
	assert_eq(b.label_offset, Vector2.ZERO)


func test_realm_suffix_only_when_near() -> void:
	var n := _npc("Zhao Huanyue (Qi Refining, 1st Layer)", Vector2.ZERO)
	assert_eq(n.label_text(), "Zhao Huanyue")
	n._near = true
	assert_eq(n.label_text(), "Zhao Huanyue (Qi Refining, 1st Layer)")


func test_inventory_list_shrinks_for_few_stacks() -> void:
	assert_true(InventoryScreen.list_height(1) < InventoryScreen.LIST_MAX_HEIGHT)
	assert_eq(InventoryScreen.list_height(100), InventoryScreen.LIST_MAX_HEIGHT)


func test_fight_log_shrinks_for_short_fights() -> void:
	assert_true(CombatReport.log_height(3) < 360.0)
	assert_eq(CombatReport.log_height(60), 360.0)
