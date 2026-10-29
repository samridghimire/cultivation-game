extends TestCase
## QA-176: asset licence guard. Every shipped file under assets/ needs a row in
## docs/ASSETS.md, every sprite names a listed pack and lives in that pack's
## folder, every pack folder carries a LICENSE file, and only CC0 / CC-BY
## licences are allowed (no NC / ND). The checks take plain lists so they are
## testable without files.

const ALLOWED_LICENSES := ["CC0", "CC-BY 3.0", "CC-BY 4.0"]
const SKIP_SUFFIXES := [".import", ".uid"]


## Repo paths ("assets/...") from the first column of the ASSETS.md table rows.
func asset_doc_paths(doc: String) -> Array[String]:
	var out: Array[String] = []
	for line in doc.split("\n"):
		var l := line.strip_edges()
		if not l.begins_with("|"):
			continue
		var first := l.split("|")[1].strip_edges().trim_prefix("`").trim_suffix("`")
		if first.begins_with("assets/"):
			out.append(first)
	return out


func _is_licence_name(file_name: String) -> bool:
	var n := file_name.to_lower()
	return n.begins_with("license") or n.begins_with("licence")


func _is_asset_file(path: String) -> bool:
	for suffix: String in SKIP_SUFFIXES:
		if path.ends_with(suffix):
			return false
	return not _is_licence_name(path.get_file()) and not path.get_file().to_lower().begins_with("readme")


## Files (repo-relative paths) that have no row in the doc.
func undocumented_files(files: Array[String], documented: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for f in files:
		if _is_asset_file(f) and not documented.has(f):
			out.append(f)
	return out


## Problems with sprites (key -> def) against pack ids; empty when fine.
func sprite_problems(sprites: Dictionary, pack_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for key: String in sprites:
		var def: Dictionary = sprites[key]
		var pack := str(def.get("pack", ""))
		if not pack_ids.has(pack):
			out.append("%s: pack '%s' is not listed" % [key, pack])
		elif not str(def.get("path", "")).begins_with("res://assets/third_party/%s/" % pack):
			out.append("%s: path is not under pack folder %s" % [key, pack])
	return out


## Pack directories under assets/third_party that lack a LICENSE file.
func dirs_without_licence(files: Array[String]) -> Array[String]:
	var dirs: Array[String] = []
	var licensed: Array[String] = []
	var prefix := "assets/third_party/"
	for f in files:
		if not f.begins_with(prefix):
			continue
		var dir := f.trim_prefix(prefix).get_slice("/", 0)
		if not dirs.has(dir):
			dirs.append(dir)
		if f.trim_prefix(prefix + dir + "/").find("/") == -1 and _is_licence_name(f.get_file()) and not licensed.has(dir):
			licensed.append(dir)
	return dirs.filter(func(d: String) -> bool: return not licensed.has(d))


func bad_licences(packs: Array) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in packs:
		var lic := str(p.get("license", ""))
		if not ALLOWED_LICENSES.has(lic) or lic.contains("NC") or lic.contains("ND"):
			out.append("%s: '%s'" % [p.get("id", "?"), lic])
	return out


func _list_files(dir_path: String, rel: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_list_files(dir_path.path_join(sub), rel.path_join(sub), out)
	for f in DirAccess.get_files_at(dir_path):
		out.append(rel.path_join(f))


func test_helpers_pass_and_fail_each_rule() -> void:
	var files: Array[String] = ["assets/third_party/kenney/LICENSE.txt", "assets/third_party/kenney/a.png", "assets/third_party/kenney/a.png.import"]
	assert_eq(undocumented_files(files, ["assets/third_party/kenney/a.png"]).size(), 0)
	assert_eq(undocumented_files(files, []), ["assets/third_party/kenney/a.png"])
	var ids: Array[String] = ["kenney"]
	var ok := {"p": {"pack": "kenney", "path": "res://assets/third_party/kenney/a.png"}}
	assert_eq(sprite_problems(ok, ids).size(), 0)
	assert_eq(sprite_problems({"p": {"pack": "other", "path": "res://assets/third_party/other/a.png"}}, ids).size(), 1)
	assert_eq(sprite_problems({"p": {"pack": "kenney", "path": "res://assets/third_party/zzz/a.png"}}, ids).size(), 1)
	assert_eq(dirs_without_licence(files).size(), 0)
	assert_eq(dirs_without_licence(["assets/third_party/x/a.png", "assets/third_party/x/sub/LICENSE"]), ["x"])
	assert_eq(dirs_without_licence(["assets/third_party/x/a.png", "assets/third_party/x/Licence.md"]).size(), 0)
	assert_eq(bad_licences([{"id": "a", "license": "CC0"}, {"id": "b", "license": "CC-BY 4.0"}]).size(), 0)
	assert_eq(bad_licences([{"id": "c", "license": "CC-BY-NC 4.0"}, {"id": "d", "license": "CC-BY-ND 4.0"}, {"id": "e", "license": "MIT"}]).size(), 3)
	var doc := "| file | pack |\n|---|---|\n| assets/third_party/k/a.png | k |\n| `assets/third_party/k/b.png` | k |\n"
	assert_eq(asset_doc_paths(doc), ["assets/third_party/k/a.png", "assets/third_party/k/b.png"])


func test_shipped_assets_are_licensed_and_documented() -> void:
	var files: Array[String] = []
	if DirAccess.dir_exists_absolute("res://assets"):
		_list_files("res://assets", "assets", files)
	var documented := asset_doc_paths(FileAccess.get_file_as_string("res://docs/ASSETS.md"))
	assert_eq(undocumented_files(files, documented), [] as Array[String], "every asset file has a docs/ASSETS.md row")
	assert_eq(dirs_without_licence(files), [] as Array[String], "every pack folder has a LICENSE file")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	assert_true(parsed is Dictionary, "sprites.json parses")
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var packs: Array = data.get("packs", [])
	var ids: Array[String] = []
	for p: Dictionary in packs:
		ids.append(str(p.get("id", "")))
	assert_eq(sprite_problems(data.get("sprites", {}), ids), [] as Array[String], "sprites use listed packs and folders")
	assert_eq(bad_licences(packs), [] as Array[String], "pack licences are CC0 / CC-BY")
