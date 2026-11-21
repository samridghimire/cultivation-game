extends TestCase
## PERF-024: the pin pass builds its obstacle rects once; the result is pinned by a golden hash of 150 random crowds.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const VIEW := Rect2(0, 0, 1280, 800)
const GOLDEN := "acbb16d61ba2c98be49d37b4d7d9705b"


func _scene_hash() -> String:
	var rng := seeded_rng()
	var out := PackedStringArray()
	for scene in 150:
		var nodes: Array = []
		for i in rng.randi_range(6, 24):
			var n: Interactable
			if rng.randf() < 0.6:
				n = NPC_SCRIPT.new()
				n.npc_id = "npc_%d" % i
			else:
				n = Interactable.new()
				n.size = Vector2(60, 60)
			n.display_name = "Name %d of the Hall" % rng.randi_range(0, 99)
			n.position = Vector2(rng.randf_range(100, 700), rng.randf_range(100, 500))
			if n.size == Vector2(32, 32) or n.get("npc_id") != null:
				n.size = Vector2(28, 28)
			nodes.append(n)
		Interactable.spread_on_screen(nodes, VIEW, [] as Array[Rect2], Vector2(400, 300))
		for n: Interactable in nodes:
			out.append("%.2f,%.2f,%s,%s" % [n.screen_lift, n.screen_shift_x, n.label_covered, n.crowd_hidden])
		for n: Node in nodes:
			n.free()
	return ("\n".join(out)).md5_text()


func test_pin_pass_output_is_unchanged() -> void:
	var h := _scene_hash()
	if GOLDEN == "@GOLDEN@":
		print("GOLDEN=", h)
		return
	assert_eq(h, GOLDEN)
