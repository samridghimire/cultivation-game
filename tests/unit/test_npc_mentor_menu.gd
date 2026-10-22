extends TestCase
## WU-059: pointers and spar entries in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


## The spar entry for `npc` (not the generic dialogue's "Spar with them." line).
func _spar(options: Array, npc: CharacterData) -> Dictionary:
	return _find(options, "Spar with %s" % npc.name)


func _setup(gs: Node, realm: int, favor: int) -> Array:
	var c := CharacterFactory.create("Hero", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = 1
	c.stage = 1
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"gender": "female", "region": gs.current_region})
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	npc.realm_index = realm
	npc.stage = 5
	gs.npc_favor[npc.id] = favor
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = npc.id
	return [menu, npc]


func test_senior_friend_lists_both() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 100)
	var opts: Array = r[0].get_options()
	assert_false(_find(opts, "Ask ").is_empty(), "pointers listed")
	var spar := _spar(opts, r[1])
	assert_false(spar.is_empty(), "spar listed")
	assert_false(spar["disabled"], spar["reason"])
	r[0].free()
	gs.end_session()


func test_stranger_spar_disabled_and_far_realm_hidden() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 0)
	var spar := _spar(r[0].get_options(), r[1])
	assert_true(spar["disabled"], "needs favor")
	assert_true(String(spar["reason"]).contains("favor"))
	r[0].free()
	r = _setup(gs, 1 + 3, 100)
	var opts: Array = r[0].get_options()
	assert_true(_spar(opts, r[1]).is_empty(), "realm gap too big")
	r[0].free()
	gs.end_session()


func test_rival_spar_reads_as_challenge() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 100)
	var npc: CharacterData = r[1]
	gs.player.rival = npc.id
	var opts: Array = r[0].get_options()
	assert_true(_spar(opts, npc).is_empty(), "no plain spar label for the rival")
	var ch := _find(opts, "Challenge your rival %s" % npc.name)
	assert_false(ch.is_empty(), "challenge listed")
	assert_false(ch["disabled"], ch["reason"])
	assert_true(String(ch["label"]).contains(" in 100)"), "WU-173: odds shown: %s" % ch["label"])
	gs.player.rival = ""
	r[0].free()
	gs.end_session()


func test_bitter_rival_challenge_disabled_proud_enabled() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 0)
	var npc: CharacterData = r[1]
	gs.player.rival = npc.id
	var label := "Challenge your rival %s" % npc.name
	var proud := _find(r[0].get_options(), label)
	assert_false(proud.is_empty(), "challenge listed for a proud rival")
	assert_false(proud["disabled"], "a proud rival at favor 0 accepts: %s" % proud["reason"])
	Karma.add_grudge(gs.player, gs.data, npc.id, int(gs.data.karma["rival"]["bitter_grudge"]))
	var bitter := _find(r[0].get_options(), label)
	assert_true(bitter["disabled"], "a bitter rival refuses")
	assert_true(String(bitter["reason"]).contains("will not spar with you"), str(bitter["reason"]))
	gs.player.rival = ""
	r[0].free()
	gs.end_session()


func test_rival_challenge_opening_line() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 100)
	var npc: CharacterData = r[1]
	gs.player.rival = npc.id
	var log_lines: Array = []
	var cb := func(text: String, _cat: String) -> void: log_lines.append(text)
	gs.get_node("/root/EventBus").message_posted.connect(cb)
	gs.spar_with(npc.id)
	gs.get_node("/root/EventBus").message_posted.disconnect(cb)
	var found := false
	for l: String in log_lines:
		if l.begins_with("%s accepts your challenge." % npc.name):
			found = true
	assert_true(found, "challenge line: %s" % str(log_lines))
	r[0].free()
	gs.end_session()


func test_spar_label_odds() -> void:
	var want := "Challenge your rival Lin to a bout (%s, 52 in 100)" % Combat.label_for_chance(0.52)
	assert_eq(load("res://src/world/interactables/npc.gd").spar_label("Lin", true, 0.52), want)
	assert_eq(load("res://src/world/interactables/npc.gd").spar_label("Lin", false, -1.0), "Spar with Lin")


## PERF-001: a Foundation NPC's menu is the same on a cold and a warm odds cache, and a repeat call is fast.
func test_foundation_menu_is_stable_and_cheap() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, gs.data.realm_index_of("foundation_establishment"), 100)
	gs.player.realm_index = gs.data.realm_index_of("foundation_establishment")
	var labels := func(opts: Array) -> Array:
		return opts.map(func(o: Dictionary) -> String: return String(o["label"]))
	Combat._chance_cache.clear()
	var cold: Array = labels.call(r[0].get_options())
	var t0 := Time.get_ticks_usec()
	var warm: Array = labels.call(r[0].get_options())
	var warm_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_eq(warm, cold, "labels do not change between calls")
	assert_true(String(cold.filter(func(l: String) -> bool: return l.begins_with("Spar with"))[0]).contains(" in 100)"), "spar odds shown")
	assert_true(warm_ms < 50.0, "warm get_options took %.1f ms" % warm_ms)
