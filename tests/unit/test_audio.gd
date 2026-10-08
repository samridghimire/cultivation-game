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
