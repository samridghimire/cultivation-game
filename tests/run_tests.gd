extends SceneTree
## Headless test runner. Usage (from the project root):
##   godot --headless --path . -s res://tests/run_tests.gd
## Or simply: tools/test.sh
## Runs every test_* method in tests/unit/test_*.gd. Exit code 1 on failure.
## Test methods may `await` (e.g. process frames so deferred UI focus lands).
## TEST_ONLY=<substring> runs only the test files whose name contains it;
## TEST_METHOD=<substring> further narrows to matching test methods.
## TEST_SEED_SALT=<text> changes every test's GameState.rng seed (hunting flaky tests).

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
	var timings: Array = []  # [ms, "file::method"]

	for file_name in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		if OS.get_environment("TEST_ONLY") != "" and not file_name.contains(OS.get_environment("TEST_ONLY")):
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
			if OS.get_environment("TEST_METHOD") != "" and not method_name.contains(OS.get_environment("TEST_METHOD")):
				continue
			instance.failures = PackedStringArray()
			# Each test starts from its own seed, so no test depends on how much
			# randomness the tests before it happened to use.
			root.get_node("GameState").rng.seed = hash(file_name + "::" + method_name + OS.get_environment("TEST_SEED_SALT"))
			var errors_before := errors.count
			var started := Time.get_ticks_msec()
			await instance.call(method_name)
			timings.append([Time.get_ticks_msec() - started, file_name + "::" + method_name])
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
	timings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total_ms := 0
	for t in timings:
		total_ms += t[0]
	print("Slowest tests (total %.1f s):" % (total_ms / 1000.0))
	for i in mini(15, timings.size()):
		print("  %6d ms  %s" % [timings[i][0], timings[i][1]])
	var per_file := {}
	for t in timings:
		var file_name: String = String(t[1]).get_slice("::", 0)
		per_file[file_name] = int(per_file.get(file_name, 0)) + int(t[0])
	var files_sorted: Array = per_file.keys()
	files_sorted.sort_custom(func(a: String, b: String) -> bool: return per_file[a] > per_file[b])
	print("Slowest files:")
	for i in mini(10, files_sorted.size()):
		print("  %6d ms  %s" % [per_file[files_sorted[i]], files_sorted[i]])
	print("%d passed, %d failed" % [passed, failed.size()])
	quit(1 if failed.size() > 0 else 0)
