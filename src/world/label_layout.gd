class_name LabelLayout
extends RefCounted
## WU-421: pure rect logic that keeps world labels from drawing over each other.

const MAX_STEPS := 2


## `rects` are label rects in priority order (first = most important). Returns one
## {offset: float (y shift), faded: bool} per rect. A rect that overlaps an already placed one
## (or a `blockers` rect) is nudged down then up by its height (max MAX_STEPS tries each way,
## and never off `screen`); if it still overlaps it is marked faded and left in place.
## `own_blocker` (GFX-071) maps a rect index to the blocker index that rect belongs to; that one is ignored for it.
static func resolve(rects: Array[Rect2], screen: Rect2, blockers: Array[Rect2] = [], own_blocker: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed: Array[Rect2] = blockers.duplicate()
	for ri in rects.size():
		var rect := rects[ri]
		var skip: int = int(own_blocker.get(ri, -1))
		var chosen := rect
		var offset := 0.0
		var faded := false
		if _hits(rect, placed, skip):
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
				if not _hits(moved, placed, skip):
					chosen = moved
					offset = dy
					faded = false
					break
		placed.append(chosen)
		out.append({"offset": offset, "faded": faded})
	return out


## GFX-056: per-label y offsets so no two label rects overlap. `anchors` are the things the labels name.
## Processed by anchor y then x; each label stays put unless it hits an already placed one, then it moves
## up (else down) in 4 px steps, at most 40 px, and gives up (offset 0) when nothing fits.
static func offsets(rects: Array[Rect2], anchors: Array[Vector2]) -> Array[Vector2]:
	var order: Array[int] = []
	for i in rects.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if anchors[a].y != anchors[b].y:
			return anchors[a].y < anchors[b].y
		if anchors[a].x != anchors[b].x:
			return anchors[a].x < anchors[b].x
		return a < b)
	var out: Array[Vector2] = []
	out.resize(rects.size())
	out.fill(Vector2.ZERO)
	var placed: Array[Rect2] = []
	for i in order:
		var chosen := rects[i]
		if _hits(chosen, placed):
			for dir in [-1.0, 1.0]:
				var found := false
				for k in range(1, 11):
					var moved := Rect2(rects[i].position + Vector2(0, dir * 4.0 * k), rects[i].size)
					if not _hits(moved, placed):
						chosen = moved
						out[i] = Vector2(0, dir * 4.0 * k)
						found = true
						break
				if found:
					break
		placed.append(chosen)
	return out


static func _hits(rect: Rect2, others: Array[Rect2], skip: int = -1) -> bool:
	for i in others.size():
		if i != skip and rect.intersects(others[i]):
			return true
	return false
