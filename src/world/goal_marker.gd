class_name GoalMarker
extends Node2D
## WU-567: a gold chevron bobbing over the person or place the current first goal points at (Guidance.goal_target),
## and a gold edge arrow with the short name when the target is off screen. Follows walking villagers every frame.
## reduce_motion: no bob. Lives in the World; refreshes on goal changes (player_changed), travel and day changes.

const GOLD := Color(0.98, 0.82, 0.25)
const SILVER := Color(0.78, 0.82, 0.88)  ## WU-570: the easy-fight marker, dimmer than the goal's gold
const OUTLINE := Color(0.1, 0.07, 0.02, 0.9)
const SIZE := Vector2(9, 7)
const EDGE_MARGIN := 36.0

var target: Dictionary = {}  ## {"npc": id} or {"place": display name}, {} = none
var _node: Interactable = null
var silver := false  ## WU-570: marking the easy fight's giver because the goal has no target in this region
var _t := 0.0
var _edge := _EdgeArrow.new()


## Small screen-space arrow, drawn by the marker's own layer.
class _EdgeArrow:
	extends Control
	var info := {"visible": false}
	var label := ""
	var color := GOLD

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not bool(info["visible"]):
			return
		var p: Vector2 = info["position"]
		var a: float = info["angle"]
		var s := 12.0
		var tip := p + Vector2.from_angle(a) * s
		var l := p + Vector2.from_angle(a + 2.5) * s
		var r := p + Vector2.from_angle(a - 2.5) * s
		draw_colored_polygon(PackedVector2Array([tip + Vector2(1, 1), l + Vector2(1, 1), r + Vector2(1, 1)]), Color(0, 0, 0, 0.6))
		draw_colored_polygon(PackedVector2Array([tip, l, r]), color)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
		var at := Vector2(clampf(p.x - w / 2.0, 4.0, size.x - w - 4.0), p.y + 28.0)
		draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## The target dictionary for the current player, region and favor ({} when none or not in this region).
static func current_target() -> Dictionary:
	if not GameState.has_session():
		return {}
	return Guidance.goal_target(GameState.player, GameState.data, GameState.world_flags, GameState.npcs, GameState.current_region, GameState.npc_favor)


## WU-570: the easy fight's giver in this region ({} when none or no session).
static func current_fight_target() -> Dictionary:
	if not GameState.has_session():
		return {}
	return Guidance.fight_target(GameState.player, GameState.data, GameState.world_flags, GameState.current_region, GameClock.total_days, GameState.npcs, GameState.npc_favor)


## The node among `nodes` that `goal` names (an npc id, or a place display name); null when absent.
static func find_node(nodes: Array, goal: Dictionary) -> Interactable:
	for n in nodes:
		var node := n as Interactable
		if node == null or not node.visible:
			continue
		if goal.has("npc") and node.get("npc_id") == String(goal["npc"]):
			return node
		if goal.has("place") and node.get("npc_id") == null and not node is Roamer and node.display_name == String(goal["place"]):
			return node
	return null


## The chevron's tip position above `node` (a person's head, a place's top edge).
static func tip_for(node: Interactable) -> Vector2:
	if node.is_person():
		return Vector2(node.position.x, node.position.y + node.size.y / 2.0 - 40.0)
	return Vector2(node.position.x, node.position.y - node.size.y / 2.0 - 6.0)


func _ready() -> void:
	z_index = 200
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.add_child(_edge)
	add_child(layer)
	EventBus.player_changed.connect(refresh)
	EventBus.region_changed.connect(_on_region)
	GameClock.days_advanced.connect(_on_days)
	EventBus.ui_modal_changed.connect(_on_modal)
	refresh()


func _on_modal(is_open: bool) -> void:
	_edge.visible = not is_open


## WU-572: a bounty or mission that ends overnight must lose its marker now, not at the next player change.
func _on_days(_days: int) -> void:
	refresh()


func _on_region(_id: String) -> void:
	call_deferred("refresh")


## Re-reads the goal and finds its node (call after the region's nodes exist).
func refresh() -> void:
	target = current_target()
	var parent := get_parent()
	_node = find_node(parent.get_children(), target) if parent != null and not target.is_empty() else null
	silver = false
	if _node == null and parent != null:  # the goal is elsewhere: point at the easy fight instead, never both
		var fight := current_fight_target()
		var fnode := find_node(parent.get_children(), fight) if not fight.is_empty() else null
		if fnode != null:
			target = fight
			_node = fnode
			silver = true
	_edge.color = SILVER if silver else GOLD
	_edge.info = {"visible": false}
	_edge.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _node != null and not is_instance_valid(_node):
		_node = null
	if _node == null:
		if not target.is_empty() and Engine.get_process_frames() % 30 == 0:
			refresh()  # the node may have been built after us
		return
	var screen := get_viewport().get_visible_rect()
	var canvas_pos: Vector2 = (get_parent() as Node2D).get_canvas_transform() * _node.position
	var info: Dictionary = BeastArrow.edge_arrow(canvas_pos, screen, EDGE_MARGIN)
	_edge.info = info
	_edge.label = _node.display_name.get_slice(" (", 0)
	_edge.queue_redraw()
	queue_redraw()


func _bob() -> float:
	return 0.0 if MotionFx.reduced() else roundf(sin(_t * 4.0) * 2.0)


func _draw() -> void:
	if _node == null or not _node.visible:
		return
	var tip := tip_for(_node) + Vector2(0, _bob())
	var pts := PackedVector2Array([tip, tip + Vector2(-SIZE.x / 2.0, -SIZE.y), tip + Vector2(SIZE.x / 2.0, -SIZE.y)])
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1.5), tip + Vector2(-SIZE.x / 2.0 - 1.5, -SIZE.y - 1.0), tip + Vector2(SIZE.x / 2.0 + 1.5, -SIZE.y - 1.0)]), OUTLINE)
	draw_colored_polygon(pts, SILVER if silver else GOLD)
