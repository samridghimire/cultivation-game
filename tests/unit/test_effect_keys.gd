extends TestCase
## EFF-001: every effects block in data/*.json uses known keys and ids.

const SKIP_FILES := ["clan_buildings.json"]
const BLOCK_KEYS := ["effects", "rewards", "reward"]


func _walk(node: Variant, where: String, d: GameData, errors: PackedStringArray, counter: Array) -> void:
	if node is Dictionary:
		for key: Variant in node:
			var child: Variant = node[key]
			if BLOCK_KEYS.has(String(key)) and child is Dictionary:
				counter[0] += 1
				errors.append_array(Effects.validate(d, child, "%s/%s" % [where, key]))
			_walk(child, "%s/%s" % [where, key], d, errors, counter)
	elif node is Array:
		for i in node.size():
			_walk(node[i], "%s[%d]" % [where, i], d, errors, counter)


func test_all_data_effects_valid() -> void:
	var d := data()
	var errors: PackedStringArray = []
	var counter := [0]
	for file_name in DirAccess.get_files_at("res://data"):
		if not file_name.ends_with(".json") or SKIP_FILES.has(file_name):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file_name))
		_walk(parsed, file_name, d, errors, counter)
	for dialogue_file in DirAccess.get_files_at("res://data/dialogue"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + dialogue_file))
		_walk(parsed, dialogue_file, d, errors, counter)
	assert_gt(counter[0], 20, "walked effect blocks")
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_validate_reports_problems() -> void:
	var d := data()
	assert_eq(Effects.validate(d, {"qi": 5, "set_flag": "x"}, "t").size(), 0)
	assert_eq(Effects.validate(d, {"bogus": 1}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"items": {"no_such_item": 1}}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"set_flag": ["a", "b"], "clear_flag": ["c"]}, "t").size(), 0)
	assert_eq(Effects.validate(d, {"set_flag": ""}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"clear_flag": ["a", ""]}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"heal_injury": "all"}, "t").size(), 0)
	assert_eq(Effects.validate(d, {"reputation": {"no_sect": 1}}, "t").size(), 1)


func test_apply_flag_arrays() -> void:
	var d := data()
	var c := new_character()
	var flags := {"old": true, "keep": true}
	Effects.apply(c, d, {"set_flag": ["a", "b"], "clear_flag": ["old"]}, flags)
	assert_true(flags.has("a") and flags.has("b"))
	assert_false(flags.has("old"))
	assert_true(flags.has("keep"))
	Effects.apply(c, d, {"set_flag": "solo"}, flags)
	assert_true(flags.has("solo"))
