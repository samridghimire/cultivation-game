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


func test_greeting_bands_and_edges() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	assert_eq(Folk.greeting(npc, 19, 5, data()), "")
	assert_true(Folk.greeting(npc, 20, 5, data()) != "")
	assert_eq(Folk.greeting(npc, -9, 5, data()), "")
	assert_true(Folk.greeting(npc, -10, 5, data()) != "")
	assert_eq(Folk.greeting(npc, 0, 5, data()), "")
	var warm: Array = data().family["folk_greetings"]["warm"]["lines"]
	var cool: Array = data().family["folk_greetings"]["cool"]["lines"]
	assert_true(warm.has(Folk.greeting(npc, 50, 5, data())))
	assert_true(cool.has(Folk.greeting(npc, -50, 5, data())))


func test_greeting_is_deterministic_per_day_and_varies() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	assert_eq(Folk.greeting(npc, 30, 7, data()), Folk.greeting(npc, 30, 7, data()))
	var seen := {}
	for day in 40:
		seen[Folk.greeting(npc, 30, day, data())] = true
	assert_true(seen.size() > 1)


func test_greeting_validation() -> void:
	var d := data()
	assert_eq(Folk.validate_greetings(d).size(), 0)
	var saved: Dictionary = d.family["folk_greetings"].duplicate(true)
	d.family["folk_greetings"]["warm"]["lines"] = []
	assert_true(Folk.validate_greetings(d).size() > 0)
	d.family["folk_greetings"] = saved.duplicate(true)
	d.family["folk_greetings"]["warm"]["min_favor"] = -20
	assert_true(Folk.validate_greetings(d).size() > 0)
	d.family["folk_greetings"] = saved


# --- FOLK-001: neighbours ask small favours --------------------------------

func _rules(d: GameData, chance: float = 1.0) -> Dictionary:
	var r: Dictionary = d.family["folk_requests"]
	r["monthly_chance"] = chance
	return r


func test_request_chance_zero_gives_nothing() -> void:
	var d := GameData.load_from_dir()
	_rules(d, 0.0)
	var npcs := {}
	_village(npcs, 3)
	assert_true(Folk.monthly_request(new_character(), npcs, d, seeded_rng(), "qingshi_village", {}, 100).is_empty())


func test_request_entry_is_a_folk_letter_request() -> void:
	var d := GameData.load_from_dir()
	var r := _rules(d)
	var npcs := {}
	_village(npcs, 3)
	var c := new_character()
	var e := Folk.monthly_request(c, npcs, d, seeded_rng(), "qingshi_village", {}, 100)
	assert_false(e.is_empty())
	assert_eq(e["source"], "folk")
	assert_eq(int(e["until"]), 100 + int(r["days"]))
	assert_true(npcs.has(e["npc_id"]))
	assert_false(String(e["text"]).contains("{"))
	assert_true(String(e["text"]).contains(npcs[e["npc_id"]].name))
	assert_eq(c.letter_requests.size(), 1)
	var ask := {}
	for a: Dictionary in r["asks"]:
		if a["item"] == e["item"]:
			ask = a
	assert_true(int(e["count"]) >= int(ask["count"][0]) and int(e["count"]) <= int(ask["count"][1]))
	var stones := int(e["effects"]["items"]["spirit_stone"])
	assert_true(stones >= int(ask["stones"][0]) and stones <= int(ask["stones"][1]))


func test_request_is_deterministic_per_seed() -> void:
	var d := GameData.load_from_dir()
	_rules(d)
	var npcs := {}
	_village(npcs, 4)
	var a := Folk.monthly_request(new_character(), npcs, d, seeded_rng(7), "qingshi_village", {}, 100)
	var b := Folk.monthly_request(new_character(), npcs, d, seeded_rng(7), "qingshi_village", {}, 100)
	assert_eq(a, b)


func test_request_respects_max_open_and_open_askers() -> void:
	var d := GameData.load_from_dir()
	var r := _rules(d)
	r["max_open"] = 2
	var npcs := {}
	_village(npcs, 3)
	var c := new_character()
	var rng := seeded_rng()
	var first := Folk.monthly_request(c, npcs, d, rng, "qingshi_village", {}, 100)
	var second := Folk.monthly_request(c, npcs, d, rng, "qingshi_village", {}, 100)
	assert_false(second.is_empty())
	assert_true(first["npc_id"] != second["npc_id"], "nobody asks twice at once")
	assert_true(Folk.monthly_request(c, npcs, d, rng, "qingshi_village", {}, 100).is_empty(), "max_open reached")
	assert_false(Folk.monthly_request(c, npcs, d, rng, "qingshi_village", {}, 100 + int(r["days"]) + 1).is_empty(), "expired ones no longer count")


func test_request_skips_family_rival_and_low_favor() -> void:
	var d := GameData.load_from_dir()
	var r := _rules(d)
	var npcs := {}
	_village(npcs, 2)
	var c := new_character()
	var ids: Array = npcs.keys()
	c.rival = ids[0]
	c.spouses = [ids[1]]
	assert_true(Folk.monthly_request(c, npcs, d, seeded_rng(), "qingshi_village", {}, 100).is_empty())
	c.spouses = []
	r["min_favor"] = 10
	assert_true(Folk.monthly_request(c, npcs, d, seeded_rng(), "qingshi_village", {ids[1]: 9}, 100).is_empty())
	assert_eq(Folk.monthly_request(c, npcs, d, seeded_rng(), "qingshi_village", {ids[1]: 10}, 100)["npc_id"], ids[1])


func test_request_region_and_season_filters() -> void:
	var d := GameData.load_from_dir()
	var r := _rules(d)
	r["asks"] = [{"item": "spirit_herb", "count": [1, 1], "favor": 1, "stones": [0, 0], "regions": ["misty_forest"], "seasons": ["winter"], "text": "{villager} wants {count} {item}."}]
	var npcs := {}
	_village(npcs, 2)
	assert_true(Folk.monthly_request(new_character(), npcs, d, seeded_rng(), "qingshi_village", {}, 100).is_empty(), "wrong region")
	r["asks"][0]["regions"] = ["qingshi_village"]
	var winter := 0
	while Calendar.season_of(winter) != "Winter":
		winter += 1
	assert_false(Folk.monthly_request(new_character(), npcs, d, seeded_rng(), "qingshi_village", {}, winter).is_empty())
	assert_true(Folk.monthly_request(new_character(), npcs, d, seeded_rng(), "qingshi_village", {}, winter + 180).is_empty() or Calendar.season_of(winter + 180) == "Winter")
	var e := Folk.monthly_request(new_character(), npcs, d, seeded_rng(), "qingshi_village", {}, winter)
	assert_eq(e["effects"], {}, "zero stones pays nothing")


func test_request_validation() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Folk.validate_requests(d).size(), 0)
	var ask: Dictionary = d.family["folk_requests"]["asks"][0]
	ask["text"] = "Someone wants {count} {item}."
	assert_eq(Folk.validate_requests(d).size(), 1, "missing {villager}")
	ask["text"] = "{villager} wants {count} {item}."
	ask["count"] = [3, 2]
	assert_eq(Folk.validate_requests(d).size(), 1, "min > max")
	ask["count"] = [1, 2]
	ask["item"] = "nope"
	assert_eq(Folk.validate_requests(d).size(), 1, "unknown item")
	ask["item"] = "spirit_herb"
	ask["favor"] = 16
	assert_eq(Folk.validate_requests(d).size(), 1, "favor out of range")


# --- WORLD-005: village weddings you can attend ------------------------------

func test_celebration_opens_expires_and_attends_once() -> void:
	var flags := {}
	Folk.start_celebration(flags, ["a", "b"], 100, data())
	assert_true(Folk.celebration_open(flags, "a", 130))
	assert_false(Folk.celebration_open(flags, "a", 131))
	assert_false(Folk.celebration_open(flags, "zed", 100))
	var r := Folk.attend(flags, "a", "b", 105, data())
	assert_true(r["ok"])
	assert_eq(r["favor"], 6)
	assert_false(Folk.attend(flags, "a", "b", 106, data())["ok"])
	assert_false(Folk.attend(flags, "b", "a", 106, data())["ok"])
	assert_false(Folk.attend(flags, "a", "b", 200, data())["ok"])
	Folk.expire_celebrations(flags, 120)
	assert_true(flags.has("celebration_a"))
	Folk.expire_celebrations(flags, 131)
	assert_true(flags.is_empty())


func test_celebration_gift_multiplier_is_once() -> void:
	var flags := {}
	assert_eq(Folk.gift_multiplier(flags, "a", 100, data(), true), 1)
	Folk.start_celebration(flags, ["a"], 100, data())
	assert_eq(Folk.gift_multiplier(flags, "a", 101, data(), false), 2)
	assert_eq(Folk.gift_multiplier(flags, "a", 101, data(), true), 2)
	assert_eq(Folk.gift_multiplier(flags, "a", 102, data(), true), 1)


func test_celebration_validation() -> void:
	var d := data()
	assert_eq(Folk.validate_celebrations(d).size(), 0)
	var saved: Dictionary = d.family["celebrations"]
	d.family["celebrations"] = {"days": 0}
	assert_true(Folk.validate_celebrations(d).size() > 0)
	d.family["celebrations"] = saved



# --- WORLD-006: full-month feasts and funerals --------------------------------

func test_celebration_types_have_their_own_rules() -> void:
	var d := data()
	var flags := {}
	Folk.start_celebration(flags, ["m"], 100, d, "full_month")
	Folk.start_celebration(flags, ["x"], 100, d, "funeral")
	assert_eq(Folk.celebration_kind(flags, "m"), "full_month")
	assert_true(Folk.celebration_open(flags, "m", 130))
	assert_true(Folk.celebration_open(flags, "x", 110))
	assert_false(Folk.celebration_open(flags, "x", 111), "a funeral lasts 10 days")
	assert_eq(Folk.celebration_label(flags, "x", d), "Pay your respects (1 day)")
	assert_eq(Folk.celebration_label(flags, "m", d), "Attend the full-month feast (1 day)")
	var r := Folk.attend(flags, "x", "", 101, d)
	assert_eq(r["favor"], 8)
	assert_eq(r["alignment"], 1)
	assert_eq(Folk.check_attend(flags, "x", 102), "You have already paid your respects.")
	assert_eq(Folk.check_attend(flags, "zed", 102), "There is no wedding to attend.", "no flags: the wedding wording")
	assert_eq(Folk.gift_multiplier(flags, "m", 101, d, true), 2)
	assert_eq(Folk.gift_multiplier(flags, "x", 101, d, true), 1)


func test_kind_flag_defaults_to_wedding_and_expires_with_it() -> void:
	var d := data()
	var flags := {"celebration_old": 130}
	assert_eq(Folk.celebration_kind(flags, "old"), "wedding")
	assert_eq(Folk.celebration_label(flags, "old", d), "Attend the wedding (1 day)")
	Folk.start_celebration(flags, ["x"], 100, d, "funeral")
	Folk.expire_celebrations(flags, 105)
	assert_true(flags.has("celebration_kind_x"), "a live kind flag is not mistaken for an end day")
	assert_true(flags.has("celebration_old"))
	Folk.expire_celebrations(flags, 111)
	assert_false(flags.has("celebration_kind_x"))
	assert_false(flags.has("celebration_x"))


func test_legacy_top_level_rules_still_work() -> void:
	var d := data()
	d.family["celebrations"] = {"days": 30, "attend_days": 1, "favor": 6, "alignment": 1, "gift_mult": 2}
	assert_eq(Folk.validate_celebrations(d).size(), 0)
	var flags := {}
	Folk.start_celebration(flags, ["a"], 100, d)
	assert_eq(Folk.attend(flags, "a", "", 101, d)["favor"], 6)
	d.family["celebrations"]["types"] = {"funeral": {"days": 10, "attend_days": 1, "favor": 1}}
	assert_true(Folk.validate_celebrations(d).size() >= 2, "a type needs a label and news")


func test_mourners_are_living_relatives_in_the_region() -> void:
	var dead := CharacterData.new()
	dead.id = "dead"
	var kin := CharacterData.new()
	kin.id = "kin"
	var far := CharacterData.new()
	far.id = "far"
	var gone := CharacterData.new()
	gone.id = "gone"
	gone.alive = false
	var mine := CharacterData.new()
	mine.id = "mine"
	var player := CharacterData.new()
	player.children = ["mine"]
	dead.spouses = ["kin"]
	dead.children = ["far", "gone", "mine"]
	var npcs := {"kin": kin, "far": far, "gone": gone, "mine": mine}
	var d := data()
	for c: CharacterData in [kin, gone, mine]:
		c.home_region = "qingshi_village"
	far.home_region = "misty_forest"
	assert_eq(Folk.mourners(npcs, d, dead, "qingshi_village", player), ["kin"] as Array[String])
	assert_true(Folk.mourners(npcs, d, dead, "fallen_star_market", player).is_empty())


# --- FOLK-003: a friend's tip ---

func _tip_data() -> GameData:
	var d := data()
	d.family["folk_tips"]["chance"] = 1.0
	return d


func test_tip_needs_favor_no_active_tip_and_cooldown() -> void:
	var d := _tip_data()
	var c := new_character()
	var flags := {}
	assert_true(Folk.roll_tip(c, d, flags, "qingshi_village", [], 5, "n1", 100, "spring", seeded_rng(1)).is_empty())
	var tip := Folk.roll_tip(c, d, flags, "qingshi_village", [], 40, "n1", 100, "spring", seeded_rng(1))
	assert_false(tip.is_empty())
	assert_true(Folk.tip_candidates(c, d, "qingshi_village", "spring").has(tip["item"]))
	assert_eq(int(tip["until"]), 100 + int(d.family["folk_tips"]["days"]))
	assert_true(Folk.roll_tip(c, d, flags, "qingshi_village", [], 40, "n1", 101, "spring", seeded_rng(1)).is_empty())  # active
	flags.erase(Folk.TIP_KEY)
	assert_true(Folk.roll_tip(c, d, flags, "qingshi_village", [], 40, "n1", 110, "spring", seeded_rng(1)).is_empty())  # cooldown
	assert_false(Folk.roll_tip(c, d, flags, "qingshi_village", [], 40, "n1", 130, "spring", seeded_rng(1)).is_empty())


func test_tip_falls_back_to_a_neighbour_and_is_off_without_rules() -> void:
	var d := _tip_data()
	var c := new_character()
	var tip := Folk.roll_tip(c, d, {}, "no_such_region", ["qingshi_village"], 40, "n1", 100, "spring", seeded_rng(2))
	assert_eq(tip["region"], "qingshi_village")
	var rules: Dictionary = d.family["folk_tips"]
	d.family.erase("folk_tips")
	assert_true(Folk.roll_tip(c, d, {}, "qingshi_village", [], 40, "n1", 100, "spring", seeded_rng(2)).is_empty())
	d.family["folk_tips"] = rules
	assert_eq(Folk.validate_tips(d).size(), 0)


func test_tip_is_deterministic_and_bonus_needs_region_and_item() -> void:
	var d := _tip_data()
	var c := new_character()
	var a := Folk.roll_tip(c, d, {}, "qingshi_village", [], 40, "n1", 100, "summer", seeded_rng(7))
	var b := Folk.roll_tip(c, d, {}, "qingshi_village", [], 40, "n1", 100, "summer", seeded_rng(7))
	assert_eq(a, b)
	var flags := {Folk.TIP_KEY: a}
	var table := [{"item": a["item"], "weight": 1}]
	assert_eq(Folk.tip_bonus(d, flags, 105, "qingshi_village", table), {a["item"]: int(d.family["folk_tips"]["bonus"])})
	assert_true(Folk.tip_bonus(d, flags, 105, "misty_forest", table).is_empty())
	assert_true(Folk.tip_bonus(d, flags, 105, "qingshi_village", [{"item": "", "weight": 1}]).is_empty())
	assert_true(Folk.active_tip(flags, 100 + int(d.family["folk_tips"]["days"]) + 1).is_empty())
	assert_true(Folk.tip_line(d, a, "Wu Lan", 3).contains("Wu Lan") or Folk.tip_line(d, a, "Wu Lan", 3) != "")


func test_tip_validation_rejects_bad_rules() -> void:
	var d := data()
	var rules: Dictionary = d.family["folk_tips"].duplicate(true)
	d.family["folk_tips"]["lines"] = ["no placeholder"]
	d.family["folk_tips"]["bonus"] = 9
	assert_true(Folk.validate_tips(d).size() >= 2)
	d.family["folk_tips"] = rules


func test_tip_min_favor_is_below_where_chat_stops() -> void:
	var d := data()
	assert_eq(Folk.validate_tips(d).size(), 0)
	var old := int(d.family["folk_tips"]["min_favor"])
	d.family["folk_tips"]["min_favor"] = int(d.family["acquaintance"]["chat_max_favor"])
	assert_eq(Folk.validate_tips(d).size(), 1, "chat is refused at chat_max_favor, so a tip there could never come")
	d.family["folk_tips"]["min_favor"] = old


func test_gift_needs_favor_and_cooldown() -> void:
	var c := new_character()
	var npc := Npcs.spawn({}, data(), seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	assert_true(Folk.gift(c, npc, 39, 100, data()).is_empty())
	var g := Folk.gift(c, npc, 40, 100, data())
	assert_true(data().items.has(g["item"]))
	assert_true(String(g["text"]).contains(npc.name))
	assert_false(String(g["text"]).contains("{"))
	c.folk_gift_day[npc.id] = 100
	assert_true(Folk.gift(c, npc, 90, 144, data()).is_empty())
	assert_false(Folk.gift(c, npc, 90, 145, data()).is_empty())


func test_gift_pick_is_deterministic_per_day() -> void:
	var c := new_character()
	var npc := Npcs.spawn({}, data(), seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	assert_eq(Folk.gift(c, npc, 60, 200, data()), Folk.gift(c, npc, 60, 200, data()))
	var seen := {}
	for day in 60:
		seen[Folk.gift(c, npc, 60, day, data())["item"]] = true
	assert_true(seen.size() > 1)


func test_gift_day_round_trips_through_save() -> void:
	var c := new_character()
	c.folk_gift_day["npc_x"] = 123
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.folk_gift_day, {"npc_x": 123})
	assert_eq(CharacterData.from_dict({}).folk_gift_day, {})


func test_celebrants_and_sash_looks() -> void:
	var flags := {}
	Folk.start_celebration(flags, ["a"], 10, data(), Folk.WEDDING)
	Folk.start_celebration(flags, ["b"], 10, data(), "funeral")
	var party := Folk.celebrants(flags, ["a", "b", "c"], 10)
	assert_eq(party.size(), 2)
	assert_eq(party["a"], Folk.WEDDING)
	assert_eq(party["b"], "funeral")
	assert_false(party.has("c"))
	assert_true(Folk.celebrants(flags, ["a", "b"], 400).is_empty())
	assert_true(Folk.celebration_sash(Folk.WEDDING).r > Folk.celebration_sash(Folk.WEDDING).g * 2.0)
	assert_true(Folk.celebration_sash("funeral").g > 0.8)
	assert_true(Folk.celebration_lantern("funeral") != Folk.celebration_lantern(Folk.WEDDING))
