extends TestCase
## WU-165: HUD panels fade when the player or a place label is behind them.

const HudScript := preload("res://src/ui/hud.gd")


func test_panel_alpha() -> void:
	var panel := Rect2(0, 0, 100, 100)
	var none: Array[Rect2] = []
	var far: Array[Rect2] = [Rect2(300, 300, 10, 10)]
	var near: Array[Rect2] = [Rect2(300, 300, 10, 10), Rect2(90, 90, 40, 40)]
	assert_eq(HudScript.panel_alpha(panel, none), 1.0)
	assert_eq(HudScript.panel_alpha(panel, far), 1.0)
	assert_eq(HudScript.panel_alpha(panel, near), 0.35)


func test_fade_targets_key_bar() -> void:
	var rects := {"key_bar": Rect2(600, 760, 600, 30), "log": Rect2(0, 600, 300, 150)}
	assert_eq(HudScript.fade_targets(rects, Rect2(700, 750, 40, 50)), ["key_bar"] as Array[String])
	assert_eq(HudScript.fade_targets(rects, Rect2(620, 380, 40, 50)), [] as Array[String])


func test_hud_key_bar_fades_under_player() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var tree := root.get_tree()
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)  # no camera: canvas transform is identity
	await tree.process_frame
	await tree.process_frame
	var kb: Control = hud._key_bar
	player.global_position = kb.get_global_rect().get_center()
	for i in 30:
		await tree.process_frame
		await tree.create_timer(0.02).timeout
	assert_true(kb.modulate.a < 0.9, "key bar fades behind the player")
	player.global_position = Vector2(300, 100)
	for i in 30:
		await tree.process_frame
		await tree.create_timer(0.02).timeout
	assert_true(kb.modulate.a > 0.9, "and returns when the player moves on")
	player.queue_free()
	hud.queue_free()


## WU-511: a panel stays opaque while only a label or beast (not the player's body) is behind it.
func test_panel_alpha_ignores_non_player_rects() -> void:
	var panel := Rect2(0, 0, 200, 100)
	var no_body: Array[Rect2] = []
	assert_eq(HudScript.panel_alpha(panel, no_body), 1.0)
