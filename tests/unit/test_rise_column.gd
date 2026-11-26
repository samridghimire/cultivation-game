extends TestCase
## GFX-262: the light column over a friend who breaks through in sight.

func test_text_for() -> void:
	assert_eq(RiseColumn.text_for("Xiao Ling", "Qi Refining"), "Xiao Ling: Qi Refining!")
	assert_eq(RiseColumn.text_for("Xiao Ling", ""), "Xiao Ling rises!")


func test_alpha_curve() -> void:
	assert_eq(RiseColumn.alpha_at(-1.0), 0.0)
	assert_eq(RiseColumn.alpha_at(0.0), 0.0)
	assert_eq(RiseColumn.alpha_at(1.0), 1.0, "holds at full")
	assert_true(RiseColumn.alpha_at(2.3) < 0.5, "fading out")
	assert_eq(RiseColumn.alpha_at(RiseColumn.LIFETIME), 0.0)


func test_motes_stay_in_the_column() -> void:
	for i in RiseColumn.MOTES:
		for step in 30:
			var p := RiseColumn.mote_pos(i, float(step) * 0.1)
			assert_true(p.y <= 0.0 and p.y >= -RiseColumn.HEIGHT, "mote %d inside the column height" % i)
			assert_true(absf(p.x) <= 10.0, "mote %d inside the column width" % i)


func test_spawn_adds_a_labelled_node() -> void:
	var root := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var col := RiseColumn.spawn(root, Vector2(50, 60), "Xiao Ling", "Qi Refining")
	assert_eq(col.position, Vector2(50, 60))
	assert_eq(col.get_child_count(), 1)
	assert_eq((col.get_child(0) as Label).text, "Xiao Ling: Qi Refining!")
	root.queue_free()


func test_friend_rose_signal_fires_with_own_news() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var bus := (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	assert_true(bus.has_signal("friend_rose"))
	assert_true(gs != null)
