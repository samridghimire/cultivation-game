class_name FriendSceneCard
extends PanelContainer
## WU-467: a small centred card for a friend scene (EventBus.friend_scene): the villager's figure, name and the
## scene text, with a Close button that takes focus. Confirm/cancel also closes it. No motion.

signal closed

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const WRAP_WIDTH := 460
const ZOOM := 5

var _face: TextureRect
var _name: Label
var _text: Label
var _button: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	_face = TextureRect.new()
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_face.custom_minimum_size = Vector2(PixelFigure.SIZE * ZOOM)
	box.add_child(_face)
	_name = UIStyle.label("", 24, Color(0.95, 0.8, 0.35))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	_text = UIStyle.label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_button = UIStyle.button("Close", close)
	box.add_child(_button)


## `npc_id` picks the figure's look ("" = a plain villager).
func open(npc_id: String, npc_name: String, text: String) -> void:
	_face.texture = PixelFigure.frame(NPC_SCRIPT.look_of(npc_id, Color("9a8f7a")), "down", 0)
	_name.text = npc_name
	_text.text = text
	visible = true
	_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func button() -> Button:
	return _button


func scene_text() -> String:
	return _text.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()
