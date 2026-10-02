class_name PauseMenu
extends PanelContainer
## Modal pause menu opened with the pause_menu action (Esc / Start).

signal closed
## The player chose Settings; the owner shows a SettingsScreen.
signal settings_requested

const MAIN_MENU := "res://src/ui/main_menu.tscn"

var _load_button: Button
var _status: Label


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel().get_theme_stylebox("panel"))
	custom_minimum_size = Vector2(360, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := UIStyle.label("Paused", 26, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIStyle.button("Resume", close))
	box.add_child(UIStyle.button("Save Game", _save))
	_load_button = UIStyle.button("Load Game", _load)
	box.add_child(_load_button)
	box.add_child(UIStyle.button("Settings", settings_requested.emit))
	box.add_child(UIStyle.button("Save and Quit to Menu", _quit_to_menu))
	_status = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_status.text = ""
	_load_button.disabled = not SaveManager.has_save()
	visible = true
	(get_child(0).get_child(1) as Button).grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _save() -> void:
	if SaveManager.save_game():
		_status.text = "Game saved."
		_load_button.disabled = false
		EventBus.post("Game saved.")
	else:
		_status.text = "Could not save the game."


func _load() -> void:
	if SaveManager.load_game():
		get_tree().reload_current_scene()
	else:
		_status.text = "Could not load the save."


func _quit_to_menu() -> void:
	if GameState.player.alive:
		SaveManager.save_game()
	GameState.end_session()
	get_tree().change_scene_to_file(MAIN_MENU)
