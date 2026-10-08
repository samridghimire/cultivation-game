extends TestCase
## WU-002: sect balance-of-power window and character sheet rank line.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_ordinals() -> void:
	assert_eq(SectBalanceWindow.ordinal(1), "1st")
	assert_eq(SectBalanceWindow.ordinal(2), "2nd")
	assert_eq(SectBalanceWindow.ordinal(3), "3rd")
	assert_eq(SectBalanceWindow.ordinal(4), "4th")
	assert_eq(SectBalanceWindow.ordinal(11), "11th")
	assert_eq(SectBalanceWindow.ordinal(22), "22nd")


func test_hall_offers_balance_and_text_names_sects() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var labels: Array = hall.get_options().map(func(o: Dictionary) -> String: return o["label"])
	assert_true(labels.has("Balance of power"))
	hall.free()
	var sect_id: String = gs.data.sects.keys()[0]
	c.sect = {"id": sect_id, "rank": 0}
	var standings: Array[Dictionary] = gs.sect_standings()
	var text := SectBalanceWindow.window_text(c, standings, PackedStringArray(["A rumor."]))
	for sect: SectDef in gs.data.sects.values():
		assert_true(text.contains(sect.name), sect.name)
	assert_true(text.contains("(your sect)"))
	assert_true(text.contains("A rumor."))
	assert_true(SectBalanceWindow.rank_line(c, standings).begins_with("Your sect ranks "))
	c.sect = {}
	assert_false(SectBalanceWindow.window_text(c, standings, PackedStringArray()).contains("(your sect)"))
	assert_eq(SectBalanceWindow.rank_line(c, standings), "")
	gs.end_session()
