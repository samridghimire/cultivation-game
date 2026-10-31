class_name DigestCard
extends PanelContainer
## WU-416: the "While you were away" card. A small panel above the message log that lists
## GameState.last_digest (DAY-001) after a 5+ day action, then fades after HOLD_SECONDS or on any input.
## It never takes focus. The HUD decides when it may appear (see Hud._try_show_digest).

const HOLD_SECONDS := 6.0
const FADE_SECONDS := 0.5
const MAX_LINES := 5
const KIND_COLORS := {
	"realm": Color(0.95, 0.8, 0.35), "crop": Color(0.55, 0.85, 0.4), "visit": Color(0.9, 0.6, 0.75),
	"quarrel": Color(0.9, 0.45, 0.4), "event": Color(0.6, 0.75, 0.95), "weather": Color(0.6, 0.7, 0.8),
	"": Color(0.75, 0.75, 0.75),
}

var _title: Label
var _lines: VBoxContainer
var _tween: Tween
var _age: float = 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	custom_minimum_size = Vector2(376, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = UIStyle.label("", 18, UIStyle.ACCENT)
	box.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lines)


## "15 days pass" / "1 day passes".
static func title_for(days: int) -> String:
	return "%d days pass" % days if days != 1 else "1 day passes"


## Whether a digest of `days` days may be shown: only for 5+ days with at least one line.
static func should_show(digest: Dictionary) -> bool:
	return not digest.is_empty() and int(digest.get("days", 0)) >= DayDigest.MIN_DAYS and not (digest.get("lines", []) as Array).is_empty()


## The lines shown, capped at MAX_LINES.
static func shown_lines(digest: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for l in digest.get("lines", []):
		if out.size() >= MAX_LINES:
			break
		out.append(String(l))
	return out


func show_digest(digest: Dictionary) -> void:
	if not should_show(digest):
		return
	_title.text = title_for(int(digest["days"]))
	for c in _lines.get_children():
		_lines.remove_child(c)
		c.queue_free()
	for line in shown_lines(digest):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := UIStyle.label("•", 14, KIND_COLORS.get(DayDigest.kind_of(line, "info"), KIND_COLORS[""]))
		row.add_child(dot)
		var l := UIStyle.label(line, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 340
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		_lines.add_child(row)
	size = Vector2.ZERO
	modulate = Color.WHITE
	visible = true
	_age = 0.0
	if _tween != null:
		_tween.kill()
	_tween = null


func is_showing() -> bool:
	return visible


func title_text() -> String:
	return _title.text


func line_count() -> int:
	return _lines.get_child_count()


## Hides at once (a modal opened, or any input).
func dismiss() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false


func _process(delta: float) -> void:
	if not visible or _tween != null:
		return
	_age += delta
	if _age < HOLD_SECONDS:
		return
	if MotionFx.reduced():
		dismiss()
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(dismiss)


func _input(event: InputEvent) -> void:
	if not visible or _age < 0.3:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed):
		dismiss()
