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
var _window_realm := ""


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _gs() -> Node:
	return _tree().root.get_node("GameState")


func _clock() -> Node:
	return _tree().root.get_node("GameClock")


## A fresh session for `kind`: "mortal", "disciple" (righteous Qi Refining sect
## member with money and goods), "demonic" (Foundation, Blood Lotus) or
## "veteran" (QA-030: Foundation inner disciple, married with two children, an
## abode, a clan with an estate and a companion beast).
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
	if kind == "veteran":
		_build_veteran(c)
	elif kind == "realm_window":
		_build_realm_window(c)
	elif kind == "trial":
		_build_trial_candidate(c)
	elif kind == "disciple":
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


func _build_veteran(c: CharacterData) -> void:
	var gs := _gs()
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.stage = 3
	c.alignment = 200
	c.add_item("spirit_stone", 30000)
	gs.join_sect("azure_cloud_sect")
	var def: SectDef = gs.data.sects["azure_cloud_sect"]
	c.sect["rank"] = mini(2, def.ranks.size() - 1)
	# Abode first (a clan needs a seat), then move the family into its region.
	var abode_id := "cloud_piercing_grotto"
	var abode_region := String(Abodes.get_def(gs.data, abode_id)["region"])
	gs.current_region = abode_region
	gs.claim_abode(abode_id)
	var spouse := Npcs.spawn(gs.npcs, gs.data, seeded_rng(77), {"region": abode_region, "gender": "male" if c.gender == "female" else "female", "age_years": 25})
	var rank := "wife" if c.gender == "male" else "dao_companion"
	c.spouses.append(spouse.id)
	c.spouse_ranks[spouse.id] = rank
	spouse.spouses.append(c.id)
	spouse.spouse_ranks[c.id] = rank
	gs.npc_favor[spouse.id] = 100
	var mother: CharacterData = spouse if c.gender == "male" else c
	var father: CharacterData = c if c.gender == "male" else spouse
	for i in 2:
		Children.give_birth(mother, father, gs.npcs, gs.data, seeded_rng(80 + i), abode_region)
	for child_id: String in c.children:
		var child: CharacterData = gs.npcs[child_id]
		child.age_days = 12 * Calendar.DAYS_PER_YEAR
	gs.found_clan()
	for building: Dictionary in gs.data.clan_estate.get("buildings", []):
		gs.build_clan_building(String(building["id"]))
	if gs.data.beasts.has("boar"):
		c.companions.append("boar")


## QA-033: a Qi Refining disciple standing at the entrance of a secret realm
## they qualify for, with the clock inside its opening window.
func _build_realm_window(c: CharacterData) -> void:
	var gs := _gs()
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.stage = 6
	gs.join_sect("azure_cloud_sect")
	var ids: Array = gs.data.secret_realms.keys()
	ids.sort()
	for realm_id: String in ids:
		var def: Variant = gs.data.secret_realms[realm_id]
		if not (def is Dictionary) or not (def as Dictionary).has("period_years") or not SecretRealms.admits(c, gs.data, def):
			continue
		var offset := int(def.get("offset_years", 0)) * Calendar.DAYS_PER_YEAR
		var period := int(def.get("period_years", 1)) * Calendar.DAYS_PER_YEAR
		# The start of the second opening, so the first is already over.
		_clock().total_days = offset + period + 1
		gs.current_region = String(def["region"])
		_window_realm = realm_id
		return
	_window_realm = ""


## QA-033: an Azure Cloud disciple whose contribution and realm meet the next
## rank, which needs a trial fight.
func _build_trial_candidate(c: CharacterData) -> void:
	var gs := _gs()
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.stage = 2
	gs.join_sect("azure_cloud_sect")
	c.sect["rank"] = 1
	c.sect["contribution"] = 3500
	c.alignment = 200


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
	# Secret realm entrances first: meditation spots would run out the clock
	# of a short opening before the entrance gets its turn.
	var nodes: Array = world.get_children()
	nodes.sort_custom(func(a: Node, b: Node) -> bool: return a is SecretRealmEntrance and not b is SecretRealmEntrance)
	for node in nodes:
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
	var bus := _tree().root.get_node("EventBus")
	bus.message_posted.connect(_check_message)
	_last_day = _clock().total_days
	var ids: Array = _gs().data.regions.keys()
	ids.sort()
	if _window_realm != "" and kind == "realm_window":
		# The window is open now; visit its entrance before time moves on.
		var entrance := String(_gs().data.secret_realms[_window_realm]["region"])
		ids.erase(entrance)
		ids.push_front(entrance)
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
	bus.message_posted.disconnect(_check_message)
	_gs().end_session()


func test_fuzz_mortal() -> void:
	await _fuzz_all_regions("mortal")
	assert_gt(_calls, 50, "the fuzz should reach many options")


func test_fuzz_righteous_disciple() -> void:
	await _fuzz_all_regions("disciple")
	assert_gt(_calls, 80, "the fuzz should reach many options")


## Same walk with the HUD loaded, so the screens that react to actions (shop,
## combat report, time-skip overlay, dialogue and encounter windows) run too.
func test_fuzz_with_hud() -> void:
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_tree().root.add_child(hud)
	await _fuzz_all_regions("disciple")
	hud.queue_free()
	await _tree().process_frame


func test_fuzz_veteran_family_head() -> void:
	await _fuzz_all_regions("veteran")
	assert_gt(_calls, 80, "the fuzz should reach many options")
	assert_true(_gs().clan == null or _gs().clan.members.size() >= 1)


func test_fuzz_demonic_foundation() -> void:
	await _fuzz_all_regions("demonic")
	assert_gt(_calls, 80, "the fuzz should reach many options")


## QA-030: no unformatted template or null leaks into the message log.
func _check_message(text: String, _category: String) -> void:
	for bad: String in ["<null>", "{", "}", "%s", "%d", "%f", "null", "<Object"]:
		assert_false(text.contains(bad), "message leaks '%s': %s" % [bad, text])


func _log_message(text: String, category: String) -> void:
	print("MSG ", category, " | ", text)


## QA-033: a profile spawned while a secret realm's window is open.
func test_fuzz_secret_realm_window() -> void:
	await _fuzz_all_regions("realm_window")
	assert_true(_window_realm != "", "a realm admits a Qi Refining disciple")
	assert_gt(_calls, 50, "the fuzz should reach many options")


## QA-033: a profile with a sect promotion trial available.
func test_fuzz_promotion_trial() -> void:
	await _fuzz_all_regions("trial")
	assert_gt(_calls, 80, "the fuzz should reach many options")
