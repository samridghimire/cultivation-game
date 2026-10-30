class_name Interactable
extends Area2D
## Base class for anything the player can walk up to and use.
##
## Subclasses override get_options() to return menu entries:
##   {"label": String, "action": Callable, "disabled": bool (optional),
##    "reason": String (optional, why it is disabled; shown in the warning color when focused),
##    "description": String (optional, shown under the menu when an enabled option is focused),
##    "keep_open": bool (optional, re-show the menu after the action)}
## Actions should call GameState methods, not change data directly.
## Menus call menu_options(), which adds shared entries (e.g. artifact anchors).

@export var display_name := "Object"
@export var size := Vector2(64, 64)
@export var color := Color.WHITE
## How far beyond its footprint the player can be and still interact.
@export var reach := 28.0
## Creation Artifact anchor id (data/regions.json "anchor_id"); "" = not an anchor.
@export var anchor_id := ""
## PlaceArt look: the regions.json place type or "npc" ("" = plain box).
var art_kind := ""
## The player's current interaction target pulses (set by Player).
var highlighted := false:
	set(value):
		highlighted = value
		set_process(value)
		queue_redraw()
		_redraw_label()

var _pulse_time := 0.0
## Added to the name label's position; World.spread_labels lifts labels that would overlap (WU-087).
var label_offset := Vector2.ZERO
const LABEL_FONT_SIZE := 14
const PLACE_NEAR := 220.0
const PLACE_FAR := 420.0
const PLACE_FAR_ALPHA := 0.35
## Draws the name label above every sibling building (WU-278).
var _label_node: Node2D
## The top hint names this place: a gold "!" is drawn above its label (WU-280).
var hinted := false
## Added to the label's y (and badge) by spread_on_screen when the screen-edge clamp made it overlap (WU-281).
var screen_lift := 0.0
## Fade of the name label by distance to the player (GFX-015); 0 hides it and frees its spot.
var label_fade := 1.0
## Set by spread_on_screen when a HUD panel covers the label and it cannot move clear: drawn dimmed.
var label_covered := false


func _ready() -> void:
	_label_node = Node2D.new()
	_label_node.z_index = 10
	_label_node.draw.connect(_draw_label)
	add_child(_label_node)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size + Vector2(reach, reach) * 2.0
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.player_changed.connect(_refresh)
	set_process(highlighted)
	_refresh()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()
	_redraw_label()


func get_options() -> Array[Dictionary]:
	return []


## get_options() plus the anchor entry when this place is an artifact anchor.
func menu_options() -> Array[Dictionary]:
	var options := get_options()
	if anchor_id == "":
		return options
	var c: CharacterData = GameState.player
	if c.anchors.has(anchor_id):
		var label := "Release artifact anchor" if c.anchors[-1] != anchor_id else "Release artifact anchor (current respawn point)"
		if c.anchors[-1] != anchor_id:
			options.append({"label": "Make this your respawn point", "action": GameState.bind_anchor.bind(anchor_id), "keep_open": true})
		if c.anchors.size() > 1:
			options.append({"label": label, "action": GameState.unbind_anchor.bind(anchor_id), "keep_open": true})
	else:
		var slots := CreationArtifact.anchor_slots(c, GameState.data)
		if c.anchors.size() >= slots:
			options.append({"label": "Bind artifact anchor here (All %d anchor slots are bound; release one first)" % slots, "action": GameState.bind_anchor.bind(anchor_id), "disabled": true, "keep_open": true})
		else:
			options.append({"label": "Bind artifact anchor here (%d/%d used)" % [c.anchors.size(), slots], "action": GameState.bind_anchor.bind(anchor_id), "keep_open": true})
	return options


## Whether this can currently be interacted with (e.g. a dead NPC cannot).
func is_available() -> bool:
	return true


func _refresh() -> void:
	visible = is_available()
	queue_redraw()
	_redraw_label()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.add_interactable(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.remove_interactable(self)


## The text of the name label.
func label_text() -> String:
	return display_name


## The color of the name label (NPCs override it, WU-138).
func label_color() -> Color:
	return Color.WHITE


## The rect the name label covers, in the parent's coordinates (for overlap checks).
func label_rect(text: String = "") -> Rect2:
	if text == "":
		text = label_text()
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var h := font.get_height(LABEL_FONT_SIZE)
	return Rect2(position + Vector2(-w / 2.0, -size.y / 2.0 - 8.0 - h * 0.8) + label_offset, Vector2(w, h))


## The names in `names` that appear in `hint`, longest first; a name inside an already-counted longer one
## (e.g. "Clinic" within "Village Clinic") is not counted again (WU-280). An NPC label "Name (Title)" also
## matches a hint that writes "Name (Realm)" (WU-297: hints name people by realm, labels by title).
static func hinted_names(hint: String, names: Array) -> Array:
	var sorted := names.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var found: Array = []
	var rest := hint
	for n: String in sorted:
		if n == "" or found.has(n):
			continue
		var key := n
		if not rest.contains(key) and n.contains(" ("):
			key = n.get_slice(" (", 0) + " ("
		if rest.contains(key):
			found.append(n)
			rest = rest.replace(key, "")
	return found


## The nodes the top `hint` points at: those whose display_name it names; when it names none here but names
## another region, the road (nodes with a `hint_region` property) instead (WU-283).
## With `c`, a hinted region no route leads toward marks nothing (WU-292).
static func hinted_targets(hint: String, nodes: Array, data: GameData, region_id: String, c: CharacterData = null) -> Array:
	var names: Array = nodes.map(func(n: Interactable) -> String: return n.display_name)
	var hit := hinted_names(hint, names)
	if not hit.is_empty():
		return nodes.filter(func(n: Interactable) -> bool: return hit.has(n.display_name))
	var target := Guidance.hinted_region(data, hint, region_id)
	if target == "":
		return []
	if c != null and Guidance.first_hop(c, data, region_id, target) == "":
		return []
	return nodes.filter(func(n: Interactable) -> bool: return "hint_region" in n)


## Display names of what the world marks in `region_id`: data places plus the NPCs it spawns there (WU-293).
## Mirrors World._build_npcs / _build_generated_npcs so the HUD badge and the world marker agree.
static func region_marker_names(data: GameData, npcs: Dictionary, region_id: String, player: CharacterData = null) -> Array:
	var names: Array = []
	var region: Dictionary = data.regions.get(region_id, {})
	for place: Dictionary in region.get("places", []):
		names.append(str(place.get("display_name", "")))
	for c in Npcs.in_region(npcs, data, region_id):
		if data.npcs.has(c.id):
			var def: Dictionary = data.npcs[c.id]
			names.append("%s (%s)" % [c.name, def["title"]] if def.has("title") else c.name)
		else:
			names.append("%s (%s)" % [c.name, Npcs.world_title(c, player, data)])
	return names


## Whether the gold "!" badge shows above the label: hinted places, and NPCs who need you (WU-402).
func shows_badge() -> bool:
	return hinted


## Sets or clears `hinted`, redrawing only when it changed.
func set_hinted(value: bool) -> void:
	if hinted == value:
		return
	hinted = value
	if value:
		label_fade = 1.0
	_redraw_label()


## Lifts the labels of `nodes` (in order) until none overlaps an earlier one.
static func spread_labels(nodes: Array) -> void:
	var placed: Array[Rect2] = []
	for node: Interactable in nodes:
		var text := node.label_text()
		var rect := node.label_rect(text)
		for _i in 6:
			var hit := false
			for other in placed:
				if rect.intersects(other):
					hit = true
					break
			if not hit:
				break
			node.label_offset.y -= rect.size.y + 2.0
			rect = node.label_rect(text)
		placed.append(rect)


## The interact prompt already names the current target, so its own label is not drawn
## (it sat under the player sprite and the prompt, WU-176). The HUD shows the prompt
## whenever a target exists, so the target's own label is always hidden.
static func label_visible(is_target: bool) -> bool:
	return not is_target


## The rect the label is drawn at in the parent's coordinates once clamped inside `view` (WU-281).
func drawn_label_rect(view: Rect2) -> Rect2:
	var rect := label_rect()
	rect.position.x = clamp_label_left(rect.position.x, rect.size.x, view.position.x, view.end.x)
	rect.position.y += screen_lift
	if shows_badge():
		# The "!" badge sits above the label: a 20px circle centered on it, 14px over the baseline.
		var base := position.y - size.y / 2.0 - 8.0 + label_offset.y + screen_lift
		var badge := Rect2(rect.position.x + rect.size.x / 2.0 - 10.0, base - 34.0, 20.0, 20.0)
		rect = rect.merge(badge)
	return rect


## Whether the name label is drawn at all (unavailable places and the current target hide it).
func label_drawn() -> bool:
	return visible and label_visible(highlighted) and label_fade > 0.0


## How visible the name label is for a player standing at `player_pos` (parent coordinates).
## Places are full strength within PLACE_NEAR px and fade to PLACE_FAR_ALPHA at PLACE_FAR px (GFX-025),
## except hinted or highlighted ones and with the "Show all place names" setting. NPC labels override this (GFX-015).
func label_alpha(player_pos: Vector2) -> float:
	if hinted or highlighted or Settings.get_value("show_all_labels"):
		return 1.0
	return lerpf(PLACE_FAR_ALPHA, 1.0, proximity_alpha(position.distance_to(player_pos), PLACE_NEAR, PLACE_FAR))


## 1 within `near`, 0 beyond `far`, linear between (GFX-015).
static func proximity_alpha(dist: float, near: float, far: float) -> float:
	if dist <= near:
		return 1.0
	if dist >= far:
		return 0.0
	return (far - dist) / (far - near)


## Updates `label_fade` for the player's position and redraws the label if it changed.
func refresh_label_alpha(player_pos: Vector2) -> void:
	var a := label_alpha(player_pos)
	if not is_equal_approx(a, label_fade):
		label_fade = a
		_redraw_label()


## Lifts labels (in order) whose screen-clamped rects overlap an earlier one; `view` is the visible
## area in the nodes' parent coordinates. Redraws the labels that moved (WU-281).
## `occupied` are HUD rects in the same coordinates; they count as already-placed labels (GFX-025).
static func spread_on_screen(nodes: Array, view: Rect2, occupied: Array[Rect2] = []) -> void:
	var placed: Array[Rect2] = occupied.duplicate()
	for node: Interactable in nodes:
		if not node.label_drawn():
			if node.screen_lift != 0.0:
				node.screen_lift = 0.0
				node._redraw_label()
			continue
		var before := node.screen_lift
		node.screen_lift = 0.0
		var rect := node.drawn_label_rect(view)
		for _i in 6:
			var hit := false
			for other in placed:
				if rect.intersects(other):
					hit = true
					break
			if not hit:
				break
			node.screen_lift -= rect.size.y + 2.0
			rect = node.drawn_label_rect(view)
		var covered := false
		for other in occupied:
			covered = covered or rect.intersects(other)
		placed.append(rect)
		if node.screen_lift != before or node.label_covered != covered:
			node.label_covered = covered
			node._redraw_label()


## Shifts labels sideways so none sticks out past `bounds` (WU-160).
static func clamp_labels(nodes: Array, bounds: Rect2, margin: float = 6.0) -> void:
	for node: Interactable in nodes:
		var rect := node.label_rect()
		var over := rect.end.x - (bounds.end.x - margin)
		if over > 0.0:
			node.label_offset.x -= over
		var under := (bounds.position.x + margin) - rect.position.x
		if under > 0.0:
			node.label_offset.x += under


## Left edge for a label of `width` so it stays inside [view_left, view_right] (WU-269).
static func clamp_label_left(left: float, width: float, view_left: float, view_right: float, margin: float = 4.0) -> float:
	var lo := view_left + margin
	var hi := view_right - margin - width
	if hi < lo:
		return lo
	return clampf(left, lo, hi)


## The visible area in this node's local coordinates.
func _view_rect_local() -> Rect2:
	var to_local := get_global_transform().affine_inverse() * get_canvas_transform().affine_inverse()
	return to_local * get_viewport_rect()


## Called by the world when the camera moved: redraws the label if it is near a screen edge (WU-269).
func camera_moved() -> void:
	if _label_near_edge():
		_redraw_label()


## True when the label is within one label width of a screen edge (cheap redraw test).
func _label_near_edge() -> bool:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var view := _view_rect_local()
	return label_offset.x - w / 2.0 < view.position.x + w or label_offset.x + w / 2.0 > view.end.x - w


## Sprite keys tried in order for this node's art (GFX-006); subclasses prepend more specific ones.
func sprite_keys() -> PackedStringArray:
	return PackedStringArray(["place_" + art_kind])


## Subclasses draw their own generated art here when no sprite is mapped; false falls back to PlaceArt.
func draw_generated_art() -> bool:
	return false


## Whether the place's art shows its live state (e.g. an open secret realm).
func art_active() -> bool:
	return false


func _draw() -> void:
	if anchor_id != "":
		# Artifact anchor places sit on a faint golden ring (VIS-004).
		PlaceArt.ellipse(self, Vector2(0, size.y * 0.35), Vector2(size.x * 0.65, size.y * 0.3), Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.18))
		PlaceArt.ellipse(self, Vector2(0, size.y * 0.35), Vector2(size.x * 0.65, size.y * 0.3), Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.5), 1.5)
	var art := Sprites.first(sprite_keys())
	if art != null:
		var tex_size := art.get_size()
		var k := maxi(1, int(minf(size.x / tex_size.x, size.y / tex_size.y)))
		draw_texture_rect(art, Rect2(-tex_size * k / 2.0, tex_size * k), false)
	elif not draw_generated_art():
		PlaceArt.draw(self, art_kind, size, color, art_active())
	if highlighted:
		var glow := 0.5 + 0.5 * sin(_pulse_time * 5.0)
		var ring := Rect2(-size / 2.0, size).grow(6.0 + 2.0 * glow)
		var ring_tex := Sprites.texture("highlight")
		if ring_tex != null:
			Sprites.draw_nine_patch(self, ring_tex, ring, float(Sprites.scale() * 4), Color(1, 1, 1, 0.45 + 0.4 * glow))
		else:
			draw_rect(ring, Color(1.0, 0.9, 0.5, 0.45 + 0.4 * glow), false, 2.0)
	if anchor_id != "":
		_draw_anchor_marker()


## Asks the label layer to redraw.
func _redraw_label() -> void:
	if _label_node != null:
		_label_node.queue_redraw()


## Draws the name label on the label layer (WU-278).
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	var text := label_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var left := -text_width / 2.0 + label_offset.x
	if is_inside_tree():
		var view := _view_rect_local()
		left = clamp_label_left(left, text_width, view.position.x, view.end.x)
	if shows_badge():
		# A gold badge with a dark "!" above the label.
		var center := Vector2(left + text_width / 2.0, -size.y / 2.0 - 8.0 + label_offset.y + screen_lift - LABEL_FONT_SIZE - 10.0)
		_label_node.draw_circle(center, 10.0, UIStyle.ACCENT)
		_label_node.draw_arc(center, 10.0, 0.0, TAU, 24, Color(0.1, 0.08, 0.04), 1.5)
		var mw := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_label_node.draw_string(font, center + Vector2(-mw / 2.0, 6.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.08, 0.04))
	if not label_visible(highlighted):
		return
	var fade := minf(label_fade, PLACE_FAR_ALPHA) if label_covered else label_fade
	if fade <= 0.0:
		return
	var at := Vector2(left, -size.y / 2.0 - 8.0 + label_offset.y + screen_lift)
	var fill := label_color()
	fill.a *= fade
	# A dark outline first so the name reads on any ground (GFX-015).
	_label_node.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 3, Color(0, 0, 0, 0.7 * fade))
	_label_node.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, fill)


## A small diamond in the top-right corner of artifact anchor places: hollow
## when unbound, filled when bound, ringed when it is the respawn point.
func _draw_anchor_marker() -> void:
	var anchors: Array = GameState.player.anchors if GameState.player != null else []
	var center := Vector2(size.x / 2.0 - 2.0, -size.y / 2.0 + 2.0)
	var r := 8.0
	var points := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
	var gold := UIStyle.ACCENT
	if anchors.has(anchor_id):
		draw_colored_polygon(points.slice(0, 4), gold)
		if anchors[-1] == anchor_id:
			draw_arc(center, r + 4.0, 0.0, TAU, 24, gold, 2.0)
	else:
		draw_polyline(points, gold.darkened(0.3), 2.0)
