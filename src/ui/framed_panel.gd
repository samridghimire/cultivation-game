class_name FramedPanel
extends StyleBox
## GFX-099: the shared HUD/modal panel look: flat dark fill, a 2 px gold outer line, a 1 px darker inner
## line 3 px inside it, and 6x6 corner brackets. Drawn in code (no assets); integer sizes stay crisp.
## Use UIStyle.panel_style(); callers that tweak fill/border colours use UIStyle.flat_panel_style().

const BRACKET := 6
const INNER_INSET := 3

var bg_color: Color = Color(0.08, 0.09, 0.13, 1.0)
var border_color: Color = Color("e8c76a")
var inner_color: Color = Color("e8c76a").darkened(0.55)
var _fill: StyleBoxFlat


func _init() -> void:
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(2)
	_fill.set_border_width_all(2)


func _draw(canvas_item: RID, rect: Rect2) -> void:
	_fill.bg_color = bg_color
	_fill.border_color = border_color
	_fill.draw(canvas_item, rect)
	var r := Rect2(rect.position.round(), rect.size.round())
	var inner := r.grow(-INNER_INSET)
	if inner.size.x > 2 * BRACKET and inner.size.y > 2 * BRACKET:
		_line_rect(canvas_item, inner, inner_color, 1.0)
	if r.size.x > 4 * BRACKET and r.size.y > 4 * BRACKET:
		for corner in 4:
			var cx := r.position.x if corner % 2 == 0 else r.end.x - BRACKET
			var cy := r.position.y if corner < 2 else r.end.y - BRACKET
			var sx := Rect2(cx, cy if corner < 2 else cy + BRACKET - 2, BRACKET, 2)
			var sy := Rect2(cx if corner % 2 == 0 else cx + BRACKET - 2, cy, 2, BRACKET)
			RenderingServer.canvas_item_add_rect(canvas_item, sx, border_color)
			RenderingServer.canvas_item_add_rect(canvas_item, sy, border_color)


static func _line_rect(ci: RID, r: Rect2, color: Color, w: float) -> void:
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position, Vector2(r.size.x, w)), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.end.y - w, r.size.x, w), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position, Vector2(w, r.size.y)), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.end.x - w, r.position.y, w, r.size.y), color)
