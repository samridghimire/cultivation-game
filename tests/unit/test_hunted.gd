extends TestCase
## RIV-003: NPCs with strong grudges ambush the player on the road; grateful
## NPCs may come to help.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_hunt_chance_scales_with_grudge_and_realm_gap() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	var people := {}
	var npc := Npcs.spawn(people, d, seeded_rng(), {"realm": "foundation_establishment", "age_years": 30})
	assert_eq(Karma.hunt_chance(c, npc, d), 0.0, "no grudge, no hunt")
	Karma.add_grudge(c, d, npc.id, 30)
	assert_eq(Karma.hunt_chance(c, npc, d), 0.0, "below min_grudge")
	Karma.add_grudge(c, d, npc.id, 30)
	var at_60 := Karma.hunt_chance(c, npc, d)
	assert_gt(at_60, 0.0)
	Karma.add_grudge(c, d, npc.id, 40)
	assert_gt(Karma.hunt_chance(c, npc, d), at_60, "stronger grudges hunt more")
	assert_true(Karma.hunt_chance(c, npc, d) <= float(d.karma["hunt"]["max_chance"]))
	npc.realm_index = 1
	assert_true(Karma.hunt_chance(c, npc, d) < at_60, "a weaker NPC rarely dares")


func test_roll_hunter_picks_the_strongest_grudge_and_skips_the_dead() -> void:
	var d := data()
	var c := new_character()
	var people := {}
	var a := Npcs.spawn(people, d, seeded_rng(1), {"age_years": 30})
	var b := Npcs.spawn(people, d, seeded_rng(2), {"age_years": 30})
	Karma.add_grudge(c, d, a.id, 100)
	Karma.add_grudge(c, d, b.id, 60)
	var seen := {}
	for i in 200:
		seen[Karma.roll_hunter(c, people, d, seeded_rng(i))] = true
	assert_true(seen.has(a.id) and seen.has(""))
	assert_false(seen.has(b.id), "only the strongest grudge hunts")
	a.alive = false
	seen = {}
	for i in 200:
		seen[Karma.roll_hunter(c, people, d, seeded_rng(i))] = true
	assert_true(seen.has(b.id), "the dead hunt no more")


func test_after_hunt_and_ally() -> void:
	var d := data()
	var c := new_character()
	var people := {}
	var hunter := Npcs.spawn(people, d, seeded_rng(1), {"age_years": 30})
	var friend := Npcs.spawn(people, d, seeded_rng(2), {"age_years": 30})
	Karma.add_grudge(c, d, hunter.id, 80)
	Karma.after_hunt(c, d, hunter.id, true)
	assert_eq(Karma.grudge(c, hunter.id), 80 + int(d.karma["hunt"]["beaten_grudge"]))
	Karma.add_gratitude(c, d, friend.id, 90)
	var came := false
	for i in 20:
		if Karma.roll_ally(c, people, d, seeded_rng(i), hunter.id) == friend.id:
			came = true
			break
	assert_true(came, "a deeply grateful friend comes to help")
	assert_true(c.buffs.has("ally_aid"))
	assert_true(Karma.gratitude(c, friend.id) < 90, "helping spends gratitude")


func test_travel_ambush_in_game() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.realm_index = 1
	var hunter := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "realm": "qi_refining"})
	Karma.add_grudge(c, gs.data, hunter.id, 100)
	var posted: Array = []
	var bus := _root().get_node("EventBus")
	var cb := func(text: String, _cat: String) -> void: posted.append(text)
	bus.message_posted.connect(cb)
	var ambushed := false
	for i in 30:
		var route: Dictionary = Exploration.routes(c, gs.data, gs.current_region).filter(func(r: Dictionary) -> bool: return r["ok"])[0]
		gs.travel(route["to"])
		if posted.any(func(t: String) -> bool: return t.contains("hunted you down")):
			ambushed = true
			break
	bus.message_posted.disconnect(cb)
	assert_true(ambushed, "a sworn enemy finds you on the road")
	assert_true(Karma.grudge(c, hunter.id) < 100, "the ambush settles part of the grudge")
	gs.end_session()
