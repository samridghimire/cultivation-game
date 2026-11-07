class_name FriendSceneCard
extends PanelContainer
## WU-467: a small centred card for a friend scene (EventBus.friend_scene): the villager's figure, name and the
## scene text, with a Close button that takes focus. Confirm/cancel also closes it. No motion.

signal closed

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const WRAP_WIDTH := 400
const ZOOM := 5

var _portrait: PortraitBox
var _name: Label
var _text: Label
var _gift: Label
var _gift_row: HBoxContainer
var _gift_icon: TextureRect
var _learned: Label
var _button: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_portrait = PortraitBox.new(ZOOM)  # WU-476: a real 5x face in a framed inset
	row.add_child(_portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	row.add_child(box)
	_name = UIStyle.label("", 24, Color(0.95, 0.8, 0.35))
	box.add_child(_name)
	_text = UIStyle.label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_gift_row = HBoxContainer.new()  # GFX-092: the gift's icon before the line
	_gift_row.add_theme_constant_override("separation", 6)
	_gift_row.visible = false
	box.add_child(_gift_row)
	_gift_icon = TextureRect.new()
	_gift_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gift_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_gift_icon.custom_minimum_size = Vector2(24, 24)
	_gift_icon.visible = false
	_gift_row.add_child(_gift_icon)
	_gift = UIStyle.label("", 17, Color(0.95, 0.8, 0.35))
	_gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gift.custom_minimum_size = Vector2(WRAP_WIDTH - 32, 0)
	_gift_row.add_child(_gift)
	_learned = UIStyle.label("", 17, Color(0.95, 0.8, 0.35))  # WU-479: "You learned: ..." for a lesson
	_learned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learned.visible = false
	box.add_child(_learned)
	_button = UIStyle.button("Close", close)
	box.add_child(_button)


## `npc_id` picks the figure's look ("" = a plain villager).
func open(npc_id: String, npc_name: String, text: String, gift_name: String = "", gift_id: String = "", learned: String = "") -> void:
	_portrait.set_portrait(PixelFigure.frame(NPC_SCRIPT.look_of(npc_id, Color("9a8f7a")), "down", 0))
	_name.text = npc_name
	_text.text = text
	_gift.text = "They give you %s." % gift_name if gift_name != "" else ""
	_gift_row.visible = gift_name != ""
	var tex: Texture2D = ItemIcon.for_id(GameState.data, gift_id) if gift_id != "" and GameState.data != null else null
	_gift_icon.texture = tex
	_gift_icon.visible = tex != null
	_learned.text = "You learned: %s" % learned if learned != "" else ""
	_learned.visible = learned != ""
	visible = true
	_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The face texture rect's drawn size (WU-476 test).
func face_size() -> Vector2:
	return _portrait.get_child(0).custom_minimum_size


func button() -> Button:
	return _button


func gift_text() -> String:
	return _gift.text if _gift_row.visible else ""


## True when the gift row shows an item icon (GFX-092 test).
func has_gift_icon() -> bool:
	return _gift_row.visible and _gift_icon.visible


## The gold "You learned: ..." line, or "" when hidden (WU-479 test).
func learned_text() -> String:
	return _learned.text if _learned.visible else ""


func scene_text() -> String:
	return _text.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()
