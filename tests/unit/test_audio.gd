extends TestCase
## Procedural SFX (REL-004): streams exist, volume settings reach the SFX bus.


func test_every_sfx_stream_exists() -> void:
	for sfx_name in Audio.RECIPES:
		assert_true(Audio.streams.has(sfx_name), sfx_name)
		var wav: AudioStreamWAV = Audio.streams[sfx_name]
		assert_true(wav.data.size() > 0, sfx_name)


func test_synth_is_deterministic() -> void:
	var a := Audio.synth(Audio.RECIPES["lightning"])
	var b := Audio.synth(Audio.RECIPES["lightning"])
	assert_eq(a.data, b.data)


func test_sfx_bus_follows_volume_setting() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	assert_true(idx != -1)
	var old: Variant = Settings.get_value("sfx_volume")
	Settings.set_value("sfx_volume", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.01)
	Settings.set_value("sfx_volume", old)


func test_play_unknown_is_harmless() -> void:
	Audio.play("nope")
	Audio.play("press")


func test_a_chime_does_not_cut_off_a_big_sound() -> void:
	Audio.play("lightning")
	Audio.play("chime_danger")
	var held: Array = []
	for p: AudioStreamPlayer in Audio._players:
		held.append(p.stream)
	assert_true(held.has(Audio.streams["lightning"]), "lightning still on a voice")
	assert_true(held.has(Audio.streams["chime_danger"]), "chime on another voice")


func test_music_streams_loop_and_are_deterministic() -> void:
	for m: String in Audio.MOODS:
		var wav := Audio.music_stream(m)
		assert_true(wav.data.size() > 0, m)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, m)
		assert_eq(wav.loop_end, wav.data.size() / 2, m)
	var a := Audio.synth_music(Audio.MOODS["dark"], 5)
	var b := Audio.synth_music(Audio.MOODS["dark"], 5)
	assert_eq(a.data, b.data)
	assert_true(Audio.music_stream("calm").data != Audio.music_stream("dark").data)


func test_music_mood_follows_region_danger() -> void:
	var calm := ""
	var dark := ""
	for id: String in GameState.data.regions:
		var d: int = int(GameState.data.regions[id].get("danger", 0))
		if d <= 0 and calm == "":
			calm = id
		if d >= Audio.DARK_DANGER and dark == "":
			dark = id
	assert_eq(Audio.mood_for_region(calm), "calm")
	assert_eq(Audio.mood_for_region(dark), "dark")
	Audio.set_mood("dark")
	assert_eq(Audio.mood, "dark")
	Audio.set_mood("calm")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_music_mood_change_crossfades() -> void:
	Audio.crossfade_seconds = 0.1
	Audio.set_mood("calm")
	Audio.set_mood("dark")
	var fresh: AudioStreamPlayer = Audio._music_player
	var old: AudioStreamPlayer = Audio._old_music_player
	assert_true(fresh.playing)
	assert_true(fresh.stream == Audio.music_stream("dark"))
	var before := Audio.mood
	Audio.set_mood("dark")  # same mood: no restart
	assert_true(Audio._music_player == fresh)
	assert_eq(Audio.mood, before)
	await _tree().create_timer(0.4).timeout
	assert_false(old.playing)
	assert_true(fresh.playing)
	assert_true(fresh.volume_db > -1.0)
	Audio.crossfade_seconds = 2.0
	Audio.set_mood("calm")


func test_music_bus_follows_volume_setting() -> void:
	var idx := AudioServer.get_bus_index("Music")
	assert_true(idx != -1)
	var old: Variant = Settings.get_value("music_volume")
	Settings.set_value("music_volume", 0.4)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.4), 0.01)
	Settings.set_value("music_volume", old)
