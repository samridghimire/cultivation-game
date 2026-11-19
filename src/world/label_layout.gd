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
		var dx := 0.0
		var faded := false
		var extra: Array[Rect2] = []
		var given: Variant = covers.get(ri, extra)
		if given is Array and (given as Array).is_typed():  # PERF-021: typed lists are read in place, not copied
			extra = given
		else:
			extra.assign(given)
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
			if faded and covers.has(ri):  # WU-540: a person's label that cannot move vertically slides sideways clear of the building
				for k in range(1, 9):
					var done := false
					for dir in [1.0, -1.0]:
						var moved := Rect2(rect.position + Vector2(dir * 12.0 * k, 0), rect.size)
						if screen.size != Vector2.ZERO and not screen.encloses(moved):
							continue
						if not _hits(moved, placed, skip) and not _hits(moved, extra):
							chosen = moved
							dx = dir * 12.0 * k
							faded = false
							done = true
							break
					if done:
						break
		placed.append(chosen)
		out.append({"offset": offset, "faded": faded, "dx": dx})
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


## WU-511/WU-522, GFX-206: where a person's name label goes so it never sits on a place label. `label` is the rect
## drawn above their head, `feet_y` the y of their feet (NAN: no below-the-feet try). Clear of `place_rects` ->
## Vector2.ZERO; else it tries, in order: sideways up to 24 px, a lift of at most PERSON_MAX_LIFT (with the sideways
## tries), then just below the feet (label top at feet_y + 2, with the sideways tries). Vector2.ZERO when nothing fits
## (the caller then moves the place label).
const PERSON_MAX_LIFT := 16.0


static func person_offset(label: Rect2, feet_y: float, raw_place_rects: Array[Rect2]) -> Vector2:
	var place_rects: Array[Rect2] = _padded(raw_place_rects)
	if not _hits(label, place_rects):
		return Vector2.ZERO
	var rows: Array[float] = []
	for up in range(0, int(PERSON_MAX_LIFT / 4.0) + 1):
		rows.append(-4.0 * up)
	if not is_nan(feet_y):
		rows.append(feet_y + 2.0 - label.position.y)
	for dy in rows:
		for k in range(0, 7):
			for dir in [1.0, -1.0]:
				if k == 0 and dir < 0.0:
					continue
				var d := Vector2(dir * 4.0 * k, dy)
				if not _hits(Rect2(label.position + d, label.size), place_rects):
					return d
	return Vector2.ZERO


static func _padded(rects: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pr in rects:  # GFX-145: keep a 2 px margin
		out.append(pr.grow(2.0))
	return out


## WU-475: which labels stay in a crowd. A label whose neighbourhood (rect centres within `radius`, itself
## included) holds more than `max_shown` labels is kept only if fewer than `max_shown` of those neighbours
## outrank it: the `focus` index first, then a lower `priority` number, then the earlier index (callers sort
## by distance to the player). Labels in a thin neighbourhood are always kept.
static func crowd_keep(rects: Array[Rect2], priority: Array[int], focus: int, radius: float = 160.0, max_shown: int = 3) -> Array[bool]:
	var keep: Array[bool] = []
	var centers: Array[Vector2] = []  # PERF-020: centres once, squared distances
	for r in rects:
		centers.append(r.get_center())
	var r2 := radius * radius
	for i in rects.size():
		var near: Array[int] = []
		var ci := centers[i]
		for j in rects.size():
			if ci.distance_squared_to(centers[j]) <= r2:
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


## PERF-020: whether `rect` hits a placed rect j != i that is fixed or earlier than i (separate's blockers).
static func _hits_placed(rect: Rect2, placed: Array[Rect2], fixed: Array[bool], i: int) -> bool:
	for j in placed.size():
		if j != i and (fixed[j] or j < i) and rect.intersects(placed[j]):
			return true
	return false


## WU-545: the last pass over labels already placed. `fixed[i]` marks place labels (they never move); a moving label
## that overlaps anything placed is nudged up, then down, by its own height (at most two tries), else it is marked faded.
## Rects are processed in order, so earlier ones win. Returns one {dy: float, faded: bool} per rect.
static func separate(rects: Array[Rect2], fixed: Array[bool]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed: Array[Rect2] = []
	for i in rects.size():
		out.append({"dy": 0.0, "faded": false})
		placed.append(rects[i])
	# Fixed rects are obstacles for everything; moving ones only for those after them.
	for i in rects.size():
		if fixed[i]:
			continue
		var r := rects[i]
		if not _hits_placed(r, placed, fixed, i):  # PERF-020: no blockers list built per label
			continue
		var done := false
		for step in [-1.0, 1.0, -2.0, 2.0]:
			var moved := Rect2(r.position + Vector2(0, step * r.size.y), r.size)
			if not _hits_placed(moved, placed, fixed, i):
				placed[i] = moved
				out[i]["dy"] = step * r.size.y
				done = true
				break
		if not done:
			out[i]["faded"] = true
	return out


## GFX-201: the y shift that lifts `label` clear of `avoid` (the player's sprite rect): above it, or below it when
## above would leave `bounds`. 0 when they do not overlap or neither fits.
static func clear_of(label: Rect2, avoid: Rect2, bounds: Rect2) -> float:
	if not label.intersects(avoid):
		return 0.0
	var up := avoid.position.y - 2.0 - label.end.y
	var down := avoid.end.y + 2.0 - label.position.y
	for dy in [up, down]:
		var moved := Rect2(label.position + Vector2(0, dy), label.size)
		if bounds.size == Vector2.ZERO or bounds.encloses(moved):
			return dy
	return 0.0
