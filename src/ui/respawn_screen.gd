class_name RespawnScreen
extends PanelContainer
## Shown after the Creation Artifact saves the player from a violent death
## (GameState.pending_respawn): how they died, lives left, qi lost, and a
## button per bound anchor to choose where to awaken
## (GameState.choose_respawn_anchor). Cancel keeps the default respawn point.

signal closed

var _cause: Label
var _summary: Label
var _lesson: Label
var _cost: Label
var _choices: VBoxContainer


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(560, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(UIStyle.label("The artifact pulls your soul back...", 26, UIStyle.ACCENT))
	_cause = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["danger"]))
	box.add_child(_cause)
	_summary = _wrapped(UIStyle.label("", 16))
	box.add_child(_summary)
	_lesson = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["warning"]))
	box.add_child(_lesson)
	_cost = _wrapped(UIStyle.label("", 16))
	box.add_child(_cost)
	box.add_child(UIStyle.label("Where will you awaken?", 18, UIStyle.ACCENT))
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_choose(String(GameState.pending_respawn.get("anchor_id", "")))


## "2 lives remain. 340 qi was lost." for a pending_respawn dictionary.
static func summary_text(pending: Dictionary) -> String:
	var lives := int(pending.get("lives_left", 0))
	var text := "%d %s remain%s in the artifact." % [lives, "life" if lives == 1 else "lives", "s" if lives == 1 else ""]
	if lives == 0:
		text = "The artifact is empty. Recharge it with spirit stones, or the next death is final."
	return text + " %d qi scattered as your soul was torn loose." % int(pending.get("qi_lost", 0.0))


## "You had about 12% odds against the Stone Ape. ..." when the death was a fight (pending has `enemy_name`
## and `win_chance`; older pendings have neither), else "".
static func lesson_text(pending: Dictionary) -> String:
	if not pending.has("enemy_name") or not pending.has("win_chance"):
		return ""
	return "You had about %d%% odds against %s. Grow stronger before you face it again." % [roundi(float(pending["win_chance"]) * 100.0), pending["enemy_name"]]


## "Recharging the artifact costs N spirit stones (you have M)."
static func cost_text(c: CharacterData, data: GameData) -> String:
	return "Recharging the artifact costs %d spirit stones (you have %d)." % [CreationArtifact.recharge_cost(c, data), c.item_count("spirit_stone")]


## Opens if a respawn is waiting for the player's choice.
func open() -> void:
	var pending := GameState.pending_respawn
	if pending.is_empty() or GameState.player == null:
		return
	_cause.text = String(pending.get("cause", ""))
	_summary.text = summary_text(pending)
	_lesson.text = lesson_text(pending)
	_lesson.visible = _lesson.text != ""
	_cost.text = cost_text(GameState.player, GameState.data)
	if int(pending.get("lives_left", 0)) <= 1:
		_cost.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS["warning"])
	else:
		_cost.remove_theme_color_override("font_color")
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for choice in CreationArtifact.respawn_choices(GameState.player, GameState.data):
		var label := "Awaken at %s" % choice["label"]
		if choice["respawn_point"]:
			label += "  (respawn point)"
		var b := UIStyle.button(label, _choose.bind(String(choice["anchor_id"])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.add_child(b)
	visible = true
	_focus_first.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _choose(anchor_id: String) -> void:
	close()
	GameState.choose_respawn_anchor(anchor_id)


func _focus_first() -> void:
	if visible and _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
