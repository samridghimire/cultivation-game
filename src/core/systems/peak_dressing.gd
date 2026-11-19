class_name PeakDressing
extends RefCounted
## GFX-205: draw-only high-ground dressing for a `map.high.peak` region (Azure Peak): cliff faces along the top and right map
## edges, stone terraces and stair segments near the sect hall, wind-bent pine clusters and mist rows low on the map edges.
## Pure and seeded by region id; nothing here changes collision. Dressing stays clear of places, paths, landmarks, the
## spawn, travel points and the label zone above every place.

const CLIFF_TOP_DEPTH := 22.0
const CLIFF_SIDE_DEPTH := 26.0
const MAX_TERRACES := 5
const MAX_STAIRS := 2
const PINE_CLUSTERS := 3
const LEDGE_Y := 430.0  # GFX-210: the rock ledge band north of the road (road y 470..530 on Azure Peak)
const LEDGE_H := 18.0
const LEDGE_X0 := 60.0
const LEDGE_X1 := 1360.0
const LABEL_LIFT := 44.0  # keepout above a place for its name label


static func enabled(region: Dictionary) -> bool:
	var high: Variant = region.get("map", {}).get("high", null)
	return high is Dictionary and bool(high.get("peak", false))


## GFX-210 adds ledges: Array[Dictionary{rect, seed}] (rock band north of the road, broken by places and paths),
## cascades: Array[Rect2] (foam steps where a stream crosses the ledge) and boulders: Array[Dictionary{pos, r}] at the ledge foot.
## {cliffs: Array[Dictionary{rect, seed, side}], terraces: Array[Rect2], stairs: Array[Rect2],
##  pines: Array[Dictionary{pos, lean}], mist: Array[Dictionary{rect, alpha}]}; all empty when not enabled.
static func layout(region: Dictionary) -> Dictionary:
	var out := {"cliffs": [] as Array[Dictionary], "terraces": [] as Array[Rect2], "stairs": [] as Array[Rect2], "pines": [] as Array[Dictionary], "mist": [] as Array[Dictionary], "ledges": [] as Array[Dictionary], "cascades": [] as Array[Rect2], "boulders": [] as Array[Dictionary]}
	if not enabled(region):
		return out
	var map: Dictionary = region["map"]
	var sz: Array = map.get("size", [1600, 1000])
	var size := Vector2(float(sz[0]), float(sz[1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|peak")
	# Cliff faces: ragged segments along the top and right edges (the drop is off the map).
	var x := 0.0
	while x < size.x:
		var w := rng.randf_range(90.0, 170.0)
		var d := CLIFF_TOP_DEPTH + rng.randf_range(-6.0, 10.0)
		out["cliffs"].append({"rect": Rect2(x, 0.0, minf(w, size.x - x), d), "seed": rng.randi(), "side": "top"})
		x += w
	var y := 0.0
	while y < size.y:
		var h := rng.randf_range(90.0, 160.0)
		var d := CLIFF_SIDE_DEPTH + rng.randf_range(-6.0, 10.0)
		out["cliffs"].append({"rect": Rect2(size.x - d, y, d, minf(h, size.y - y)), "seed": rng.randi(), "side": "right"})
		y += h
	# Mist rows low on the left and bottom edges.
	out["mist"].append({"rect": Rect2(0.0, size.y - 70.0, size.x, 70.0), "alpha": 0.22})
	out["mist"].append({"rect": Rect2(0.0, size.y - 36.0, size.x, 36.0), "alpha": 0.2})
	out["mist"].append({"rect": Rect2(0.0, 0.0, 60.0, size.y), "alpha": 0.14})
	# Keepouts for the remaining props.
	var forbid: Array[Rect2] = Scenery.blocked_rects(region)
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var ps: Array = p.get("size", [64, 64])
		var c := Vector2(float(pos[0]), float(pos[1]))
		forbid.append(Rect2(c.x - 90.0, c.y - float(ps[1]) / 2.0 - LABEL_LIFT, 180.0, float(ps[1]) / 2.0 + LABEL_LIFT + 30.0))
	if region.has("spawn"):
		forbid.append(Rect2(float(region["spawn"][0]) - 40.0, float(region["spawn"][1]) - 40.0, 80.0, 80.0))
	for s in region.get("npc_spots", []):
		forbid.append(Rect2(float(s[0]) - 30.0, float(s[1]) - 30.0, 60.0, 60.0))
	for it: Dictionary in Scenery.relief_layout(region):
		forbid.append((it["rect"] as Rect2).grow(6.0))
	for it: Dictionary in Scenery.high_crags(region):
		forbid.append((it["rect"] as Rect2).grow(6.0))
	for hp: Dictionary in Scenery.high_pines(region):
		forbid.append(Rect2(hp["pos"] - Vector2(40.0, 60.0), Vector2(80.0, 80.0)))
	var bounds := Rect2(Vector2(40.0, CLIFF_TOP_DEPTH + 40.0), size - Vector2(80.0 + CLIFF_SIDE_DEPTH, 80.0 + CLIFF_TOP_DEPTH))
	var taken: Array[Rect2] = []
	# Stone terraces and stair segments near the hall (the first sect_hall place; else the map centre).
	var anchor := size / 2.0
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) == "sect_hall":
			anchor = Vector2(float(p["pos"][0]), float(p["pos"][1]))
			break
	for i in 120:
		if (out["stairs"] as Array).size() >= MAX_STAIRS:
			break
		var r := Rect2(anchor + Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(-220.0, 220.0)), Vector2(36.0, 44.0)).abs()
		if _fits(r, bounds, forbid, taken):
			out["stairs"].append(r)
			taken.append(r.grow(14.0))
	for i in 200:
		if (out["terraces"] as Array).size() >= MAX_TERRACES:
			break
		var r := Rect2(anchor + Vector2(rng.randf_range(-340.0, 340.0), rng.randf_range(-260.0, 260.0)), Vector2(rng.randf_range(60.0, 96.0), 12.0))
		if _fits(r, bounds, forbid, taken):
			out["terraces"].append(r)
			taken.append(r.grow(16.0))
	# Wind-bent pines in small clusters, all leaning the same way per cluster.
	for ci in PINE_CLUSTERS:
		for attempt in 60:
			var c := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			var lean := -1.0 if rng.randf() < 0.5 else 1.0
			var feet: Array[Vector2] = []
			for k in 3:
				feet.append(c + Vector2(float(k) * 34.0 + rng.randf_range(-6.0, 6.0), rng.randf_range(-14.0, 14.0)))
			var ok := true
			for f in feet:
				var box := Rect2(f - Vector2(26.0, 56.0), Vector2(52.0, 64.0))
				if not _fits(box, bounds.grow(30.0), forbid, taken):
					ok = false
					break
			if ok:
				for f in feet:
					out["pines"].append({"pos": f, "lean": lean})
					taken.append(Rect2(f - Vector2(26.0, 56.0), Vector2(52.0, 64.0)))
				break
	# Ledge keepouts: the hard blockers and each place's own rect (names are drawn over the band, not blocked by it).
	var lforbid: Array[Rect2] = []
	for b in Scenery.blocked_rects(region):
		if b.size.y < 900.0:  # a stream's full-height blocker is handled by the cascade gap in _ledges
			lforbid.append(b)
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var c := Vector2(float(p["pos"][0]), float(p["pos"][1]))
		var ps: Array = p.get("size", [64, 64])
		lforbid.append(Rect2(c - Vector2(float(ps[0]), float(ps[1])) / 2.0, Vector2(float(ps[0]), float(ps[1]))).grow(12.0))
	for it: Dictionary in Scenery.relief_layout(region):
		lforbid.append((it["rect"] as Rect2).grow(6.0))
	for it: Dictionary in Scenery.high_crags(region):
		lforbid.append((it["rect"] as Rect2).grow(6.0))
	_ledges(region, rng, lforbid, out)
	return out


## GFX-210: a rock ledge band across the map north of the road, skipped wherever a place, path, landmark or label zone is in
## the way; streams that cross the band get cascades; boulders gather at the ledge foot.
static func _ledges(region: Dictionary, rng: RandomNumberGenerator, forbid: Array[Rect2], out: Dictionary) -> void:
	var map: Dictionary = region["map"]
	var streams: Array[Rect2] = []
	for lm: Dictionary in map.get("landmarks", []):
		if String(lm.get("kind", "")) == "stream":
			var c := Vector2(float(lm["pos"][0]), float(lm["pos"][1]))
			streams.append(Rect2(c.x - float(lm["size"][0]) / 2.0, LEDGE_Y - 14.0, float(lm["size"][0]), LEDGE_H + 40.0))
	var x := LEDGE_X0
	while x < LEDGE_X1:
		var w := rng.randf_range(70.0, 130.0)
		var r := Rect2(x, LEDGE_Y + rng.randf_range(-3.0, 3.0), minf(w, LEDGE_X1 - x), LEDGE_H)
		var hit := false
		for f in forbid:
			if f.intersects(r):
				hit = true
				break
		for st in streams:
			if st.intersects(r):
				hit = true
		if not hit:
			out["ledges"].append({"rect": r, "seed": rng.randi()})
		x += w + (rng.randf_range(4.0, 14.0))
	for st in streams:
		out["cascades"].append(st)
	# boulders at the ledge foot, in the meadow just north of the band (the road hugs its south side)
	var led: Array = out["ledges"]
	var tries := 0
	while (out["boulders"] as Array).size() < 7 and tries < 200 and not led.is_empty():
		tries += 1
		var l: Rect2 = (led[rng.randi() % led.size()] as Dictionary)["rect"]
		var rad := rng.randf_range(6.0, 11.0)
		var pos := Vector2(l.position.x + rng.randf_range(0.0, l.size.x), l.position.y - 8.0 - rng.randf_range(0.0, 8.0))
		var box := Rect2(pos - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		var ok := true
		for f in forbid:
			if f.intersects(box):
				ok = false
				break
		if ok:
			for b: Dictionary in out["boulders"]:
				if (b["pos"] as Vector2).distance_to(pos) < 26.0:
					ok = false
		if ok:
			out["boulders"].append({"pos": pos, "r": rad})


static func _fits(r: Rect2, bounds: Rect2, forbid: Array[Rect2], taken: Array[Rect2]) -> bool:
	if not bounds.encloses(r):
		return false
	for f in forbid:
		if f.intersects(r):
			return false
	for t in taken:
		if t.intersects(r):
			return false
	return true
