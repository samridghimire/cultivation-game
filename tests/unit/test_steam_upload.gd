extends TestCase
## REL-011: Steam depot templates parse as key/values and name both depots; the upload script refuses to run without its env vars.


## Minimal VDF reader: returns nested Dictionaries.
func _parse(text: String) -> Dictionary:
	var stack: Array[Dictionary] = [{}]
	var pending := ""
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line == "{":
			var child := {}
			stack.back()[pending] = child
			stack.push_back(child)
		elif line == "}":
			stack.pop_back()
		elif line != "":
			var parts := line.split("\"", false)
			var toks: Array[String] = []
			for p: String in parts:
				if p.strip_edges() != "":
					toks.append(p)
			if toks.size() == 1:
				pending = toks[0]
			elif toks.size() >= 2:
				stack.back()[toks[0]] = toks[1]
	return stack[0]


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, path + " exists")
	return f.get_as_text() if f != null else ""


func test_app_build_names_both_depots() -> void:
	var d := _parse(_read("res://tools/steam/app_build.vdf"))
	assert_true(d.has("AppBuild"), "AppBuild root")
	var app: Dictionary = d.get("AppBuild", {})
	assert_eq(app.get("AppID"), "${STEAM_APP_ID}", "app id comes from env")
	var depots: Dictionary = app.get("Depots", {})
	assert_true(depots.has("${STEAM_DEPOT_WINDOWS}"), "windows depot")
	assert_true(depots.has("${STEAM_DEPOT_LINUX}"), "linux depot")
	for file: String in depots.values():
		assert_true(FileAccess.file_exists("res://tools/steam/" + file), file + " exists")


func test_depot_builds_point_at_platform_folders() -> void:
	var win: Dictionary = _parse(_read("res://tools/steam/depot_build_windows.vdf")).get("DepotBuild", {})
	var lin: Dictionary = _parse(_read("res://tools/steam/depot_build_linux.vdf")).get("DepotBuild", {})
	assert_eq(win.get("DepotID"), "${STEAM_DEPOT_WINDOWS}", "windows depot id")
	assert_eq(lin.get("DepotID"), "${STEAM_DEPOT_LINUX}", "linux depot id")
	assert_eq((win.get("FileMapping", {}) as Dictionary).get("LocalPath"), "windows/*", "windows path")
	assert_eq((lin.get("FileMapping", {}) as Dictionary).get("LocalPath"), "linux/*", "linux path")


func test_upload_script_refuses_without_env() -> void:
	var script := ProjectSettings.globalize_path("res://tools/steam_upload.sh")
	var out: Array = []
	var code := OS.execute("env", ["-u", "STEAM_APP_ID", "-u", "STEAM_USER", "-u", "STEAM_DEPOT_WINDOWS", "-u", "STEAM_DEPOT_LINUX", "bash", script], out, true)
	assert_true(code != 0, "exits non-zero")
	assert_true(String(out[0]).contains("Refusing to upload"), "explains refusal")
	code = OS.execute("env", ["STEAM_APP_ID=0000000", "STEAM_DEPOT_WINDOWS=1", "STEAM_DEPOT_LINUX=2", "STEAM_USER=x", "bash", script], out, true)
	assert_true(code != 0, "placeholder id refused")
