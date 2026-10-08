extends TestCase
## QA-012: cross-reference check over every data file. Walks the raw JSON and
## fails on any id that names nothing: items, enemies, techniques, recipes,
## injuries, realms, Dao insights, bloodlines, professions, regions, sects,
## dialogues, merchant stock tags with no items, and flags that are read
## (requires/blocked_by/hidden_by/not_flag) but never set by data or code.

## Flags the code builds from a prefix plus an id (GameState sets "sect_call_<sect id>" after a sect clash).
const CODE_FLAG_PREFIXES := ["sect_call_"]
const FLAG_READ_KEYS := ["requires_flag", "blocked_by_flag", "hidden_by_flag", "not_flag"]

var _errors: PackedStringArray = []
var _flags_set := {}
var _flags_read: Array = []  # [[where, flag]]
var _single: Dictionary = {}  # key -> {id: true}
var _lists: Dictionary = {}
var _dict_keys: Dictionary = {}


func _ids(entries: Array) -> Dictionary:
	var out := {}
	for e: Dictionary in entries:
		out[String(e["id"])] = true
	return out


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _setup() -> Dictionary:
	var d := data()
	var items := {}
	for id: String in d.items:
		items[id] = true
	var techniques := {}
	for id: String in d.techniques:
		techniques[id] = true
	var realms := {}
	for r: RealmDef in d.realms:
		realms[r.id] = true
	var injuries := {"all": true}
	for id: String in d.injuries:
		injuries[id] = true
	var tags := {}
	for item: Dictionary in d.items.values():
		for tag in item.get("tags", []):
			tags[String(tag)] = true
	var bloodlines := {"": true}
	for id: String in d.bloodlines:
		bloodlines[id] = true
	var dialogues := {}
	for id: String in d.dialogues:
		dialogues[id] = true
	_single = {
		"item": items, "item_id": items, "manual_item": items,
		"enemy": _keys(d.enemies), "guardian": _keys(d.enemies), "trial": _keys(d.enemies),
		"learn_technique": techniques, "not_knows_technique": techniques,
		"learn_recipe": _keys(d.recipes), "heal_injury": injuries, "expulsion_injury": injuries,
		"realm": realms, "min_realm": realms, "max_realm": realms, "awaken_realm": realms,
		"dao_insight": _keys(d.dao_insights), "bloodline": bloodlines,
		"profession": _keys(d.professions), "region": _keys(d.regions), "to": _keys(d.regions),
		"start_region": _keys(d.regions), "dialogue": dialogues,
	}
	_lists = {"favored_professions": _keys(d.professions), "sects": _keys(d.sects), "stock_tags": tags}
	_dict_keys = {"items": items, "ingredients": items}
	var files := {}
	for name in DirAccess.get_files_at("res://data"):
		if name.ends_with(".json"):
			files[name] = _read("res://data".path_join(name))
	for name in DirAccess.get_files_at("res://data/dialogue"):
		if name.ends_with(".json"):
			files["dialogue/" + name] = _read("res://data/dialogue".path_join(name))
	return files


func _keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = true
	return out


func _walk(value: Variant, where: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var k := String(key)
			var child: Variant = value[key]
			var here := "%s.%s" % [where, k]
			if _single.has(k) and child is String and child != "" and not _single[k].has(child):
				_errors.append("%s: unknown %s '%s'" % [here, k, child])
			if _lists.has(k) and child is Array:
				for entry: Variant in child:
					if entry is String and not _lists[k].has(entry):
						_errors.append("%s: unknown %s entry '%s'" % [here, k, entry])
			if _dict_keys.has(k) and child is Dictionary:
				for id: Variant in child:
					if not _dict_keys[k].has(String(id)):
						_errors.append("%s: unknown item '%s'" % [here, id])
			if k == "set_flag" and child is String:
				_flags_set[child] = true
			if FLAG_READ_KEYS.has(k) and child is String:
				_flags_read.append([here, child])
			_walk(child, here)
	elif value is Array:
		for i in (value as Array).size():
			_walk(value[i], "%s[%d]" % [where, i])


## Flags the code sets itself (string literals in src/), e.g. GameState.INTRO_EVENT_FLAG.
func _code_mentions(flag: String) -> bool:
	for prefix in CODE_FLAG_PREFIXES:
		if flag.begins_with(prefix) and _source_text().contains('"%s"' % prefix):
			return true
	return _source_text().contains('"%s"' % flag)


var _source_cache := ""


func _source_text() -> String:
	if _source_cache == "":
		var dirs := ["res://src"]
		while not dirs.is_empty():
			var dir: String = dirs.pop_back()
			for sub in DirAccess.get_directories_at(dir):
				dirs.append(dir.path_join(sub))
			for name in DirAccess.get_files_at(dir):
				if name.ends_with(".gd"):
					_source_cache += FileAccess.get_file_as_string(dir.path_join(name))
	return _source_cache


func test_every_reference_names_something() -> void:
	var files := _setup()
	for name: String in files:
		_walk(files[name], name)
	for entry: Array in _flags_read:
		if not _flags_set.has(entry[1]) and not _code_mentions(entry[1]):
			_errors.append("%s: flag '%s' is never set" % [entry[0], entry[1]])
	assert_gt(_flags_read.size(), 10, "the walk should find flag checks")
	for error in _errors:
		_fail(error)


func test_checker_catches_broken_references() -> void:
	_setup()
	_errors = PackedStringArray()
	_walk({"enemy": "nobody", "items": {"no_such_item": 1}, "stock_tags": ["no_such_tag"], "min_realm": "qi_refining"}, "fake")
	assert_eq(_errors.size(), 3, str(_errors))
