class_name GiftLeftCard
extends Control
## WU-600: a small bottom-centre card "From <Name>" when a friend leaves a gift on arrival
## (EventBus.friend_gift_left): item icon, name x count and the friend's line. Gifts queue and show
## one after another, HOLD_SECONDS each; a confirm press skips the current one. Never takes focus or
## pauses time.

const HOLD_SECONDS := 3.0

var _panel: PanelContainer
var _title: Label
var _icon: TextureRect
var _item: Label
var _line: Label
var _queue: Array = []  ## waiting entries: {name, item_id, count, line}
var _left := 0.0  ## seconds the current card has left


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	_panel = UIStyle.panel(Vector2(460, 0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -96  # above the key-hint strip
	_panel.offset_bottom = -96
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = UIStyle.label("", 20, UIStyle.ACCENT)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(_icon)
	_item = UIStyle.label("", 18)
	row.add_child(_item)
	_line = UIStyle.label("", 16, Color(0.8, 0.8, 0.8))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(430, 0)
	box.add_child(_line)


## "Honey x2" / "Honey": the item line of the card.
static func item_text(item_name: String, count: int) -> String:
	return "%s x%d" % [item_name, count] if count > 1 else item_name


## Add a gift; it shows now when nothing is showing, else after the ones before it.
func enqueue(npc_name: String, item_id: String, count: int, line: String) -> void:
	_queue.append({"name": npc_name, "item_id": item_id, "count": count, "line": line})
	if not visible:
		_next()


## Number of gifts still waiting (not counting the one showing).
func queued_count() -> int:
	return _queue.size()


## End the current card (a confirm press, or the hold running out) and show the next one.
func skip() -> void:
	if visible:
		_next()


func _next() -> void:
	if _queue.is_empty():
		visible = false
		return
	var e: Dictionary = _queue.pop_front()
	var data: GameData = GameState.data
	var item_name: String = String(data.items[e["item_id"]].get("name", e["item_id"])) if data != null and data.items.has(e["item_id"]) else String(e["item_id"])
	_title.text = "From %s" % e["name"]
	_item.text = item_text(item_name, int(e["count"]))
	var tex: Texture2D = ItemIcon.for_id(data, String(e["item_id"])) if data != null else null
	_icon.texture = tex
	_icon.visible = tex != null
	_line.text = String(e["line"])
	_left = HOLD_SECONDS
	visible = true


func _process(delta: float) -> void:
	if visible:
		_left -= delta
		if _left <= 0.0:
			_next()


func _input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		skip()
