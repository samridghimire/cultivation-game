class_name SwornOath
extends Control
## GFX-235: the staged moment when a villager becomes a Sworn friend: the player and the friend face a small
## incense burner, both bow, three smoke threads rise and a card names the tier. Skippable with any confirm/cancel
## press, never pauses time, at most DURATION seconds. Drawn in code so it needs no sprites.

signal finished

const DURATION := 3.0
const BOW_START := 0.5
const BOW_LENGTH := 0.6
const GAP := 72.0  ## px between the two figures' feet; the burner sits in the middle

var _time := 0.0
var _name := ""
var _tier := ""
var _line := ""
var _title: Label
var _body: Label
var _hint: Label
var _npc: Node2D
var _center: Control
var _staged_player := false


## Positions (centres of the figures' feet, and the burner) for a pair `gap` px apart around `centre`.
static func layout(centre: Vector2, gap: float) -> Dictionary:
	return {"player": centre + Vector2(-gap / 2.0, 0), "friend": centre + Vector2(gap / 2.0, 0), "burner": centre}


## How far (px, in art pixels) a figure is lowered at time `t`: 2 while bowing, 0 before and after.
static func bow_amount(t: float) -> float:
	return 2.0 if t >= BOW_START and t < BOW_START + BOW_LENGTH else 0.0


## True for the tier a villager must reach for the oath scene (the top friendship tier).
static func is_oath_tier(hearts: int, tier_count: int) -> bool:
	return tier_count > 0 and hearts >= tier_count


## Card text: "<Name>: <Tier>" and the tier's line with {name} filled in.
static func card_lines(npc_name: String, tier: Dictionary) -> PackedStringArray:
	var line := String(tier.get("line", "")).replace("{name}", npc_name)
	return PackedStringArray(["%s: %s" % [npc_name, String(tier.get("name", "Sworn friend"))], line])


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = UIStyle.label("", 16)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = UIStyle.label("Press any button to continue", 14, Color(0.7, 0.7, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var panel := UIStyle.panel(Vector2(560, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_title)
	box.add_child(_body)
	box.add_child(_hint)
	var centre := UIStyle.centered(panel)
	_center = centre
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 200.0
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)


func begin(npc_id: String, npc_name: String, tier: Dictionary) -> void:
	_unstage()
	var lines := card_lines(npc_name, tier)
	_title.text = lines[0]
	_body.text = lines[1]
	_time = 0.0
	visible = true
	_center.offset_top = 200.0
	_stage(npc_id)
	queue_redraw()


## GFX-236: the friend's world figure stays at its spot, the player stands GAP px away facing them, the burner
## between (drawn by the villager node). A friend who is not in this region: only the dim and the card.
func _stage(npc_id: String) -> void:
	if not is_inside_tree():
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("begin_lend"):
		return
	for n in get_tree().get_nodes_in_group("npc"):
		if n.get("npc_id") == npc_id and n.has_method("set_oath"):
			_npc = n
			var region: Dictionary = GameState.data.regions.get(GameState.current_region, {})
			var spot := Scenery.lend_spot(region, n.position, GAP)
			n.set_oath(true, spot)
			_staged_player = true
			p.begin_lend(spot, (n.position - spot).normalized())
			_set_labels_suppressed(true)
			# the card drops below the pair, or rises above it when they stand in the lower half
			var screen_y: float = (n as Node2D).get_global_transform_with_canvas().origin.y
			_center.offset_top = -480.0 if screen_y > get_viewport_rect().size.y * 0.45 else 260.0
			return


## Hides (or restores) every place label and name plate in the world, redrawing them at once.
func _set_labels_suppressed(on: bool) -> void:
	Interactable.labels_suppressed = on
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p == null or p.get_parent() == null:
		return
	for c in p.get_parent().get_children():
		if c is Interactable:
			c._redraw_label()


func _unstage() -> void:
	_set_labels_suppressed(false)
	_set_bow(false)
	if is_instance_valid(_npc):
		_npc.set_oath(false)
	_npc = null
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p != null and p.has_method("end_lend") and _staged_player:
		p.end_lend()
	_staged_player = false


func _set_bow(on: bool) -> void:
	if on and MotionFx.reduced():
		return
	if is_instance_valid(_npc):
		_npc.set_bow(on)
	var p := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if p != null and p.has_method("set_bow"):
		p.set_bow(on)


func end() -> void:
	if not visible:
		return
	visible = false
	_unstage()
	finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_set_bow(bow_amount(_time) > 0.0)
	if _time >= DURATION:
		end()
	else:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if visible and TimeSkipOverlay.is_dismiss_event(event):
		get_viewport().set_input_as_handled()
		end()


func _draw() -> void:
	if not visible:
		return
	var fade := clampf(minf(_time / 0.3, (DURATION - _time) / 0.3), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45 * fade))
	if is_instance_valid(_npc):
		_draw_smoke(_burner_screen(), fade)


## Screen position of the burner's rim (the villager node draws it halfway to the player).
func _burner_screen() -> Vector2:
	var s := float(Sprites.scale())
	var local: Vector2 = _npc.get("_oath_to") * 0.5 + Vector2(0, _npc.size.y / 2.0 - 1.0 - 9.0 * s)
	return (_npc as Node2D).get_global_transform_with_canvas() * local


func _draw_smoke(at: Vector2, fade: float) -> void:
	var threads := 1 if MotionFx.reduced() else 3
	var t := 0.0 if MotionFx.reduced() else _time
	for i in threads:
		var x := (i - 1) * 6.0
		var prev := at + Vector2(x, 0)
		for k in range(1, 24):
			var rise := k * 4.0 + t * 20.0
			var p := at + Vector2(x + sin(rise * 0.12 + i * 2.0) * 6.0, -k * 5.0)
			draw_line(prev, p, Color(0.85, 0.85, 0.9, fade * (1.0 - k / 24.0) * 0.8), 2.0)
			prev = p
