extends TestCase
## GFX-127: Scenery.village_yards (footpaths, yards, props and roofs of a village).


func _region() -> Dictionary:
	return data().regions["qingshi_village"]


func _size(r: Dictionary) -> Vector2:
	var s: Array = r["map"]["size"]
	return Vector2(float(s[0]), float(s[1]))


func test_deterministic() -> void:
	var r := _region()
	assert_eq(str(Scenery.village_yards(r, _size(r))), str(Scenery.village_yards(r, _size(r))))


func test_footpaths_reach_a_road_from_the_door() -> void:
	var r := _region()
	var y := Scenery.village_yards(r, _size(r))
	var roads: Array[Rect2] = []
	for p in r["map"]["paths"]:
		roads.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	assert_true((y["footpaths"] as Array).size() >= 2, "some cottages get a path")
	var touches := {}
	var starts := {}
	for f: Dictionary in y["footpaths"]:
		var fr: Rect2 = f["rect"]
		for road in roads:
			if road.grow(1.0).intersects(fr):
				touches[f["door"]] = true
		starts[f["door"]] = true
	for door in starts:
		assert_true(touches.has(door), "path of building %s reaches a road" % door)


func test_props_clear_of_everything() -> void:
	var r := _region()
	var y := Scenery.village_yards(r, _size(r))
	assert_true((y["props"] as Array).size() >= 2, "props are placed")
	var lms := Scenery.landmark_rects(r)
	var roads: Array[Rect2] = []
	for p in r["map"]["paths"]:
		roads.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	var seen: Array[Rect2] = []
	for p: Dictionary in y["props"]:
		var pr: Rect2 = p["rect"]
		for rr in roads:
			assert_false(rr.intersects(pr), "prop on a road")
		for f: Dictionary in y["footpaths"]:
			assert_false((f["rect"] as Rect2).intersects(pr), "prop on a footpath")
		for l in lms:
			assert_false(l.intersects(pr), "prop on a landmark")
		for pl: Dictionary in r["places"]:
			assert_false(Npcs.place_keepout(pl).grow(10.0).intersects(pr), "prop in a place keepout")
		for o in seen:
			assert_false(o.intersects(pr), "props overlap")
		seen.append(pr)


func test_roofs_vary() -> void:
	var r := _region()
	var roofs: Dictionary = Scenery.village_yards(r, _size(r))["roof"]
	assert_eq(roofs.size(), 4)
	var distinct := {}
	for c: Color in roofs.values():
		distinct[c.to_html()] = true
	assert_true(distinct.size() > 1, "not all one colour")


func test_other_regions_empty_and_validation() -> void:
	var d := data()
	var m: Dictionary = d.regions["misty_forest"]
	var y := Scenery.village_yards(m, Vector2(1600, 1000))
	assert_eq((y["footpaths"] as Array).size() + (y["props"] as Array).size() + (y["yards"] as Array).size() + (y["roof"] as Dictionary).size(), 0)
	d.regions["qingshi_village"]["map"]["yards"] = "yes"
	var errs := Scenery.validate(d).size()
	d.regions["qingshi_village"]["map"]["yards"] = true
	assert_eq(errs, 1)


func test_every_qingshi_house_has_a_prop() -> void:
	var r := _region()
	var y := Scenery.village_yards(r, _size(r))
	var lms := Scenery.landmark_rects(r)
	var lm_list: Array = r["map"]["landmarks"]
	for i in lm_list.size():
		if str(lm_list[i].get("kind", "")) != "house":
			continue
		var near := false
		for p: Dictionary in y["props"]:
			if (p["rect"] as Rect2).intersects(lms[i].grow(60.0)):
				near = true
		assert_true(near, "house %d has a prop" % i)


func test_place_buildings_have_footpaths_clear_of_landmarks() -> void:
	var r := _region()
	var y := Scenery.village_yards(r, _size(r))
	var lms := Scenery.landmark_rects(r)
	var lm_list: Array = r["map"]["landmarks"]
	var roads: Array[Rect2] = []
	for p in r["map"]["paths"]:
		roads.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	var houses := 0
	for l in lm_list:
		if str(l.get("kind", "")) == "house":
			houses += 1
	var door_has := {}
	for f: Dictionary in y["footpaths"]:
		door_has[f["door"]] = true
		for q in lms.size():
			if str(lm_list[q].get("kind", "")) in ["stream", "house"]:
				continue
			assert_false(lms[q].intersects(f["rect"]), "footpath crosses landmark %d" % q)
	var idx := houses
	for pl: Dictionary in r["places"]:
		if str(pl.get("type", "")) in Scenery.YARD_BUILDINGS:
			var pos: Array = pl["pos"]
			var door := Vector2(float(pos[0]), float(pos[1]) + float(pl["size"][1]) / 2.0)
			var br := Rect2(float(pos[0]) - float(pl["size"][0]) / 2.0, float(pos[1]) - float(pl["size"][1]) / 2.0, float(pl["size"][0]), float(pl["size"][1]))
			var touching := false
			for road in roads:
				if road.grow(1.0).has_point(door) or road.grow(12.0).intersects(br):
					touching = true
			assert_true(touching or door_has.has(idx), "%s has a footpath" % pl.get("id", "?"))
			idx += 1
