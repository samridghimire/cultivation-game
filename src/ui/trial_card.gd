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
	var enemy := Sects.trial_foe(c, data)
	var chance := Combat.win_chance(c, data, enemy)  # once, on open: never on the frame loop
	_title.text = sect.name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Trial for %s" % sect.rank_name(next)
	arena.color = color
	arena.sect_id = String(c.sect["id"])
	arena.result = false
	arena.player_look = PlayerLook.of(c, data)
	arena.queue_redraw()
	_foe.text = foe_line(data, enemy)
	_odds.text = odds_line(chance)
	_odds.add_theme_color_override("font_color", odds_color(chance))
	var lessons := lessons_line(c, data)  # WU-624
	if lessons != "":
		_odds.text += "\n" + lessons
	if chance < 0.5:  # SECT-040: the biggest gap, under the odds
		var advice := Sects.trial_advice(c, data)
		if advice != "":
			_odds.text += "\n" + advice
	_safe.text = SAFE_LINE
	_perks.text = _perk_text(c, data, sect, next)
	_perks.visible = _perks.text != ""
	_step_button.visible = true
	_wait_button.text = "Not yet"
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


## WU-614: the result mode after a lost trial: the examiner lowers the wooden sword, what you lacked, any injury,
## the odds now and one "Back" button (focused). `info` is the promotion_trial_lost payload.
func open_lost(sect_name: String, info: Dictionary, color: Color = UIStyle.ACCENT) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = lost_subtitle(info)
	arena.color = color
	arena.result = true
	arena.queue_redraw()
	var lines := lost_lines(info)
	_foe.text = lines[0]
	_odds.text = lines[1]
	_odds.remove_theme_color_override("font_color")
	_safe.text = lines[2]
	_perks.text = lines[3]
	var learned := lost_lesson_line(info)  # WU-624
	if learned != "":
		_perks.text = (_perks.text + "\n" + learned).strip_edges()
	_perks.visible = _perks.text != ""
	_step_button.visible = false
	_wait_button.text = "Back"
	visible = true
	_wait_button.grab_focus.call_deferred()


## WU-624: "Lessons from 2 tries: examiner -12%" under the odds; "" when nothing was learned yet. Pure.
static func lessons_line(c: CharacterData, data: GameData) -> String:
	var lesson := Sects.trial_lesson(c, data)
	if lesson <= 0.0:
		return ""
	var tries := int(c.sect.get("trial_losses", 0))
	return "Lessons from %d %s: examiner -%d%%" % [tries, "try" if tries == 1 else "tries", roundi(lesson * 100.0)]


## WU-624: what the lost trial taught, from the info dict's `lesson` (total) and `learned` (grew this time). "" when 0.
static func lost_lesson_line(info: Dictionary) -> String:
	var lesson := float(info.get("lesson", 0.0))
	if lesson <= 0.0:
		return ""
	if bool(info.get("learned", false)):
		return "You learned the examiner's forms: next time they fight %d%% weaker." % roundi(lesson * 100.0)
	return "You know the examiner's forms as well as you can (they fight %d%% weaker)." % roundi(lesson * 100.0)


## The result-mode subtitle: names the rank the trial was for (the next rank, not the current one). Pure.
static func lost_subtitle(info: Dictionary) -> String:
	return "Trial for %s: lost" % String(info.get("rank", "the next rank"))


## [examiner line, what you lacked, injury line, odds now]; "" entries are empty. Pure.
static func lost_lines(info: Dictionary) -> Array[String]:
	var injuries: PackedStringArray = info.get("injuries", PackedStringArray())
	var out: Array[String] = []
	out.append("%s lowers the wooden sword." % String(info.get("examiner", "The examiner")))
	out.append(String(info.get("advice", "")))
	out.append("Your injury: %s." % ", ".join(injuries) if not injuries.is_empty() else "You come away unhurt.")
	out.append(odds_line(float(info["chance"])).replace("Your odds", "Your odds now") if info.has("chance") else "")
	return out


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


## GFX-250: the arena at 2x (480x128), the SectVignette set (ground, ring/pit/vault props per sect) with the player on
## the left and the examiner (sect colour, white hair, wooden sword) on the right, facing each other.
class TrialArena extends SectCard.SectVignette:
	## WU-616: result mode after a lost trial: the player kneels back a step, the examiner's sword points down.
	var result := false

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color(0.14, 0.15, 0.2))  # dusk sky
		draw_rect(Rect2(0, GROUND, W, H - GROUND), Color(0.3, 0.24, 0.17))  # packed earth
		draw_rect(Rect2(0, GROUND, W, 3), color)  # sect colour floor stripe
		_props()
		for x in [210, W - 214]:  # rope posts
			draw_rect(Rect2(x, 52, 6, 46), Color(0.45, 0.32, 0.2))
		draw_line(Vector2(213, 62), Vector2(W - 211, 62), color.darkened(0.2), 3.0)
		if result:
			draw_figure(self, _player(), 226, 122, 4.0, "right")
			draw_rect(Rect2(262, 118, 22, 4), Color(0.75, 0.6, 0.4))  # your sword on the ground
		else:
			draw_figure(self, _player(), 250, 118, 4.0, "right")
		var examiner := _disciple({"robe": color, "sash": Color(0.9, 0.75, 0.3), "accessories": PackedStringArray(["white_hair"])})
		draw_figure(self, examiner, 370, 118, 4.0, "left")
		if result:
			draw_rect(Rect2(336, 84, 4, 22), Color(0.75, 0.6, 0.4))  # sword lowered, point down
		else:
			draw_rect(Rect2(332, 78, 22, 4), Color(0.75, 0.6, 0.4))  # wooden sword
