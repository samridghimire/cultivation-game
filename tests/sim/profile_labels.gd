extends SceneTree
## PERF-019: what do the name labels cost per frame while the player walks across a busy region?
## Times World._process (walk lift, label fades, re-spread) over 300 frames of walking, per region.
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1280x800 \
##     -s res://tests/sim/profile_labels.gd [-- --region=fallen_star_market,qingshi_village --frames=300]
## Writes no saves. Budget: mean < 0.5 ms, worst frame < 4 ms.

var frames := 0
var started := false


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3 and not started:
		started = true
		_run()
	return false


## Mean, p95 and worst of the sample list (ms). Pure so a unit test can check it.
static func summarize(ms: Array[float]) -> Dictionary:
	if ms.is_empty():
		return {"mean": 0.0, "p95": 0.0, "worst": 0.0}
	var s := ms.duplicate()
	s.sort()
	var total := 0.0
	for v in s:
		total += v
	return {"mean": total / s.size(), "p95": s[mini(s.size() - 1, int(s.size() * 0.95))], "worst": s[s.size() - 1]}


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, rng, "male"))
	var only: Array[String] = ["fallen_star_market", "qingshi_village"]
	var n := 300
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			n = maxi(10, int(arg.substr(9)))
		elif arg.begins_with("--region="):
			only.clear()
			for id in arg.substr(9).split(",", false):
				only.append(id)
	print("%-24s %8s %8s %8s  (ms per frame of World._process, %d walking frames)" % ["region", "mean", "p95", "worst", n])
	for id in only:
		if not gs.data.regions.has(id):
			continue
		gs.current_region = id
		var w: Node = load("res://src/world/world.tscn").instantiate()
		root.add_child(w)
		for i in 5:
			await process_frame
		w.set_process(false)  # we call _process ourselves so each call is timed
		var p: Node2D = w.player
		var a: Vector2 = Vector2(80, w.map_size.y / 2.0)
		var b: Vector2 = Vector2(w.map_size.x - 80, w.map_size.y / 2.0)
		var samples: Array[float] = []
		for i in n:
			p.position = a.lerp(b, float(i) / float(n))
			await process_frame
			var t0 := Time.get_ticks_usec()
			w._process(1.0 / 60.0)
			samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		var parts := {"spread": [], "fade": [], "count": 0}
		var nodes: Array = w.get_children().filter(func(n: Node) -> bool: return n.has_method("camera_moved"))
		parts["count"] = nodes.size()
		var spreader: GDScript = load("res://src/world/interactables/interactable.gd")  # loaded late: autoloads must exist first
		var sp: Array[float] = []
		for i in 60:
			p.position = a.lerp(b, float(i) / 60.0)
			await process_frame
			var view: Rect2 = w.get_canvas_transform().affine_inverse() * w.get_viewport_rect()
			var t1 := Time.get_ticks_usec()
			var occ: Array[Rect2] = []
			spreader.spread_on_screen(nodes, view, occ, p.position)
			sp.append(float(Time.get_ticks_usec() - t1) / 1000.0)
		print("  %d nodes; spread_on_screen alone: %s" % [nodes.size(), summarize(sp)])
		var r := summarize(samples)
		print("%-24s %8.3f %8.3f %8.3f" % [id, r["mean"], r["p95"], r["worst"]])
		root.remove_child(w)
		w.free()
	quit()
