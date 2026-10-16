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


func test_practice_days_trains_weakest_combat_technique() -> void:
	var d := data()
	var c := new_character()
	Techniques.learn(c, d, "iron_fist")
	Techniques.learn(c, d, "stone_skin")
	c.techniques["stone_skin"]["level"] = 2
	var before := Techniques.level(c, "stone_skin")
	var notes := Effects.apply(c, d, {"practice_days": 30}, {})
	assert_eq(notes.size(), 1)
	assert_true(String(notes[0]).begins_with("Your Iron Fist improves"), notes[0])
	assert_eq(Techniques.level(c, "stone_skin"), before)
	assert_gt(float(c.techniques["iron_fist"]["xp"]) + Techniques.level(c, "iron_fist") * 1000.0, 0.0)


func test_practice_days_falls_back_to_any_technique() -> void:
	var d := data()
	var c := new_character()
	Techniques.learn(c, d, "basic_breathing")
	var notes := Effects.apply(c, d, {"practice_days": 5}, {})
	assert_eq(notes.size(), 1)
	assert_true(String(notes[0]).begins_with("Your "), notes[0])


func test_practice_days_nothing_to_train() -> void:
	var d := data()
	var c := new_character()
	assert_eq(Effects.apply(c, d, {"practice_days": 5}, {}).size(), 0)
	Techniques.learn(c, d, "iron_fist")
	c.techniques["iron_fist"]["level"] = d.techniques["iron_fist"].max_level
	assert_eq(Effects.apply(c, d, {"practice_days": 5}, {}).size(), 0)


func test_practice_days_validation() -> void:
	var d := data()
	assert_eq(Effects.validate(d, {"practice_days": 7}, "t").size(), 0)
	assert_eq(Effects.validate(d, {"practice_days": 0}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"practice_days": 31}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"practice_days": "x"}, "t").size(), 1)


func test_practice_days_names_the_level_only_when_gained() -> void:
	var d := data()
	var c := new_character()
	Techniques.learn(c, d, "iron_fist")
	var notes := Effects.apply(c, d, {"practice_days": 1}, {})
	assert_eq(Array(notes), ["Your Iron Fist improves"])
	c.techniques["iron_fist"]["xp"] = Techniques.xp_to_next(c, d, "iron_fist") + float(c.techniques["iron_fist"]["xp"]) - 0.01
	notes = Effects.apply(c, d, {"practice_days": 1}, {})
	assert_true(String(notes[0]).ends_with("(level 2)"), notes[0])


func test_technique_training_encounters_exist() -> void:
	var d := GameData.load_from_dir()
	for id: String in ["village_old_soldier_stance", "forest_wolf_tracks_snow", "road_wandering_boxer", "azure_peak_stream_sparring"]:
		assert_true(d.encounters.has(id), id)
		var e: Dictionary = d.encounters[id]
		var trains: bool = e.get("effects", {}).has("practice_days")
		for ch: Dictionary in e.get("choices", []):
			if ch.get("effects", {}).has("practice_days"):
				trains = true
			# A fight choice trains only on a win: the practice sits in the foe's rewards.
			if d.enemies.get(String(ch.get("enemy", "")), {}).get("rewards", {}).has("practice_days"):
				trains = true
		assert_true(trains, id + " trains a technique")


## C-077 review: the wandering boxer's bout trains (and is marked beaten) only on a win.
func test_wandering_boxer_trains_only_on_a_win() -> void:
	var d := GameData.load_from_dir()
	var choice: Dictionary = d.encounters["road_wandering_boxer"]["choices"][0]
	assert_eq(choice.get("effects", {}), {}, "accepting the bout grants nothing before the fight")
	var rewards: Dictionary = d.enemies["wandering_boxer"]["rewards"]
	assert_eq(int(rewards.get("practice_days", 0)), 7)
	assert_eq(String(rewards.get("set_flag", "")), "beat_wandering_boxer")


func test_profession_xp_adds_experience_and_promotes() -> void:
	var d := data()
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	var notes := Effects.apply(c, d, {"profession_xp": {"alchemist": 3}}, {})
	assert_eq(Array(notes), ["+3 %s experience" % d.professions["alchemist"].name])
	assert_eq(Professions.xp_of(c, "alchemist"), 3.0)
	notes = Effects.apply(c, d, {"profession_xp": {"alchemist": 500}}, {})
	assert_true(String(notes[0]).contains("(now %s)" % Professions.rank_title(c, d, "alchemist")), notes[0])
	assert_gt(Professions.rank_of(c, "alchemist"), 0)


func test_profession_xp_skips_professions_not_taken() -> void:
	var d := data()
	var c := new_character()
	assert_eq(Effects.apply(c, d, {"profession_xp": {"alchemist": 50}}, {}).size(), 0)
	assert_false(c.professions.has("alchemist"))


func test_profession_xp_check_refuses_untaken_profession() -> void:
	var d := data()
	var c := new_character()
	var fx := {"profession_xp": {"alchemist": 5}}
	assert_eq(Effects.check(c, d, fx), "You have not taken up %s." % d.professions["alchemist"].name)
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	assert_eq(Effects.check(c, d, fx), "")
	# Some known: allowed, and only the known one is trained.
	var mixed := {"profession_xp": {"blacksmith": 5, "alchemist": 5}}
	assert_eq(Effects.check(c, d, mixed), "")
	Effects.apply(c, d, mixed, {})
	assert_false(c.professions.has("blacksmith"))


func test_profession_xp_validation() -> void:
	var d := data()
	assert_eq(Effects.validate(d, {"profession_xp": {"alchemist": 5}}, "t").size(), 0)
	assert_eq(Effects.validate(d, {"profession_xp": {"nope": 5}}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"profession_xp": {"alchemist": 0}}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"profession_xp": {"alchemist": 501}}, "t").size(), 1)
	assert_eq(Effects.validate(d, {"profession_xp": "x"}, "t").size(), 1)
