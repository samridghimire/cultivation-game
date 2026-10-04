extends TestCase
## QA-015: interactable option fuzz. For several kinds of character, builds
## every region's world scene, invokes every enabled menu option of every
## interactable (following sub-menus such as gifts or hostile acts) and checks
## that no engine error is logged, time never runs backwards and the player
## state stays valid. Travel options are skipped while the world is loaded
## (they reload the scene) and exercised afterwards through GameState.travel.
## FUZZ_LOG=1 prints every option invoked and every message posted.

## Options invoked per interactable, so a long list cannot stall the run.
const MAX_CALLS_PER_NODE := 14
## Long actions (a year of closed-door cultivation) are covered elsewhere and slow the run.
const SKIP_PREFIXES := ["Travel to ", "Closed-door cultivation"]

var _last_day := 0
var _calls := 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _gs() -> Node:
	return _tree().root.get_node("GameState")


func _clock() -> Node:
	return _tree().root.get_node("GameClock")


## A fresh session for `kind`: "mortal", "disciple" (righteous Qi Refining sect
## member with money and goods) or "demonic" (Foundation, Blood Lotus).
func _start(kind: String) -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Fuzz %s" % kind, gs.data, seeded_rng(hash(kind)), "female" if kind == "disciple" else "male")
	c.spiritual_roots = {"fire": 70, "wood": 50}
	gs.start_session(c)
	gs.rng.seed = hash(kind) + 1
	gs.pending_event = ""
	if kind == "mortal":
		return c
	c.add_item("spirit_stone", 20000)
	for item_id: String in gs.data.items:
		if item_id != "spirit_stone" and int(gs.data.items[item_id].get("price", 0)) > 0:
			c.add_item(item_id, 2)
	Professions.add_xp(c, gs.data, "alchemist", 500.0)
	Techniques.learn(c, gs.data, "iron_fist")
	if kind == "disciple":
		c.realm_index = gs.data.realm_index_of("qi_refining")
		c.stage = 6
		c.alignment = 300
		gs.join_sect("azure_cloud_sect")
	else:
		c.realm_index = gs.data.realm_index_of("foundation_establishment")
		c.stage = 1
		c.alignment = -500
		gs.join_sect("blood_lotus_sect")
	return c


func _check_state(context: String) -> void:
	var gs := _gs()
	var c: CharacterData = gs.player
	var day: int = _clock().total_days
	assert_true(day >= _last_day, "%s: time ran backwards (%d -> %d)" % [context, _last_day, day])
	_last_day = day
	for item_id: String in c.inventory:
		assert_gt(c.item_count(item_id), 0, "%s: %s count %d" % [context, item_id, c.item_count(item_id)])
		assert_true(gs.data.items.has(item_id), "%s: unknown item '%s' in inventory" % [context, item_id])
	for item_id: String in c.abode_storage:
		assert_gt(int(c.abode_storage[item_id]), 0, "%s: abode %s" % [context, item_id])
	for item_id: String in c.artifact_storage:
		assert_gt(int(c.artifact_storage[item_id]), 0, "%s: artifact storage %s" % [context, item_id])
	assert_true(c.qi >= 0.0, "%s: qi %f" % [context, c.qi])
	assert_true(c.realm_index >= 0 and c.realm_index < gs.data.realms.size(), "%s: realm %d" % [context, c.realm_index])
	assert_true(c.stage >= 0 and c.stage < gs.data.realms[c.realm_index].stage_count(), "%s: stage %d" % [context, c.stage])
	assert_true(c.alignment >= gs.data.alignment_min and c.alignment <= gs.data.alignment_max, "%s: alignment %d" % [context, c.alignment])
	for injury_id: String in c.injuries:
		assert_gt(int(c.injuries[injury_id]), 0, "%s: injury %s" % [context, injury_id])
	if not c.sect.is_empty():
		var def: SectDef = gs.data.sects.get(String(c.sect["id"]))
		assert_true(def != null, "%s: unknown sect %s" % [context, c.sect["id"]])
		if def != null:
			assert_true(int(c.sect["rank"]) >= 0 and int(c.sect["rank"]) < def.ranks.size(), "%s: sect rank %d" % [context, c.sect["rank"]])
	var stats := Combat.stats(c, gs.data)
	assert_gt(int(stats["max_hp"]), 0, context)
	if gs.clan != null:
		assert_true(gs.clan.treasury >= 0, "%s: clan treasury %d" % [context, gs.clan.treasury])


## Calls every enabled option of `node`, re-reading the menu after each call
## since actions open sub-menus or change what is offered.
func _fuzz_node(node: Interactable, region_id: String) -> void:
	var done := {}
	var calls := 0
	while calls < MAX_CALLS_PER_NODE:
		if not is_instance_valid(node) or not _gs().has_session() or not _gs().player.alive:
			return
		var pick: Dictionary = {}
		for option: Dictionary in node.menu_options():
			var label := String(option.get("label", ""))
			if option.get("disabled", false) or done.has(label) or SKIP_PREFIXES.any(func(p: String) -> bool: return label.begins_with(p)):
				continue
			var action: Callable = option.get("action", Callable())
			if not action.is_valid():
				continue
			pick = option
			break
		if pick.is_empty():
			return
		var label := String(pick["label"])
		done[label] = true
		calls += 1
		_calls += 1
		(pick["action"] as Callable).call()
		if _gs().in_dialogue():
			_gs().end_dialogue()
		if _gs().pending_encounter != "":
			_gs().dismiss_encounter()
		if not _gs().pending_respawn.is_empty():
			_gs().choose_respawn_anchor(String(_gs().pending_respawn.get("anchor_id", "")))
		_check_state("%s / %s / %s" % [region_id, node.display_name, label])
		if OS.get_environment("FUZZ_LOG") != "":
			print("  ", region_id, " | ", node.display_name, " | ", label)


func _fuzz_region(region_id: String) -> void:
	var gs := _gs()
	gs.current_region = region_id
	gs.spawn_anchor = ""
	var world: Node = load("res://src/world/world.tscn").instantiate()
	_tree().root.add_child(world)
	await _tree().process_frame
	for node in world.get_children():
		if node is Interactable and node.is_available():
			_fuzz_node(node, region_id)
		if not gs.player.alive:
			break
	world.queue_free()
	await _tree().process_frame
	# The world may have moved the player (an artifact respawn); travel is the
	# only way out of a region, so exercise every route without a world loaded.
	for route in Exploration.routes(gs.player, gs.data, gs.current_region):
		if route["ok"]:
			gs.travel(String(route["to"]))
			_check_state("travel to %s" % route["to"])
			break


func _fuzz_all_regions(kind: String) -> void:
	if OS.get_environment("FUZZ_LOG") != "" and not _tree().root.get_node("EventBus").message_posted.is_connected(_log_message):
		_tree().root.get_node("EventBus").message_posted.connect(_log_message)
	_start(kind)
	_last_day = _clock().total_days
	var ids: Array = _gs().data.regions.keys()
	ids.sort()
	for region_id: String in ids:
		if not _gs().player.alive:
			_start(kind)
			_last_day = _clock().total_days
		await _fuzz_region(region_id)
	# The session must still save and load after everything above.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_gs().to_save_dict()))
	_gs().load_save_dict(saved)
	_check_state("%s after save/load" % kind)
	if OS.get_environment("FUZZ_LOG") != "":
		print("FUZZ %s calls=%d day=%d" % [kind, _calls, _clock().total_days])
	_gs().end_session()


func test_fuzz_mortal() -> void:
	await _fuzz_all_regions("mortal")
	assert_gt(_calls, 50, "the fuzz should reach many options")


func test_fuzz_righteous_disciple() -> void:
	await _fuzz_all_regions("disciple")
	assert_gt(_calls, 80, "the fuzz should reach many options")


func test_fuzz_demonic_foundation() -> void:
	await _fuzz_all_regions("demonic")
	assert_gt(_calls, 80, "the fuzz should reach many options")


func _log_message(text: String, category: String) -> void:
	print("MSG ", category, " | ", text)
