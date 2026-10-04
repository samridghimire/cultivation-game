class_name MessageLogScreen
extends PanelContainer
## Modal message history: the last EventBus.HISTORY_LIMIT messages grouped by
## date, filterable by category and by topic (UI-002b: combat, cultivation,
## family, sect, trade, world), so players can reread what happened while
## time skipped. Gamepad: d-pad picks a filter, right stick scrolls.

signal closed

## [label, category] pairs; "" shows every category.
const FILTERS := [
	["All", ""],
	["Progress", "progress"],
	["Info", "info"],
	["Warnings", "warning"],
	["Danger", "danger"],
	["Karma", "karma"],
]
## [label, topic] pairs (EventBus.TOPICS); "" shows every topic.
const TOPIC_FILTERS := [
	["All topics", ""],
	["Combat", "combat"],
	["Cultivation", "cultivation"],
	["Family", "family"],
	["Sect", "sect"],
	["Trade", "trade"],
	["World", "world"],
]
const SCROLL_SPEED := 900.0
const DATE_COLOR := Color(0.6, 0.6, 0.6)

var _filter := ""
var _filter_buttons: Array[Button] = []
var _topic := ""
var _topic_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _text: RichTextLabel
var _count: Label


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Message Log", 24, UIStyle.ACCENT))

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	box.add_child(filters)
	var group := ButtonGroup.new()
	for f in FILTERS:
		var category: String = f[1]
		var b := UIStyle.button(f[0], _set_filter.bind(category))
		b.toggle_mode = true
		b.button_group = group
		if category != "":
			b.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS[category])
		filters.add_child(b)
		_filter_buttons.append(b)
	var topics := HBoxContainer.new()
	topics.add_theme_constant_override("separation", 6)
	box.add_child(topics)
	var topic_group := ButtonGroup.new()
	for f in TOPIC_FILTERS:
		var b := UIStyle.button(f[0], _set_topic.bind(String(f[1])))
		b.toggle_mode = true
		b.button_group = topic_group
		topics.add_child(b)
		_topic_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(736, 440)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 15)
	_scroll.add_child(_text)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	footer.add_child(UIStyle.button("Close", close))
	_count = UIStyle.label("", 14, DATE_COLOR)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_count)
	footer.add_child(UIStyle.label("[PgUp/PgDn] or right stick: scroll", 14, DATE_COLOR))
	EventBus.message_posted.connect(func(_t, _c): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Input.get_axis("scroll_up", "scroll_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


func open() -> void:
	_filter = ""
	_filter_buttons[0].button_pressed = true
	_topic = ""
	_topic_buttons[0].button_pressed = true
	_rebuild()
	visible = true
	_filter_buttons[0].grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## History entries matching `category` and `topic` ("" = any), oldest first.
static func filtered(history: Array, category: String, topic: String = "") -> Array:
	return history.filter(func(e: Dictionary) -> bool:
		return (category == "" or e.get("category", "") == category) and (topic == "" or e.get("topic", "") == topic))


## BBCode for `entries`, with a date line whenever the day changes.
static func format_entries(entries: Array) -> String:
	var out := PackedStringArray()
	var last_day := -1
	for e: Dictionary in entries:
		var day := int(e.get("day", 0))
		if day != last_day:
			out.append("[color=#%s]%s[/color]" % [DATE_COLOR.to_html(false), Calendar.format_date(day)])
			last_day = day
		var color: Color = UIStyle.CATEGORY_COLORS.get(e.get("category", "info"), Color.WHITE)
		out.append("  [color=#%s]%s[/color]" % [color.to_html(false), String(e.get("text", "")).replace("[", "[lb]")])
	return "\n".join(out)


func _set_filter(category: String) -> void:
	_filter = category
	_rebuild()


func _set_topic(topic: String) -> void:
	_topic = topic
	_rebuild()


func _rebuild() -> void:
	var entries := filtered(EventBus.history, _filter, _topic)
	_text.clear()
	if entries.is_empty():
		_text.append_text("[color=#%s]Nothing to show yet.[/color]" % DATE_COLOR.to_html(false))
	else:
		_text.append_text(format_entries(entries))
	_count.text = "%d of %d messages" % [entries.size(), EventBus.history.size()]
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
