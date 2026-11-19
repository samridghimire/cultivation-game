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
		assert_true(Audio.streams.has(name), name)
		assert_true((Audio.streams[name] as AudioStreamWAV).data.size() > 0, name)
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
