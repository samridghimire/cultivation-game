class_name ArtifactScreen
extends PanelContainer
## Modal Creation Artifact screen (ART-002b): energy and sealed/unsealed
## functions (ArtifactFunctions.describe), feeding spirit stones or carried
## items for energy, unsealing functions, the Storage Space panel that
## moves items between the inventory and the artifact, and the Lives & Anchors
## page (ART-005b): recharge lives, pick the respawn point or release anchors
## from anywhere. Once unsealed, "Enter the Inner World" cultivates there
## (ART-003b, GameState.enter_inner_world). ui_cancel goes back
## from a sub-page, then closes.

signal closed

const STONE_AMOUNTS: Array[int] = [10, 100]
## Stone feeds of at least this many stones ask for a second press.
const CONFIRM_STONES := 100
const PAGE_MAIN := "main"
const PAGE_FEED := "feed"
const PAGE_STORAGE := "storage"
const PAGE_ANCHORS := "anchors"
const PAGE_GARDEN := "garden"

var _title: Label
var _info: Label
var _rows: VBoxContainer
var _energy_bar: ProgressBar
var _energy_caption: Label
var _close_button: Button
var _page := PAGE_MAIN
## Node name of the button waiting for a second press (WU-032), "" = none.
var _armed := ""


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
	_energy_bar = UIStyle.bar(Vector2(656, 14), UIStyle.CATEGORY_COLORS["artifact"])
	box.add_child(_energy_bar)
	_energy_caption = UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["artifact"])
	box.add_child(_energy_caption)
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
	EventBus.player_changed.connect(_on_player_changed_rebuild)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _page != PAGE_MAIN:
			_show_page(PAGE_MAIN)
		else:
			close()


func open() -> void:
	_page = PAGE_MAIN
	var p := GameState.player
	# WU-340: a nearly-dead player lands on the recharge button.
	var low := p != null and p.artifact_lives >= 0 and p.artifact_lives <= Guidance.LOW_ARTIFACT_LIVES
	if low:
		_page = PAGE_ANCHORS
	_rebuild()
	visible = true
	_focus("recharge" if low else "")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The page currently shown (PAGE_MAIN, PAGE_FEED, PAGE_STORAGE or PAGE_ANCHORS).
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
	_armed = ""
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
	_energy_bar.visible = false
	_energy_caption.visible = false
	match _page:
		PAGE_FEED:
			_build_feed(p, data)
		PAGE_STORAGE:
			_build_storage(p, data)
		PAGE_ANCHORS:
			_build_anchors(p, data)
		PAGE_GARDEN:
			_build_garden(p, data)
		_:
			_build_main(p, data)
	if focused_name != "":
		_focus(focused_name)


func _build_main(p: CharacterData, data: GameData) -> void:
	_title.text = "Creation Artifact"
	var max_lives := int(data.artifact.get("max_lives", 9))
	_info.text = "Lives: %d / %d  %s   |   Next life: %d stones" % [p.artifact_lives, max_lives, pips(p.artifact_lives, max_lives), CreationArtifact.recharge_cost(p, data)]
	_show_energy(p, data)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(grid)
	for function_id: String in ArtifactFunctions.KNOWN:
		if not ArtifactFunctions.get_def(data, function_id).is_empty():
			_add_card(grid, p, data, function_id)
	for amount in STONE_AMOUNTS:
		var reason := ArtifactFunctions.check_feed(p, data, "spirit_stone", amount)
		var feed_text := "Feed %d spirit stones (+%d energy)" % [amount, amount * ArtifactFunctions.energy_value(data, "spirit_stone")]
		if amount >= CONFIRM_STONES:
			_add_confirm_button("feed_stones_%d" % amount, feed_text, reason, GameState.feed_artifact.bind("spirit_stone", amount), "Confirm: feed %d stones?" % amount)
		else:
			_add_button("feed_stones_%d" % amount, feed_text, reason, GameState.feed_artifact.bind("spirit_stone", amount))
	_add_button("feed_item", "Feed an item...", "", _show_page.bind(PAGE_FEED))
	_add_button("anchors", "Lives & anchors...", "", _show_page.bind(PAGE_ANCHORS))
	if ArtifactFunctions.is_unlocked(p, InnerWorld.FUNCTION):
		var days := InnerWorld.max_days(data)
		_add_button("inner_world", "Enter the Inner World (%s outside, %s inside)" % [Calendar.format_duration(days), Calendar.format_duration(InnerWorld.inner_days(data, days))], InnerWorld.check_enter(p, data, days), GameState.enter_inner_world.bind(days))


## WU-524: filled diamonds for the lives held, hollow ones up to the cap.
static func pips(lives: int, max_lives: int) -> String:
	return "◆".repeat(clampi(lives, 0, max_lives)) + "◇".repeat(maxi(max_lives - lives, 0))


## WU-524: the energy bar toward the cheapest sealed power, with its caption.
func _show_energy(p: CharacterData, data: GameData) -> void:
	var target := ""
	var cost := 0
	for function_id: String in ArtifactFunctions.KNOWN:
		var st := ArtifactFunctions.status(p, data, function_id, GameState.world_flags)
		if st["state"] != "open" and not ArtifactFunctions.get_def(data, function_id).is_empty() and (target == "" or int(st["cost"]) < cost):
			target = String(st["name"])
			cost = int(st["cost"])
	_energy_bar.visible = true
	_energy_caption.visible = true
	_energy_bar.max_value = maxi(cost, 1)
	_energy_bar.value = mini(p.artifact_energy, maxi(cost, 1)) if target != "" else 1
	_energy_caption.text = "Energy %d / %d (%s)" % [p.artifact_energy, cost, target] if target != "" else "Energy %d. All seals broken" % p.artifact_energy


## One power card: name, state chip and a single line. Ready cards unseal, open ones open their page.
func _add_card(grid: GridContainer, p: CharacterData, data: GameData, function_id: String) -> void:
	var st := ArtifactFunctions.status(p, data, function_id, GameState.world_flags)
	var state := String(st["state"])
	var line := ""
	var action := Callable()
	match state:
		"open":
			var desc := String(ArtifactFunctions.get_def(data, function_id).get("description", ""))
			line = desc.get_slice(". ", 0).trim_suffix(".") + "."
			match function_id:
				"storage":
					action = _show_page.bind(PAGE_STORAGE)
				"spirit_garden":
					action = _show_page.bind(PAGE_GARDEN)
		"ready":
			line = "Ready: press to unseal (%d energy)" % int(st["cost"])
			action = GameState.unlock_artifact_function.bind(function_id)
		_:
			line = String(st["need"]).capitalize() if String(st["need"]).length() < 2 else String(st["need"]).substr(0, 1).to_upper() + String(st["need"]).substr(1)
	var chip := {"open": "OPEN", "ready": "READY", "sealed": "SEALED"}[state] as String
	var b := UIStyle.button("%s   [%s]\n%s" % [st["name"], chip, line], action if action.is_valid() else Callable())
	b.name = ("card_" + function_id).validate_node_name()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(320, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.set_meta("state", state)
	if state == "sealed":
		b.tooltip_text = "Needs " + String(st["need"])
		UIStyle.tint_button_text(b, Color(0.62, 0.62, 0.68))
	elif state == "ready":
		UIStyle.tint_button_text(b, UIStyle.DANGER_COLORS["Weak"])
	else:
		UIStyle.tint_button_text(b, UIStyle.ACCENT)
	grid.add_child(b)


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
			_add_confirm_button("feedall_" + item_id, "Feed all", ArtifactFunctions.check_feed(p, data, item_id, count), GameState.feed_artifact.bind(item_id, count), "Confirm: feed %d items?" % count, row)


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


func _build_anchors(p: CharacterData, data: GameData) -> void:
	_title.text = "Lives & Anchors"
	var lines := CreationArtifact.describe(p, data)
	_info.text = "%s\n%s. If you fall with a life left, you may awaken at any bound anchor; the respawn point is offered first. Bind new anchors at anchor places in the world." % [lines[0], lines[1]]
	_add_button("back", "Back", "", _show_page.bind(PAGE_MAIN))
	_add_button("recharge", "Recharge: buy a life (%d spirit stones)" % CreationArtifact.recharge_cost(p, data), CreationArtifact.check_recharge(p, data), GameState.recharge_artifact)
	if p.anchors.is_empty():
		_rows.add_child(UIStyle.label("No anchors are bound. You would awaken in %s." % Exploration.region_name(data, data.start_region), 15, Color(0.7, 0.7, 0.7)))
	for i in range(p.anchors.size() - 1, -1, -1):
		var anchor_id: String = p.anchors[i]
		var current := i == p.anchors.size() - 1
		var row := _add_row(CreationArtifact.anchor_name(data, anchor_id) + ("  (respawn point)" if current else ""))
		if not current:
			_add_button("respawn_" + anchor_id, "Make respawn point", "", GameState.bind_anchor.bind(anchor_id), row)
		_add_button("release_" + anchor_id, "Release", "", GameState.unbind_anchor.bind(anchor_id), row)


func _build_garden(p: CharacterData, data: GameData) -> void:
	_title.text = ArtifactFunctions.function_name(data, SpiritGarden.FUNCTION)
	_info.text = "Herbs grow on inner-world time: %d inner days for every day outside.\n%s" % [InnerWorld.inner_days(data, 1), "\n".join(SpiritGarden.describe(p, data))]
	_add_button("back", "Back", "", _show_page.bind(PAGE_MAIN))
	var ready := p.garden.any(func(plot: Dictionary) -> bool: return int(plot["days_left"]) <= 0)
	_add_button("harvest", "Harvest", "" if ready else "nothing is ready", GameState.harvest_garden)
	for item_id in SpiritGarden.plantable(data):
		if p.item_count(item_id) <= 0:
			continue
		var plant := SpiritGarden.plant_def(data, item_id)
		var days := ceili(float(plant.get("days", 1)) / float(InnerWorld.inner_days(data, 1)))
		var label := "Plant %s (x%d carried; ready in %s, yields %d-%d)" % [_item_name(data, item_id), p.item_count(item_id), Calendar.format_duration(days), int(plant["yield"][0]), int(plant["yield"][1])]
		_add_button("plant_" + item_id, label, SpiritGarden.check_plant(p, data, item_id), GameState.plant_in_garden.bind(item_id))


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


## A button that needs two presses: the first arms it ("Confirm: ..."), the
## second runs `action`. Moving focus away disarms it.
func _add_confirm_button(node_name: String, text: String, reason: String, action: Callable, confirm_text: String, parent: Control = null) -> Button:
	var id := node_name.validate_node_name()
	var armed := _armed == id and reason == ""
	var b := _add_button(node_name, confirm_text if armed else text, reason, _confirm_pressed.bind(id, action), parent)
	if armed:
		b.focus_exited.connect(_disarm_if_unfocused.bind(b).call_deferred)
	return b


func _confirm_pressed(node_name: String, action: Callable) -> void:
	if _armed != node_name:
		_armed = node_name
		_rebuild()
		_focus(node_name)
		return
	_armed = ""
	action.call()
	_focus(node_name)


func _disarm_if_unfocused(button: Button) -> void:
	if _armed == "" or (is_instance_valid(button) and button.has_focus()):
		return
	_armed = ""
	_rebuild()


func _focus(node_name: String) -> void:
	_focus_now.call_deferred(node_name)


func _focus_now(node_name: String) -> void:
	if not visible or not is_inside_tree():
		return
	var enabled := buttons().filter(func(b: Button) -> bool: return not b.disabled)
	for b: Button in enabled:
		if String(b.name) == node_name:
			b.grab_focus()
			return
	# WU-524: a fresh main page lands on the first Ready card, else Feed 10; never on a sealed card.
	enabled = enabled.filter(func(b: Button) -> bool: return b.get_meta("state", "") != "sealed")
	for b: Button in enabled:
		if b.get_meta("state", "") == "ready":
			b.grab_focus()
			return
	var plain := enabled.filter(func(b: Button) -> bool: return not b.has_meta("state"))
	if not plain.is_empty():
		enabled = plain
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


func _on_player_changed_rebuild() -> void:
	if visible:
		_rebuild()
