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
