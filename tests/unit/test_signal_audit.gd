extends TestCase
## QA-201: nodes in src/world must not connect lambdas to autoload signals
## (Godot never disconnects those when the node is freed, so later emissions
## call into a dead node). Use bound methods instead.

const AUTOLOADS := ["EventBus", "GameState", "GameClock", "Settings", "SaveManager", "InputConfig"]


func _scan(dir: String, hits: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in lines.size():
				var l := lines[i]
				if ".connect(func" in l:
					for a in AUTOLOADS:
						if l.strip_edges().begins_with(a + "."):
							hits.append("%s/%s:%d" % [dir, f, i + 1])
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, hits)


func test_world_has_no_lambdas_on_autoload_signals() -> void:
	var hits := PackedStringArray()
	_scan("res://src/world", hits)
	assert_eq(hits.size(), 0, "lambda connected to autoload signal: " + ", ".join(hits))


func test_ui_has_no_lambdas_on_autoload_signals() -> void:
	var hits := PackedStringArray()
	_scan("res://src/ui", hits)
	assert_eq(hits.size(), 0, "lambda connected to autoload signal: " + ", ".join(hits))


func test_hud_freed_twice_leaves_no_dead_bus_connections() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	for i in 2:
		var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
		tree.root.add_child(hud)
		await tree.process_frame
		hud.free()
	await tree.process_frame
	for sig in [EventBus.message_posted, EventBus.player_changed, EventBus.region_changed, EventBus.player_respawned, EventBus.dialogue_ended, EventBus.session_started, GameClock.days_advanced]:
		for c in sig.get_connections():
			assert_true(is_instance_valid(c["callable"].get_object()), "dead target on bus signal")


func test_freed_npc_leaves_no_connections() -> void:
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	var before := EventBus.ui_modal_changed.get_connections().size()
	npc._ready() if npc.has_method("_ready") else null
	var after := EventBus.ui_modal_changed.get_connections()
	for c in after:
		assert_true(is_instance_valid(c["callable"].get_object()), "dead target on ui_modal_changed")
	npc.free()
	for c in EventBus.ui_modal_changed.get_connections():
		assert_true(is_instance_valid(c["callable"].get_object()), "dead target after free")
	assert_true(before >= 0)
