extends TestCase
## WU-057: ambient particles by region and season, and the "Ambient effects" setting.


func test_kind_for_prefers_season_over_any() -> void:
	var amb := {"winter": "snow", "any": "mist"}
	assert_eq(Ambient.kind_for(amb, "Winter"), "snow")
	assert_eq(Ambient.kind_for(amb, "Spring"), "mist")
	assert_eq(Ambient.kind_for({}, "Spring"), "")
	assert_eq(Ambient.kind_for({"any": "bogus"}, "Spring"), "")


func test_presets_cover_kinds_and_stay_small() -> void:
	for kind in Ambient.KINDS:
		var p := Ambient.make_emitter(kind, Vector2(1600, 1000))
		assert_true(p != null, kind)
		assert_true(p.amount <= Ambient.MAX_AMOUNT, kind)
		assert_true(p.color.a <= 0.75, kind)
		p.free()
	assert_true(Ambient.make_emitter("bogus", Vector2.ONE) == null)


func test_every_region_ambient_validates() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(gs.data.load_errors.size(), 0)
	for region: Dictionary in gs.data.regions.values():
		for key: String in region.get("map", {}).get("ambient", {}):
			assert_true(["spring", "summer", "autumn", "winter", "any"].has(key), key)
			assert_true(Ambient.KINDS.has(String(region["map"]["ambient"][key])), key)


func test_world_emitter_follows_setting_and_region() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var settings := root.get_node("Settings")
	var old: Variant = settings.get_value("ambient_effects")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	settings.set_value("ambient_effects", true)
	gs.current_region = "qingshi_village"
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_true(world._ambient != null)
	settings.set_value("ambient_effects", false)
	assert_true(world._ambient == null)
	settings.set_value("ambient_effects", true)
	assert_true(world._ambient != null)
	world.free()
	# Summer has no ambient kind in the village.
	root.get_node("GameClock").advance(120)
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_true(world._ambient == null)
	world.free()
	settings.set_value("ambient_effects", old)
	gs.end_session()


func test_weather_plan_maps_kind_to_preset() -> void:
	assert_eq(Ambient.weather_plan("rain")["emitter"], "rain")
	assert_eq(Ambient.weather_plan("snow")["emitter"], "snow")
	assert_true(Ambient.weather_plan("fog")["fog"])
	assert_eq(Ambient.weather_plan("cloudy")["tint"], Ambient.CLOUDY_TINT)
	assert_eq(Ambient.weather_plan("clear")["emitter"], "")
	assert_eq(Ambient.weather_plan("clear")["tint"], Color.WHITE)
	assert_true(Ambient.replaces_season("rain"))
	assert_true(not Ambient.replaces_season("cloudy"))
	assert_true(not Ambient.replaces_season("clear"))


func test_rain_and_fog_nodes_build() -> void:
	var rain := Ambient.make_rain(Vector2(1600, 1000))
	assert_true(rain.amount <= 300)
	rain.free()
	var fog := Ambient.make_fog(Vector2(1600, 1000), false)
	assert_eq(fog.get_child_count(), Ambient.FOG_SHEETS)
	fog.free()
