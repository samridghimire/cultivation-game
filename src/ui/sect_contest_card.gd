class_name SectContestCard
extends PanelContainer
## WU-611: the yearly outer-sect contest as a moment. Entry mode (opened from the hall before the first bout): the
## sect banner, "<Sect> outer-sect contest", the round ladder (foe and prize per round) and your odds for the next bout.
## "Enter the contest" emits `confirmed` (the HUD then runs GameState.enter_sect_contest); "Not yet" or cancel closes.
## Result mode (one per bout, through the moments queue): won -> prize and the next foe; lost -> "You placed in round N".
## GFX-256: Champion mode (after the last bout card of a full win): the player alone on the platform, sword raised.

signal closed
signal confirmed

const WRAP_WIDTH := 520

var _banner: SectCard.SectBanner
var _title: Label
var _subtitle: Label
var _arena: ContestArena
var _rows: VBoxContainer  ## GFX-254: one row per round
var _row_text: PackedStringArray = PackedStringArray()
var _ladder: Label
var _odds: Label
var _note: Label
var _enter_button: Button
var _back_button: Button


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
	_arena = ContestArena.new()
	_arena.custom_minimum_size = Vector2(ContestArena.W, ContestArena.H)
	var arena_row := CenterContainer.new()
	arena_row.add_child(_arena)
	box.add_child(arena_row)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	_ladder = _wrapped(box, 18)
	_odds = _wrapped(box, 18)
	_note = _wrapped(box, 16, Color(0.75, 0.85, 0.7))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_enter_button = UIStyle.button("Enter the contest", _on_enter)
	row.add_child(_enter_button)
	_back_button = UIStyle.button("Not yet", close)
	row.add_child(_back_button)


func _wrapped(box: Control, size: int, color: Color = Color.WHITE) -> Label:
	var l := UIStyle.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	box.add_child(l)
	return l


## "Prize: 10 contribution, 15 spirit stones". Pure.
static func prize_text(prize: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(prize.get("contribution", 0)) > 0:
		parts.append("%d contribution" % int(prize["contribution"]))
	if int(prize.get("spirit_stones", 0)) > 0:
		parts.append("%d spirit stones" % int(prize["spirit_stones"]))
	return ", ".join(parts) if not parts.is_empty() else "no prize"


## WU-620: true when `rival` (may be null) fills round `index` (0-based), the last. Pure.
static func rival_round(c: CharacterData, data: GameData, rival: CharacterData, index: int) -> bool:
	var rounds := int(Sects.contest_def(c, data).get("rounds", 0))
	return index == rounds - 1 and Rivals.contest_rival(c, rival, data)


## "Your rival <name> waits in the final round." Pure.
static func rival_line(name: String) -> String:
	return "Your rival %s waits in the final round." % name


## One line per round: "Round 1: Village Boxer (Prize: ...)". `next_index` is the index of the next bout (earlier rounds are
## shown as won). `rival` (WU-620) replaces the last round's foe when they fill it. Pure.
static func ladder_lines(c: CharacterData, data: GameData, next_index: int = 0, rival: CharacterData = null) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while true:
		var round_def := Sects.contest_round(c, data, i)
		if round_def.is_empty():
			break
		var foe := Sects.trial_opponent(data, String(round_def["foe"]), float(round_def["power_mult"]))
		var mark := "won" if i < next_index else ("next" if i == next_index else "")
		var foe_name := rival.name if rival_round(c, data, rival, i) else String(foe.get("name", "a rival"))
		out.append("Round %d: %s (%s)%s" % [i + 1, foe_name, prize_text(round_def["prize"]), " - " + mark if mark != "" else ""])
		i += 1
	return out


## Entry mode. Returns false (and stays closed) when the contest cannot be entered.
func open(c: CharacterData, data: GameData, today: int, color: Color = UIStyle.ACCENT, rival: CharacterData = null) -> bool:
	if Sects.check_contest(c, data, today) != "":
		return false
	var sect: SectDef = data.sects[c.sect["id"]]
	_style(sect.name, color)
	_subtitle.text = "%s %s" % [sect.name, Sects.contest_name(c, data)]
	var lines := ladder_lines(c, data, 0, rival)
	if rival_round(c, data, rival, int(Sects.contest_def(c, data).get("rounds", 0)) - 1):
		lines.append(rival_line(rival.name))
	_set_rows(lines)
	_ladder.text = ""
	_arena.setup(String(c.sect["id"]), color, PlayerLook.of(c, data))
	_arena.mode = "ready"
	_arena.set_foe(rival if rival_round(c, data, rival, 0) else null)
	var first := Sects.contest_round(c, data, 0)
	var foe := Sects.trial_opponent(data, String(first["foe"]), float(first["power_mult"]))
	if rival_round(c, data, rival, 0):  # a one-round contest
		foe = Karma.npc_enemy(rival, data, c)
	var chance := Combat.win_chance(c, data, foe)  # once, on open
	_odds.text = "First bout vs %s. %s" % [String(foe.get("name", "a rival")), TrialCard.odds_line(chance)]
	_odds.add_theme_color_override("font_color", TrialCard.odds_color(chance))
	_note.text = TrialCard.SAFE_LINE + " You fight until you lose; each win pays its prize."
	_enter_button.visible = true
	_back_button.text = "Not yet"
	visible = true
	if TrialCard.default_to_wait(chance):
		_back_button.grab_focus.call_deferred()
	else:
		_enter_button.grab_focus.call_deferred()
	return true


## Result mode for one bout. `info`: round (1-based), rounds, won, foe, prize, next_foe ("" when none), next_chance.
func open_result(sect_name: String, info: Dictionary, color: Color = UIStyle.ACCENT) -> void:
	_style(sect_name, color)
	_subtitle.text = result_subtitle(info)
	_set_rows(PackedStringArray())
	_ladder.text = result_text(info)
	var rival_person: CharacterData = null
	if GameState.player != null:
		_arena.setup(String(GameState.player.sect.get("id", "")), color, PlayerLook.of(GameState.player, GameState.data))
		if bool(info.get("rival", false)):
			rival_person = GameState.npcs.get(String(info.get("foe_person", "")))
	else:
		_arena.color = color
	_arena.set_foe(rival_person)
	_arena.mode = "won" if bool(info.get("won", false)) else "lost"
	_odds.text = ""
	_odds.remove_theme_color_override("font_color")
	if bool(info.get("won", false)) and String(info.get("next_foe", "")) != "":
		_odds.text = "Next: %s. %s" % [String(info["next_foe"]), TrialCard.odds_line(float(info.get("next_chance", 0.0)))]
		if bool(info.get("next_rival", false)):
			_odds.text = rival_line(String(info["next_foe"])) + "\n" + _odds.text
	_note.text = ""
	_enter_button.visible = false
	_back_button.text = "OK"
	visible = true
	_back_button.grab_focus.call_deferred()


## GFX-256: the sum of every round's prize. Pure.
static func total_prize(c: CharacterData, data: GameData) -> Dictionary:
	var total := {"contribution": 0, "spirit_stones": 0}
	var i := 0
	while true:
		var round_def := Sects.contest_round(c, data, i)
		if round_def.is_empty():
			break
		for k: String in total:
			total[k] = int(total[k]) + int(round_def["prize"].get(k, 0))
		i += 1
	return total


## GFX-256: the champion card's title. Pure.
static func champion_title(sect_name: String) -> String:
	return "Champion of the %s contest" % sect_name


## GFX-256: the champion card's body. `news` is true when friends' news was queued (FOLK-049). Pure.
static func champion_text(total: Dictionary, news: bool) -> String:
	var line := "You won every round. Prize in all: %s." % prize_text(total)
	if news:
		line += " Word will reach your friends."
	return line


## GFX-256: the champion moment. Opens only after a full win (the HUD queues it from the last bout).
func open_champion(sect_name: String, total: Dictionary, news: bool, color: Color = UIStyle.ACCENT) -> void:
	_style(sect_name, color)
	_subtitle.text = champion_title(sect_name)
	_set_rows(PackedStringArray())
	_ladder.text = champion_text(total, news)
	if GameState.player != null:
		_arena.setup(String(GameState.player.sect.get("id", "")), color, PlayerLook.of(GameState.player, GameState.data))
	else:
		_arena.color = color
	_arena.set_foe(null)
	_arena.mode = "champion"
	_odds.text = ""
	_odds.remove_theme_color_override("font_color")
	_note.text = ""
	_enter_button.visible = false
	_back_button.text = "OK"
	visible = true
	_back_button.grab_focus.call_deferred()


static func result_subtitle(info: Dictionary) -> String:
	return "Round %d of %d: %s" % [int(info.get("round", 1)), int(info.get("rounds", 1)), "won" if bool(info.get("won", false)) else "lost"]


static func result_text(info: Dictionary) -> String:
	var foe := String(info.get("foe", "your foe"))
	if bool(info.get("rival", false)):
		foe = "Your rival " + foe
	if not bool(info.get("won", false)):
		return "%s beats you. You placed in round %d." % [foe, int(info.get("round", 1))]
	var line := "You defeat %s. Prize: %s." % [foe, prize_text(info.get("prize", {}))]
	if String(info.get("next_foe", "")) == "":
		line += " You have won every round!"
	return line


## One row per round: the next round in the accent colour, won rounds dimmed with "won", the rest plain.
func _set_rows(lines: PackedStringArray) -> void:
	for ch in _rows.get_children():
		_rows.remove_child(ch)
		ch.queue_free()
	_row_text = lines
	for line in lines:
		var l := UIStyle.label(line, 18)
		if line.ends_with("- won"):
			l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.55))
		elif line.ends_with("- next"):
			l.add_theme_color_override("font_color", UIStyle.ACCENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
		_rows.add_child(l)


func arena() -> ContestArena:
	return _arena


func _style(sect_name: String, color: Color) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()


func _on_enter() -> void:
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


func enter_button() -> Button:
	return _enter_button


func back_button() -> Button:
	return _back_button


func all_text() -> String:
	return "\n".join([_title.text, _subtitle.text, "\n".join(_row_text), _ladder.text, _odds.text, _note.text])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## GFX-254: the contest stage at 2x (480x128): a plank platform with sect banners and spectators, you facing the round's foe.
## mode: "ready" (facing off), "won" (foe kneels, your sword raised), "lost" (you kneel, the foe's sword points down).
class ContestArena extends SectCard.SectVignette:
	var foe_look: Dictionary = {}  ## empty = a disciple in the sect's darker colour
	var rival_name := ""

	func _init() -> void:
		mode = "ready"

	func setup(id: String, sect_color: Color, look: Dictionary) -> void:
		sect_id = id
		color = sect_color
		player_look = look
		queue_redraw()

	## `rival` (CharacterData or null): the foe takes the rival's own look.
	func set_foe(rival: CharacterData) -> void:
		if rival == null:
			foe_look = {}
			rival_name = ""
		else:
			foe_look = FamilyScreen.look_of(rival)
			rival_name = rival.name
		queue_redraw()

	func _draw() -> void:
		var wood := Color(0.45, 0.32, 0.2)
		draw_rect(Rect2(0, 0, W, H), Color(0.14, 0.15, 0.2))  # dusk sky
		draw_rect(Rect2(0, GROUND, W, H - GROUND), Color(0.3, 0.24, 0.17))
		draw_rect(Rect2(0, GROUND, W, 3), color.darkened(0.3))
		# Spectators below the platform edge, both sides.
		for x in [30, 62, 96, W - 96, W - 62, W - 30]:
			draw_figure(self, _disciple({"sash": color.lightened(0.15 * float(x % 3))}), x, 124, 2.0, "right" if x < W / 2 else "left")
		# The platform: posts, then planks 300 px wide across the middle.
		var px := (W - 300) / 2
		for x in [px + 8, px + 146, px + 284]:
			draw_rect(Rect2(x, 92, 8, 24), wood.darkened(0.3))
		draw_rect(Rect2(px, 84, 300, 12), wood.lightened(0.2))
		draw_rect(Rect2(px, 84, 300, 3), wood.lightened(0.45))
		# Banner poles at the corners in the sect colour.
		for x in [px + 4, px + 292]:
			draw_rect(Rect2(x, 20, 4, 64), wood.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 22), Vector2(x + 24, 28), Vector2(x + 4, 40)]), color)
		var foe := foe_look if not foe_look.is_empty() else _disciple({"robe": color.darkened(0.35), "sash": Color(0.9, 0.75, 0.3)})
		var sword := Color(0.78, 0.82, 0.88)
		match mode:
			"champion":
				_draw_champion(px, wood, sword)
			"won":
				draw_figure(self, _player(), px + 100, 84, 4.0, "right")
				draw_rect(Rect2(px + 126, 36, 4, 22), sword)  # your sword raised
				draw_figure(self, foe, px + 214, 90, 4.0, "left")  # the foe a step back, kneeling
				draw_rect(Rect2(px + 176, 80, 22, 4), sword)
			"lost":
				draw_figure(self, _player(), px + 90, 90, 4.0, "right")
				draw_rect(Rect2(px + 126, 80, 22, 4), sword)  # your sword on the ground
				draw_figure(self, foe, px + 200, 84, 4.0, "left")
				draw_rect(Rect2(px + 168, 40, 4, 22), sword)  # their sword point down
			_:
				draw_figure(self, _player(), px + 100, 84, 4.0, "right")
				draw_figure(self, foe, px + 200, 84, 4.0, "left")
				draw_rect(Rect2(px + 126, 56, 22, 4), sword)
				draw_rect(Rect2(px + 152, 56, 22, 4), sword)


	## GFX-256: you alone at the platform's centre, sword raised, both banners flying, spectators' arms up, petals falling.
	func _draw_champion(px: int, wood: Color, sword: Color) -> void:
		for x in [30, 62, 96, W - 96, W - 62, W - 30]:  # raised arms over the crowd
			draw_rect(Rect2(x - 12 if x < W / 2 else x + 8, 70, 4, 14), Color(0.85, 0.7, 0.55))
		draw_figure(self, _player(), W / 2, 84, 4.0, "down")
		draw_rect(Rect2(W / 2 + 22, 28, 4, 30), sword)  # your sword raised
		draw_rect(Rect2(W / 2 + 18, 28, 12, 3), wood.lightened(0.3))
		for i in 14:  # petals in the sect colour, a fixed scatter (no randomness)
			draw_rect(Rect2((i * 37) % (W - 20) + 8, (i * 23) % 70 + 6, 2, 2), color.lightened(0.25))
