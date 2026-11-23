class_name SectCard
extends PanelContainer
## WU-602: the card shown once when you join a sect. A code-drawn banner on a pole beside the sect's name,
## "You are now <rank>", rows for home, duty and up to 3 perks, the first step in the accent colour, and a
## Continue button that takes focus. Confirm/cancel also closes it. Time does not pass.

signal closed

const WRAP_WIDTH := 520
const BANNER_SCALE := 3  # 8x11 art px drawn at 3x ~ 24x33 px

var _banner: SectBanner
var _title: Label
var _subtitle: Label
var _rows: VBoxContainer
var _step: Label
var _button: Button
var vignette: SectVignette  ## GFX-246: the header picture of the current mode (null in lecture mode)


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
	_banner = SectBanner.new()
	_banner.custom_minimum_size = Vector2(26, 34)
	head.add_child(_banner)
	_title = UIStyle.label("", 26, UIStyle.ACCENT)
	head.add_child(_title)
	_subtitle = UIStyle.label("", 18)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	_step = UIStyle.label("", 17, UIStyle.ACCENT)
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	box.add_child(_step)
	_button = UIStyle.button("Continue", close)
	box.add_child(_button)


## "Home: Azure Peak, 3 days' walk" / "You are at the sect's home" / "Home: Azure Peak". Pure.
static func home_line(welcome: Dictionary) -> String:
	var days := int(welcome.get("home_days", -1))
	var home := String(welcome.get("home_region_name", ""))
	if days == 0:
		return "You are at the sect's home"
	if days > 0:
		return "Home: %s, %d days' walk" % [home, days] if days != 1 else "Home: %s, 1 day's walk" % home
	return "Home: %s" % home


## WU-604: "gather qi x1.5" -> "Gather qi 1.5x faster"; other perks just get a capital. Pure.
static func perk_line(perk: String) -> String:
	if perk.begins_with("gather qi x"):
		perk = "gather qi %sx faster" % perk.trim_prefix("gather qi x")
	return perk.substr(0, 1).to_upper() + perk.substr(1)


## `welcome` comes from Guidance.sect_welcome; `color` is the sect's robe colour (white-ish when none).
func open(welcome: Dictionary, color: Color = UIStyle.ACCENT, sect_id: String = "") -> void:
	_title.text = String(welcome.get("name", ""))
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "You are now %s" % String(welcome.get("rank_name", ""))
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	vignette = null
	_add_vignette("join", color, sect_id)
	var lines := PackedStringArray()
	if String(welcome.get("home_region_name", "")) != "":
		lines.append(home_line(welcome))
	lines.append(String(welcome.get("duty", "")))
	for perk in welcome.get("perks", PackedStringArray()):
		lines.append("- %s" % perk_line(String(perk)))
	for line in lines:
		var l := UIStyle.label(line, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
		_rows.add_child(l)
	_step.text = "First step: %s" % String(welcome.get("first_step", ""))
	_step.visible = true
	visible = true
	_button.grab_focus.call_deferred()


## WU-603: promotion mode. `summary` is Sects.promotion_summary; `sect_name` leads the card; `has_next` is false at the top rank.
func open_promotion(sect_name: String, summary: Dictionary, has_next: bool, color: Color = UIStyle.ACCENT, sect_id: String = "") -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Promoted: %s" % String(summary.get("rank_name", ""))
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	vignette = null
	_add_vignette("promote", color, sect_id)
	var perks: PackedStringArray = summary.get("perks_new", PackedStringArray())
	var lines := PackedStringArray()
	if perks.is_empty():
		lines.append("Your standing in the sect rises")
	for perk in perks:
		lines.append("- %s" % perk)
	for line in lines:
		var l := UIStyle.label(line, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
		_rows.add_child(l)
	var needs := String(summary.get("next_needs", ""))
	if has_next:
		_step.text = "Next rank: %s" % (needs if needs != "" else "a trial awaits")
	else:
		_step.text = ""
	_step.visible = has_next
	visible = true
	_button.grab_focus.call_deferred()


## WU-604: welcome mode after reporting at the hall. `items` is [[item_id, "2 x Qi Gathering Pill"], ...]; `services` from Guidance.hall_services.
func open_report(sect_name: String, rank_name: String, line: String, items: Array, services: PackedStringArray, data: GameData, color: Color = UIStyle.ACCENT, sect_id: String = "") -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = "Welcome to the hall, %s" % rank_name
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	vignette = null
	_add_vignette("report", color, sect_id)
	if line != "":
		_add_row("\"%s\"" % line)
	if not items.is_empty():
		_add_row("Received:")
		for it: Array in items:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var icon := TextureRect.new()
			icon.texture = ItemIcon.for_id(data, String(it[0]))
			icon.custom_minimum_size = Vector2(24, 24)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h.add_child(icon)
			var l := UIStyle.label(String(it[1]), 16)
			h.add_child(l)
			_rows.add_child(h)
	if not services.is_empty():
		_add_row("This hall offers:")
		for sv in services:
			_add_row("- %s" % sv)
	_step.text = ""
	_step.visible = false
	visible = true
	_button.grab_focus.call_deferred()


## WU-606: lecture mode: a drawn hall vignette, the elder's line, the qi gained and any insight.
func open_lecture(sect_name: String, lecture_name: String, line: String, qi: int, insight_name: String, color: Color = UIStyle.ACCENT, qi_capped: bool = true) -> void:
	_title.text = sect_name
	_title.add_theme_color_override("font_color", color)
	_banner.color = color
	_banner.queue_redraw()
	_subtitle.text = lecture_name.substr(0, 1).to_upper() + lecture_name.substr(1)
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	vignette = null
	var scene := LectureScene.new()
	scene.color = color
	if GameState.player != null and GameState.data != null:
		scene.player_look = PlayerLook.of(GameState.player, GameState.data)
	scene.custom_minimum_size = Vector2(LectureScene.W, LectureScene.H)
	scene.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scene.clip_contents = true
	_rows.add_child(scene)
	_add_row(line)
	if qi > 0:
		_add_row("+%d qi" % qi)
	elif qi_capped:
		_add_row("Your qi is at a bottleneck: the words settle in your mind")
	if insight_name != "":
		var l := UIStyle.label("Insight glimpsed: %s" % insight_name, 17, UIStyle.ACCENT)
		_rows.add_child(l)
	var dim := UIStyle.label("Next lecture: next month", 15)
	dim.modulate = Color(1, 1, 1, 0.6)
	_rows.add_child(dim)
	_step.text = ""
	_step.visible = false
	visible = true
	_button.grab_focus.call_deferred()


## GFX-246: a small drawn header picture for the join / report / promotion modes ("join", "report", "promote").
func _add_vignette(mode: String, color: Color, sect_id: String = "") -> SectVignette:
	var v := SectVignette.new()
	v.sect_id = sect_id
	if GameState.player != null and GameState.data != null:
		v.player_look = PlayerLook.of(GameState.player, GameState.data)
	v.mode = mode
	v.color = color
	v.custom_minimum_size = Vector2(SectVignette.W, SectVignette.H)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.clip_contents = true
	_rows.add_child(v)
	vignette = v
	return v


func _add_row(text: String) -> void:
	var l := UIStyle.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	_rows.add_child(l)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func button() -> Button:
	return _button


func all_text() -> String:
	var t := "%s\n%s\n" % [_title.text, _subtitle.text]
	for l in _rows.get_children():
		if l is Label:
			t += (l as Label).text + "\n"
		else:
			for k in l.get_children():
				if k is Label:
					t += (k as Label).text + "\n"
	return t + _step.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


## A small pole with a hanging pennant, drawn in code at BANNER_SCALE.
class SectBanner extends Control:
	var color := Color.WHITE
	var px := SectCard.BANNER_SCALE  ## WU-607: art-pixel size (3 on cards, 2 on the map)

	func _draw() -> void:
		paint(self, color, px)

	## Draws the banner with its pole top at the canvas origin (WU-607: the map reuses it at px 2).
	static func paint(ci: CanvasItem, col: Color, s: int) -> void:
		ci.draw_rect(Rect2(0, 0, s, 11 * s), Color(0.45, 0.32, 0.2))
		ci.draw_rect(Rect2(0, 0, 2 * s, s), Color(0.9, 0.75, 0.3))
		ci.draw_rect(Rect2(s, s, 7 * s, 7 * s), col)
		ci.draw_rect(Rect2(s, 8 * s, 7 * s, s), col.darkened(0.25))  # swallow-tail
		ci.draw_rect(Rect2(3 * s, 3 * s, 3 * s, 3 * s), col.lightened(0.5))


## WU-606 / GFX-248: the lecture hall at 2x: the elder seated on the dais (3x), four disciples in two rows and the
## player in the front row (PixelFigure sprites, upper body only), mats under them, scroll hangings either side.
class LectureScene extends Control:
	const W := 480
	const H := 144
	var color := Color.WHITE
	var player_look: Dictionary = {}

	func _sit(look: Dictionary, cx: float, base: float, s: float) -> void:
		var tex := PixelFigure.frame(look, "down", 0)
		var w := 16.0 * s
		var h := 15.0 * s  # cropped above the knees: they sit on a mat
		draw_rect(Rect2(cx - w * 0.7, base - 3 * s, w * 1.4, 4 * s), Color(0.55, 0.2, 0.18))  # mat
		draw_rect(Rect2(cx - w * 0.7, base - 3 * s, w * 1.4, s), Color(0.7, 0.35, 0.25))
		draw_texture_rect_region(tex, Rect2(cx - w / 2, base - h, w, h), Rect2(0, 0, 16, 15))

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.13, 0.12))  # hall wall
		draw_rect(Rect2(0, 92, W, H - 92), Color(0.3, 0.22, 0.15))  # floor boards
		for x in range(0, W, 48):
			draw_rect(Rect2(x, 92, 2, H - 92), Color(0.22, 0.16, 0.11))
		for x in [24, W - 60]:  # hanging scrolls
			draw_rect(Rect2(x, 12, 36, 60), Color(0.85, 0.8, 0.65))
			draw_rect(Rect2(x - 2, 8, 40, 5), Color(0.45, 0.32, 0.2))
			draw_rect(Rect2(x + 15, 22, 5, 38), Color(0.2, 0.15, 0.1))
			draw_rect(Rect2(x + 8, 28, 19, 4), color)
		draw_rect(Rect2(W / 2.0 - 80, 80, 160, 18), Color(0.4, 0.28, 0.18))  # dais
		draw_rect(Rect2(W / 2.0 - 80, 80, 160, 4), Color(0.55, 0.4, 0.25))
		_sit({"robe": color.darkened(0.35), "sash": color.lightened(0.3), "hair": Color(0.85, 0.85, 0.85)}, W / 2.0, 90, 3.0)
		var robe := {"robe": color, "sash": color.darkened(0.3)}
		for x in [W / 2.0 - 150, W / 2.0 - 70, W / 2.0 + 70, W / 2.0 + 150]:  # back row
			_sit(robe, x, 118, 1.7)
		for x in [W / 2.0 - 110, W / 2.0 + 110]:  # front row
			_sit(robe, x, 140, 2.0)
		_sit(player_look if player_look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, W / 2.0, 140, 2.0)  # the player


## GFX-250: 480x128 header pictures at 2x, code-drawn in the sect colour with PixelFigure people and one set of props
## per sect (`sect_id`). join: the player before the hall gate; report: the player bowing to a steward at the hall door;
## promote: the player under a raised banner, a disciple either side with a rank sash.
class SectVignette extends Control:
	const W := 480
	const H := 128
	const GROUND := 96
	var mode := "join"
	var color := Color.WHITE
	var sect_id := ""
	var player_look: Dictionary = {}

	## A whole PixelFigure standing with its feet at `base`, `s` times its 16x20 art size. `dir` is "down"/"left"/"right".
	static func draw_figure(ci: CanvasItem, look: Dictionary, cx: float, base: float, s: float, dir: String = "down", bow: bool = false) -> void:
		var tex := PixelFigure.frame(look, dir, 0)
		var w := 16.0 * s
		var h := 20.0 * s
		ci.draw_rect(Rect2(cx - w * 0.4, base - s, w * 0.8, s * 1.5), Color(0, 0, 0, 0.3))  # shadow
		if bow:
			ci.draw_set_transform(Vector2(cx, base), 0.35, Vector2.ONE)
			ci.draw_texture_rect(tex, Rect2(-w / 2, -h, w, h), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(tex, Rect2(cx - w / 2, base - h, w, h), false)

	func _player() -> Dictionary:
		return player_look if player_look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}

	func _disciple(extra: Dictionary = {}) -> Dictionary:
		var d := {"robe": color.darkened(0.2), "sash": color.lightened(0.3)}
		d.merge(extra, true)
		return d

	func _props() -> void:
		var wood := Color(0.45, 0.32, 0.2)
		match sect_id:
			"blood_lotus_sect":
				draw_rect(Rect2(20, GROUND - 2, 120, 12), Color(0.35, 0.05, 0.07))  # blood pit rim and pool
				draw_rect(Rect2(20, GROUND - 2, 120, 3), Color(0.25, 0.2, 0.2))
				draw_rect(Rect2(28, GROUND + 3, 104, 5), Color(0.6, 0.08, 0.1))
				for x in [58, 80, 102]:  # a lotus on the pit
					draw_rect(Rect2(x - 6, GROUND - 8, 12, 6), color.lightened(0.2))
					draw_rect(Rect2(x - 3, GROUND - 13, 6, 6), color.lightened(0.5))
			"myriad_treasure_pavilion":
				draw_rect(Rect2(14, 34, 96, 62), Color(0.35, 0.3, 0.22))  # vault door
				draw_rect(Rect2(20, 40, 84, 56), Color(0.22, 0.2, 0.17))
				draw_rect(Rect2(60, 40, 4, 56), Color(0.5, 0.4, 0.2))
				draw_rect(Rect2(48, 64, 8, 8), Color(0.8, 0.65, 0.25))  # lock plates
				draw_rect(Rect2(68, 64, 8, 8), Color(0.8, 0.65, 0.25))
				draw_rect(Rect2(116, 76, 44, 20), wood)  # counter with an abacus
				draw_rect(Rect2(120, 68, 36, 10), wood.darkened(0.2))
				for i in 4:
					draw_rect(Rect2(124 + i * 8, 70, 4, 6), Color(0.9, 0.8, 0.4))
			_:
				draw_rect(Rect2(16, GROUND - 4, 120, 10), Color(0.5, 0.5, 0.52))  # stone sparring ring
				draw_rect(Rect2(24, GROUND - 2, 104, 6), Color(0.4, 0.4, 0.42))
				draw_rect(Rect2(150, 54, 40, 6), wood)  # sword rack
				draw_rect(Rect2(152, 54, 4, 42), wood.darkened(0.2))
				draw_rect(Rect2(184, 54, 4, 42), wood.darkened(0.2))
				for x in [160, 168, 176]:
					draw_rect(Rect2(x, 32, 3, 28), Color(0.78, 0.82, 0.88))
					draw_rect(Rect2(x - 1, 58, 5, 3), color)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color(0.14, 0.15, 0.2))  # dusk sky
		draw_rect(Rect2(0, GROUND, W, H - GROUND), Color(0.3, 0.24, 0.17))  # ground
		draw_rect(Rect2(0, GROUND, W, 3), color.darkened(0.3))
		_props()
		var wood := Color(0.45, 0.32, 0.2)
		match mode:
			"join":
				draw_rect(Rect2(300, 24, 14, 74), wood)  # gate posts
				draw_rect(Rect2(392, 24, 14, 74), wood)
				draw_rect(Rect2(288, 14, 130, 10), color)  # gate roof
				draw_rect(Rect2(314, 36, 78, 60), color.darkened(0.55))  # doorway
				draw_figure(self, _player(), 230, 118, 4.0, "right")
			"report":
				draw_rect(Rect2(296, 70, 100, 8), wood)  # desk in the doorway
				draw_rect(Rect2(302, 78, 6, 20), wood.darkened(0.2))
				draw_rect(Rect2(384, 78, 6, 20), wood.darkened(0.2))
				draw_rect(Rect2(330, 64, 22, 6), Color(0.85, 0.8, 0.65))  # ledger
				draw_figure(self, _disciple({"sash": Color(0.9, 0.75, 0.3)}), 342, 100, 3.0, "left")  # steward at the door
				draw_figure(self, _player(), 230, 118, 4.0, "right", true)
			_:
				draw_rect(Rect2(W / 2.0 - 2, 6, 5, 92), wood)  # raised banner
				draw_rect(Rect2(W / 2.0 + 3, 10, 52, 44), color)
				draw_rect(Rect2(W / 2.0 + 3, 50, 52, 8), color.darkened(0.25))
				draw_rect(Rect2(W / 2.0 + 18, 22, 20, 18), color.lightened(0.5))
				var sash := Color(0.9, 0.75, 0.3)
				draw_figure(self, _disciple({"robe": color.darkened(0.3)}), W / 2.0 - 100, 118, 3.5, "right")
				draw_figure(self, _disciple({"robe": color.darkened(0.3)}), W / 2.0 + 100, 118, 3.5, "left")
				var look := _player().duplicate()
				look["sash"] = sash  # the new rank's sash
				draw_figure(self, look, W / 2.0 - 40, 120, 4.0)
