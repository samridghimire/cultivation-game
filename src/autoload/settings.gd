extends Node
## Player preferences (window mode, UI scale, volume, HUD hints, fast time skips) persisted to
## user://settings.cfg and applied on boot. Change values with set_value() so
## they are applied and saved together.

signal changed(key: String, value: Variant)

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const WINDOW_MODES: PackedStringArray = ["windowed", "fullscreen"]
const UI_SCALE_RANGE := Vector2(0.75, 1.5)
## Audio bus name -> settings key. Missing buses are created on boot.
const VOLUME_BUSES := {"Master": "master_volume", "Music": "music_volume", "SFX": "sfx_volume"}
const DEFAULTS := {
	"window_mode": "windowed",
	"ui_scale": 1.0,
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	# How many next-step hints the HUD shows, 0-3 (0 hides the panel).
	"hud_hints": 2,
	# Skip the time-skip overlay after meditation, travel... (UI-010).
	"fast_time_skips": false,
	# Silent autosave on travel, breakthrough, each month and window close (REL-001).
	"autosave": true,
	# Banner card with the year's review on each new year (WU-031).
	"yearly_recap": true,
}

var path := DEFAULT_PATH
var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply_all()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


## Validates, applies and saves one setting.
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("Unknown setting '%s'" % key)
		return
	_values[key] = sanitize(key, value)
	_apply(key)
	save_settings()
	changed.emit(key, _values[key])


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
	apply_all()
	save_settings()


## Clamps or replaces an out-of-range value, so a hand-edited file can't break anything.
static func sanitize(key: String, value: Variant) -> Variant:
	match key:
		"window_mode":
			return str(value) if WINDOW_MODES.has(str(value)) else DEFAULTS["window_mode"]
		"ui_scale":
			return clampf(float(value), UI_SCALE_RANGE.x, UI_SCALE_RANGE.y)
		"hud_hints":
			return clampi(int(value), 0, 3) if value is int or value is float else DEFAULTS["hud_hints"]
		"autosave", "yearly_recap":
			return value if value is bool else DEFAULTS[key]
		"fast_time_skips":
			return (value is bool and value) or str(value).to_lower() == "true"
		_:
			return clampf(float(value), 0.0, 1.0)


func load_settings() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key in DEFAULTS:
		_values[key] = sanitize(key, cfg.get_value(SECTION, key, DEFAULTS[key]))
	# Older settings files had a show_hints checkbox.
	if not cfg.has_section_key(SECTION, "hud_hints") and cfg.get_value(SECTION, "show_hints", true) == false:
		_values["hud_hints"] = 0


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(path)
	if err != OK:
		push_error("Could not save settings to %s: %s" % [path, error_string(err)])


func apply_all() -> void:
	for key in _values:
		_apply(key)


func _apply(key: String) -> void:
	var value: Variant = _values[key]
	match key:
		"window_mode":
			# The headless display server used by tests has no real window.
			if DisplayServer.get_name() != "headless":
				var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
				DisplayServer.window_set_mode(mode)
		"ui_scale":
			get_tree().root.content_scale_factor = value
		_:
			for bus_name in VOLUME_BUSES:
				if VOLUME_BUSES[bus_name] == key:
					var idx := AudioServer.get_bus_index(bus_name)
					AudioServer.set_bus_volume_db(idx, linear_to_db(value))
					AudioServer.set_bus_mute(idx, value <= 0.0)


func _ensure_buses() -> void:
	for bus_name in VOLUME_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
