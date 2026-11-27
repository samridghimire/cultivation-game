class_name SeasonMarkers
extends Node2D
## WU-639: a small dim leaf over each place that serves an open season task (SeasonBoard.task_spots), in Qingshi only.
## Hidden when a place is the GoalMarker's target already. reduce_motion: no bob. Lives in the World.

const COLOR := Color(0.72, 0.95, 0.55, 0.7)  ## the goal chevron's look at ~60% alpha, green
const OUTLINE := Color(0.05, 0.1, 0.03, 0.75)

var _nodes: Array[Interactable] = []
var _t := 0.0


func _ready() -> void:
	z_index = 190
	EventBus.player_changed.connect(refresh)
	EventBus.region_changed.connect(_on_region)
	GameClock.days_advanced.connect(_on_days)
	refresh.call_deferred()


func _on_region(_id: String) -> void:
	refresh.call_deferred()


func _on_days(_days: int) -> void:
	refresh()


## Place names to mark for the current region ({} entries skipped when the goal already points there).
static func spot_names() -> PackedStringArray:
	var out: PackedStringArray = []
	if not GameState.has_session() or GameState.current_region != SeasonTasks.REGION:
		return out
	var day := GameClock.total_days
	var done: Dictionary = GameState.player.season_tasks.get("progress", {}) if String(GameState.player.season_tasks.get("season_key", "")) == SeasonTasks.season_key(day) else {}
	var goal := GoalMarker.current_target()
	for s: Dictionary in SeasonBoard.task_spots(GameState.data, GameState.current_region, SeasonTasks.tasks_for(GameState.data, day), done, SeasonTasks.season_name(day), day):
		var nm := String(s["interactable_id"])
		if String(goal.get("place", "")) != nm and not out.has(nm):
			out.append(nm)
	return out


func refresh() -> void:
	_nodes.clear()
	var parent := get_parent()
	if parent != null:
		var names := spot_names()
		for n in parent.get_children():
			var node := n as Interactable
			if node != null and node.get("npc_id") == null and not node is Roamer and names.has(node.display_name.get_slice(" (", 0)):
				_nodes.append(node)
	set_process(not _nodes.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := 0.0 if MotionFx.reduced() else roundf(sin(_t * 3.0) * 1.5)
	for node in _nodes:
		if not is_instance_valid(node) or not node.visible:
			continue
		var c := Vector2(node.position.x, node.position.y - node.size.y / 2.0 - 16.0 + bob)
		var leaf := PackedVector2Array([c + Vector2(0, 9), c + Vector2(-8, 0), c + Vector2(0, -10), c + Vector2(8, 0)])
		var shadow := PackedVector2Array()
		for p in leaf:
			shadow.append(p + Vector2(1, 1))
		draw_colored_polygon(shadow, OUTLINE)
		draw_colored_polygon(leaf, COLOR)
		draw_line(c + Vector2(0, 9), c + Vector2(0, -7), Color(0.3, 0.5, 0.25, 0.6), 1.0)
