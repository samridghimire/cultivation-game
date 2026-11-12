class_name LabelLayout
extends RefCounted
## WU-421: pure rect logic that keeps world labels from drawing over each other.

const MAX_STEPS := 2


## `rects` are label rects in priority order (first = most important). Returns one
## {offset: float (y shift), faded: bool} per rect. A rect that overlaps an already placed one
## (or a `blockers` rect) is nudged down then up by its height (max MAX_STEPS tries each way,
## and never off `screen`); if it still overlaps it is marked faded and left in place.
## `own_blocker` (GFX-071) maps a rect index to the blocker index that rect belongs to; that one is ignored for it.
## WU-483: `covers` maps a rect index to extra rects (building sprites) only that label must clear; it then moves down first.
static func resolve(rects: Array[Rect2], screen: Rect2, blockers: Array[Rect2] = [], own_blocker: Dictionary = {}, covers: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed: Array[Rect2] = blockers.duplicate()
	for ri in rects.size():
		var rect := rects[ri]
		var skip: int = int(own_blocker.get(ri, -1))
		var chosen := rect
		var offset := 0.0
		var faded := false
		var extra: Array[Rect2] = []
		extra.assign(covers.get(ri, []))
		if _hits(rect, placed, skip) or _hits(rect, extra):
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
				if not _hits(moved, placed, skip) and not _hits(moved, extra):
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


## WU-511/WU-522: where a person's name label goes so it never sits on a place label. `label` is the rect drawn
## above their head, `feet_y` the y of their feet. Clear of `place_rects` -> Vector2.ZERO; else it slides sideways in
## 4 px steps up to 40 px, then tries again 4..80 px higher. It never moves down (that put it on the figure).
## Returns the offset to add to the label; Vector2.ZERO when nothing fits.
static func person_offset(label: Rect2, _feet_y: float, place_rects: Array[Rect2]) -> Vector2:
	if not _hits(label, place_rects):
		return Vector2.ZERO
	for up in range(0, 21):
		for k in range(0, 11):
			for dir in [1.0, -1.0]:
				if k == 0 and dir < 0.0:
					continue
				var d := Vector2(dir * 4.0 * k, -4.0 * up)
				if not _hits(Rect2(label.position + d, label.size), place_rects):
					return d
	return Vector2.ZERO


## WU-475: which labels stay in a crowd. A label whose neighbourhood (rect centres within `radius`, itself
## included) holds more than `max_shown` labels is kept only if fewer than `max_shown` of those neighbours
## outrank it: the `focus` index first, then a lower `priority` number, then the earlier index (callers sort
## by distance to the player). Labels in a thin neighbourhood are always kept.
static func crowd_keep(rects: Array[Rect2], priority: Array[int], focus: int, radius: float = 160.0, max_shown: int = 3) -> Array[bool]:
	var keep: Array[bool] = []
	for i in rects.size():
		var near: Array[int] = []
		for j in rects.size():
			if rects[i].get_center().distance_to(rects[j].get_center()) <= radius:
				near.append(j)
		if near.size() <= max_shown:
			keep.append(true)
			continue
		var outranking := 0
		for j in near:
			if j != i and _outranks(j, i, priority, focus):
				outranking += 1
		keep.append(outranking < max_shown)
	return keep


static func _outranks(a: int, b: int, priority: Array[int], focus: int) -> bool:
	if (a == focus) != (b == focus):
		return a == focus
	var pa: int = priority[a] if a < priority.size() else 0
	var pb: int = priority[b] if b < priority.size() else 0
	if pa != pb:
		return pa < pb
	return a < b


static func _hits(rect: Rect2, others: Array[Rect2], skip: int = -1) -> bool:
	for i in others.size():
		if i != skip and rect.intersects(others[i]):
			return true
	return false
