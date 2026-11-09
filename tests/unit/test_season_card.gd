extends TestCase
## SeasonCard (WU-495): builds from the two line arrays, focus on Continue, queues behind the friend card.

func _frames(n: int = 4) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func test_card_builds_from_both_blocks() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var card := SeasonCard.new()
	root.add_child(card)
	card.open("Spring", 1, PackedStringArray(["You won 2 fights."]), PackedStringArray(["The Lantern Festival is coming.", "Spring tasks are up."]))
	assert_eq(card.title_text(), "Spring of Year 1")
	assert_true(card.visible)
	await _frames(2)
	assert_true(card.button().has_focus(), "Continue holds focus for the gamepad")
	card.close()
	assert_false(card.visible)
	card.queue_free()


func test_kickoff_only_hides_looking_back() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var card := SeasonCard.new()
	root.add_child(card)
	card.open("Spring", 2, PackedStringArray(), PackedStringArray(["A new year."]))
	assert_eq(card.back_lines().size(), 0)
	assert_eq(card.coming_lines().size(), 1)
	card.queue_free()


func test_line_kinds() -> void:
	assert_eq(SeasonCard.line_kind("You won 3 fights."), "fight")
	assert_eq(SeasonCard.line_kind("Spring tasks are up."), "season")
	assert_eq(SeasonCard.line_kind("You made a friend."), "other")


func test_hud_queues_card_behind_friend_card() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	EventBus.friend_scene.emit("xiao_ling", "Xiao Ling", "A quiet moment.", "", "")
	await _frames()
	var friend: FriendSceneCard = hud.get("_friend_card")
	var card: SeasonCard = hud.get("_season_card")
	if not friend.visible:
		gs.end_session()
		root.remove_child(hud)
		hud.free()
		return
	EventBus.season_reviewed.emit("Spring", 1, PackedStringArray(["You won 2 fights."]))
	EventBus.season_began.emit("Summer", 1, PackedStringArray(["Summer begins."]))
	await _frames()
	assert_false(card.visible, "the season card waits for the friend card")
	friend.close()
	await _frames()
	assert_true(card.visible)
	assert_eq(card.title_text(), "Summer of Year 1")
	assert_eq(card.back_lines().size(), 1)
	assert_eq(hud.get("_banner").visible, false)
	card.close()
	root.remove_child(hud)
	hud.free()
	gs.end_session()
