class_name WorldMapScreen
extends PanelContainer
## Modal world map (information only; travel still happens at travel points).
## Every region in data/regions.json is a focusable node placed by its
## `map_pos`; routes are drawn between them with their travel days. The panel
## on the right describes the focused region and how to reach it from here.
## Colored dots under a region mark what is yours there or happening there
## (UI-008b): your sect hall, abode, family, artifact anchors, secret realms
## and world events; the details list them.

signal closed

const HudScript := preload("res://src/ui/hud.gd")
const CANVAS_SIZE := Vector2(560, 420)
const NODE_SIZE := Vector2(132, 40)
const DANGER_NAMES: PackedStringArray = ["Safe", "Low", "Moderate", "High", "Deadly"]
const ROUTE_COLOR := Color(0.85, 0.76, 0.5, 0.8)
const LOCKED_COLOR := Color(0.9, 0.38, 0.32, 0.8)
## Mark kind -> dot color (see region_marks).
const MARK_COLORS := {
	"sect": Color("6fa8e8"),
	"abode": Color("e8c76a"),
	"family": Color("e6a3c4"),
	"anchor": Color("7fe0d0"),
	"secret_realm": Color("b58ae8"),
	"event": Color("e85a4a"),
	"discovery": Color("f2f0a0"),
}

var _canvas: Control
var _name: Label
var _info: Label
var _description: Label
var _places: Label
var _marks: Label
var _foes: RichTextLabel
var _routes: Label
var _close_button: Button
var _selected := ""
var _positions: Dictionary = {}


func _init() -> void:
	var temp := UIStyle.panel()
	add_theme_stylebox_override("panel", temp.get_theme_stylebox("panel"))
	temp.free()
	custom_minimum_size = Vector2(980, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("World Map", 24, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	_canvas = Control.new()
	_canvas.custom_minimum_size = CANVAS_SIZE
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	columns.add_child(_canvas)

	# The details scroll so long region notes never push the screen past a
	# Steam Deck's height.
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size = Vector2(380, CANVAS_SIZE.y)
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(360, 0)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 15, Color(0.75, 0.75, 0.75))
	details.add_child(_info)
	_description = _wrapped(UIStyle.label("", 16))
	details.add_child(_description)
	_places = _wrapped(UIStyle.label("", 15))
	details.add_child(_places)
	_foes = RichTextLabel.new()
	_foes.bbcode_enabled = true
	_foes.fit_content = true
	_foes.scroll_active = false
	_foes.add_theme_font_size_override("normal_font_size", 15)
	_foes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_foes)
	_marks = _wrapped(UIStyle.label("", 15, Color(0.85, 0.85, 0.95)))
	details.add_child(_marks)
	_routes = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_routes)
	details.add_child(_wrapped(UIStyle.label("Red roads need a higher realm. Travel at a region's gate. Dots: blue sect hall, gold abode, pink family, teal anchor, purple secret realm, red world event.", 14, Color(0.6, 0.6, 0.6))))

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.region_changed.connect(func(_id): if visible: _rebuild())
	EventBus.player_changed.connect(func(): if visible: _show_details())


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_selected = GameState.current_region
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Region id -> position as 0..1 fractions of the map. Uses `map_pos` when set;
## other regions are spread around an ellipse so new content always shows up.
static func layout(data: GameData) -> Dictionary:
	var result := {}
	var unplaced: Array = []
	for region: Dictionary in data.regions.values():
		var pos: Array = region.get("map_pos", [])
		if pos.size() == 2:
			result[region["id"]] = Vector2(float(pos[0]), float(pos[1]))
		else:
			unplaced.append(region["id"])
	for i in unplaced.size():
		var angle := TAU * float(i) / unplaced.size() - PI / 2.0
		result[unplaced[i]] = Vector2(0.5, 0.5) + Vector2(cos(angle) * 0.4, sin(angle) * 0.38)
	return result


## Text lines for the focused region: route from the current region (or
## "You are here"), then every road out of it with days and realm gates.
static func route_lines(c: CharacterData, data: GameData, from_id: String, region_id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	if region_id == from_id:
		lines.append("You are here.")
	else:
		var check := Exploration.check_travel(c, data, from_id, region_id)
		if check["ok"]:
			lines.append("Direct road from here: %s." % Calendar.format_duration(int(check["days"])))
		else:
			lines.append(String(check["reason"]))
	lines.append("Roads:")
	for route in Exploration.routes(c, data, region_id):
		var line := "  %s, %s" % [route["name"], Calendar.format_duration(route["days"])]
		if not route["ok"]:
			line += " (%s)" % route["reason"]
		lines.append(line)
	return lines


## Names of the places in a region (travel points left out).
static func place_names(data: GameData, region_id: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.get("type", "") != "travel":
			names.append(String(place.get("display_name", place.get("type", ""))))
	return names


## What `c` has or what is going on in `region_id`: [{kind, text}] with kind
## a MARK_COLORS key. `people` are the NPCs, `events` the active world events,
## `flags` the world flags (an unexplored discovery hint needs them).
static func region_marks(c: CharacterData, data: GameData, people: Dictionary, events: Array, total_days: int, region_id: String, current_region: String = "", flags: Dictionary = {}) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	var region: Dictionary = data.regions.get(region_id, {})
	if not c.is_rogue() and (region.get("places", []) as Array).any(func(p: Dictionary) -> bool: return p.get("type", "") == "sect_hall"):
		marks.append({"kind": "sect", "text": "A hall of the %s (missions, rank)" % (data.sects[c.sect["id"]] as SectDef).name})
	if c.abode != "" and String(data.abodes.get(c.abode, {}).get("region", "")) == region_id:
		marks.append({"kind": "abode", "text": "Your abode: %s" % Abodes.abode_name(data, c.abode)})
	var family: PackedStringArray = []
	for person_id in c.spouses + c.children:
		var person: CharacterData = people.get(person_id)
		if person != null and person.alive and Npcs.region_of(person, data) == region_id:
			family.append(person.name)
	if not family.is_empty():
		marks.append({"kind": "family", "text": "Family: %s" % ", ".join(family)})
	for i in c.anchors.size():
		if String(data.anchors.get(c.anchors[i], {}).get("region", "")) == region_id:
			var tag := " (respawn point)" if i == c.anchors.size() - 1 else ""
			marks.append({"kind": "anchor", "text": "Artifact anchor: %s%s" % [CreationArtifact.anchor_name(data, c.anchors[i]), tag]})
	for def: Dictionary in data.secret_realms.values():
		if String(def.get("region", "")) != region_id:
			continue
		var when := "open, closes in %s" % Calendar.format_duration(SecretRealms.days_until_close(def, total_days)) if SecretRealms.is_open(def, total_days) else "opens in %s" % Calendar.format_duration(SecretRealms.days_until_open(def, total_days))
		marks.append({"kind": "secret_realm", "text": "Secret realm: %s (%s)" % [def.get("name", def["id"]), when]})
	if Exploration.visited(c, region_id) and not Exploration.discovery_for(c, data, region_id, flags).is_empty():
		marks.append({"kind": "discovery", "text": "Something here waits to be found. Explore."})
	for instance in WorldEvents.active_in(events, region_id):
		var enter := ""
		if region_id == current_region and HudScript.region_event_suffix(data, [instance], region_id, c).contains("(you can enter)"):
			enter = " (you can enter)"
		marks.append({"kind": "event", "text": "%s! (%s left)%s" % [WorldEvents.event_name(data, instance["id"]), Calendar.format_duration(maxi(0, int(instance["end_day"]) - total_days)), enter]})
	return marks


## Foes met while exploring the current region, as BBCode with each danger colored (WU-030).
static func foes_bbcode(foes: Array) -> String:
	var parts := PackedStringArray()
	for foe: Dictionary in foes:
		var danger := String(foe["danger"])
		parts.append("[color=#%s]%s (%s)[/color]" % [UIStyle.danger_color(danger).to_html(false), foe["name"], danger])
	return "" if parts.is_empty() else "You may meet: " + ", ".join(parts)


static func danger_name(data: GameData, region_id: String) -> String:
	var danger := int(data.regions.get(region_id, {}).get("danger", 0))
	return DANGER_NAMES[clampi(danger, 0, DANGER_NAMES.size() - 1)]


func _rebuild() -> void:
	var data := GameState.data
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_positions.clear()
	var fractions := layout(data)
	var area := CANVAS_SIZE - NODE_SIZE
	var ids := fractions.keys()
	ids.sort()
	for region_id in ids:
		var top_left: Vector2 = Vector2(fractions[region_id]) * area
		_positions[region_id] = top_left + NODE_SIZE / 2.0
		var b := Button.new()
		b.name = region_id
		b.text = Exploration.region_name(data, region_id)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.position = top_left
		b.size = NODE_SIZE
		b.toggle_mode = true
		b.button_pressed = region_id == _selected
		if region_id == GameState.current_region:
			b.add_theme_color_override("font_color", UIStyle.ACCENT)
			b.add_theme_color_override("font_focus_color", UIStyle.ACCENT)
			b.text = "* " + b.text
		b.focus_entered.connect(_select.bind(region_id))
		b.pressed.connect(_select.bind(region_id))
		_canvas.add_child(b)
	_canvas.queue_redraw()
	_show_details()


func _draw_map() -> void:
	var data := GameState.data
	if data == null:
		return
	_canvas.draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color(0.12, 0.14, 0.12, 0.9))
	var font := ThemeDB.fallback_font
	var drawn := {}
	for region_id in _positions:
		for route: Dictionary in data.regions[region_id].get("routes", []):
			var to: String = route.get("to", "")
			var key := [region_id, to] if region_id < to else [to, region_id]
			if drawn.has(key) or not _positions.has(to):
				continue
			drawn[key] = true
			var a: Vector2 = _positions[region_id]
			var b: Vector2 = _positions[to]
			_canvas.draw_line(a, b, LOCKED_COLOR if _route_gated(data, region_id, to) else ROUTE_COLOR, 4.0)
			var days := "%dd" % int(route.get("days", 1))
			_canvas.draw_string(font, (a + b) / 2.0 + Vector2(4, -4), days, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.85))
	for region_id in _positions:
		var kinds: Array = []
		for mark in region_marks(GameState.player, data, GameState.npcs, GameState.world_events, GameClock.total_days, region_id, GameState.current_region, GameState.world_flags):
			if not kinds.has(mark["kind"]):
				kinds.append(mark["kind"])
		var start: Vector2 = Vector2(_positions[region_id]) + Vector2(-(kinds.size() - 1) * 7.0, NODE_SIZE.y / 2.0 + 8.0)
		for i in kinds.size():
			_canvas.draw_circle(start + Vector2(i * 14.0, 0), 5.0, MARK_COLORS[kinds[i]])
	if _positions.has(GameState.current_region):
		var here := Rect2(Vector2(_positions[GameState.current_region]) - NODE_SIZE / 2.0, NODE_SIZE).grow(5.0)
		_canvas.draw_rect(here, UIStyle.ACCENT, false, 3.0)


## Whether the road between two regions needs a minimum realm in either direction.
static func _route_gated(data: GameData, a: String, b: String) -> bool:
	for pair in [[a, b], [b, a]]:
		for route: Dictionary in data.regions.get(pair[0], {}).get("routes", []):
			if route.get("to", "") == pair[1] and route.has("min_realm"):
				return true
	return false


func _select(region_id: String) -> void:
	_selected = region_id
	for b in _canvas.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == region_id)
	_show_details()


func _show_details() -> void:
	var data := GameState.data
	var region: Dictionary = data.regions.get(_selected, {})
	if region.is_empty():
		return
	_name.text = String(region.get("name", _selected))
	_info.text = "Qi density x%s   |   Danger: %s" % [String.num(Exploration.qi_density(data, _selected) * WorldEvents.qi_multiplier(data, GameState.world_events, _selected), 2), danger_name(data, _selected)]
	_description.text = String(region.get("description", ""))
	var places := place_names(data, _selected)
	_places.text = "Places: " + (", ".join(places) if not places.is_empty() else "none known")
	var foes_text := ""
	if _selected == GameState.current_region:
		var tags: Array = region.get("encounter_tags", []) + WorldEvents.encounter_tags(data, GameState.world_events, _selected)
		foes_text = foes_bbcode(Exploration.outlook(GameState.player, data, tags, GameState.world_flags, Calendar.season_of(GameClock.total_days), _selected)["foes"])
	_foes.text = foes_text
	_foes.visible = foes_text != ""
	var marks := region_marks(GameState.player, data, GameState.npcs, GameState.world_events, GameClock.total_days, _selected, GameState.current_region, GameState.world_flags)
	_marks.visible = not marks.is_empty()
	_marks.text = "\n".join(marks.map(func(m: Dictionary) -> String: return "• " + String(m["text"])))
	_routes.text = "\n".join(route_lines(GameState.player, data, GameState.current_region, _selected))


func _focus_selected() -> void:
	var b := _canvas.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
