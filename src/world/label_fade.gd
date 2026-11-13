class_name LabelFade
extends RefCounted
## WU-508: pure rules for fading name labels that would cover the player or sit under the [E] chip.

const OVER_PLAYER_ALPHA := 0.35
## The player's body box (32x48) around its position, in world coordinates.
const PLAYER_BODY := Vector2(32.0, 48.0)


static func player_rect(player_pos: Vector2) -> Rect2:
	return Rect2(player_pos - PLAYER_BODY / 2.0, PLAYER_BODY)


## 0.35 when the label rect overlaps the player's body rect, else 1.
static func alpha_for(label_rect: Rect2, player_rect_: Rect2) -> float:
	return OVER_PLAYER_ALPHA if label_rect.intersects(player_rect_) else 1.0


## Whether a place label must hide because the [E] chip (same coordinates) meets it.
static func hidden_by_chip(label_rect: Rect2, chip_rect: Rect2) -> bool:
	return chip_rect.size != Vector2.ZERO and label_rect.intersects(chip_rect)


## WU-529: alphas for a set of labels. A label clear of the player's body stays 1; of those over the body only the
## one whose owner is nearest the player shows (faded), the rest hide until they clear.
static func keep_nearest(rects: Array[Rect2], owner_pos: Array[Vector2], player_pos: Vector2) -> Array[float]:
	var body := player_rect(player_pos)
	var out: Array[float] = []
	var best := -1
	for i in rects.size():
		if rects[i].intersects(body) and (best < 0 or owner_pos[i].distance_to(player_pos) < owner_pos[best].distance_to(player_pos)):
			best = i
	for i in rects.size():
		if not rects[i].intersects(body):
			out.append(1.0)
		else:
			out.append(OVER_PLAYER_ALPHA if i == best else 0.0)
	return out


## WU-529: a walking NPC's label yields (35%) when it crosses a place label.
static func npc_alpha(npc_rect: Rect2, place_rects: Array[Rect2]) -> float:
	for p: Rect2 in place_rects:
		if npc_rect.intersects(p):
			return OVER_PLAYER_ALPHA
	return 1.0
