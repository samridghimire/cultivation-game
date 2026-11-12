extends TestCase
## ARCH-001: src/core stands alone. No script under src/core may use a class declared in src/world or src/ui.

## file (relative to src/core) -> task id, for known leaks too big to fix in place.
const ALLOWED := {}


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		out.append_array(_gd_files(dir_path.path_join(sub)))
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out


func _class_names(dir_path: String) -> Array[String]:
	var names: Array[String] = []
	var rx := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in _gd_files(dir_path):
		var m := rx.search(FileAccess.get_file_as_string(path))
		if m != null:
			names.append(m.get_string(1))
	return names


func test_core_does_not_use_world_or_ui_classes() -> void:
	var names: Array[String] = _class_names("res://src/world")
	names.append_array(_class_names("res://src/ui"))
	assert_gt(names.size(), 20, "found the world/ui class names")
	var rx := RegEx.create_from_string("\\b(" + "|".join(names) + ")\\b")
	var leaks: Array[String] = []
	for path in _gd_files("res://src/core"):
		if ALLOWED.has(path.trim_prefix("res://src/core/")):
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.split("#")[0]
			if code.contains("\"") or code.contains("'"):
				# Strip string literals so prose in messages is not code.
				code = RegEx.create_from_string("\"[^\"]*\"|'[^']*'").sub(code, "", true)
			var m := rx.search(code)
			if m != null:
				leaks.append("%s:%d uses %s" % [path, n, m.get_string(1)])
	assert_true(leaks.is_empty(), "core must not use world/ui classes: " + "; ".join(leaks))
