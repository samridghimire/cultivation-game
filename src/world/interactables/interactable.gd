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

var _pulse_time := 0.0
## Added to the name label's position; World.spread_labels lifts labels that would overlap (WU-087).
var label_offset := Vector2.ZERO
const LABEL_FONT_SIZE := 14


func _ready() -> void:
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


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.add_interactable(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.remove_interactable(self)


## The text of the name label.
func label_text() -> String:
	return display_name


## The rect the name label covers, in the parent's coordinates (for overlap checks).
func label_rect(text: String = "") -> Rect2:
	if text == "":
		text = label_text()
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var h := font.get_height(LABEL_FONT_SIZE)
	return Rect2(position + Vector2(-w / 2.0, -size.y / 2.0 - 8.0 - h * 0.8) + label_offset, Vector2(w, h))


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


## Whether the place's art shows its live state (e.g. an open secret realm).
func art_active() -> bool:
	return false


func _draw() -> void:
	if anchor_id != "":
		# Artifact anchor places sit on a faint golden ring (VIS-004).
		PlaceArt.ellipse(self, Vector2(0, size.y * 0.35), Vector2(size.x * 0.65, size.y * 0.3), Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.18))
		PlaceArt.ellipse(self, Vector2(0, size.y * 0.35), Vector2(size.x * 0.65, size.y * 0.3), Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.5), 1.5)
	PlaceArt.draw(self, art_kind, size, color, art_active())
	if highlighted:
		var glow := 0.5 + 0.5 * sin(_pulse_time * 5.0)
		draw_rect(Rect2(-size / 2.0, size).grow(6.0 + 2.0 * glow), Color(1.0, 0.9, 0.5, 0.45 + 0.4 * glow), false, 2.0)
	var font := ThemeDB.fallback_font
	var text := label_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	draw_string(font, Vector2(-text_width / 2.0, -size.y / 2.0 - 8.0) + label_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
	if anchor_id != "":
		_draw_anchor_marker()


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
