class_name FestivalStall
extends Node2D
## WU-097: placeholder festival decoration beside a merchant (no interaction, no
## collision): a red and gold awning with two hanging lanterns, or willow branches
## for the Qingming festival. Unknown festivals get lanterns.

const RED := Color("b83a2e")
const GOLD := Color("e0b84a")
const WILLOW := Color("6f9f4a")
const GREEN_DEEP := Color("3f6f3a")
const POLE := Color("6b4a2e")
const OUTLINE := Color("2a2018")

var event_id := ""
## WU-457: "<contest> today" shown above the stall while its contest is open to the player.
var caption := ""
var _label: Label


func _ready() -> void:
	if caption == "":
		return
	_label = Label.new()
	_label.text = caption
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", GOLD)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(-90, -40)
	_label.size = Vector2(180, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.z_index = 20  # GFX-085: above every NPC label
	add_child(_label)


## GFX-083: the look of a festival's decoration: "dragon_boat", "lanterns", "moon" or "willow"; unknown festivals get "lanterns".
const LOOKS := {"dragon_boat_festival": "dragon_boat", "lantern_festival": "lanterns", "mid_autumn_festival": "moon", "qingming_festival": "willow"}


static func decor_for(festival_id: String) -> String:
	return String(LOOKS.get(festival_id, "lanterns"))


## GFX-083: when true this node draws only the festival decoration (beside a `festival_only` merchant), no awning.
var decor_only := false
var _t := 0.0
var _phase := 0.0


func _process(delta: float) -> void:
	if MotionFx.reduced() or not visible:
		return
	_t += delta
	var p := snappedf(sin(_t * 1.6), 0.25)
	if not is_equal_approx(p, _phase):
		_phase = p
		queue_redraw()


## GFX-083: draws `look` on `ci` with its ground point at `at`. `phase` (-1..1) sways it; 0 is still.
static func draw_look(ci: CanvasItem, look: String, at: Vector2, phase: float) -> void:
	var sway := phase * 2.0
	match look:
		"dragon_boat":
			var hull := PackedVector2Array([at + Vector2(-26, -8), at + Vector2(22, -8), at + Vector2(30, -20), at + Vector2(16, 2), at + Vector2(-18, 2)])
			ci.draw_colored_polygon(hull, GREEN_DEEP)
			ci.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[4], hull[0]]), OUTLINE, 1.5)
			ci.draw_line(at + Vector2(-20, -3), at + Vector2(18, -3), RED, 2.0)
			ci.draw_circle(at + Vector2(30, -24), 6.0, RED)  # dragon head
			ci.draw_circle(at + Vector2(30, -24), 6.0, GOLD, false, 1.5)
			ci.draw_line(at + Vector2(33, -26), at + Vector2(39, -29 + sway), GOLD, 2.0)  # horn
			ci.draw_circle(at + Vector2(-34, -6), 8.0, RED)  # drum
			ci.draw_circle(at + Vector2(-34, -6), 8.0, GOLD, false, 2.0)
			ci.draw_line(at + Vector2(-40, -6), at + Vector2(-28, -6), GOLD, 1.0)
		"lanterns":
			ci.draw_line(at + Vector2(-34, -26), at + Vector2(34, -26), POLE, 1.5)
			for i in 5:
				var x := -28.0 + i * 14.0
				var c := at + Vector2(x + sway * 0.5, -14.0)
				ci.draw_line(at + Vector2(x, -26), c + Vector2(0, -6), OUTLINE, 1.0)
				ci.draw_circle(c, 11.0, Color(1.0, 0.8, 0.4, 0.14 + 0.04 * phase))  # soft glow
				ci.draw_circle(c, 6.0, RED.lightened(0.1))
				ci.draw_circle(c, 6.0, GOLD, false, 1.5)
		"moon":
			ci.draw_line(at + Vector2(0, 2), at + Vector2(0, -42), POLE, 3.0)
			ci.draw_circle(at + Vector2(0, -46), 13.0, Color(0.98, 0.95, 0.8))
			ci.draw_circle(at + Vector2(-4, -49), 3.0, Color(0.88, 0.85, 0.68))
			ci.draw_circle(at + Vector2(4, -43), 2.0, Color(0.88, 0.85, 0.68))
			ci.draw_arc(at + Vector2(0, -46), 13.0, 0.0, TAU, 20, GOLD, 1.5)
			for dx in [-16.0, 16.0]:
				ci.draw_line(at + Vector2(dx, 2), at + Vector2(dx + signf(dx) * 6.0 + sway * 0.5, -16), WILLOW.darkened(0.2), 2.0)
				for k in 3:
					ci.draw_circle(at + Vector2(dx + signf(dx) * (3.0 + k), -8.0 - k * 4.0), 2.0, GOLD)
		_:  # willow with a kite on a string
			for x in [-22.0, -8.0, 8.0, 22.0]:
				ci.draw_line(at + Vector2(x, -34), at + Vector2(x - 2 + sway, -6), WILLOW, 2.0)
				ci.draw_line(at + Vector2(x + 4, -34), at + Vector2(x + 3 + sway, -12), WILLOW.lightened(0.15), 2.0)
			ci.draw_line(at + Vector2(-26, -36), at + Vector2(26, -36), POLE, 2.0)
			var kite := at + Vector2(34 + sway, -46)
			ci.draw_line(at + Vector2(30, -2), kite, OUTLINE, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([kite + Vector2(0, -9), kite + Vector2(7, 0), kite + Vector2(0, 9), kite + Vector2(-7, 0)]), Color("e8e4d0"))
			ci.draw_polyline(PackedVector2Array([kite + Vector2(0, -9), kite + Vector2(7, 0), kite + Vector2(0, 9), kite + Vector2(-7, 0), kite + Vector2(0, -9)]), RED, 1.5)


## GFX-083: a scalloped trim of `count` half-discs along the top edge of a stall `width` wide, in `col`.
static func draw_scallops(ci: CanvasItem, at: Vector2, width: float, col: Color, count: int = 6) -> void:
	var r := width / float(count) / 2.0
	for i in count:
		var c := at + Vector2(-width / 2.0 + r + i * r * 2.0, 0)
		ci.draw_circle(c, r, GOLD if i % 2 == 0 else col.darkened(0.25))
		ci.draw_arc(c, r, 0.0, PI, 8, OUTLINE, 1.0)


func _draw() -> void:
	if decor_only:
		var key := "festival_stall_" + FestivalStall.decor_for(event_id)
		var tex := Sprites.texture(key)
		if tex != null:
			var k := Sprites.scale()
			draw_texture_rect(tex, Rect2(Vector2(-tex.get_size().x * k / 2.0, 4.0 - tex.get_size().y * k), tex.get_size() * k), false)
		else:
			FestivalStall.draw_look(self, FestivalStall.decor_for(event_id), Vector2(0, 4), _phase)
		return
	var art := Sprites.texture("festival_stall")
	if art != null:
		var k := Sprites.scale()
		draw_texture_rect(art, Rect2(Vector2(-art.get_size().x * k / 2.0, 28.0 - art.get_size().y * k), art.get_size() * k), false)
		return
	draw_line(Vector2(-22, 0), Vector2(-22, 28), POLE, 3.0)
	draw_line(Vector2(22, 0), Vector2(22, 28), POLE, 3.0)
	var awning := PackedVector2Array([Vector2(-28, 2), Vector2(28, 2), Vector2(22, -12), Vector2(-22, -12)])
	draw_colored_polygon(awning, RED)
	for i in 4:
		draw_rect(Rect2(-28 + i * 14.0, 2, 7, 4), GOLD)
	draw_polyline(PackedVector2Array([awning[0], awning[1], awning[2], awning[3], awning[0]]), OUTLINE, 1.5)
	if FestivalStall.decor_for(event_id) == "willow":
		for x in [-18.0, 0.0, 18.0]:
			draw_line(Vector2(x, 6), Vector2(x - 2, 24), WILLOW, 2.0)
			draw_line(Vector2(x + 4, 6), Vector2(x + 3, 20), WILLOW.lightened(0.15), 2.0)
	else:
		for x in [-14.0, 14.0]:
			draw_line(Vector2(x, 6), Vector2(x, 12), OUTLINE, 1.0)
			draw_circle(Vector2(x, 18), 6.0, RED.lightened(0.1))
			draw_circle(Vector2(x, 18), 6.0, GOLD, false, 1.5)
