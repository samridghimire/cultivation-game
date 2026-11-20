extends TestCase
## QA-239: adding one named NPC to data/npcs.json must not change any other NPC's seeded rolls.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _roots_of(extra: bool) -> Dictionary:
	var data: GameData = _root().get_node("GameState").data
	if extra:
		data.npcs["zz_throwaway"] = {"id": "zz_throwaway", "name": "Zz Throwaway", "region": data.start_region, "age_years": 30}
	var npcs := {}
	var rng := seeded_rng(77)
	Npcs.ensure_all(npcs, data, rng)
	var out := {"next": rng.randi()}
	for id: String in npcs:
		if id != "zz_throwaway":
			out[id] = (npcs[id] as CharacterData).spiritual_roots.duplicate()
	data.npcs.erase("zz_throwaway")
	return out


func test_extra_named_npc_leaves_other_npcs_and_rng_alone() -> void:
	var base := _roots_of(false)
	var more := _roots_of(true)
	assert_eq(more.size(), base.size(), "the throwaway must not appear in the comparison")
	for id: String in base:
		assert_eq(more[id], base[id], "%s changed when an unrelated NPC was added" % id)
