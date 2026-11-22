class_name SwornOath
extends Control
## GFX-235: the staged moment when a villager becomes a Sworn friend: the player and the friend face a small
## incense burner, both bow, three smoke threads rise and a card names the tier. Skippable with any confirm/cancel
## press, never pauses time, at most DURATION seconds. Drawn in code so it needs no sprites.

signal finished

const DURATION := 3.0
const BOW_START := 0.5
const BOW_LENGTH := 0.6
const SCALE := 4.0
const FIGURE := Vector2(16, 24)  ## figure size in art pixels

var _time := 0.0
var _name := ""
var _tier := ""
var _line := ""
var _title: Label
var _body: Label
var _hint: Label


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
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 200.0
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)


func begin(npc_name: String, tier: Dictionary) -> void:
	var lines := card_lines(npc_name, tier)
	_title.text = lines[0]
	_body.text = lines[1]
	_time = 0.0
	visible = true
	queue_redraw()


func end() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
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
	var pos := layout(Vector2(size.x / 2.0, size.y * 0.38), 120.0)
	var bow := bow_amount(_time) * SCALE
	_draw_figure(pos["player"], bow, Color(0.55, 0.75, 0.95, fade), 1.0)
	_draw_figure(pos["friend"], bow, Color(0.9, 0.75, 0.5, fade), -1.0)
	_draw_burner(pos["burner"], fade)


func _draw_figure(feet: Vector2, bow: float, col: Color, _facing: float) -> void:
	var h := FIGURE.y * SCALE - bow  # a bow shortens the figure and lowers the head
	var body := Rect2(feet + Vector2(-FIGURE.x * SCALE / 2.0, -h), Vector2(FIGURE.x * SCALE, h))
	draw_rect(body, col)
	draw_rect(Rect2(body.position + Vector2(body.size.x * 0.2, 0), Vector2(body.size.x * 0.6, 10 * SCALE * 0.5)), Color(0.95, 0.85, 0.7, col.a))


func _draw_burner(at: Vector2, fade: float) -> void:
	var s := SCALE
	draw_rect(Rect2(at + Vector2(-4 * s, -5 * s), Vector2(8 * s, 5 * s)), Color(0.35, 0.25, 0.15, fade))
	draw_rect(Rect2(at + Vector2(-5 * s, -6 * s), Vector2(10 * s, 1 * s)), Color(0.55, 0.4, 0.2, fade))
	for i in 3:  # three thin smoke threads
		var x := (i - 1) * 3.0 * s
		var prev := at + Vector2(x, -6 * s)
		for k in range(1, 24):
			var rise := k * 4.0 + _time * 20.0
			var p := at + Vector2(x + sin(rise * 0.12 + i * 2.0) * 6.0, -6 * s - k * 5.0)
			draw_line(prev, p, Color(0.85, 0.85, 0.9, fade * (1.0 - k / 24.0) * 0.8), 2.0)
			prev = p
