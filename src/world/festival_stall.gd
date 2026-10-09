class_name FestivalStall
extends Node2D
## WU-097: placeholder festival decoration beside a merchant (no interaction, no
## collision): a red and gold awning with two hanging lanterns, or willow branches
## for the Qingming festival. Unknown festivals get lanterns.

const RED := Color("b83a2e")
const GOLD := Color("e0b84a")
const WILLOW := Color("6f9f4a")
const POLE := Color("6b4a2e")
const OUTLINE := Color("2a2018")

var event_id := ""


## "willow" for Qingming, otherwise "lanterns".
static func decor_for(festival_id: String) -> String:
	return "willow" if festival_id == "qingming_festival" else "lanterns"


func _draw() -> void:
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
