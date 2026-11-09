class_name MainMenu
extends Control
## Title screen. Help (UI-003b) opens the same HelpScreen as the pause menu;
## it only needs GameState.data, so it works before a session exists.

const CHARACTER_CREATION := "res://src/ui/character_creation.tscn"
const WORLD := "res://src/world/world.tscn"

var _menu: Control
var _settings: SettingsScreen
var _load_screen: LoadScreen
var _help: HelpScreen
var _credits: CreditsScreen


func _ready() -> void:
	add_child(TitleBackdrop.new())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360, 0)
	# GFX-105: the title sits on a framed plaque; the tagline under it in the dim gold accent.
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UIStyle.panel_style())
	var plaque_box := VBoxContainer.new()
	plaque_box.add_theme_constant_override("separation", 4)
	var title := UIStyle.label(ProjectSettings.get_setting("application/config/name"), 32, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque_box.add_child(title)
	var subtitle := UIStyle.label("Mortal today. Immortal, perhaps, tomorrow.", 16, UIStyle.ACCENT.darkened(0.25))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque_box.add_child(subtitle)
	plaque.add_child(plaque_box)
	box.add_child(plaque)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)

	var new_game := UIStyle.button("New Game", func(): get_tree().change_scene_to_file(CHARACTER_CREATION))
	box.add_child(new_game)
	var continue_button := UIStyle.button(continue_label(), _continue)
	continue_button.disabled = SaveManager.most_recent_living_slot() == ""
	continue_button.clip_text = true
	continue_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(continue_button)
	var load_button := UIStyle.button("Load Game", _open_load)
	load_button.disabled = SaveManager.list_slots().is_empty()
	box.add_child(load_button)
	var settings_button := UIStyle.button("Settings", _open_settings)
	box.add_child(settings_button)
	var help_button := UIStyle.button("Help", _open_help)
	box.add_child(help_button)
	var credits_button := UIStyle.button("Credits", _open_credits)
	box.add_child(credits_button)
	box.add_child(UIStyle.button("Quit", func(): get_tree().quit()))
	# Lower-left column over the dark foreground; the moon, pavilion and figure stay clear.
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	add_child(box)
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

	_credits = CreditsScreen.new()
	_credits.closed.connect(func():
		_menu.visible = true
		credits_button.grab_focus())
	add_child(UIStyle.centered(_credits))

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


func _open_credits() -> void:
	_menu.visible = false
	_credits.open()


## The credits screen, for tests.
func credits_screen() -> CreditsScreen:
	return _credits


## The help screen, for tests.
func help_screen() -> HelpScreen:
	return _help


func _open_load() -> void:
	_menu.visible = false
	_load_screen.open()


func _load_slot(slot: String) -> void:
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file(WORLD)


## "Continue: Li Wei, Qi Refining 3, age 16" for the newest live slot, or plain "Continue".
static func continue_label() -> String:
	var slot := SaveManager.most_recent_living_slot()
	if slot == "":
		return "Continue"
	var meta := SaveManager.read_meta(slot)
	return "Continue: %s, %s, age %d" % [meta.get("name", "?"), meta.get("realm_label", "?"), int(meta.get("age", 0))]


func _continue() -> void:
	_load_slot(SaveManager.most_recent_living_slot())
