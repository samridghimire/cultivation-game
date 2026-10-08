extends TestCase
## WU-001: save feedback toast.

func test_toast_text_and_hide() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var toast := SaveToast.new()
	root.add_child(toast)
	assert_false(toast.is_showing())
	var saves := root.get_node("SaveManager")
	saves.saved.emit("slot1", false)
	assert_true(toast.is_showing())
	assert_eq(toast.text(), "Saved")
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(toast.focus_mode, Control.FOCUS_NONE)
	saves.saved.emit("autosave", true)
	assert_eq(toast.text(), "Autosaved")
	await root.get_tree().create_timer(2.2).timeout
	assert_false(toast.is_showing(), "hidden after fade")
	toast.queue_free()


func test_save_game_emits_signal() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	gs.start_session(CharacterFactory.create("Toast", gs.data, seeded_rng(5)))
	var got := []
	var cb := func(slot: String, is_auto: bool): got.append([slot, is_auto])
	saves.saved.connect(cb)
	saves.save_game("toasttest")
	saves.autosave(true)
	saves.saved.disconnect(cb)
	saves.delete_save("toasttest")
	saves.delete_save("autosave")
	gs.end_session()
	assert_eq(got.size(), 2)
	assert_eq(got[0], ["toasttest", false])
	assert_eq(got[1], ["autosave", true])
