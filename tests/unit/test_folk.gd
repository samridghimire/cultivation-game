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


func test_tip_lines_follow_season_and_weather() -> void:
	var d := _tip_data()
	var tip := {"region": "qingshi_village", "item": "spirit_grass"}
	var lines: Array = d.family["folk_tips"]["lines"]
	var seasonal := 0
	var rainy := 0
	for line: Variant in lines:
		assert_true((String(line.get("text", "")) if line is Dictionary else String(line)).contains("{item}"), "every tip line names {item}")
		if line is Dictionary and line.has("seasons"):
			seasonal += 1
		if line is Dictionary and line.has("weather"):
			rainy += 1
	assert_eq(lines.size(), 13)
	assert_eq(seasonal, 4)
	assert_true(rainy >= 2)
	for day in range(0, 360):
		var said := Folk.tip_line(d, tip, "Wu Lan", day, "clear")
		assert_true(said != "")
		assert_true(not said.contains("{"), "all placeholders filled")
		if Calendar.season_of(day) != "Winter":
			assert_false(said.contains("brazier"), "a winter-only line never shows out of winter (day %d)" % day)
		assert_false(said.contains("wet cloak") or said.contains("Fog sits"), "weather lines need their weather")
	assert_true(Folk.tip_line(d, tip, "Wu Lan", 5, "rain") != "")
	assert_true(Folk.tip_line(d, tip, "Wu Lan", 5, "storm") != "")


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


# --- WORLD-007: friends drop by ----------------------------------------------

func _visit_setup(chance: float = 1.0) -> Dictionary:
	var npcs := {}
	_village(npcs, 3)
	var favors := {}
	for id: String in npcs:
		favors[id] = 50
	data().family["folk_visits"]["chance"] = chance
	return {"npcs": npcs, "favors": favors}


func test_visitor_needs_clear_or_cloudy_weather() -> void:
	var s := _visit_setup()
	var c := new_character()
	for weather in ["rain", "snow", "fog"]:
		assert_eq(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 10, weather, {}), "")
	assert_true(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 10, "clear", {}) != "")
	assert_true(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 10, "cloudy", {}) != "")


func test_visitor_needs_favor_and_other_regions_do_not_count() -> void:
	var s := _visit_setup()
	var c := new_character()
	var low := {}
	for id: String in s["npcs"]:
		low[id] = int(data().family["folk_visits"]["min_favor"]) - 1
	assert_eq(Folk.visitor(s["npcs"], low, data(), c, "qingshi_village", 10, "clear", {}), "")
	assert_eq(Folk.visitor(s["npcs"], s["favors"], data(), c, "misty_forest", 10, "clear", {}), "")


func test_visitor_cooldown_and_same_day_tea() -> void:
	var s := _visit_setup()
	var c := new_character()
	var first := Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 100, "clear", {})
	var last := {}
	for id: String in s["npcs"]:
		last[id] = 100
	assert_eq(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 100, "clear", last), first, "tea today keeps today's visitor")
	assert_eq(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 101, "clear", last), "", "everyone is on cooldown")
	assert_true(Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", 100 + int(data().family["folk_visits"]["cooldown_days"]), "clear", last) != "")


func test_visitor_is_deterministic_and_chance_gates_it() -> void:
	var s := _visit_setup(0.15)
	var c := new_character()
	var days := 0
	for day in 200:
		var a := Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", day, "clear", {})
		assert_eq(a, Folk.visitor(s["npcs"], s["favors"], data(), c, "qingshi_village", day, "clear", {}))
		if a != "":
			days += 1
	assert_true(days > 10 and days < 60, "about 15%% of days, got %d" % days)
	data().family["folk_visits"]["chance"] = 0.15


func test_visits_validation_and_visit_place() -> void:
	var d := data()
	assert_eq(Folk.validate_visits(d).size(), 0)
	var saved: Dictionary = d.family["folk_visits"].duplicate()
	d.family["folk_visits"]["chance"] = 0.0
	assert_true(Folk.validate_visits(d).size() > 0)
	d.family["folk_visits"] = saved.duplicate()
	d.family["folk_visits"]["min_favor"] = 1
	assert_true(Folk.validate_visits(d).size() > 0)
	d.family["folk_visits"] = saved
	var region: Dictionary = d.regions["qingshi_village"]
	var place := Npcs.visit_place_of(region, false)
	assert_eq(String(place["type"]), "meditation")
	var home := Npcs.visit_place_of(region, true)
	assert_eq(String(home["type"]), "family_home")
	assert_eq(Npcs.visit_place_of({}, true), {})


func test_celebration_news_picks_a_variant_by_day() -> void:
	var d := GameData.load_from_dir()
	for kind in ["wedding", "full_month", "funeral"]:
		var seen := {}
		for day in 3:
			var line := Folk.celebration_news(d, kind, day)
			assert_true(line.contains("{region}") and line.contains("{text}"), kind)
			seen[line] = true
		assert_eq(seen.size(), 3, kind)
		assert_eq(Folk.celebration_news(d, kind, 0), Folk.celebration_news(d, kind, 3))
	assert_eq(Folk.validate_celebrations(d).size(), 0)


func test_celebration_greeting_only_while_open() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var flags := {}
	var d := GameData.load_from_dir()
	Folk.start_celebration(flags, [npc.id], 100, d, "funeral")
	var lines: Array = d.family["folk_greetings"]["celebration"]["funeral"]
	assert_true(lines.has(Folk.greeting(npc, 0, 105, d, flags)), "open: celebration bucket even at neutral favor")
	assert_true(lines.has(Folk.greeting(npc, 50, 105, d, flags)))
	assert_eq(Folk.greeting(npc, 0, 111, d, flags), "", "closed: normal rules")
	assert_eq(Folk.greeting(npc, 0, 105, d), "", "no flags: normal rules")


# --- FOLK-004: quarrels ---

func _quarrel_rig() -> Array:
	var npcs := {}
	_village(npcs, 4)
	return [new_character(), npcs]


func test_quarrel_picks_two_non_family_adults_deterministically() -> void:
	var d := data()
	d.family["folk_quarrels"]["chance"] = 1.0
	var rig := _quarrel_rig()
	var c: CharacterData = rig[0]
	var npcs: Dictionary = rig[1]
	var family: CharacterData = Folk.candidates(npcs, d, c, "qingshi_village")[0]
	c.spouses = [family.id]
	var flags := {}
	var q := Folk.monthly_quarrel(c, npcs, d, seeded_rng(3), "qingshi_village", 100, flags)
	assert_false(q.is_empty())
	assert_true(q["a"] != q["b"])
	assert_true(q["a"] != family.id and q["b"] != family.id)
	assert_eq(flags[Folk.quarrel_flag("qingshi_village")], q)
	var again := {}
	assert_eq(Folk.monthly_quarrel(c, npcs, d, seeded_rng(3), "qingshi_village", 100, again), q)
	assert_true(Folk.quarrel_text(q, npcs, d).find("{") < 0)
	d.family["folk_quarrels"]["chance"] = 0.25


func test_quarrel_one_at_a_time_and_expiry_clears_quietly() -> void:
	var d := data()
	d.family["folk_quarrels"]["chance"] = 1.0
	var rig := _quarrel_rig()
	var flags := {}
	var q := Folk.monthly_quarrel(rig[0], rig[1], d, seeded_rng(), "qingshi_village", 100, flags)
	assert_true(Folk.monthly_quarrel(rig[0], rig[1], d, seeded_rng(), "qingshi_village", 110, flags).is_empty())
	assert_eq(Folk.open_quarrel(flags, "qingshi_village", 110), q)
	assert_true(Folk.open_quarrel(flags, "qingshi_village", int(q["until"]) + 1).is_empty())
	var next := Folk.monthly_quarrel(rig[0], rig[1], d, seeded_rng(), "qingshi_village", int(q["until"]) + 1, flags)
	assert_false(next.is_empty())
	d.family["folk_quarrels"]["chance"] = 0.25


func test_quarrel_needs_two_villagers() -> void:
	var d := data()
	d.family["folk_quarrels"]["chance"] = 1.0
	var npcs := {}
	_village(npcs, 1)
	assert_true(Folk.monthly_quarrel(new_character(), npcs, d, seeded_rng(), "qingshi_village", 100, {}).is_empty())
	d.family["folk_quarrels"]["chance"] = 0.25


func test_quarrel_settle_outcomes() -> void:
	var d := data()
	var o: Dictionary = d.family["folk_quarrels"]["outcomes"]
	var c := new_character()
	var q := {"a": "x", "b": "y", "topic": "rice_debt", "until": 200}
	var side := Folk.settle(c, d, q, "side_a", seeded_rng())
	assert_eq(int(side["favor"]["x"]), int(o["side_a"]["favor_winner"]))
	assert_eq(int(side["favor"]["y"]), int(o["side_a"]["favor_loser"]))
	side = Folk.settle(c, d, q, "side_b", seeded_rng())
	assert_eq(int(side["favor"]["y"]), int(o["side_b"]["favor_winner"]))
	var ext := Folk.settle(c, d, q, "extort", seeded_rng())
	assert_eq(int(ext["stones"]), int(o["extort"]["stones"]))
	assert_eq(int(ext["alignment"]), int(o["extort"]["alignment"]))
	assert_eq(int(ext["favor"]["x"]), int(o["extort"]["favor_a"]))


func test_quarrel_mediate_check_passes_and_fails() -> void:
	var d := data()
	var c := new_character()
	var q := {"a": "x", "b": "y", "topic": "rice_debt", "until": 200}
	c.attributes["charisma"] = 100
	var rng := RandomNumberGenerator.new()
	var ok := Folk.settle(c, d, q, "mediate", seeded_rng())
	assert_true(Folk.mediate_chance(c, d) == 0.9)
	var wins := 0
	var losses := 0
	for i in 40:
		rng.seed = i
		var r := Folk.settle(c, d, q, "mediate", rng)
		if r["ok"]:
			wins += 1
			assert_eq(int(r["favor"]["x"]), 4)
		else:
			losses += 1
			assert_eq(int(r["favor"]["x"]), -2)
	assert_true(wins > 0 and losses > 0)
	assert_true(ok.has("ok"))


func test_quarrel_validation() -> void:
	var d := data()
	assert_true(Folk.validate_quarrels(d).is_empty())
	d.family["folk_quarrels"]["topics"][0]["text"] = "no names"
	assert_false(Folk.validate_quarrels(d).is_empty())
	d.family["folk_quarrels"]["topics"][0]["text"] = "{a} {b}"


# --- FOLK-005: a friend at your side ---

func _companion_setup() -> Dictionary:
	var npcs := {}
	var npc := Npcs.spawn(npcs, data(), seeded_rng(3), {"age_years": 30, "region": "qingshi_village", "realm": "qi_refining"})
	return {"npcs": npcs, "npc": npc}


func test_companion_invite_gates() -> void:
	var s := _companion_setup()
	var npc: CharacterData = s["npc"]
	var c := new_character()
	var min_favor := int(data().family["folk_companions"]["min_favor"])
	assert_true(Folk.check_invite(c, npc, min_favor - 1, data(), "qingshi_village", 100) != "")
	assert_eq(Folk.check_invite(c, npc, min_favor, data(), "qingshi_village", 100), "")
	var mortal := Npcs.spawn(s["npcs"], data(), seeded_rng(4), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	assert_true(Folk.check_invite(c, mortal, 100, data(), "qingshi_village", 100) != "")
	Folk.invite(c, npc.id, 100)
	assert_eq(Folk.companion_today(c, 100), npc.id)
	assert_eq(Folk.companion_today(c, 101), "")
	assert_true(Folk.check_invite(c, npc, 100, data(), "qingshi_village", 101) != "", "cooldown")
	assert_eq(Folk.check_invite(c, npc, 100, data(), "qingshi_village", 100 + int(data().family["folk_companions"]["cooldown_days"])), "")


func test_companion_finish_win_and_loss() -> void:
	var s := _companion_setup()
	var npc: CharacterData = s["npc"]
	var c := new_character()
	var favors := {npc.id: 60}
	Folk.invite(c, npc.id, 5)
	assert_eq(Folk.finish_companion(c, s["npcs"], favors, data(), seeded_rng(1), npc.id, true), 2)
	assert_eq(int(favors[npc.id]), 62)
	assert_true(c.folk_companion.is_empty())
	data().family["folk_companions"]["injury_chance"] = 1.0
	assert_eq(Folk.finish_companion(c, s["npcs"], favors, data(), seeded_rng(1), npc.id, false), -2)
	assert_eq(int(favors[npc.id]), 60)
	assert_true(npc.injuries.has("internal_injury"))
	data().family["folk_companions"]["injury_chance"] = 0.25


func test_companion_strike_and_validation() -> void:
	var s := _companion_setup()
	var strike := Folk.companion_strike(s["npcs"], data(), s["npc"].id)
	assert_true(int(strike["damage"]) >= 1)
	assert_eq(Folk.validate_companions(data()).size(), 0)
	var saved: Dictionary = data().family["folk_companions"].duplicate()
	data().family["folk_companions"]["injury"] = "nope"
	data().family["folk_companions"]["blows"] = 0
	assert_eq(Folk.validate_companions(data()).size(), 2)
	data().family["folk_companions"] = saved


func test_quarrel_marks_record_expire_and_shun() -> void:
	var d := data()
	var flags := {}
	var q := {"a": "x", "b": "y", "topic": "rice_debt", "until": 200}
	Folk.record_mark(d, flags, "qingshi_village", q, "side_a", 100)
	var mark := Folk.active_mark(flags, "qingshi_village", 100)
	assert_eq(String(mark["loser"]), "y")
	assert_eq(int(mark["until"]), 100 + int(d.family["folk_quarrels"]["mark_days"]))
	assert_true(Folk.shunned_by_mark(flags, "y", 110))
	assert_false(Folk.shunned_by_mark(flags, "x", 110))
	assert_false(Folk.shunned_by_mark(flags, "y", 131), "expired")
	Folk.record_mark(d, flags, "qingshi_village", q, "side_b", 100)
	assert_eq(String(Folk.active_mark(flags, "qingshi_village", 100)["loser"]), "x")
	Folk.expire_mark(flags, "qingshi_village", 110)
	assert_true(flags.has("quarrel_mark_qingshi_village"))
	Folk.expire_mark(flags, "qingshi_village", 131)
	assert_false(flags.has("quarrel_mark_qingshi_village"), "expiry clears the flag")


func test_shunned_villager_greets_coldly() -> void:
	var d := data()
	var npc := new_character()
	npc.id = "y"
	var flags := {}
	Folk.record_mark(d, flags, "qingshi_village", {"a": "x", "b": "y"}, "side_a", 10)
	var line := Folk.greeting(npc, 50, 11, d, flags)
	assert_true(d.family["folk_greetings"]["shunned"].has(line), line)
	assert_false(d.family["folk_greetings"]["warm"]["lines"].has(line), "cold beats warm")
	assert_false(d.family["folk_greetings"]["shunned"].has(Folk.greeting(npc, 50, 50, d, flags)), "after the season")


func test_mediated_pair_is_seen_together_for_the_season() -> void:
	var d := data()
	var npcs := {}
	var a := Npcs.spawn(npcs, d, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var b := Npcs.spawn(npcs, d, seeded_rng(6), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	var flags := {}
	var region: Dictionary = d.regions["qingshi_village"]
	assert_true(Folk.together_places(npcs, flags, "qingshi_village", region, 10, "").is_empty())
	Folk.record_mark(d, flags, "qingshi_village", {"a": a.id, "b": b.id}, "mediate", 10)
	var places := Folk.together_places(npcs, flags, "qingshi_village", region, 11, "")
	assert_eq(places.size(), 2)
	assert_eq(places[a.id], places[b.id])
	assert_true(Folk.together_places(npcs, flags, "qingshi_village", region, 41, "").is_empty(), "expired")
	Folk.record_mark(d, flags, "qingshi_village", {"a": a.id, "b": b.id}, "extort", 10)
	assert_true(Folk.together_places(npcs, flags, "qingshi_village", region, 11, "").is_empty(), "extort does not unite")


func test_extort_mark_starts_a_rumor_until_it_expires() -> void:
	var d := data()
	var c := new_character()
	var flags := {}
	var q := {"a": "x", "b": "y"}
	assert_false(Rumors.eligible(c, d, flags, "qingshi_village", 10).has("takes_coin_to_settle"))
	Folk.record_mark(d, flags, "qingshi_village", q, "extort", 10)
	assert_true(Rumors.eligible(c, d, flags, "qingshi_village", 11).has("takes_coin_to_settle"))
	assert_false(Rumors.eligible(c, d, flags, "misty_forest", 11).has("takes_coin_to_settle"), "only where it happened")
	assert_false(Rumors.eligible(c, d, flags, "qingshi_village", 41).has("takes_coin_to_settle"))


func test_tea_lines_pick_by_day_and_season() -> void:
	var d := data()
	var a := Folk.tea_line(d, "Wen", "Friendly", 10, "winter", false)
	var b := Folk.tea_line(d, "Wen", "Friendly", 11, "winter", false)
	assert_true(a.contains("Wen") and a.contains("Friendly"))
	assert_true(a != b, "consecutive days differ")
	assert_eq(a, Folk.tea_line(d, "Wen", "Friendly", 10, "winter", false))
	for day in range(0, 40):
		assert_false(Folk.tea_line(d, "Wen", "x", day, "winter", false).contains("melon"), "no summer melon in winter")
	assert_true(Folk.tea_line(d, "Wen", "x", 3, "summer", true) != Folk.tea_line(d, "Wen", "x", 3, "summer", false))
	assert_eq(Folk.validate_visits(d).size(), 0)


func test_tea_lines_validation() -> void:
	var d := data()
	var saved: Dictionary = d.family["folk_visits"].duplicate(true)
	d.family["folk_visits"]["tea_lines"] = []
	assert_gt(Folk.validate_visits(d).size(), 0)
	d.family["folk_visits"] = saved.duplicate(true)
	d.family["folk_visits"]["tea_lines"] = ["No name here"]
	assert_gt(Folk.validate_visits(d).size(), 0)
	d.family["folk_visits"] = saved.duplicate(true)
	d.family["folk_visits"]["tip_tea_lines"] = ["{name} says {oops}"]
	assert_gt(Folk.validate_visits(d).size(), 0)
	d.family["folk_visits"] = saved


func test_wedding_greetings_use_partner() -> void:
	var n := 0
	for line: String in data().family["folk_greetings"]["celebration"]["wedding"]:
		if line.contains("{partner}"):
			n += 1
	assert_true(n >= 2)


func test_birthday_is_stable_and_generated_only() -> void:
	var npcs := {}
	_village(npcs, 2)
	var npc: CharacterData = npcs.values()[0]
	var b := Folk.birthday_day(npc, data())
	assert_true(b >= 0 and b < Calendar.DAYS_PER_YEAR)
	assert_eq(Folk.birthday_day(npc, data()), b)
	assert_true(Folk.birthday_today(npc, data(), b + Calendar.DAYS_PER_YEAR * 3))
	assert_false(Folk.birthday_today(npc, data(), b + 1))
	assert_eq(Folk.days_to_birthday(npc, data(), b + 1), Calendar.DAYS_PER_YEAR - 1)
	var named := CharacterData.new()
	named.id = "elder_mo"
	assert_eq(Folk.birthday_day(named, data()), (3 - 1) * Calendar.DAYS_PER_MONTH + 11)
	for id: String in data().npcs:
		if not data().npcs[id].has("birthday"):
			named.id = id
			assert_eq(Folk.birthday_day(named, data()), -1)
			break


func test_named_birthday_line_gift_and_validation() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng(3))
	var mo: CharacterData = npcs["elder_mo"]
	var day := Folk.birthday_day(mo, data()) + Calendar.DAYS_PER_YEAR
	assert_eq(Folk.greeting(mo, 50, day, data()), String(data().npcs["elder_mo"]["birthday_line"]))
	var flags := {}
	assert_eq(Folk.birthday_gift_multiplier(flags, mo, data(), day, true), 2)
	assert_eq(Folk.birthday_gift_multiplier(flags, mo, data(), day, true), 1)
	assert_eq(Folk.birthdays_soon(npcs, data(), "qingshi_village", day - 2, {"elder_mo": 20})[0]["npc"].id, "elder_mo")
	var d := data()
	var original: Variant = d.npcs["elder_mo"]["birthday"]
	d.npcs["elder_mo"]["birthday"] = {"month": 13, "day": 1}
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("birthday"))
	d.npcs["elder_mo"]["birthday"] = {"month": 3, "day": 0}
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("birthday"))
	d.npcs["elder_mo"]["birthday"] = original
	d.load_errors.clear()


func test_birthday_greeting_uses_birthday_line() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var day := Folk.birthday_day(npc, data()) + Calendar.DAYS_PER_YEAR
	var lines: Array = data().family["folk_greetings"]["birthday"]
	assert_true(lines.has(Folk.greeting(npc, 0, day, data())))
	assert_true(lines.has(Folk.greeting(npc, 50, day, data())))
	assert_false(lines.has(Folk.greeting(npc, 50, day + 1, data())))


func test_birthday_gift_doubles_once_per_year() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var flags := {}
	var day := Folk.birthday_day(npc, data())
	assert_eq(Folk.birthday_gift_multiplier(flags, npc, data(), day + 1, true), 1)
	assert_eq(Folk.birthday_gift_multiplier(flags, npc, data(), day, false), 2)
	assert_eq(Folk.birthday_gift_multiplier(flags, npc, data(), day, true), 2)
	assert_eq(Folk.birthday_gift_multiplier(flags, npc, data(), day, true), 1)
	assert_eq(Folk.birthday_gift_multiplier(flags, npc, data(), day + Calendar.DAYS_PER_YEAR, true), 2)


func test_birthdays_soon_needs_favor_and_window() -> void:
	var npcs := {}
	_village(npcs, 3)
	var ids: Array = npcs.keys()
	var npc: CharacterData = npcs[ids[0]]
	var b := Folk.birthday_day(npc, data())
	var favor := {npc.id: 10}
	var soon := Folk.birthdays_soon(npcs, data(), "qingshi_village", b + Calendar.DAYS_PER_YEAR - 3, favor)
	assert_eq(soon.size(), 1)
	assert_eq(int(soon[0]["in_days"]), 3)
	assert_eq(Folk.birthdays_soon(npcs, data(), "qingshi_village", b + Calendar.DAYS_PER_YEAR - 3, {npc.id: 9}).size(), 0)
	assert_eq(Folk.birthdays_soon(npcs, data(), "qingshi_village", b + 1, favor).size(), 0)
	var lines := Guidance.village_lines(new_character(), data(), npcs, {}, "qingshi_village", b + Calendar.DAYS_PER_YEAR, favor)
	assert_true("\n".join(lines).contains("birthday is today"))


func test_is_birthday_today_needs_favor_and_the_day() -> void:
	var npcs := {}
	_village(npcs, 3)
	var npc: CharacterData = npcs[npcs.keys()[0]]
	var b := Folk.birthday_day(npc, data())
	var day := b + Calendar.DAYS_PER_YEAR
	assert_true(Folk.is_birthday_today(npc, data(), day, {npc.id: 10}))
	assert_false(Folk.is_birthday_today(npc, data(), day, {npc.id: 9}), "strangers are not marked")
	assert_false(Folk.is_birthday_today(npc, data(), day + 1, {npc.id: 50}))
	assert_false(Folk.is_birthday_today(null, data(), day, {}))
	var named: CharacterData = null
	for id: String in data().npcs:
		if data().npcs[id].has("birthday"):
			named = CharacterData.new()
			named.id = id
			break
	if named != null:
		assert_true(Folk.is_birthday_today(named, data(), Folk.birthday_day(named, data()), {named.id: 20}))


func test_people_entries_filter_order_and_tastes() -> void:
	var npcs := {}
	_village(npcs, 3)
	var ids: Array = npcs.keys()
	var favor := {ids[0]: 9, ids[1]: 30, ids[2]: 30}
	# Only real item ids count (Family.known_tastes): "taste_<id>_nope" is ignored.
	var flags := {"taste_%s_spirit_herb" % ids[1]: 1, "taste_%s_iron_essence" % ids[1]: -1, "taste_%s_moon_cake" % ids[1]: 1, "taste_%s_nope" % ids[1]: 1}
	var rows := Folk.people_entries(npcs, data(), "qingshi_village", favor, flags, 0)
	assert_eq(rows.size(), 2, "favor 9 excluded")
	assert_true(String(rows[0]["name"]) <= String(rows[1]["name"]), "ties by name")
	var r: Dictionary = rows[0] if rows[0]["id"] == ids[1] else rows[1]
	assert_eq(r["likes_known"], ["moon_cake", "spirit_herb"])
	assert_eq(r["dislikes_known"], ["iron_essence"])
	assert_true(String(r["birthday_text"]).begins_with("Month "))
	favor[ids[2]] = 50
	assert_eq(Folk.people_entries(npcs, data(), "qingshi_village", favor, flags, 0)[0]["id"], ids[2], "favor desc")


func test_people_entries_named_npc_birthday() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng(3))
	var rows := Folk.people_entries(npcs, data(), "qingshi_village", {"elder_mo": 20}, {}, 0)
	assert_eq(rows[0]["birthday_text"], "Month 3, Day 12")
	assert_true(int(rows[0]["birthday_in"]) >= 0)
	assert_true(int(rows[0]["likes_total"]) > 0)


func test_news_line_fresh_local_villager_only() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var flags := {}
	assert_eq(Folk.news_line(npc, flags, data(), "qingshi_village", 10), "")
	Folk.record_news(flags, "great_beast", "Great Wolf", "qingshi_village", 10)
	var line := Folk.news_line(npc, flags, data(), "qingshi_village", 11)
	assert_true(line.contains("Great Wolf"))
	assert_false(line.contains("{subject}"))
	assert_eq(Folk.news_line(npc, flags, data(), "qingshi_village", 17), "", "stale after news_days")
	for rid: String in data().regions:
		if rid != "qingshi_village" and not Exploration.is_nearby(data(), "qingshi_village", rid):
			assert_eq(Folk.news_line(npc, flags, data(), rid, 11), "", "far region " + rid)
	var elder := CharacterData.new()
	elder.id = "elder_x"
	elder.sect = {"id": "azure_cloud"}
	assert_eq(Folk.news_line(elder, flags, data(), "qingshi_village", 11), "")


func test_news_beats_warm_but_not_birthday_or_cool() -> void:
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var flags := {}
	var day := Folk.birthday_day(npc, data()) + Calendar.DAYS_PER_YEAR
	Folk.record_news(flags, "breakthrough", "Foundation Establishment", "qingshi_village", day - 1)
	var cake: Array = data().family["folk_greetings"]["birthday"]
	assert_true(cake.has(Folk.greeting(npc, 50, day, data(), flags, "", "qingshi_village")))
	var news := Folk.greeting(npc, 50, day + 1, data(), flags, "", "qingshi_village")
	assert_true(news.contains("Foundation Establishment"))
	assert_eq(Folk.greeting(npc, 0, day + 1, data(), flags, "", "qingshi_village"), news, "neutral villagers talk too")
	var cool: Array = data().family["folk_greetings"]["cool"]["lines"]
	assert_true(cool.has(Folk.greeting(npc, -50, day + 1, data(), flags, "", "qingshi_village")))
	assert_false(Folk.greeting(npc, 50, day + 1, data(), flags).contains("Foundation"), "no region, no news")


func test_news_validation() -> void:
	var d := data()
	var saved: Variant = d.family["folk_greetings"].get("news")
	d.family["folk_greetings"]["news"] = {"news_days": 7, "bogus": ["x"]}
	assert_false(Folk.validate_greetings(d).is_empty())
	d.family["folk_greetings"]["news"] = {"contest_win": [""]}
	assert_false(Folk.validate_greetings(d).is_empty())
	d.family["folk_greetings"]["news"] = {"news_days": 31}
	assert_false(Folk.validate_greetings(d).is_empty())
	d.family["folk_greetings"]["news"] = saved
	assert_true(Folk.validate_greetings(d).is_empty())


func test_gift_memory_window_and_once() -> void:
	var d := data()
	var flags := {}
	Folk.record_gift(flags, "x", "spirit_herb", 100, 1)
	assert_eq(Folk.gift_memory_line(flags, "x", d, 100, true), "", "same day: nothing")
	assert_true(Folk.gift_memory_line(flags, "x", d, 101, false).contains("spirit herb"), "next day")
	assert_true(Folk.gift_memory_line(flags, "x", d, 101, true) != "")
	assert_eq(Folk.gift_memory_line(flags, "x", d, 102, true), "", "once")
	Folk.record_gift(flags, "x", "spirit_herb", 100, -1)
	assert_eq(Folk.gift_memory_line(flags, "x", d, 131, true), "", "after 30 days")
	assert_true(Folk.gift_memory_line(flags, "x", d, 130, true) != "", "day 30 still counts")
	assert_eq(Folk.last_gift_text(flags, "x", d), "Last gift: Spirit Herb (disliked)")
	assert_eq(Folk.last_gift_text({}, "x", d), "", "old save without the flag")


func test_gift_memory_validation() -> void:
	var d := data()
	var saved: Variant = d.family["gift_memory"]
	d.family["gift_memory"] = {"days": 30, "liked": ["no placeholder"], "neutral": ["{item}"], "disliked": ["{item}"]}
	assert_false(Folk.validate_gift_memory(d).is_empty())
	d.family["gift_memory"] = {"days": 0, "liked": ["{item}"], "neutral": ["{item}"], "disliked": ["{item}"]}
	assert_false(Folk.validate_gift_memory(d).is_empty())
	d.family["gift_memory"] = saved
	assert_true(Folk.validate_gift_memory(d).is_empty())


func test_project_news_uses_own_lines_when_present() -> void:  # SEASON-016
	var npcs := {}
	_village(npcs, 1)
	var npc: CharacterData = npcs.values()[0]
	var d := data()
	var jetty: Dictionary = {}
	for p: Dictionary in SeasonTasks.project_list(d):
		if p["id"] == "jetty":
			jetty = p
	var own: Array = jetty["news"]
	var generic: Array = d.family["folk_greetings"]["news"]["project_stage"]
	var own_hits := 0
	for day in range(10, 60):
		var flags := {}
		Folk.record_news(flags, "project_stage", "the Village Pond Jetty", "qingshi_village", day, "jetty")
		var line := Folk.news_line(npc, flags, d, "qingshi_village", day)
		var plain := {}
		Folk.record_news(plain, "project_stage", "the Village Pond Jetty", "qingshi_village", day)
		var base := Folk.news_line(npc, plain, d, "qingshi_village", day)
		assert_true(line != "")
		if own.has(line):
			own_hits += 1
		else:
			assert_eq(line, base, "falls back to the generic pool")
		assert_true(generic.size() > 0)
	assert_true(own_hits > 20 and own_hits < 50, "about 70 percent own lines: %d" % own_hits)


func test_project_news_validation_rejects_unknown_placeholder() -> void:  # SEASON-016
	var d := data()
	var proj: Dictionary = {}
	for p: Dictionary in d.season_tasks["restoration"]["projects"]:
		if p["id"] == "jetty":
			proj = p
	var saved: Variant = proj["news"]
	proj["news"] = ["Hello {nobody}"]
	assert_true(SeasonTasks.validate(d).size() > 0)
	proj["news"] = saved
	assert_eq(SeasonTasks.validate(d).size(), 0)
