extends Node
## Procedural sound effects (REL-004). Every SFX is synthesized in code at startup
## (sine/noise envelopes in an AudioStreamWAV), so there are no binary assets.
## Plays through the "SFX" bus, whose volume the settings sliders control.
## Muted while the window is unfocused.

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
	"lightning": {"notes": [[90.0, 0.25]], "noise": 0.9, "gain": 0.55},
}

## Voices that can sound at once, so a click or chime never cuts off a breakthrough or thunderclap.
const VOICES := 6

var streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
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


static func _s16(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_s16(0, int(clampf(v, -1.0, 1.0) * 32767.0))
	return b
