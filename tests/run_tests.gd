extends SceneTree
## Headless test runner. Usage (from the project root):
##   godot --headless --path . -s res://tests/run_tests.gd
## Or simply: tools/test.sh
## Runs every test_* method in tests/unit/test_*.gd. Exit code 1 on failure.
## Test methods may `await` (e.g. process frames so deferred UI focus lands).

const TEST_DIR := "res://tests/unit"


class ErrorCounter extends Logger:
	var count := 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	# Wait one frame so autoloads (GameState etc.) have run _ready().
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var passed := 0
	var failed: PackedStringArray = []

	for file_name in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var path := TEST_DIR.path_join(file_name)
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to load (parse error?)" % path)
			continue
		var instance: Object = script.new()
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			instance.failures = PackedStringArray()
			var errors_before := errors.count
			await instance.call(method_name)
			if errors.count > errors_before:
				instance.failures.append("engine logged %d error(s) (see output above)" % (errors.count - errors_before))
			if instance.failures.is_empty():
				passed += 1
			else:
				for f in instance.failures:
					failed.append("%s::%s: %s" % [file_name, method_name, f])

	print("")
	for f in failed:
		print("FAIL  " + f)
	print("%d passed, %d failed" % [passed, failed.size()])
	quit(1 if failed.size() > 0 else 0)
