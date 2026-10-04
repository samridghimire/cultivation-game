extends SceneTree
## Screenshots of every region's world scene, for eyeballing placeholder art and
## layout without a display. Needs a GPU-less X server:
## xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 \
##     --resolution 1280x800 -s res://tests/sim/screenshot_regions.gd
## PNGs go to user://screenshots/<region>.png (OUT_DIR).

const OUT_DIR := "user://screenshots"
var regions: Array = []
var i := 0
var frames := 0
var world: Node = null

var started := false

func _start() -> void:
	started = true
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Shot", gs.data, RandomNumberGenerator.new()))
	gs.pending_event = ""
	regions = gs.data.regions.keys()
	_load()

func _load() -> void:
	var gs: Node = root.get_node("GameState")
	gs.current_region = regions[i]
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
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, regions[i]])
		print("saved %s" % ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, regions[i]]))
		i += 1
		if i >= regions.size():
			return true
		_load()
	return false
