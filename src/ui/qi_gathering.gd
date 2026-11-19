class_name QiGathering
extends Control
## GFX-213: qi motes drift in to the player and a soft glow pulses on each tick of the
## time-skip bar. Lives inside TimeSkipOverlay, above its dim, so the player stays visible.

var _colors: Array[Color] = [QiMotes.FALLBACK]
var _count := QiMotes.MIN_COUNT
var _time := 0.0
var _pulse := 0.0
var _last_tick := -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Start for the current player; `multiplier` is the place's qi multiplier.
func begin(multiplier: float) -> void:
	_colors = [QiMotes.FALLBACK]
	if GameState.has_session():
		_colors = QiMotes.colors_for(GameState.player, GameState.data)
	_count = QiMotes.count_for(multiplier)
	_time = 0.0
	_pulse = 0.0
	_last_tick = -1
	visible = true
	queue_redraw()


func end() -> void:
	visible = false


## Called with the overlay bar's 0..1 value: four glow pulses over the fill.
func on_bar(value: float) -> void:
	var tick := int(value * 4.0)
	if tick != _last_tick:
		_last_tick = tick
		_pulse = 1.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	queue_redraw()


func _body_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return size / 2.0
	return get_viewport().get_canvas_transform() * p.global_position + Vector2(0, -6)


func _draw() -> void:
	var at := _body_pos()
	var glow := _pulse
	if MotionFx.reduced():
		glow = 0.0
	draw_circle(at, 22.0 + 10.0 * glow, Color(_colors[0], 0.10 + 0.25 * glow))
	for i in _count:
		var phase := 0.6 if MotionFx.reduced() else fposmod(_time * 0.5 + float(i) / float(_count), 1.0)
		var col: Color = _colors[i % _colors.size()]
		col.a = 0.9 * (1.0 - phase * phase) if not MotionFx.reduced() else 0.8
		draw_circle(at + QiMotes.mote_offset(i, _count, phase), 2.5, col)
