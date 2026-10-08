extends Node
## Procedural sound effects (REL-004). Every SFX is synthesized in code at startup
## (sine/noise envelopes in an AudioStreamWAV), so there are no binary assets.
## Plays through the "SFX" bus, whose volume the settings sliders control.
## Muted while the window is unfocused.
## Ambient music (REL-008) is a procedural guqin-like pluck loop plus a soft drone, built
## lazily per mood and played on the "Music" bus: calm in safe regions, a minor scale where
## danger >= DARK_DANGER. Mood changes crossfade between two players (WU-010).

const MIX_RATE := 22050
const BUS := "SFX"
## SFX name -> synth recipe: {notes: [[freq_hz, seconds], ...], noise: 0..1, gain: 0..1}.
const RECIPES := {
	"focus": {"notes": [[880.0, 0.03]], "gain": 0.25},
	"press": {"notes": [[660.0, 0.04], [990.0, 0.05]], "gain": 0.35},
	"chime_info": {"notes": [[784.0, 0.06]], "gain": 0.2},
	"chime_progress": {"notes": [[523.0, 0.08], [784.0, 0.12]], "gain": 0.35},
	"chime_warning": {"notes": [[440.0, 0.1], [370.0, 0.12]], "gain": 0.35},
	"chime_danger": {"notes": [[220.0, 0.14], [165.0, 0.2]], "noise": 0.15, "gain": 0.45},
	"breakthrough_success": {"notes": [[392.0, 0.1], [523.0, 0.1], [659.0, 0.1], [784.0, 0.3]], "gain": 0.45},
	"breakthrough_fail": {"notes": [[300.0, 0.15], [200.0, 0.15], [120.0, 0.3]], "noise": 0.2, "gain": 0.45},
	"combat_win": {"notes": [[523.0, 0.08], [659.0, 0.08], [784.0, 0.16]], "gain": 0.4},
	"combat_loss": {"notes": [[330.0, 0.12], [247.0, 0.12], [165.0, 0.25]], "gain": 0.4},
	"hit_light": {"notes": [[1400.0, 0.03]], "noise": 0.6, "gain": 0.25},
	"hit": {"notes": [[140.0, 0.07]], "noise": 0.35, "gain": 0.4},
	"hit_heavy": {"notes": [[80.0, 0.14]], "noise": 0.5, "gain": 0.5},
	"lightning": {"notes": [[90.0, 0.25]], "noise": 0.9, "gain": 0.55},
}

## Voices that can sound at once, so a click or chime never cuts off a breakthrough or thunderclap.
const VOICES := 6

const MUSIC_RATE := 11025
const MUSIC_BEATS := 8
const MUSIC_BEAT_SECONDS := 1.5
const MUSIC_BUS := "Music"
const DARK_DANGER := 3
const SILENT_DB := -40.0
## Mood -> {scale: semitones above root, root: Hz, density: chance a beat plucks, gain}.
const MOODS := {
	"calm": {"scale": [0, 2, 4, 7, 9], "root": 196.0, "density": 0.6, "gain": 0.30},
	"normal": {"scale": [0, 2, 4, 7, 9], "root": 220.0, "density": 0.85, "gain": 0.34},
	"dark": {"scale": [0, 3, 5, 7, 10], "root": 164.81, "density": 0.85, "gain": 0.34},
}

var streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var mood := ""
var _music_streams: Dictionary = {}
var _music_player: AudioStreamPlayer
var _old_music_player: AudioStreamPlayer
var crossfade_seconds := 2.0
var _fade_tween: Tween
var _focused := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sfx_name in RECIPES:
		streams[sfx_name] = synth(RECIPES[sfx_name])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS if AudioServer.get_bus_index(BUS) != -1 else "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) != -1 else "Master"
	add_child(_music_player)
	_old_music_player = AudioStreamPlayer.new()
	_old_music_player.bus = _music_player.bus
	add_child(_old_music_player)
	set_mood("calm")
	EventBus.region_changed.connect(func(id: String) -> void: set_mood(mood_for_region(id)))
	EventBus.message_posted.connect(_on_message)
	EventBus.breakthrough_attempted.connect(func(ok: bool, _r: String) -> void: play("breakthrough_success" if ok else "breakthrough_fail"))
	EventBus.combat_finished.connect(func(_n: String, win: bool, _l: PackedStringArray) -> void: play("combat_win" if win else "combat_loss"))
	EventBus.tribulation_endured.connect(func(_r: String, _res: Dictionary) -> void: play("lightning"))
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: play("focus"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
	if _music_player != null and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN):
		_music_player.stream_paused = not _focused
		_old_music_player.stream_paused = not _focused


func play(sfx_name: String) -> void:
	if not _focused or _players.is_empty() or not streams.has(sfx_name):
		return
	var voice := _free_voice()
	voice.stream = streams[sfx_name]
	voice.play()


## An idle player if there is one, else the next one round-robin (the oldest sound is cut).
func _free_voice() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	_next_voice = (_next_voice + 1) % _players.size()
	return _players[_next_voice]


## Mood for a region: calm where it is perfectly safe, dark where danger is high.
func mood_for_region(region_id: String) -> String:
	var region: Dictionary = GameState.data.regions.get(region_id, {}) if GameState.data != null else {}
	var danger: int = int(region.get("danger", 0))
	if danger >= DARK_DANGER:
		return "dark"
	return "calm" if danger <= 0 else "normal"


func set_mood(new_mood: String) -> void:
	if not MOODS.has(new_mood) or new_mood == mood:
		return
	mood = new_mood
	if _music_player == null:
		return
	if _fade_tween != null:
		_fade_tween.kill()
	# The player that was fading in becomes the outgoing one; the other starts the new mood.
	var outgoing := _music_player
	_music_player = _old_music_player
	_old_music_player = outgoing
	_music_player.stream = music_stream(new_mood)
	_music_player.stream_paused = not _focused
	_music_player.volume_db = SILENT_DB if outgoing.playing else 0.0
	_music_player.play()
	if not outgoing.playing or not is_inside_tree():
		outgoing.stop()
		_music_player.volume_db = 0.0
		return
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(outgoing, "volume_db", SILENT_DB, crossfade_seconds)
	_fade_tween.tween_property(_music_player, "volume_db", 0.0, crossfade_seconds)
	_fade_tween.chain().tween_callback(outgoing.stop)


func music_stream(for_mood: String) -> AudioStreamWAV:
	if not _music_streams.has(for_mood):
		_music_streams[for_mood] = synth_music(MOODS[for_mood], hash(for_mood))
	return _music_streams[for_mood]


func _on_message(_text: String, category: String) -> void:
	if streams.has("chime_" + category):
		play("chime_" + category)


## Builds a mono 16-bit AudioStreamWAV from a recipe. Deterministic (fixed noise seed).
static func synth(recipe: Dictionary) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var noise_mix: float = recipe.get("noise", 0.0)
	var gain: float = recipe.get("gain", 0.5)
	var data := PackedByteArray()
	for note: Array in recipe["notes"]:
		var freq: float = note[0]
		var count := int(float(note[1]) * MIX_RATE)
		for i in count:
			var t := float(i) / MIX_RATE
			# Short attack, linear release so notes do not click.
			var env := minf(1.0, float(i) / 100.0) * (1.0 - float(i) / count)
			var s := sin(TAU * freq * t) * (1.0 - noise_mix) + rng.randf_range(-1.0, 1.0) * noise_mix
			data.append_array(_s16(s * env * gain))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## A looping mono WAV: random pentatonic plucks (from `seed_value`, so deterministic) over a
## drone. Plucks wrap around the loop end and the drone has whole cycles, so it loops cleanly.
static func synth_music(recipe: Dictionary, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := int(MUSIC_BEATS * MUSIC_BEAT_SECONDS * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var scale: Array = recipe["scale"]
	var root: float = recipe["root"]
	var seconds := float(total) / MUSIC_RATE
	# Drone: root an octave down, snapped to whole cycles over the loop.
	var drone_freq := roundf(root * 0.5 * seconds) / seconds
	for i in total:
		buf[i] = sin(TAU * drone_freq * float(i) / MUSIC_RATE) * 0.35
	var beat_samples := int(MUSIC_BEAT_SECONDS * MUSIC_RATE)
	var pluck_samples := beat_samples * 2
	for beat in MUSIC_BEATS:
		if beat > 0 and rng.randf() > float(recipe["density"]):
			continue
		var degree: int = scale[rng.randi_range(0, scale.size() - 1)]
		var octave := 1.0 if rng.randf() < 0.7 else 2.0
		var freq := root * octave * pow(2.0, degree / 12.0)
		for i in pluck_samples:
			var t := float(i) / MUSIC_RATE
			var env := minf(1.0, float(i) / 60.0) * exp(-t * 2.2)
			var v := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t) * exp(-t * 3.0)) * env * 0.5
			buf[(beat * beat_samples + i) % total] += v
	var gain: float = recipe["gain"]
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUSIC_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav


static func _s16(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_s16(0, int(clampf(v, -1.0, 1.0) * 32767.0))
	return b
