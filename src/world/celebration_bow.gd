class_name CelebrationBow
extends Node2D
## GFX-027: a pixel ribbon and bow tied to the stall or house nearest a village celebration.
## Red for a wedding, white for a funeral (the lantern colour).

const LANDMARK_KINDS: Array[String] = ["stall", "house"]

var ribbon_color := Color("e03030")
var span := 60.0


## The stall or house landmark (a regions.json map.landmarks entry) closest to `from`, {} if the region has none.
static func nearest_landmark(landmarks: Array, from: Vector2) -> Dictionary:
	var best := {}
	var best_dist := INF
	for lm: Dictionary in landmarks:
		if not LANDMARK_KINDS.has(str(lm.get("kind", ""))):
			continue
		var pos: Array = lm.get("pos", [0, 0])
		var d := from.distance_to(Vector2(float(pos[0]), float(pos[1])))
		if d < best_dist:
			best_dist = d
			best = lm
	return best


func _draw() -> void:
	var s := float(Sprites.scale())
	var dark := ribbon_color.darkened(0.35)
	# A band along the eaves with a bow at its middle and two tails.
	draw_rect(Rect2(-span / 2.0, -s, span, s * 2.0), ribbon_color)
	draw_rect(Rect2(-span / 2.0, s, span, s * 0.5), dark)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(minf(0.0, side * s * 5.0), -s * 3.0, s * 5.0, s * 5.0), ribbon_color)
		draw_rect(Rect2(minf(0.0, side * s * 5.0), s * 1.5, s * 5.0, s * 0.5), dark)
	draw_rect(Rect2(-s * 1.5, -s * 1.5, s * 3.0, s * 3.0), ribbon_color.lightened(0.25))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * s * 2.0 - s * 0.5, s * 2.0, s, s * 5.0), ribbon_color)
