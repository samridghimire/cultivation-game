class_name TrialCard
extends PanelContainer
## WU-609: the promotion trial, staged. A centred card opened from the sect hall and the mission board before the
## fight: the sect banner, "Trial for <rank>", a drawn arena (you and the examiner), the examiner's realm, your odds,
## the never-lethal line and what the rank brings. "Step into the arena" emits `confirmed` (the HUD then runs
## GameState.attempt_promotion_trial); "Not yet" or cancel just closes. Focus starts on "Not yet" under 30 in 100.

signal closed
signal confirmed

const WRAP_WIDTH := 520
const RISKY_BELOW := 0.3
const SAFE_LINE := "A sparring match: losing can injure you, but never kills or robs you."

var _banner: SectCard.SectBanner
var _title: Label
var _subtitle: Label
var _foe: Label
var _odds: Label
var _safe: Label
var _perks: Label
var _step_button: Button
var _wait_button: Button
var arena: TrialArena


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_banner = SectCard.SectBanner.new()
	_banner.custom_minimum_size = Vector2(26, 34)
	head.add_child(_banner)
	_title = UIStyle.label("", 26, UIStyle.ACCENT)
	head.add_child(_title)
	_subtitle = UIStyle.label("", 18)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	arena = TrialArena.new()
	arena.custom_minimum_size = Vector2(TrialArena.W, TrialArena.H)
	arena.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arena.clip_contents = true
	box.add_child(arena)
	_foe = _wrapped(box, 18)
	_odds = _wrapped(box, 18)
	_safe = _wrapped(box, 16, Color(0.75, 0.85, 0.7))
	_perks = _wrapped(box, 16)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_step_button = UIStyle.button("Step into the arena", _on_step)
	row.add_child(_step_button)
	_wait_button = UIStyle.button("Not yet", close)
	row.add_child(_wait_button)


func _wrapped(box: Control, size: int, color: Color = Color.WHITE) -> Label:
	var l := UIStyle.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	box.add_child(l)
	return l


## "Azure Cloud Sword Examiner (Qi Refining)" style label of an enemy's realm. Pure.
static func foe_line(data: GameData, enemy: Dictionary) -> String:
	var realm_index := data.realm_index_of(String(enemy.get("realm", "mortal")))
	var stage := int(enemy.get("stage", 0))
	var realm_text := String(enemy.get("realm", ""))
	if realm_index >= 0 and realm_index < data.realms.size():
		realm_text = data.realms[realm_index].stage_label(stage) if stage > 0 else data.realms[realm_index].name
	return "%s (%s)" % [String(enemy.get("name", "The examiner")), realm_text]


## "Your odds: Risky (55 in 100)". Pure.
static func odds_line(chance: float) -> String:
	return "Your odds: %s (%d in 100)" % [Combat.odds_word(chance), roundi(chance * 100.0)]


## The colour of the odds line, from the danger ratings. Pure.
static func odds_color(chance: float) -> Color:
	return UIStyle.danger_color(Combat.label_for_chance(chance))


## True when the "Not yet" button should hold focus (the odds are under 30 in 100). Pure.
static func default_to_wait(chance: float) -> bool:
	return chance < RISKY_BELOW


## Opens for the player's next-rank trial. Does nothing (returns false) when no trial can be attempted.
func open(c: CharacterData, data: GameData, color: Color = UIStyle.ACCENT) -> bool:
	if Sects.check_promotion(c, data) != "":
		return false
	var sect: SectDef = data.sects[c.sect["id"]]
	var next := Sects.next_rank(c, data)
	var enemy := Sects.trial_opponent(data, Sects.trial_enemy(c, data))
	var chance := Combat.win_chance(c, data, enemy)  # once, on open: never on the frame loop
	_title.text = sect.name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Trial for %s" % sect.rank_name(next)
	arena.color = color
	arena.queue_redraw()
	_foe.text = foe_line(data, enemy)
	_odds.text = odds_line(chance)
	_odds.add_theme_color_override("font_color", odds_color(chance))
	_safe.text = SAFE_LINE
	_perks.text = _perk_text(c, data, sect, next)
	_perks.visible = _perks.text != ""
	visible = true
	if default_to_wait(chance):
		_wait_button.grab_focus.call_deferred()
	else:
		_step_button.grab_focus.call_deferred()
	return true


## What the next rank brings: its ladder perks (SECT-033). "" when none are listed.
static func _perk_text(c: CharacterData, data: GameData, sect: SectDef, rank: int) -> String:
	var rows := Sects.ladder(c, data)
	if rank >= rows.size():
		return ""
	var perks: PackedStringArray = rows[rank]["perks"]
	if perks.is_empty():
		return "%s: your standing in the sect rises." % sect.rank_name(rank)
	return "%s brings: %s." % [sect.rank_name(rank), ", ".join(perks)]


func _on_step() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()
	closed.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func step_button() -> Button:
	return _step_button


func wait_button() -> Button:
	return _wait_button


func all_text() -> String:
	return "\n".join([_title.text, _subtitle.text, _foe.text, _odds.text, _safe.text, _perks.text])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## The arena, drawn in code: the player on the left, the examiner on the right (sect robe), facing each other.
class TrialArena extends Control:
	const W := 240
	const H := 80
	var color := Color.WHITE

	func _person(x: float, y: float, robe: Color, face_right: bool) -> void:
		var s := 3.0
		var dir := 1.0 if face_right else -1.0
		draw_rect(Rect2(x - 3 * s, y - 9 * s, 6 * s, 9 * s), robe)  # robe
		draw_rect(Rect2(x - 2 * s, y - 13 * s, 4 * s, 4 * s), Color(0.9, 0.75, 0.6))  # head
		draw_rect(Rect2(x - 2 * s, y - 13 * s, 4 * s, s), Color(0.12, 0.1, 0.1))  # hair
		draw_rect(Rect2(x + dir * 3 * s - (s if dir < 0 else 0.0), y - 7 * s, s, s), robe.darkened(0.3))  # sleeve
		draw_rect(Rect2(x + dir * 4 * s - (3 * s if dir < 0 else 0.0), y - 8 * s, 3 * s, s), Color(0.75, 0.6, 0.4))  # wooden blade

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color(0.14, 0.15, 0.2))  # dusk sky
		draw_rect(Rect2(0, 60, W, H - 60), Color(0.3, 0.24, 0.17))  # packed earth
		draw_rect(Rect2(0, 60, W, 3), color)  # sect colour floor stripe
		for x in [10, W - 14]:  # rope posts
			draw_rect(Rect2(x, 36, 4, 28), Color(0.45, 0.32, 0.2))
		draw_line(Vector2(12, 42), Vector2(W - 12, 42), color.darkened(0.2), 2.0)
		draw_ellipse_ring(Vector2(W / 2.0, 70), 70.0)
		_person(70, 72, Color(0.8, 0.8, 0.75), true)
		_person(W - 70, 72, color.darkened(0.3), false)

	func draw_ellipse_ring(center: Vector2, rx: float) -> void:
		draw_line(Vector2(center.x - rx, center.y), Vector2(center.x + rx, center.y), Color(0.45, 0.36, 0.25), 1.0)
