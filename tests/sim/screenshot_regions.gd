extends SceneTree
## Screenshots of every region's world scene, for eyeballing placeholder art and
## layout without a display. Needs a GPU-less X server:
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_regions.gd
## PNGs go to user://screenshots/<region>.png (OUT_DIR). Add `-- --season=Winter` for
## one season (files become <region>_<season>.png) or `-- --season=all` for all four.

const OUT_DIR := "user://screenshots"
var regions: Array = []
var i := 0
var frames := 0
var world: Node = null

var started := false
var seasons: Array = []
var si := 0

func _start() -> void:
	started = true
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Shot", gs.data, RandomNumberGenerator.new()))
	gs.pending_event = ""
	regions = gs.data.regions.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--season="):
			var v := arg.substr(9).capitalize()
			seasons = ["Spring", "Summer", "Autumn", "Winter"] if v == "All" else [v]
	# A spouse and children in every region, so the Family Home (FAM-011) shows.
	var rng := RandomNumberGenerator.new()
	for region_id: String in regions:
		var spouse := Npcs.spawn(gs.npcs, gs.data, rng, {"gender": "female", "region": region_id, "age_years": 28})
		Family.marry(gs.player, spouse, "wife" if gs.player.spouses.is_empty() else "concubine")
		for k in 3:
			var kid := Npcs.spawn(gs.npcs, gs.data, rng, {"age_years": 4 + k * 3, "region": region_id})
			gs.player.children.append(kid.id)
	_load()

func _load() -> void:
	var gs: Node = root.get_node("GameState")
	gs.current_region = regions[i]
	if not seasons.is_empty():
		# Middle of the season's second month: season index * 3 months + 1.
		var idx: int = ["Spring", "Summer", "Autumn", "Winter"].find(seasons[si])
		root.get_node("GameClock").total_days = (idx * 3 + 1) * Calendar.DAYS_PER_MONTH + 15
	if world != null:
		world.queue_free()
	world = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	frames = 0

func _process(_d: float) -> bool:
	if not started:
		_start()
		return false
	frames += 1
	if frames == 10:
		var cam: Camera2D = world.get_node("Player").get_node_or_null("Camera2D")
		if cam != null:
			cam.enabled = false
		var c := Camera2D.new()
		world.add_child(c)
		c.position = Vector2(800, 500)
		c.zoom = Vector2(0.8, 0.8)
		c.make_current()
	if frames == 16:
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var fname: String = regions[i] if seasons.is_empty() else "%s_%s" % [regions[i], seasons[si]]
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, fname])
		print("saved %s" % ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, fname]))
		i += 1
		if i >= regions.size():
			i = 0
			si += 1
			if si >= seasons.size():
				return true
		_load()
	return false
