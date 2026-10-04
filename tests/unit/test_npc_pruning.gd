extends TestCase
## FAM-013b: long-dead generated NPCs nobody remembers are pruned, ids never repeat.


func _people() -> Dictionary:
	var people := {}
	for i in 5:
		Npcs.spawn(people, data(), seeded_rng(i), {"age_years": 30})
	return people


func test_dead_days_count_and_save() -> void:
	var people := _people()
	var c: CharacterData = people.values()[0]
	Npcs.die(c, "test")
	Npcs.simulate(people, data(), 100, seeded_rng())
	assert_eq(c.dead_days, 100)
	assert_eq(CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))).dead_days, 100)
	assert_eq(CharacterData.from_dict({}).dead_days, 0)


func test_prune_rules() -> void:
	var people := _people()
	var ids: Array = people.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.substr(4).to_int() < b.substr(4).to_int())
	var old_dead: CharacterData = people[ids[0]]
	var remembered: CharacterData = people[ids[1]]
	var parent_of_living: CharacterData = people[ids[2]]
	var recent: CharacterData = people[ids[3]]
	var highest: CharacterData = people[ids[4]]
	for c: CharacterData in [old_dead, remembered, parent_of_living, recent, highest]:
		Npcs.die(c, "test")
		c.dead_days = 60 * Calendar.DAYS_PER_YEAR
	recent.dead_days = 10 * Calendar.DAYS_PER_YEAR
	var child := Npcs.spawn(people, data(), seeded_rng(9), {"age_years": 10})
	child.parents = [parent_of_living.id] as Array[String]
	var pruned := Npcs.prune(people, {remembered.id: true, child.id: true}, 50 * Calendar.DAYS_PER_YEAR)
	assert_true(pruned.has(old_dead.id))
	assert_false(people.has(old_dead.id))
	assert_true(people.has(remembered.id), "kept: the player knows them")
	assert_true(people.has(parent_of_living.id), "kept: a living child the player knows lists them")
	assert_true(people.has(recent.id), "kept: not dead long enough")
	assert_true(pruned.has(highest.id), "no longer the highest id once the child was born")
	assert_true(people.has(child.id))


func test_ids_never_repeat_after_pruning() -> void:
	var people := _people()
	var top := Npcs.highest_generated(people)
	for id: String in people.keys():
		var c: CharacterData = people[id]
		Npcs.die(c, "test")
		c.dead_days = 999999
	Npcs.prune(people, {}, 1)
	assert_eq(people.size(), 1, "the highest id stays as an anchor")
	var fresh := Npcs.spawn(people, data(), seeded_rng(77), {"age_years": 20})
	assert_eq(fresh.id, Npcs.SPAWN_PREFIX + str(top + 1), "never reuses a pruned id")


func test_game_state_prunes_yearly() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(new_character())
	var ghost := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 30})
	Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 30})  # keeps the ghost off the top id
	Npcs.die(ghost, "test")
	ghost.dead_days = 49 * Calendar.DAYS_PER_YEAR
	var rival_id: String = gs.player.rival
	gs.cultivate(Calendar.DAYS_PER_YEAR * 2)
	assert_false(gs.npcs.has(ghost.id), "pruned once dead 50 years")
	assert_true(gs.npcs.has(rival_id), "the rival is never pruned")
	gs.end_session()



func test_strangers_parents_are_pruned() -> void:
	var people := _people()
	var ids: Array = people.keys()
	var parent: CharacterData = people[ids[0]]
	Npcs.die(parent, "test")
	parent.dead_days = 60 * Calendar.DAYS_PER_YEAR
	var child := Npcs.spawn(people, data(), seeded_rng(9), {"age_years": 10})
	child.parents = [parent.id] as Array[String]
	assert_true(Npcs.prune(people, {}, 50 * Calendar.DAYS_PER_YEAR).has(parent.id), "nobody the player knows remembers them")
	var sibling := Npcs.spawn(people, data(), seeded_rng(10), {"age_years": 12})
	sibling.parents = [parent.id] as Array[String]
	assert_true(NpcFamilies.are_related(child, sibling) and Family.is_close_kin(child, sibling, people), "siblings stay kin through the kept parent id")



func test_widows_forget_a_pruned_spouse() -> void:
	var people := _people()
	var ids: Array = people.keys()
	var husband: CharacterData = people[ids[0]]
	var wife: CharacterData = people[ids[1]]
	Family.marry(husband, wife, "wife")
	Npcs.die(husband, "test")
	husband.dead_days = 60 * Calendar.DAYS_PER_YEAR
	assert_eq(Family.living_spouses(wife, people).size(), 0)
	assert_true(Npcs.prune(people, {}, 50 * Calendar.DAYS_PER_YEAR).has(husband.id))
	assert_false(wife.spouses.has(husband.id), "a pruned spouse is forgotten")
	assert_eq(Family.living_spouses(wife, people).size(), 0, "and never counts as living")
