extends Control
## Title screen.

const CHARACTER_CREATION := "res://src/ui/character_creation.tscn"
const WORLD := "res://src/world/world.tscn"


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
	continue_button.disabled = not SaveManager.has_save()
	box.add_child(continue_button)
	box.add_child(UIStyle.button("Quit", func(): get_tree().quit()))
	add_child(UIStyle.centered(box))

	(continue_button if not continue_button.disabled else new_game).grab_focus.call_deferred()


func _continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file(WORLD)
