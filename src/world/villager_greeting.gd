class_name VillagerGreeting
extends RefCounted
## WU-401: a generated villager near the player says their greeting in a short speech bubble.
## The pure "who greets now" choice lives here; the world scene spawns the bubble.

const RADIUS := 60.0
const SHOW_SECONDS := 3.0
const MAX_WIDTH := 220.0


## The id of the nearest candidate within `radius` of the player who has not greeted today, or ""
## while a modal is open or a bubble is already showing. `candidates` are {id: String, pos: Vector2}.
static func pick(candidates: Array, player_pos: Vector2, greeted: Dictionary, day: int, modal_open: bool, bubble_active: bool, radius: float = RADIUS) -> String:
	if modal_open or bubble_active:
		return ""
	var best := ""
	var best_dist := radius
	for c: Dictionary in candidates:
		if int(greeted.get(c["id"], -1)) == day:
			continue
		var d := (c["pos"] as Vector2).distance_to(player_pos)
		if d <= best_dist:
			best_dist = d
			best = c["id"]
	return best


## WU-402: whether `req` (Letters.open_request, maybe {}) is a neighbour's folk request.
static func is_folk_request(req: Dictionary) -> bool:
	return not req.is_empty() and String(req.get("source", "letter")) == "folk"


## The greeting with " Did you bring the <item>?" appended when `req` is a folk request the player
## holds enough items for (`have` of the asked count).
static func with_request(text: String, req: Dictionary, have: int, item_name: String) -> String:
	if text == "" or not is_folk_request(req) or have < int(req.get("count", 1)):
		return text
	return "%s Did you bring the %s?" % [text, item_name]


## A small bubble above `above` (a node of height `height`): UIStyle panel, 12 px wrapped text.
## With `reduce_motion` it appears at once, otherwise it pops in with a scale. It frees itself
## after SHOW_SECONDS.
static func show_bubble(above: Node2D, height: float, text: String, reduce_motion: bool) -> Control:
	var panel := UIStyle.panel()
	var style := UIStyle.panel_style()
	style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var label := UIStyle.label(text, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(MAX_WIDTH, 12.0 * 0.55 * text.length() + 4.0)
	panel.add_child(label)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 50
	above.add_child(panel)
	panel.reset_size()
	panel.position = Vector2(-panel.size.x / 2.0, -height / 2.0 - panel.size.y - 8.0)
	if not reduce_motion:
		panel.pivot_offset = Vector2(panel.size.x / 2.0, panel.size.y)
		panel.scale = Vector2(0.6, 0.6)
		panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.15)
	var timer := above.get_tree().create_timer(SHOW_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())
	return panel
