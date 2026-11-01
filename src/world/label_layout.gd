class_name LabelLayout
extends RefCounted
## WU-421: pure rect logic that keeps world labels from drawing over each other.

const MAX_STEPS := 2


## `rects` are label rects in priority order (first = most important). Returns one
## {offset: float (y shift), faded: bool} per rect. A rect that overlaps an already placed one
## (or a `blockers` rect) is nudged down then up by its height (max MAX_STEPS tries each way,
## and never off `screen`); if it still overlaps it is marked faded and left in place.
static func resolve(rects: Array[Rect2], screen: Rect2, blockers: Array[Rect2] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed: Array[Rect2] = blockers.duplicate()
	for rect in rects:
		var chosen := rect
		var offset := 0.0
		var faded := false
		if _hits(rect, placed):
			faded = true
			var step := rect.size.y + 2.0
			var tries: Array[float] = []
			for i in range(1, MAX_STEPS + 1):
				tries.append(step * i)
			for i in range(1, MAX_STEPS + 1):
				tries.append(-step * i)
			for dy in tries:
				var moved := Rect2(rect.position + Vector2(0, dy), rect.size)
				if screen.size != Vector2.ZERO and not screen.encloses(moved):
					continue
				if not _hits(moved, placed):
					chosen = moved
					offset = dy
					faded = false
					break
		placed.append(chosen)
		out.append({"offset": offset, "faded": faded})
	return out


static func _hits(rect: Rect2, others: Array[Rect2]) -> bool:
	for other in others:
		if rect.intersects(other):
			return true
	return false
