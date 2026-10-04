extends TestCase
## QA-003: committed save fixtures keep loading. tests/fixtures/saves/ holds a
## save from the oldest supported SAVE_VERSION format (the F-000 foundation:
## no metadata, NPCs, family or artifact fields) and one from the current
## format. Add a fixture whenever SAVE_VERSION is bumped (see CLAUDE.md).

const FIXTURE_DIR := "res://tests/fixtures/saves"
const OLDEST := "v1_oldest"
const CURRENT := "v1_current"
const SLOT_PREFIX := "_fixture_"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _save_manager() -> Node:
	return _root().get_node("SaveManager")


func _game_state() -> Node:
	return _root().get_node("GameState")


func _fixture(fixture_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DIR.path_join(fixture_name + ".json")))
	assert_true(parsed is Dictionary, "fixture %s parses" % fixture_name)
	return parsed if parsed is Dictionary else {}


## Copies a fixture into the save directory and loads it like a player would.
func _load(fixture_name: String) -> bool:
	var sm := _save_manager()
	var slot := SLOT_PREFIX + fixture_name
	DirAccess.make_dir_recursive_absolute(sm.SAVE_DIR)
	var file := FileAccess.open(sm.save_path(slot), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURE_DIR.path_join(fixture_name + ".json")))
	file.close()
	var ok: bool = sm.load_game(slot)
	sm.delete_save(slot)
	return ok


func test_fixtures_cover_supported_versions() -> void:
	var sm := _save_manager()
	assert_eq(int(_fixture(OLDEST).get("version", 0)), 1, "oldest supported version")
	assert_eq(int(_fixture(CURRENT).get("version", 0)), sm.SAVE_VERSION, "add a fixture when bumping SAVE_VERSION")


## Every CharacterData field missing from an old save loads as its default.
func test_missing_character_fields_get_defaults() -> void:
	var defaults := CharacterData.new().to_dict()
	for fixture_name in [OLDEST, CURRENT]:
		var saved: Dictionary = _fixture(fixture_name)["game"]["player"]
		var restored := CharacterData.from_dict(saved).to_dict()
		assert_eq(restored.keys().size(), defaults.keys().size(), "%s: same fields as a new character" % fixture_name)
		for key in defaults:
			if not saved.has(key):
				assert_eq(restored[key], defaults[key], "%s: default for missing '%s'" % [fixture_name, key])


## No field stored in a fixture is silently dropped when loading (renamed or
## removed fields need a migration in SaveManager._migrate).
func test_saved_character_fields_are_kept() -> void:
	for fixture_name in [OLDEST, CURRENT]:
		var saved: Dictionary = _fixture(fixture_name)["game"]["player"]
		var restored := CharacterData.from_dict(saved).to_dict()
		for key in saved:
			assert_true(restored.has(key), "%s: field '%s' still loads" % [fixture_name, key])


func test_oldest_save_loads_with_sane_defaults() -> void:
	var gs := _game_state()
	var meta: Dictionary = _save_manager()._meta_from_game(_fixture(OLDEST)["game"])
	assert_eq(meta["name"], "Old Lin", "metadata is rebuilt for saves without a meta block")
	assert_true(_load(OLDEST))
	var p: CharacterData = gs.player
	assert_eq(p.name, "Old Lin")
	assert_eq(p.realm_index, 1)
	assert_eq(typeof(p.stage), TYPE_INT)
	assert_eq(p.item_count("spirit_stone"), 25)
	assert_eq(p.sect["id"], "azure_cloud_sect")
	assert_eq(p.gender, "", "unknown gender until the player picks one")
	assert_true(p.alive)
	assert_gt(p.artifact_lives, 0, "the Creation Artifact is initialised")
	assert_true(p.equipment.is_empty() and p.injuries.is_empty() and p.pregnancy.is_empty())
	assert_gt(p.known_recipes.size(), 0, "recipes granted for the saved alchemist rank")
	for npc_id in gs.data.npcs:
		assert_true(gs.npcs.has(npc_id), "named NPC %s created" % npc_id)
	assert_gt(gs.npcs.size(), gs.data.npcs.size(), "eligible NPCs spawned for courtship")
	assert_eq(gs.current_region, "qingshi_village")
	assert_true(bool(gs.world_flags.get("villager_dead", false)))
	assert_eq(_root().get_node("GameClock").total_days, 400)
	# The game keeps running on the loaded state.
	gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(_root().get_node("GameClock").total_days, 400 + Calendar.DAYS_PER_MONTH)


func test_current_save_loads_and_round_trips() -> void:
	var gs := _game_state()
	assert_true(_load(CURRENT))
	var fixture: Dictionary = _fixture(CURRENT)["game"]
	assert_eq(gs.player.name, String(fixture["player"]["name"]))
	assert_eq(gs.player.equipment.get("weapon", ""), "iron_sword")
	assert_eq(int(gs.npc_favor.get("gen_10", 0)), 25)
	assert_true(gs.npcs.has("gen_10"))
	var first: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(first)))
	assert_eq(gs.player.to_dict(), first["player"], "save -> load -> save is stable")
	assert_eq(gs.npcs.size(), (first["npcs"] as Dictionary).size())
