extends TestCase
## Review: no top-level list in data/*.json repeats an "id". Most tables load into id-keyed dictionaries, so a
## duplicate silently replaces the first entry (two workers both landed C-201's herb_hall_tithe).


func test_top_level_lists_have_unique_ids() -> void:
	var dir := DirAccess.open("res://data")
	assert_true(dir != null, "res://data opens")
	var offenders: PackedStringArray = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file_name))
		if not parsed is Dictionary:
			continue
		for key: String in parsed:
			if not parsed[key] is Array:
				continue
			var seen := {}
			for entry: Variant in parsed[key]:
				if not entry is Dictionary or not entry.has("id"):
					continue
				var id := String(entry["id"])
				if seen.has(id):
					offenders.append("%s %s: %s" % [file_name, key, id])
				seen[id] = true
	assert_eq(offenders, PackedStringArray(), "duplicate ids")
