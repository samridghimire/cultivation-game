class_name FriendThanksCard
extends PanelContainer
## WU-642: a friend's thank-you gift (FOLK-056) on a modal card: their figure, the gift's icon and name, and their
## line (npcs.json `thanks_line`, else FALLBACK_LINE). Focus is on Continue; cancel also closes. `closed` fires once.

signal closed

const FALLBACK_LINE := "For your help with my breakthrough. With thanks."
const W := 440

var _title: Label
var _figure: TextureRect
var _icon: TextureRect
var _item: Label
var _line: Label
var _continue: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(W, 0)
	add_child(box)
	_title = UIStyle.label("", 22, UIStyle.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_figure = TextureRect.new()
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.custom_minimum_size = Vector2(0, 15 * 4 + 8)
	box.add_child(_figure)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(_icon)
	_item = UIStyle.label("", 18)
	row.add_child(_item)
	_line = UIStyle.label("", 16, Color(0.85, 0.85, 0.85))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_line)
	_continue = UIStyle.button("Continue", close)
	box.add_child(_continue)


## The friend's thanks line: their own `thanks_line` when set, else the fallback.
static func line_for(data: GameData, npc_id: String) -> String:
	var l := String(data.npcs.get(npc_id, {}).get("thanks_line", "")) if data != null else ""
	return l if l != "" else FALLBACK_LINE


func open(npc_id: String, npc_name: String, item_id: String) -> void:
	var data: GameData = GameState.data
	var item_name := String(data.items[item_id].get("name", item_id)) if data != null and data.items.has(item_id) else item_id
	_title.text = "%s sends thanks" % npc_name
	_item.text = GiftLeftCard.item_text(item_name, 1)
	var tex: Texture2D = ItemIcon.for_id(data, item_id) if data != null else null
	_icon.texture = tex
	_icon.visible = tex != null
	var look: Dictionary = preload("res://src/world/interactables/npc.gd").look_of(npc_id, Color("9a8f7a"))
	_figure.texture = PixelFigure.frame(look if look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, "down", 0)
	_line.text = line_for(data, npc_id)
	visible = true
	_continue.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func continue_button() -> Button:
	return _continue


func line_text() -> String:
	return _line.text


func item_text() -> String:
	return _item.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
