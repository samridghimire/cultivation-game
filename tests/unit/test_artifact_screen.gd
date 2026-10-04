extends TestCase
## ART-002b: the Creation Artifact screen feeds, unseals and uses the Storage Space.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _press(screen: ArtifactScreen, node_name: String) -> void:
	for b in screen.buttons():
		if String(b.name) == node_name:
			assert_false(b.disabled, "%s should be enabled: %s" % [node_name, b.text])
			b.pressed.emit()
			return
	assert_true(false, "no button %s in %s" % [node_name, str(screen.buttons().map(func(x: Button) -> String: return x.name))])


func _button(screen: ArtifactScreen, node_name: String) -> Button:
	for b in screen.buttons():
		if String(b.name) == node_name:
			return b
	return null


func test_feed_unseal_and_storage_round_trip() -> void:
	var gs := _gs()
	var c := new_character()
	c.inventory = {"spirit_stone": 150, "golden_bell_talisman": 2}
	gs.start_session(c)
	var screen := ArtifactScreen.new()
	screen.open()
	assert_eq(screen.page(), ArtifactScreen.PAGE_MAIN)
	assert_true(_button(screen, "unseal_storage").disabled, "mortals cannot unseal storage")
	assert_true(_button(screen, "unseal_storage").text.contains("("), "disabled unseal shows why")
	assert_true(_button(screen, "storage").disabled, "storage page is sealed")
	_press(screen, "feed_stones_100")
	assert_eq(c.artifact_energy, 100, "fed 100 stones")
	assert_eq(c.item_count("spirit_stone"), 50)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	gs.get_node("/root/EventBus").player_changed.emit()
	_press(screen, "unseal_storage")
	assert_true(ArtifactFunctions.is_unlocked(c, "storage"), "storage unsealed")
	assert_true(_button(screen, "unseal_storage") == null, "unsealed functions leave the list")
	_press(screen, "storage")
	assert_eq(screen.page(), ArtifactScreen.PAGE_STORAGE)
	_press(screen, "storeall_golden_bell_talisman")
	assert_eq(int(c.artifact_storage.get("golden_bell_talisman", 0)), 2, "stored both")
	assert_eq(c.item_count("golden_bell_talisman"), 0)
	_press(screen, "take1_golden_bell_talisman")
	assert_eq(c.item_count("golden_bell_talisman"), 1, "took one back")
	_press(screen, "back")
	assert_eq(screen.page(), ArtifactScreen.PAGE_MAIN)
	screen.free()
	gs.end_session()


func test_feed_page_lists_items_with_energy_value() -> void:
	var gs := _gs()
	var c := new_character()
	c.inventory = {"golden_bell_talisman": 1}
	gs.start_session(c)
	var screen := ArtifactScreen.new()
	screen.open()
	assert_true(_button(screen, "feed_stones_10").disabled, "no stones to feed")
	_press(screen, "feed_item")
	assert_eq(screen.page(), ArtifactScreen.PAGE_FEED)
	assert_true(_button(screen, "feedall_golden_bell_talisman") == null, "a single item has no Feed all")
	_press(screen, "feed1_golden_bell_talisman")
	assert_eq(c.artifact_energy, ArtifactFunctions.energy_value(gs.data, "golden_bell_talisman"))
	assert_true(_button(screen, "feed1_golden_bell_talisman") == null, "fed items leave the list")
	screen.close()
	assert_false(screen.visible)
	screen.free()
	gs.end_session()


## ART-005b: lives and anchors are managed from the artifact screen anywhere.
func test_lives_and_anchors_page() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.anchors = ["qingshi_rock", "misty_clearing"]
	var lives := c.artifact_lives
	c.inventory = {"spirit_stone": CreationArtifact.recharge_cost(c, gs.data)}
	var screen := ArtifactScreen.new()
	screen.open()
	assert_true(screen._info.text.begins_with("Lives: "), screen._info.text)
	_press(screen, "anchors")
	assert_eq(screen.page(), ArtifactScreen.PAGE_ANCHORS)
	assert_true(_button(screen, "respawn_misty_clearing") == null, "already the respawn point")
	_press(screen, "respawn_qingshi_rock")
	assert_eq(c.anchors[-1], "qingshi_rock", "now the respawn point")
	assert_true(_button(screen, "respawn_qingshi_rock") == null)
	_press(screen, "release_misty_clearing")
	assert_eq(c.anchors, ["qingshi_rock"])
	_press(screen, "recharge")
	assert_eq(c.artifact_lives, lives + 1)
	assert_true(_button(screen, "recharge").disabled, "no stones left for the next life")
	assert_true(_button(screen, "recharge").text.contains("hungers"), _button(screen, "recharge").text)
	_press(screen, "back")
	assert_eq(screen.page(), ArtifactScreen.PAGE_MAIN)
	screen.free()
	gs.end_session()


func test_check_recharge_reasons() -> void:
	var c := new_character()
	var d := data()
	CreationArtifact.ensure(c, d)
	c.inventory = {}
	assert_true(CreationArtifact.check_recharge(c, d).contains("hungers"))
	c.inventory = {"spirit_stone": CreationArtifact.recharge_cost(c, d)}
	assert_eq(CreationArtifact.check_recharge(c, d), "")
	c.artifact_lives = int(d.artifact.get("max_lives", 9))
	assert_eq(CreationArtifact.check_recharge(c, d), "The artifact cannot hold more lives.")
