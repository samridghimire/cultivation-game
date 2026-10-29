extends TestCase
## ENC-011: encounter text naming the people who live in the region (Folk).


func _enc(extra: Dictionary = {}) -> Dictionary:
	var e := {"id": "test_folk", "tags": ["village"], "weight": 1, "kind": "neutral", "days": 0,
		"text": "{villager} waves; {elder} nods.", "effects": {"villager_favor": 5, "elder_favor": 2}}
	e.merge(extra, true)
	return e


func _village(npcs: Dictionary, count: int) -> void:
	for i in count:
		Npcs.spawn(npcs, data(), seeded_rng(10 + i), {"age_years": 20 + i * 10, "region": "qingshi_village", "realm": "mortal"})


func test_uses_finds_placeholders_in_text_and_choices() -> void:
	assert_true(Folk.uses(_enc()))
	assert_false(Folk.uses({"text": "Nobody."}))
	assert_true(Folk.uses({"text": "x", "choices": [{"label": "Thank {villager}", "text": "y"}, {"label": "b", "text": "c", "on_fail": {"text": "{elder} sighs"}}]}))


func test_candidates_are_living_generated_adults_of_the_region_but_not_family_or_rival() -> void:
	var c := new_character()
	var npcs := {}
	_village(npcs, 4)
	var all := Folk.candidates(npcs, data(), c, "qingshi_village")
	assert_eq(all.size(), 4)
	c.rival = all[0].id
	c.spouses = [all[1].id]
	all[2].alive = false
	var left := Folk.candidates(npcs, data(), c, "qingshi_village")
	assert_eq(left.size(), 1)
	assert_eq(left[0].id, all[3].id)
	assert_true(Folk.candidates(npcs, data(), c, "").is_empty())


func test_children_are_not_candidates() -> void:
	var npcs := {}
	Npcs.spawn(npcs, data(), seeded_rng(), {"age_years": 6, "region": "qingshi_village", "realm": "mortal"})
	assert_true(Folk.candidates(npcs, data(), new_character(), "qingshi_village").is_empty())


func test_encounter_is_ineligible_without_people() -> void:
	var c := new_character()
	var npcs := {}
	assert_false(Folk.available(_enc(), npcs, data(), c, "qingshi_village"))
	assert_true(Folk.available({"text": "Plain."}, npcs, data(), c, "qingshi_village"))
	_village(npcs, 1)
	assert_true(Folk.available(_enc(), npcs, data(), c, "qingshi_village"))


func test_pick_names_the_oldest_as_elder_and_is_deterministic() -> void:
	var c := new_character()
	var npcs := {}
	_village(npcs, 4)
	var a := Folk.pick(_enc(), npcs, data(), c, "qingshi_village", {}, seeded_rng(3))
	var b := Folk.pick(_enc(), npcs, data(), c, "qingshi_village", {}, seeded_rng(3))
	assert_eq(a, b)
	var oldest: CharacterData = null
	for p in Folk.candidates(npcs, data(), c, "qingshi_village"):
		if oldest == null or p.age_days > oldest.age_days:
			oldest = p
	assert_eq(a["elder"], oldest.id)
	assert_true(Folk.pick({"text": "Plain."}, npcs, data(), c, "qingshi_village", {}, seeded_rng()).is_empty())


func test_pick_often_prefers_someone_known() -> void:
	var c := new_character()
	var npcs := {}
	_village(npcs, 6)
	var friend: String = Folk.candidates(npcs, data(), c, "qingshi_village")[2].id
	var rng := seeded_rng(9)
	var hits := 0
	for i in 200:
		if Folk.pick(_enc(), npcs, data(), c, "qingshi_village", {friend: 10}, rng)["villager"] == friend:
			hits += 1
	assert_gt(hits, 80)  # half the time plus a share of the uniform picks


func test_fill_writes_names_and_favor_changes_follow_the_cast() -> void:
	var npcs := {}
	_village(npcs, 2)
	var c := new_character()
	var cast := Folk.pick(_enc(), npcs, data(), c, "qingshi_village", {}, seeded_rng(4))
	var text := Folk.fill("{villager} meets {elder}.", cast, npcs)
	assert_true(text.contains((npcs[cast["villager"]] as CharacterData).name))
	assert_false(text.contains("{"))
	assert_eq(Folk.fill("{villager}", {}, npcs), "{villager}")
	var changes := Folk.favor_changes({"villager_favor": 5, "elder_favor": 2}, {"villager": "a", "elder": "a"})
	assert_eq(changes, {"a": 7})


func test_validation_rejects_bad_favor() -> void:
	var d := data()
	assert_eq(Folk.validate(d).size(), 0)
	d.encounters["test_folk"] = _enc({"effects": {"villager_favor": 50}})
	assert_eq(Folk.validate(d).size(), 1)
	d.encounters["test_folk"] = _enc({"text": "No one named.", "effects": {"elder_favor": 3}})
	assert_eq(Folk.validate(d).size(), 1)
	d.encounters["test_folk"] = _enc({"effects": {"villager_favor": 0}})
	assert_eq(Folk.validate(d).size(), 1)
	d.encounters.erase("test_folk")


func test_road_encounters_never_name_people() -> void:
	var d := data()
	var c := new_character()
	d.encounters["test_folk"] = _enc({"tags": ["road_x"]})
	var pool := Exploration.eligible_encounters(c, d, ["road_x"], {}, null, 1.0, "", "", 0, func(e: Dictionary) -> bool: return not Folk.uses(e))
	d.encounters.erase("test_folk")
	assert_eq(pool.size(), 0)


func test_game_state_names_the_villager_and_changes_favor() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Folk", gs.data, seeded_rng(5))
	gs.start_session(c)
	var region: String = gs.current_region
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 30, "region": region, "realm": "mortal"})
	for other in Folk.candidates(gs.npcs, gs.data, c, region):
		if other.id != npc.id:
			other.alive = false
	var enc := _enc({"choices": [{"label": "Greet {villager}", "text": "{villager} smiles.", "effects": {"villager_favor": 4}}, {"label": "Pass", "text": "You pass."}]})
	gs.data.encounters["test_folk"] = enc
	gs._meet_encounter(enc)
	assert_eq(int(gs.npc_favor.get(npc.id, 0)), 7)  # sole villager and elder: 5 + 2
	assert_true(gs.rival_text("{villager}").contains(npc.name))
	var before := int(gs.npc_favor.get(npc.id, 0))
	gs.choose_encounter(0)
	assert_eq(int(gs.npc_favor.get(npc.id, 0)), before + 4)
	gs.data.encounters.erase("test_folk")
	gs.end_session()
