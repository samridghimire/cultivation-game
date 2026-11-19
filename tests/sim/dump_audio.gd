extends SceneTree
## WU-573: writes every sound recipe and ambience loop as a .wav to user://audio/ so the owner
## can listen: tools/godot.sh --headless --path . -s res://tests/sim/dump_audio.gd


func _init() -> void:
	var audio: Node = root.get_node("Audio")
	DirAccess.make_dir_recursive_absolute("user://audio")
	var t0 := Time.get_ticks_usec()
	for sfx_name: String in audio.RECIPES:
		audio.synth(audio.RECIPES[sfx_name]).save_to_wav("user://audio/%s.wav" % sfx_name)
	var t1 := Time.get_ticks_usec()
	for loop_name: String in audio.AMB_LOOPS:
		audio.ambience_stream(loop_name).save_to_wav("user://audio/%s.wav" % loop_name)
	var t2 := Time.get_ticks_usec()
	print("sounds %d ms, loops %d ms, in %s" % [(t1 - t0) / 1000, (t2 - t1) / 1000, ProjectSettings.globalize_path("user://audio")])
	quit()
