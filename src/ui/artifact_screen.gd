class_name ArtifactScreen
extends PanelContainer
## Modal Creation Artifact screen (ART-002b): energy and sealed/unsealed
## functions (ArtifactFunctions.describe), feeding spirit stones or carried
## items for energy, unsealing functions, and the Storage Space panel that
## moves items between the inventory and the artifact. ui_cancel goes back
## from a sub-page, then closes.

signal closed

const STONE_AMOUNTS: Array[int] = [10, 100]
const PAGE_MAIN := "main"
const PAGE_FEED := "feed"
const PAGE_STORAGE := "storage"

var _title: Label
var _info: Label
var _rows: VBoxContainer
var _close_button: Button
var _page := PAGE_MAIN


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(680, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("Creation Artifact", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_info = UIStyle.label("", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(656, 0)
	box.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(656, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _page != PAGE_MAIN:
			_show_page(PAGE_MAIN)
		else:
			close()


func open() -> void:
	_page = PAGE_MAIN
	_rebuild()
	visible = true
	_focus("")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The page currently shown (PAGE_MAIN, PAGE_FEED or PAGE_STORAGE).
func page() -> String:
	return _page


## Buttons of the current page, for tests and focus.
func buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b in _rows.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append(b as Button)
	return out


func _show_page(new_page: String) -> void:
	_page = new_page
	_rebuild()
	_focus("")


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	if p == null:
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focused_name := String(focused.name) if focused != null and _rows.is_ancestor_of(focused) else ""
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	match _page:
		PAGE_FEED:
			_build_feed(p, data)
		PAGE_STORAGE:
			_build_storage(p, data)
		_:
			_build_main(p, data)
	if focused_name != "":
		_focus(focused_name)


func _build_main(p: CharacterData, data: GameData) -> void:
	_title.text = "Creation Artifact"
	var lines: Array[String] = []
	for line in ArtifactFunctions.describe(p, data, GameState.world_flags):
		if not line.begins_with("  "):
			lines.append(line)
	_info.text = "\n".join(lines)
	for amount in STONE_AMOUNTS:
		var reason := ArtifactFunctions.check_feed(p, data, "spirit_stone", amount)
		_add_button("feed_stones_%d" % amount, "Feed %d spirit stones (+%d energy)" % [amount, amount * ArtifactFunctions.energy_value(data, "spirit_stone")], reason, GameState.feed_artifact.bind("spirit_stone", amount))
	_add_button("feed_item", "Feed an item...", "", _show_page.bind(PAGE_FEED))
	for def: Dictionary in data.artifact.get("functions", []):
		var function_id := String(def.get("id", ""))
		if ArtifactFunctions.is_unlocked(p, function_id):
			continue
		var cost := int(def.get("unlock", {}).get("energy", 0))
		var reason := ArtifactFunctions.check_unlock(p, data, function_id, GameState.world_flags)
		_add_button("unseal_" + function_id, "Unseal %s (%d energy)" % [def.get("name", function_id), cost], reason, GameState.unlock_artifact_function.bind(function_id))
	var storage_reason := "" if ArtifactFunctions.is_unlocked(p, "storage") else "sealed"
	_add_button("storage", "%s..." % ArtifactFunctions.function_name(data, "storage"), storage_reason, _show_page.bind(PAGE_STORAGE))


func _build_feed(p: CharacterData, data: GameData) -> void:
	_title.text = "Feed the Artifact"
	_info.text = "Artifact energy: %d. Fed items are consumed." % p.artifact_energy
	_add_button("back", "Back", "", _show_page.bind(PAGE_MAIN))
	for item_id in _sorted_ids(p.inventory, data):
		var value := ArtifactFunctions.energy_value(data, item_id)
		if value <= 0:
			continue
		var count := p.item_count(item_id)
		var row := _add_row("%s x%d (+%d energy each)" % [_item_name(data, item_id), count, value])
		_add_button("feed1_" + item_id, "Feed 1", ArtifactFunctions.check_feed(p, data, item_id, 1), GameState.feed_artifact.bind(item_id, 1), row)
		if count > 1:
			_add_button("feedall_" + item_id, "Feed all", ArtifactFunctions.check_feed(p, data, item_id, count), GameState.feed_artifact.bind(item_id, count), row)


func _build_storage(p: CharacterData, data: GameData) -> void:
	_title.text = ArtifactFunctions.function_name(data, "storage")
	_info.text = "%d / %d kinds stored. Stored items stay with you even through death." % [p.artifact_storage.size(), ArtifactFunctions.storage_slots(p, data)]
	_add_button("back", "Back", "", _show_page.bind(PAGE_MAIN))
	_rows.add_child(UIStyle.label("Inside the artifact", 17, UIStyle.ACCENT))
	if p.artifact_storage.is_empty():
		_rows.add_child(UIStyle.label("Nothing yet.", 15, Color(0.7, 0.7, 0.7)))
	for item_id in _sorted_ids(p.artifact_storage, data):
		var count := int(p.artifact_storage[item_id])
		var row := _add_row("%s x%d" % [_item_name(data, item_id), count])
		_add_button("take1_" + item_id, "Take 1", "", GameState.retrieve_from_artifact.bind(item_id, 1), row)
		if count > 1:
			_add_button("takeall_" + item_id, "Take all", "", GameState.retrieve_from_artifact.bind(item_id, count), row)
	_rows.add_child(UIStyle.label("Carried", 17, UIStyle.ACCENT))
	for item_id in _sorted_ids(p.inventory, data):
		var count := p.item_count(item_id)
		var row := _add_row("%s x%d" % [_item_name(data, item_id), count])
		_add_button("store1_" + item_id, "Store 1", ArtifactFunctions.check_store(p, data, item_id, 1), GameState.store_in_artifact.bind(item_id, 1), row)
		if count > 1:
			_add_button("storeall_" + item_id, "Store all", ArtifactFunctions.check_store(p, data, item_id, count), GameState.store_in_artifact.bind(item_id, count), row)


## A row with a label; buttons are added to it by _add_button.
func _add_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UIStyle.label(text, 16)
	l.custom_minimum_size = Vector2(380, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	_rows.add_child(row)
	return row


## A button that shows `reason` and is disabled when it is not "".
func _add_button(node_name: String, text: String, reason: String, action: Callable, parent: Control = null) -> Button:
	if reason != "" and parent == null:
		text += " (%s)" % reason
	elif reason != "":
		var row_label := parent.get_child(0) as Label
		if not row_label.text.ends_with("(%s)" % reason):
			row_label.text += "  (%s)" % reason
	var b := UIStyle.button(text, action)
	b.name = node_name.validate_node_name()
	b.disabled = reason != ""
	if reason != "":
		b.tooltip_text = reason
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	(parent if parent != null else _rows).add_child(b)
	return b


func _focus(node_name: String) -> void:
	_focus_now.call_deferred(node_name)


func _focus_now(node_name: String) -> void:
	if not visible:
		return
	var enabled := buttons().filter(func(b: Button) -> bool: return not b.disabled)
	for b: Button in enabled:
		if String(b.name) == node_name:
			b.grab_focus()
			return
	if not enabled.is_empty():
		(enabled[0] as Button).grab_focus()
	else:
		_close_button.grab_focus()


static func _sorted_ids(items: Dictionary, data: GameData) -> Array:
	var ids: Array = items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return _item_name(data, a).naturalnocasecmp_to(_item_name(data, b)) < 0)
	return ids


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))
