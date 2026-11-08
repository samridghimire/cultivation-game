extends TestCase
## WU-494: trophy plaques, the Village Pond Jetty's build stages, and the player's birthday cake.

func test_trophy_icon_picker() -> void:
	assert_eq(TrophyPlaques.icon_kind("fog_antler_stag_antler", ""), "antler")
	assert_eq(TrophyPlaques.icon_kind("old_tuskers_broken_tusk", ""), "tusk")
	assert_eq(TrophyPlaques.icon_kind("cloud_cranes_crown_plume", ""), "feather")
	assert_eq(TrophyPlaques.icon_kind("crane_mates_grey_feather", ""), "feather")
	assert_eq(TrophyPlaques.icon_kind("thunder_horn_rams_horn_coil", ""), "horn")
	assert_eq(TrophyPlaques.icon_kind("bog_kings_throat_pearl", "Bog-King's Throat Pearl"), "plaque")
	assert_eq(TrophyPlaques.icon_kind("x", "Great Antler"), "antler")


func test_kinds_for_caps_at_three() -> void:
	var items := {"a_tusk": {"name": "A"}, "b": {"name": "B"}}
	var kinds := TrophyPlaques.kinds_for(["a_tusk", "b", "a_tusk", "b"], items)
	assert_eq(kinds.size(), 3)
	assert_eq(kinds[0], "tusk")
	assert_eq(kinds[1], "plaque")


func test_every_icon_is_8x8_and_slots_centre() -> void:
	for k in TrophyPlaques.KINDS:
		var tex := TrophyPlaques.texture(k)
		assert_eq(tex.get_width(), 8)
		assert_eq(tex.get_height(), 8)
		assert_eq((TrophyPlaques.ROWS[k] as Array).size(), 8)
	var xs := TrophyPlaques.slots(3)
	assert_eq(xs.size(), 3)
	assert_true(absf(xs[0] + xs[2] + 16.0) < 0.01, "symmetric about the centre")
	assert_eq(TrophyPlaques.slots(0).size(), 0)


func test_jetty_stage_look() -> void:
	assert_eq(Scenery.jetty_stage_look(0)["frac"], 0.0)
	assert_eq(Scenery.jetty_stage_look(1)["frac"], 0.5)
	assert_true(Scenery.jetty_stage_look(2)["gaps"])
	assert_eq(Scenery.jetty_stage_look(2)["frac"], 1.0)
	assert_false(Scenery.jetty_stage_look(3)["gaps"])
	assert_true(Scenery.jetty_stage_look(3)["lantern"])
	assert_false(Scenery.jetty_stage_look(2)["lantern"])
	assert_true(Scenery.jetty_stage_look(9)["lantern"])
	assert_eq(Scenery.jetty_stage_look(-4)["frac"], 0.0)


func test_jetty_label() -> void:
	assert_eq(FishingSpot.jetty_label("Village Pond Jetty", [1, 3]), "Village Pond Jetty (1/3)")
	assert_eq(FishingSpot.jetty_label("Village Pond Jetty", [3, 3]), "Village Pond Jetty")
	assert_eq(FishingSpot.jetty_label("Village Pond Jetty", []), "Village Pond Jetty")


func test_project_progress_for_jetty() -> void:
	var data: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	var c := CharacterData.new()
	var p := SeasonTasks.project_progress(c, data, "jetty")
	assert_eq(p[0], 0)
	assert_eq(p[1], 3)
	assert_eq(SeasonTasks.project_progress(c, data, "nope"), [0, 0] as Array[int])


func test_cake_only_on_birthday() -> void:
	var data: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	var c := CharacterData.new()
	c.name = "Lan"
	var day := Folk.player_birthday_day(c)
	assert_true(Player.shows_cake(c, data, day))
	assert_true(Player.shows_cake(c, data, day + Calendar.DAYS_PER_YEAR))
	assert_false(Player.shows_cake(c, data, day + 1))
	assert_false(Player.shows_cake(null, data, day))
