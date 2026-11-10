extends TestCase
## GFX-092: the pickup float text, the friend card's gift icon and the pickup_noted signal.

func test_text_for_known_and_unknown_items() -> void:
	var data := GameData.load_from_dir()
	assert_eq(PickupFloat.text_for(data, "hen_egg", 1), "+1 Hen's Egg")
	assert_eq(PickupFloat.text_for(data, "hen_egg", 3), "+3 Hen's Eggs")
	assert_eq(PickupFloat.text_for(data, "nope", 1), "")


func test_spawn_builds_icon_and_label() -> void:
	var data := GameData.load_from_dir()
	var root := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var box := PickupFloat.spawn(root, data, "well_water", 1, Vector2(100, 100))
	assert_true(box != null)
	assert_eq(box.get_child_count(), 2, "icon + label")
	assert_true(PickupFloat.spawn(root, data, "nope", 1, Vector2.ZERO) == null)
	root.queue_free()


func test_friend_card_gift_icon() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var card := FriendSceneCard.new()
	root.add_child(card)
	card.open("xiao_ling", "Xiao Ling", "Hi.", "Hen's Egg", "hen_egg")
	assert_true(card.has_gift_icon())
	assert_eq(card.gift_text(), "They give you Hen's Egg.")
	card.close()
	card.open("xiao_ling", "Xiao Ling", "Hi.", "", "")
	assert_false(card.has_gift_icon())
	assert_eq(card.gift_text(), "")
	card.queue_free()
