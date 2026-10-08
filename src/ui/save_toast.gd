class_name SaveToast
extends Control
## Small non-blocking bottom-right toast: "Saved" / "Autosaved" after a
## successful save. Never takes focus or input.

const HOLD_SECONDS := 1.5
const FADE_SECONDS := 0.4

var _panel: PanelContainer
var _label: Label
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_panel = UIStyle.panel()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -24
	_panel.offset_right = -24
	_panel.offset_top = -24
	_panel.offset_bottom = -24
	add_child(_panel)
	_label = UIStyle.label("", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _ready() -> void:
	SaveManager.saved.connect(show_toast)


func show_toast(_slot: String, is_auto: bool) -> void:
	if GameState.player != null and not GameState.player.alive:
		return # record_final_death's save: the death screen is up
	_label.text = "Autosaved" if is_auto else "Saved"
	_label.modulate = Color(1, 1, 1, 0.6) if is_auto else Color.WHITE
	_panel.modulate = Color.WHITE
	_panel.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func(): _panel.visible = false)


func is_showing() -> bool:
	return _panel.visible


func text() -> String:
	return _label.text
