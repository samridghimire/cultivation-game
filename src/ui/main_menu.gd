extends Control
## Title screen. Help (UI-003b) opens the same HelpScreen as the pause menu;
## it only needs GameState.data, so it works before a session exists.

const CHARACTER_CREATION := "res://src/ui/character_creation.tscn"
const WORLD := "res://src/world/world.tscn"

var _menu: Control
var _settings: SettingsScreen
var _load_screen: LoadScreen
var _help: HelpScreen


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UIStyle.label(ProjectSettings.get_setting("application/config/name"), 48, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UIStyle.label("Mortal today. Immortal, perhaps, tomorrow.", 18, Color(0.75, 0.75, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(Control.new())

	var new_game := UIStyle.button("New Game", func(): get_tree().change_scene_to_file(CHARACTER_CREATION))
	box.add_child(new_game)
	var continue_button := UIStyle.button("Continue", _continue)
	continue_button.disabled = SaveManager.most_recent_living_slot() == ""
	box.add_child(continue_button)
	var load_button := UIStyle.button("Load Game", _open_load)
	load_button.disabled = SaveManager.list_slots().is_empty()
	box.add_child(load_button)
	var settings_button := UIStyle.button("Settings", _open_settings)
	box.add_child(settings_button)
	var help_button := UIStyle.button("Help", _open_help)
	box.add_child(help_button)
	box.add_child(UIStyle.button("Quit", func(): get_tree().quit()))
	add_child(UIStyle.centered(box))
	_menu = box
	_settings = SettingsScreen.new()
	_settings.closed.connect(func():
		_menu.visible = true
		settings_button.grab_focus())
	add_child(UIStyle.centered(_settings))

	_help = HelpScreen.new()
	_help.closed.connect(func():
		_menu.visible = true
		help_button.grab_focus())
	add_child(UIStyle.centered(_help))

	_load_screen = LoadScreen.new()
	_load_screen.closed.connect(func():
		_menu.visible = true
		load_button.grab_focus())
	_load_screen.slot_chosen.connect(_load_slot)
	add_child(UIStyle.centered(_load_screen))

	(continue_button if not continue_button.disabled else new_game).grab_focus.call_deferred()


func _open_settings() -> void:
	_menu.visible = false
	_settings.open()


func _open_help() -> void:
	_menu.visible = false
	_help.open()


## The help screen, for tests.
func help_screen() -> HelpScreen:
	return _help


func _open_load() -> void:
	_menu.visible = false
	_load_screen.open()


func _load_slot(slot: String) -> void:
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file(WORLD)


func _continue() -> void:
	_load_slot(SaveManager.most_recent_living_slot())
