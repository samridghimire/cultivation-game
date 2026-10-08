extends TestCase
## REL-005: export_presets.cfg parses and has Windows + Linux x86_64 release presets that keep tests/tools/docs out of the build.


func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg parses")
	var out := {}
	for section: String in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			out[String(cfg.get_value(section, "name"))] = {
				"cfg": cfg, "section": section,
			}
	return out


func test_both_release_presets_exist() -> void:
	var presets := _presets()
	assert_true(presets.has("Windows Desktop"), "Windows preset")
	assert_true(presets.has("Linux"), "Linux preset")


func test_presets_exclude_dev_folders_and_target_x86_64() -> void:
	var presets := _presets()
	for pname: String in ["Windows Desktop", "Linux"]:
		if not presets.has(pname):
			continue
		var cfg: ConfigFile = presets[pname]["cfg"]
		var section: String = presets[pname]["section"]
		var exclude := String(cfg.get_value(section, "exclude_filter"))
		for folder in ["tests/*", "tools/*", "docs/*"]:
			assert_true(exclude.contains(folder), "%s excludes %s" % [pname, folder])
		assert_eq(String(cfg.get_value(section + ".options", "binary_format/architecture")), "x86_64", pname)
		assert_true(String(cfg.get_value(section, "export_path")).begins_with("build/"), pname + " exports to build/")
