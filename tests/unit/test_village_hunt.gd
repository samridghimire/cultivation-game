extends TestCase
## WILD-016: VillageHunt window math and ally.

func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func test_season_start() -> void:
	assert_eq(VillageHunt.season_start(189), 180)
	assert_eq(VillageHunt.season_start(180), 180)
	assert_eq(VillageHunt.season_start(269), 180)
	assert_eq(VillageHunt.season_start(270), 270)
	assert_eq(VillageHunt.season_start(0), 0)


func test_window_and_flags() -> void:
	var gd := _gd()
	assert_eq(VillageHunt.window_start(gd, "qingshi_village", 200), 189)
	assert_eq(VillageHunt.window_start(gd, "misty_forest", 200), -1, "no market there")
	var flags := {}
	assert_true(VillageHunt.active(gd, "qingshi_village", 189, flags))
	assert_true(VillageHunt.active(gd, "qingshi_village", 191, flags))
	assert_false(VillageHunt.active(gd, "qingshi_village", 192, flags))
	assert_false(VillageHunt.active(gd, "qingshi_village", 360 + 9, flags), "spring: no in_season beast")
	VillageHunt.mark_done(flags, 190)
	assert_false(VillageHunt.active(gd, "qingshi_village", 190, flags))
	assert_true(VillageHunt.active(gd, "qingshi_village", 279, flags), "winter day 10 is a new season")


func test_ally_and_validate() -> void:
	var gd := _gd()
	var c := CharacterData.new()
	var a := VillageHunt.ally(c, gd, 0.15)
	assert_true(int(a["damage"]) >= 1)
	assert_eq(VillageHunt.validate(gd).size(), 0)
	assert_true(VillageHunt.notice(gd, "qingshi_village", 190).contains("mist fox"))
