class_name EggPickup
extends Interactable
## CRIT-001: a hen's egg lying in the grass (GameState.eggs_here). Interact picks it directly through
## GameState.pick_egg; it is gone until the next day.

var index := 0
var taken := false


## Setup before add_child: the egg of ambient critter `p_index`, lying at `pos`.
func setup(p_index: int, p_name: String, pos: Vector2) -> void:
	index = p_index
	position = pos
	size = Vector2(20, 20)
	reach = 24.0
	art_kind = "forage"
	display_name = "Pick up %s" % p_name


func label_text() -> String:
	return ""


func get_options() -> Array[Dictionary]:
	return []


func is_available() -> bool:
	return not taken


func use_directly() -> bool:
	if taken:
		return true
	if GameState.pick_egg(index):
		taken = true
		queue_free()
	return true


func draw_generated_art() -> bool:
	var shade := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		shade.append(Vector2(0, 5) + Vector2(cos(a) * 9.0, sin(a) * 3.0))
	draw_colored_polygon(shade, Color(0, 0, 0, 0.18))
	var egg := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		egg.append(Vector2(cos(a) * 5.0, sin(a) * 6.5))
	draw_colored_polygon(egg, Color("f1e6c8"))
	draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 16, Color("2a2018"), 1.0)
	return true
