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
