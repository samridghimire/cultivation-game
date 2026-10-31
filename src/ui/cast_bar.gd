class_name CastBar
extends PanelContainer
## Fishing timing bar (WU-412): a marker sweeps a bar with a bright zone (its width from the fishing skill);
## Act in the zone is a clean strike (quality 1.0), near it a fair cast (0.5), else a miss (0.0).
## After SWEEPS passes the fish is lost. The quality goes to GameState.fish.

signal closed

const SWEEPS := 3
const SWEEP_SECONDS := 1.4
const BAR_SIZE := Vector2(560, 36)
const NEAR_COLOR := Color("5b7a52")

var table: Array = []
var days := 1
var place_name := ""
var zone_center := 0.5
var zone_width := 0.25
var marker := 0.0
var sweeps_done := 0
var _dir := 1.0
var _finished := false
var _title: Label
var _bar: Control
var _hint: Label
var _strike: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620, 0)
	visible = false
	set_process(false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title = UIStyle.label("The float twitches...", 22, UIStyle.ACCENT)
	box.add_child(_title)
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_hint = UIStyle.label("", 16, UIStyle.HINT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	_strike = UIStyle.button("Strike!", strike)
	box.add_child(_strike)


## 1.0 inside the zone, 0.5 within one zone-width of it, else 0.0.
static func quality_for(marker_pos: float, center: float, width: float) -> float:
	var dist := absf(marker_pos - center)
	if dist <= width / 2.0:
		return 1.0
	if dist <= width / 2.0 + width:
		return 0.5
	return 0.0


## Zone center for a cast: 0.2..0.8 from `rng`.
static func zone_center_from(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.2, 0.8)


## Outcome line posted to the message log.
static func outcome_text(quality: float, lost: bool) -> String:
	if quality >= 1.0:
		return "A clean strike!"
	if quality >= 0.5:
		return "A fair cast."
	return "You strike too late." if not lost else "The fish slips away before you strike."


func open_for(catch_table: Array, trip_days: int, place: String, rng: RandomNumberGenerator = null) -> void:
	table = catch_table
	days = trip_days
	place_name = place
	zone_center = zone_center_from(rng if rng != null else GameState.rng)
	zone_width = Fishing.zone_width(GameState.player.fishing_xp)
	marker = 0.0
	_dir = 1.0
	sweeps_done = 0
	_finished = false
	_hint.text = "Press %s or the button when the marker is in the bright zone. Esc: let it go." % InputConfig.current_label("interact")
	visible = true
	set_process(true)
	_bar.queue_redraw()
	_strike.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	advance(delta)


## Moves the marker; true while the cast is still live.
func advance(delta: float) -> bool:
	if _finished:
		return false
	var seconds := SWEEP_SECONDS * (2.0 if Settings.get_value("reduce_motion") else 1.0)
	marker += _dir * delta / seconds
	if marker >= 1.0 or marker <= 0.0:
		marker = clampf(marker, 0.0, 1.0)
		_dir = -_dir
		sweeps_done += 1
		if sweeps_done >= SWEEPS:
			_finish(0.0, true)
			return false
	_bar.queue_redraw()
	return true


## The player pressed Act: judge the marker.
func strike() -> void:
	if _finished or not visible:
		return
	_finish(quality_for(marker, zone_center, zone_width), false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(0.0, true)
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		strike()


func _finish(quality: float, lost: bool) -> void:
	if _finished:
		return
	_finished = true
	EventBus.post(outcome_text(quality, lost))
	var t := table
	var d := days
	var p := place_name
	close()
	GameState.fish(t, d, p, quality)


func _draw_bar() -> void:
	var w := BAR_SIZE.x
	var h := BAR_SIZE.y
	_bar.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.1, 0.14))
	var near := Rect2((zone_center - zone_width * 1.5) * w, 0, zone_width * 3.0 * w, h).intersection(Rect2(0, 0, w, h))
	_bar.draw_rect(near, NEAR_COLOR)
	var zone := Rect2((zone_center - zone_width / 2.0) * w, 0, zone_width * w, h).intersection(Rect2(0, 0, w, h))
	_bar.draw_rect(zone, Color("e8c85a"))
	_bar.draw_rect(Rect2(0, 0, w, h), UIStyle.HINT, false, 2.0)
	_bar.draw_rect(Rect2(marker * w - 3, -4, 6, h + 8), Color.WHITE)
