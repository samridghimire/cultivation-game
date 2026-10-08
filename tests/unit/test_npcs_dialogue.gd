extends TestCase


func _npcs() -> Dictionary:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng())
	return npcs


func _ctx(npc_id: String, c: CharacterData, npcs: Dictionary, flags: Dictionary = {}, favor: int = 0) -> Dictionary:
	return {"player": c, "npc": npcs[npc_id], "data": data(), "flags": flags, "favor": favor}


func test_npcs_created_from_data() -> void:
	var npcs := _npcs()
	assert_eq(npcs.size(), data().npcs.size())
	var mo: CharacterData = npcs["elder_mo"]
	assert_eq(mo.realm_index, data().realm_index_of("foundation_establishment"))
	assert_eq(mo.age_years(), 182)
	assert_eq(mo.attribute("comprehension"), 14)
	assert_eq(mo.attribute("fortune"), 10)


func test_npcs_cultivate_and_break_through() -> void:
	var npcs := _npcs()
	var ling: CharacterData = npcs["xiao_ling"]
	Npcs.simulate(npcs, data(), Calendar.DAYS_PER_YEAR * 2, seeded_rng())
	assert_gt(ling.realm_index, 0, "a fire-root prodigy should reach Qi Refining within two years")
	assert_eq(ling.age_years(), 18)


func test_npcs_die_of_old_age() -> void:
	var npcs := _npcs()
	var mo: CharacterData = npcs["elder_mo"]
	mo.realm_index = 0
	var events := Npcs.simulate(npcs, data(), Calendar.DAYS_PER_MONTH, seeded_rng())
	assert_false(mo.alive)
	var texts: Array = events.map(func(e): return e["text"])
	assert_true(texts.any(func(t): return "Elder Mo" in t))
	assert_false(Npcs.in_region(npcs, data(), "qingshi_village").has(mo))


func test_npc_save_round_trip() -> void:
	var npcs := _npcs()
	var restored := Npcs.from_dict(JSON.parse_string(JSON.stringify(Npcs.to_dict(npcs))))
	assert_eq(restored["swordsman_yun"].stage, npcs["swordsman_yun"].stage)
	assert_eq(restored["herbalist_lan"].spiritual_roots, npcs["herbalist_lan"].spiritual_roots)


func test_entry_node_depends_on_conditions() -> void:
	var npcs := _npcs()
	var c := new_character()
	var mo: Dictionary = data().dialogues["elder_mo"]
	assert_eq(Dialogue.entry_node(mo, _ctx("elder_mo", c, npcs)), "greet")
	c.alignment = -500
	assert_eq(Dialogue.entry_node(mo, _ctx("elder_mo", c, npcs)), "demonic")
	c.alignment = 0
	c.realm_index = data().realm_index_of("core_formation")
	assert_eq(Dialogue.entry_node(mo, _ctx("elder_mo", c, npcs)), "respect")


func test_view_hides_and_locks_choices() -> void:
	var npcs := _npcs()
	var c := new_character()
	c.inventory = {}
	var view := Dialogue.view(data().dialogues["elder_mo"], "greet", _ctx("elder_mo", c, npcs))
	assert_eq(view["id"], "elder_mo:greet")
	var labels: Array = view["choices"].map(func(ch): return ch["label"])
	assert_false(labels.any(func(l): return "bottleneck" in l), "realm-gated choice is hidden")
	var gift: Dictionary = view["choices"].filter(func(ch): return "spirit stones" in ch["label"])[0]
	assert_true(gift["disabled"], "unaffordable gift is shown locked")
	assert_true("Elder Mo" in view["speaker"])


func test_choose_applies_effects_and_favor() -> void:
	var npcs := _npcs()
	var c := new_character()
	c.inventory = {"spirit_stone": 50}
	var mo: Dictionary = data().dialogues["elder_mo"]
	var idx := -1
	var raw: Array = mo["nodes"]["greet"]["choices"]
	for i in raw.size():
		if raw[i].get("favor", 0) == 10:
			idx = i
	var result := Dialogue.choose(mo, "greet", idx, _ctx("elder_mo", c, npcs))
	assert_true(result["ok"])
	assert_eq(result["favor"], 10)
	assert_eq(result["next"], "gift")
	assert_eq(c.item_count("spirit_stone"), 40)
	assert_eq(Dialogue.choose(mo, "greet", -1, _ctx("elder_mo", c, npcs))["next"], "")


func test_text_placeholders() -> void:
	var npcs := _npcs()
	var c := new_character()
	var view := Dialogue.view(data().dialogues["xiao_ling"], "greet", _ctx("xiao_ling", c, npcs))
	assert_true(c.name in view["text"])


func test_gathering_and_selling() -> void:
	var c := new_character()
	var table := [{"item": "dew_grass", "weight": 1, "min": 2, "max": 2}]
	var found := Exploration.gather(c, table, seeded_rng())
	assert_gt(found.get("dew_grass", 0), 5)
	assert_true(Exploration.gather(c, [{"item": "", "weight": 1}], seeded_rng()).is_empty())
	c.inventory = {"cold_iron": 2}
	assert_true(Items.sell(c, data(), "cold_iron", 2)["ok"])
	assert_eq(c.item_count("spirit_stone"), 2 * Items.sell_price(data(), "cold_iron"))
	assert_false(Items.sell(c, data(), "cold_iron")["ok"])


func test_doctor_only_finds_the_injured() -> void:
	var c := new_character()
	var ids: Array = Exploration.eligible_encounters(c, data(), ["village"], {}).map(func(e): return e["encounter"]["id"])
	assert_false(ids.has("wild_doctor"))


func test_c006_npcs_open_by_alignment_and_favor() -> void:
	var npcs := _npcs()
	var c := new_character()
	var xue: Dictionary = data().dialogues["blood_lotus_xue"]
	assert_eq(Dialogue.entry_node(xue, _ctx("blood_lotus_xue", c, npcs)), "greet")
	c.alignment = -400
	assert_eq(Dialogue.entry_node(xue, _ctx("blood_lotus_xue", c, npcs)), "kin")
	c.alignment = 400
	assert_eq(Dialogue.entry_node(xue, _ctx("blood_lotus_xue", c, npcs)), "righteous")
	var gu: Dictionary = data().dialogues["hermit_gu"]
	c.alignment = 0
	assert_eq(Dialogue.entry_node(gu, _ctx("hermit_gu", c, npcs, {}, 50)), "greet", "Qi Refining is too weak for his legacy")
	c.realm_index = data().realm_index_of("foundation_establishment")
	assert_eq(Dialogue.entry_node(gu, _ctx("hermit_gu", c, npcs, {}, 50)), "inheritance")
	assert_eq(Dialogue.entry_node(gu, _ctx("hermit_gu", c, npcs, {"gu_inheritance": true}, 50)), "greet")
	var hua: Dictionary = data().dialogues["alchemist_hua"]
	assert_eq(Dialogue.entry_node(hua, _ctx("alchemist_hua", c, npcs, {}, 30)), "greet_friend")


func test_hermit_gu_is_near_the_end_of_his_life() -> void:
	var npcs := _npcs()
	var gu: CharacterData = npcs["hermit_gu"]
	var left := Cultivation.years_left(gu, data())
	assert_true(left > 0 and left <= 40, "Hermit Gu should have only a few decades left, has %d" % left)


func _choice_index(view: Dictionary, label_start: String) -> int:
	for choice: Dictionary in view.get("choices", []):
		if (choice["label"] as String).begins_with(label_start) and not choice["disabled"]:
			return choice["index"]
	return -2


func test_generated_adults_use_generic_dialogue() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Talker", gs.data, seeded_rng(5), "male")
	gs.start_session(c)
	var adult := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 25})
	var child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 3})
	assert_true(gs.has_dialogue(adult.id))
	assert_false(gs.has_dialogue(child.id), "children have nothing to say")
	gs.start_dialogue(adult.id)
	assert_eq(gs.dialogue_npc, adult.id)
	var view: Dictionary = gs.dialogue_view()
	assert_true((view["text"] as String).contains(adult.name), view["text"])
	var days: int = c.age_days
	gs.choose_dialogue(_choice_index(view, "Chat about the Dao"))
	assert_eq(int(gs.npc_favor.get(adult.id, 0)), 3)
	assert_eq(c.age_days, days + 3)
	gs.end_dialogue()
	gs.end_session()


func test_generic_dialogue_favor_is_capped_and_extortion_sours() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Talker", gs.data, seeded_rng(5), "male")
	gs.start_session(c)
	var adult := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 25})
	gs.npc_favor[adult.id] = int(gs.data.family["courtship"]["min_favor"])
	gs.start_dialogue(adult.id)
	assert_eq(_choice_index(gs.dialogue_view(), "Chat about the Dao"), -2, "idle chat stops at the courtship threshold")
	gs.npc_favor[adult.id] = 0
	var stones := c.item_count("spirit_stone")
	gs.choose_dialogue(_choice_index(gs.dialogue_view(), "Shake them down"))
	assert_eq(c.item_count("spirit_stone"), stones + 12)
	assert_eq(int(gs.npc_favor[adult.id]), -15)
	gs.end_dialogue()
	gs.npc_favor[adult.id] = -20
	gs.start_dialogue(adult.id)
	assert_eq(gs.dialogue_node, "cold", "a soured NPC remembers")
	gs.end_dialogue()
	gs.end_session()


func test_event_dialogue_without_npc_ignores_favor() -> void:
	var dialogue := {"id": "evt", "entries": [{"node": "a"}], "nodes": {
		"a": {"speaker": "A Voice", "text": "Hello, {player}.", "choices": [{"label": "Hi", "next": "end", "favor": 5, "effects": {"qi": 10}}]}}}
	var c := new_character()
	var ctx := {"player": c, "npc": null, "data": data(), "flags": {}, "favor": 0}
	assert_eq(Dialogue.entry_node(dialogue, ctx), "a")
	var view := Dialogue.view(dialogue, "a", ctx)
	assert_eq(view["speaker"], "A Voice")
	assert_eq(view["text"], "Hello, %s." % c.name)
	var result := Dialogue.choose(dialogue, "a", 0, ctx)
	assert_true(result["ok"])
	assert_eq(result["favor"], 0)
	assert_eq(result["next"], "")


func test_intro_event_is_a_valid_dialogue() -> void:
	var intro := String(data().artifact.get("intro_event", ""))
	assert_true(data().dialogues.has(intro))
	assert_eq(Dialogue.validate(data().dialogues[intro], data()).size(), 0)


## C-011: each named NPC's errand turn-in is hidden without the items or the asked flag.
func test_npc_errand_turn_ins_need_items_and_asked_flag() -> void:
	var errands := {
		"elder_mo": ["Bring the six Spirit Herbs", {"spirit_herb": 6}, "errand_mo"],
		"herbalist_lan": ["Bring the five Qi Condensing Grass", {"qi_condensing_grass": 5}, "errand_lan"],
		"hermit_gu": ["Bring the three Cold Iron", {"cold_iron": 3}, "errand_gu"],
		"alchemist_hua": ["Bring the four Qi Gathering Pills", {"qi_gathering_pill": 4}, "errand_hua"],
		"peddler_hei": ["Bring the three Purple Cloud Mushrooms", {"purple_cloud_mushroom": 3}, "errand_hei"],
	}
	var npcs := _npcs()
	for npc_id: String in errands:
		var label: String = errands[npc_id][0]
		var items: Dictionary = errands[npc_id][1]
		var prefix: String = errands[npc_id][2]
		var dlg: Dictionary = data().dialogues[npc_id]
		var node := "greet_friend" if npc_id == "alchemist_hua" else "greet"
		var c := CharacterData.new()
		var flags := {}
		var shown := func() -> bool:
			var ctx := _ctx(npc_id, c, npcs, flags, 50)
			return _choice_index(Dialogue.view(dlg, node, ctx), label) != -2
		assert_false(shown.call(), npc_id + ": hidden with no items and no asked flag")
		flags[prefix + "_asked"] = true
		assert_false(shown.call(), npc_id + ": hidden without the items")
		for id: String in items:
			c.add_item(id, items[id])
		flags.erase(prefix + "_asked")
		assert_false(shown.call(), npc_id + ": hidden without the asked flag")
		flags[prefix + "_asked"] = true
		assert_true(shown.call(), npc_id + ": shown with items and the asked flag")
		flags[prefix + "_done"] = true
		assert_false(shown.call(), npc_id + ": hidden once done")
