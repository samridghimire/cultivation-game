extends TestCase
## Settings persistence and validation. Uses a throwaway file, never the
## player's real user://settings.cfg.

const SettingsScript := preload("res://src/autoload/settings.gd")
const TEST_PATH := "user://_test_settings.cfg"


func _fresh() -> Node:
	var s: Node = SettingsScript.new()
	s.path = TEST_PATH
	return s


func _cleanup(s: Node) -> void:
	s.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_sanitize_clamps_and_rejects_bad_values() -> void:
	assert_eq(SettingsScript.sanitize("window_mode", "borderless"), "windowed")
	assert_eq(SettingsScript.sanitize("window_mode", "fullscreen"), "fullscreen")
	assert_almost_eq(SettingsScript.sanitize("ui_scale", 9.0), SettingsScript.UI_SCALE_RANGE.y)
	assert_almost_eq(SettingsScript.sanitize("ui_scale", 0.1), SettingsScript.UI_SCALE_RANGE.x)
	assert_almost_eq(SettingsScript.sanitize("sfx_volume", -1.0), 0.0)
	assert_almost_eq(SettingsScript.sanitize("music_volume", 0.4), 0.4)
	assert_eq(SettingsScript.sanitize("show_hints", false), false)
	assert_eq(SettingsScript.sanitize("show_hints", "yes"), true)


func test_missing_file_gives_defaults() -> void:
	var s := _fresh()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	s.load_settings()
	for key in SettingsScript.DEFAULTS:
		assert_eq(s.get_value(key), SettingsScript.DEFAULTS[key], key)
	_cleanup(s)


func test_save_and_load_round_trip() -> void:
	var s := _fresh()
	s._values["music_volume"] = 0.25
	s._values["window_mode"] = "fullscreen"
	s.save_settings()
	var t := _fresh()
	t.load_settings()
	assert_almost_eq(t.get_value("music_volume"), 0.25)
	assert_eq(t.get_value("window_mode"), "fullscreen")
	t.free()
	_cleanup(s)


func test_hand_edited_file_is_sanitized_on_load() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SettingsScript.SECTION, "ui_scale", 40.0)
	cfg.set_value(SettingsScript.SECTION, "window_mode", 7)
	cfg.save(TEST_PATH)
	var s := _fresh()
	s.load_settings()
	assert_almost_eq(s.get_value("ui_scale"), SettingsScript.UI_SCALE_RANGE.y)
	assert_eq(s.get_value("window_mode"), "windowed")
	_cleanup(s)


func test_slider_labels() -> void:
	assert_eq(SettingsScreen.format_value("master_volume", 0.0), "Off")
	assert_eq(SettingsScreen.format_value("master_volume", 0.8), "80%")
	assert_eq(SettingsScreen.format_value("ui_scale", 1.25), "125%")
