extends TestCase
## WU-573: ambience selection (pure), its data validation, and the synthesized sounds.


func _region(id: String) -> Dictionary:
	return GameState.data.regions[id]


func test_every_region_has_a_layer() -> void:
	for id: String in GameState.data.regions:
		for weather in Weather.KINDS:
			var a := Soundscape.ambience_for(_region(id), weather, "Spring")
			assert_true((a["layers"] as Array).size() >= 1, "%s %s" % [id, weather])


func test_qingshi_clear_spring_has_village_water_and_birds() -> void:
	var a := Soundscape.ambience_for(_region("qingshi_village"), "clear", "Spring")
	assert_true(a["layers"].has("amb_village") and a["layers"].has("amb_water"))
	assert_true(a["accents"].has("bird"))


func test_marsh_rain_has_no_birds() -> void:
	var a := Soundscape.ambience_for(_region("withered_bone_marsh"), "rain", "Spring")
	for l in ["amb_marsh", "amb_water", "amb_rain"]:
		assert_true(a["layers"].has(l), l)
	assert_false(a["accents"].has("bird"))


func test_storm_has_no_accents_and_market_has_crowd() -> void:
	assert_true(Soundscape.ambience_for(_region("azure_peak"), "storm", "Summer")["accents"].is_empty())
	assert_true(Soundscape.ambience_for(_region("fallen_star_market"), "clear", "Summer")["layers"].has("amb_crowd"))
	assert_true(Soundscape.ambience_for({}, "clear", "Autumn")["layers"].has("amb_village"))


func test_invalid_ambience_is_rejected() -> void:
	assert_eq(Soundscape.validate({"id": "x", "map": {"ambience": {"bed": "ocean"}}}).size(), 1)
	assert_eq(Soundscape.validate({"id": "x", "map": {"ambience": {"loud": true}}}).size(), 1)
	assert_eq(Soundscape.validate({"id": "x", "map": {"ambience": {"bed": "marsh", "water": true}}}).size(), 0)
	assert_eq(Soundscape.validate({"id": "x", "map": {}}).size(), 0)


func test_sounds_build_and_loops_loop() -> void:
	for name in Soundscape.ACCENTS + ["step_snow", "step_dirt", "meditate_hum", "coin", "rustle", "splash"]:
		assert_true(Audio.RECIPES.has(name), name)
		assert_true(Audio.sfx_stream(name).data.size() > 0, name)
	for name in Soundscape.LOOPS:
		var wav := Audio.ambience_stream(name)
		assert_true(wav.data.size() > 0, name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, name)
		assert_eq(wav.loop_end, wav.data.size() / 2, name)


func test_ambience_players_follow_the_selection() -> void:
	Audio.apply_ambience({"layers": ["amb_village", "amb_rain"], "accents": ["bird"], "accent_every": Vector2(5, 14)})
	assert_eq(Audio._amb_players.size(), 2)
	Audio.apply_ambience({"layers": ["amb_village"], "accents": [], "accent_every": Vector2(5, 14)})
	assert_eq(Audio._amb_players.size(), 1)
	assert_true(Audio._amb_timer.is_stopped())
	Audio.apply_ambience({"layers": [], "accents": [], "accent_every": Vector2(5, 14)})


func test_ambience_volume_default() -> void:
	assert_almost_eq(float(Settings.DEFAULTS["ambience_volume"]), 0.6)
	assert_true(Settings.VOLUME_BUSES.has("Ambience"))


## REVIEW: travel refreshes twice in one frame (days_advanced, then region_changed). The second, unchanged refresh
## used to kill the shared fade tween, so new layers stayed silent and the old ones played on, never freed.
func test_second_refresh_keeps_fades_running() -> void:
	Audio.apply_ambience({"layers": [], "accents": [], "accent_every": Vector2(5, 14)})
	Audio.apply_ambience({"layers": ["amb_village"], "accents": [], "accent_every": Vector2(5, 14)})
	var old: AudioStreamPlayer = Audio._amb_players["amb_village"]
	var next := {"layers": ["amb_marsh"], "accents": [], "accent_every": Vector2(5, 14)}
	Audio.apply_ambience(next)
	var fresh: AudioStreamPlayer = Audio._amb_players["amb_marsh"]
	Audio.apply_ambience(next)
	for p: AudioStreamPlayer in [old, fresh]:
		var t: Variant = p.get_meta("amb_tween") if p.has_meta("amb_tween") else null
		assert_true(t is Tween and (t as Tween).is_valid() and (t as Tween).is_running(), "fade still running on %s" % p.name)
	Audio.apply_ambience({"layers": [], "accents": [], "accent_every": Vector2(5, 14)})


## WU-577: places you can hear.
func test_place_sound_validation() -> void:
	var bad := {"id": "x", "places": [{"display_name": "P", "sound": "amb_ocean", "pos": [1, 1]}]}
	assert_eq(Soundscape.validate(bad).size(), 1)
	var bad_lm := {"id": "x", "map": {"landmarks": [{"kind": "pond", "sound": "nope", "pos": [1, 1]}]}}
	assert_eq(Soundscape.validate(bad_lm).size(), 1)
	var ok := {"id": "x", "places": [{"display_name": "P", "sound": "amb_forge", "pos": [1, 1]}]}
	assert_eq(Soundscape.validate(ok).size(), 0)
	assert_eq(Soundscape.place_sounds(ok).size(), 1)


func test_new_loops_are_seamless() -> void:
	for name in ["amb_forge", "amb_falls"]:
		assert_true(Soundscape.PLACE_SOUNDS.has(name), name)
		var wav := Audio.ambience_stream(name)
		var n := wav.data.size() / 2
		assert_eq(wav.loop_end, n, name)
		assert_true(absi(wav.data.decode_s16(0) - wav.data.decode_s16((n - 1) * 2)) < 3000, name)


func test_world_builds_one_player_per_sounding_place() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var expected := 0
	for rid in ["qingshi_village", "fallen_star_market", "azure_peak"]:
		gs.current_region = rid
		expected = Soundscape.place_sounds(gs.data.regions[rid]).size()
		assert_true(expected >= 1, rid)
		var world: Node = load("res://src/world/world.tscn").instantiate()
		root.add_child(world)
		assert_eq(root.get_tree().get_nodes_in_group("place_sound").size(), expected, rid)
		world.free()
		assert_eq(root.get_tree().get_nodes_in_group("place_sound").size(), 0, rid)
	gs.end_session()


func test_storm_on_a_mountain_has_one_wind_layer() -> void:
	var layers: Array = Soundscape.ambience_for(_region("azure_peak"), "storm", "Summer")["layers"]
	var winds := layers.filter(func(l: String) -> bool: return l.begins_with("amb_wind"))
	assert_eq(winds, ["amb_wind_hard"], "WU-576: only the stronger wind")
