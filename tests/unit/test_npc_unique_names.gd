extends TestCase
## FH-006: generated NPCs avoid the full name of a living NPC.


func _data_with_pool(pool: Array) -> GameData:
	var d := GameData.load_from_dir()
	d.names["given_names"] = {"male": pool, "female": pool}
	return d


func test_spawn_rerolls_given_name_on_collision() -> void:
	var d := _data_with_pool(["Pei", "Lan"])
	var rng := seeded_rng()
	var npcs := {}
	var first := Npcs.spawn(npcs, d, rng, {"surname": "Zhao", "given_name": "Pei"})
	assert_eq(first.name, "Zhao Pei")
	for i in 20:
		var c := Npcs.spawn(npcs, d, rng, {"surname": "Zhao" + str(i)})
		assert_true(c != null)
	var second := Npcs.spawn(npcs, d, rng, {"surname": "Zhao"})
	assert_eq(second.name, "Zhao Lan", "re-rolled away from the living Zhao Pei")


func test_dead_npc_does_not_block_a_name() -> void:
	var d := _data_with_pool(["Pei"])
	var rng := seeded_rng()
	var npcs := {}
	var first := Npcs.spawn(npcs, d, rng, {"surname": "Zhao", "given_name": "Pei"})
	first.alive = false
	var second := Npcs.spawn(npcs, d, rng, {"surname": "Zhao"})
	assert_eq(second.name, "Zhao Pei")


func test_exhausted_pool_still_spawns() -> void:
	var d := _data_with_pool(["Pei"])
	var rng := seeded_rng()
	var npcs := {}
	Npcs.spawn(npcs, d, rng, {"surname": "Zhao", "given_name": "Pei"})
	var second := Npcs.spawn(npcs, d, rng, {"surname": "Zhao"})
	assert_eq(second.name, "Zhao Pei", "gives up after the re-roll limit")
