extends TestCase
## Guidance: next-step hints built from player state.


func _fresh() -> CharacterData:
	var c := new_character()
	c.realm_index = 0
	c.stage = 0
	c.qi = 0.0
	c.inventory = {}
	return c


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _has(hints: PackedStringArray, fragment: String) -> bool:
	for h in hints:
		if h.contains(fragment):
			return true
	return false


func test_new_character_gets_qi_and_starter_hints() -> void:
	var c := _fresh()
	c.professions = {}
	c.techniques = {}
	var hints := Guidance.hints(c, data(), 1.0, 10)
	assert_true(_has(hints, "more qi to reach the next stage"))
	var pay: int = Professions.work_preview(c, data(), "doctor", Calendar.DAYS_PER_MONTH)["income"]
	assert_true(_has(hints, "about %d spirit stones a month" % pay))
	assert_true(_has(hints, "breathing technique"))


func test_limit_caps_hint_count() -> void:
	var c := _fresh()
	c.professions = {}
	c.techniques = {}
	assert_eq(Guidance.hints(c, data(), 1.0, 2).size(), 2)


func test_bottleneck_shows_breakthrough_odds_and_held_pills() -> void:
	var c := _fresh()
	var realm: RealmDef = data().realms[0]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	var hints := Guidance.hints(c, data(), 1.0, 10)
	var pct := roundi(Cultivation.breakthrough_chance(c, data()) * 100)
	assert_true(_has(hints, "(%d%% chance)" % pct))
	assert_true(_has(hints, "Breakthrough pills raise the odds"))
	var pill := ""
	for item: Dictionary in data().items.values():
		var fx: Dictionary = item.get("effects", {})
		if float(fx.get("breakthrough_bonus", 0.0)) > 0.0 and Effects.check(c, data(), fx) == "":
			pill = item["id"]
			break
	c.add_item(pill, 1)
	assert_eq(Guidance.breakthrough_items(c, data()), PackedStringArray([data().items[pill]["name"]]))
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10), "Using %s first" % data().items[pill]["name"]))


## RV-005 pills are tied to their realm, one per attempt: hints and the journal
## must not recommend a pill the player cannot use now.
func test_realm_tied_pills_are_only_recommended_when_usable() -> void:
	var c := _fresh()
	c.realm_index = data().realm_index_of("qi_refining")
	var realm: RealmDef = data().realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	c.add_item("core_forming_pill", 1)
	c.add_item("foundation_establishment_pill", 2)
	var core_name: String = data().items["core_forming_pill"]["name"]
	var fe_name: String = data().items["foundation_establishment_pill"]["name"]
	assert_eq(Guidance.breakthrough_items(c, data()), PackedStringArray([fe_name]))
	c.breakthrough_bonus = 0.25  # one pill already taken
	c.breakthrough_pill = "foundation_establishment"
	assert_eq(Guidance.breakthrough_items(c, data()), PackedStringArray())
	var rows := Guidance.journal(c, data(), {}, 0, c.home_region)
	assert_false(rows.any(func(r: Dictionary) -> bool: return not String(r["text"]).begins_with("Odds now: ") and (String(r["text"]).contains(core_name) or String(r["text"]).contains(fe_name))))


func test_urgent_hints_come_first() -> void:
	var c := _fresh()
	c.age_days = (Cultivation.lifespan_years(c, data()) - 3) * Calendar.DAYS_PER_YEAR
	Injuries.inflict(c, data(), "qi_deviation")
	var hints := Guidance.hints(c, data())
	assert_true(hints[0].begins_with("Only 3 years of life remain"))
	assert_true(hints[1].begins_with("Treat your injuries"))


func test_pregnancy_and_low_artifact_lives() -> void:
	var c := _fresh()
	c.pregnancy = {"partner": "x", "days_left": 30}
	c.artifact_lives = 1
	var hints := Guidance.hints(c, data(), 1.0, 10)
	assert_true(_has(hints, "A child is due in %s." % Calendar.format_duration(30)))
	assert_true(_has(hints, "holds 1 life"))


func test_artifact_lives_hint_is_honest_about_stones() -> void:
	var c := _fresh()
	c.artifact_lives = 1
	c.add_item("spirit_stone", 40)
	var text := Guidance.artifact_lives_hint(c, data())
	assert_true(text.contains("holds 1 life"))
	assert_true(text.ends_with("You hold 40."))
	c.add_item("spirit_stone", 500)
	assert_false(Guidance.artifact_lives_hint(c, data()).contains("You hold"))
	c.artifact_lives = 0
	assert_true(Guidance.artifact_lives_hint(c, data()).contains("next death is final"))
	c.artifact_lives = 2
	assert_eq(Guidance.artifact_lives_hint(c, data()), "")
	c.artifact_lives = -1
	assert_eq(Guidance.artifact_lives_hint(c, data()), "")


func test_sect_hints_for_rogue_and_member() -> void:
	var c := _fresh()
	c.alignment = -500
	c.realm_index = 1
	var rogue := Guidance.hints(c, data(), 1.0, 10)
	var open_sects: PackedStringArray = []
	for sect: SectDef in data().sects.values():
		if Sects.check_join(c, data(), sect.id)["ok"]:
			open_sects.append(sect.name)
	assert_eq(_has(rogue, "As a rogue cultivator"), not open_sects.is_empty())
	var sect: SectDef = data().sects.values()[0]
	c.alignment = 0
	c.sect = {"id": sect.id, "rank": 0, "contribution": 100, "spent": 0}
	var need := int(sect.ranks[1]["contribution"]) - 100
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10), "Earn %d more sect contribution" % need))


## UI-009b: missions, promotion trials, tribulations, Dao, abodes and family.
func test_system_hints() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	c.inventory["spirit_herb"] = 5
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "ready on the mission board"))
	c.sect["contribution"] = 600
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "The trial for Inner Disciple is open"))
	var insight_id: String = d.dao_insights.keys()[0]
	Dao.gain_levels(c, d, insight_id, 1)
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Contemplate the %s" % Dao.def_of(d, insight_id)["name"]))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Claim a cave abode"))
	c.abode = "waterfall_cave"
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Cultivate in seclusion at %s" % Abodes.abode_name(d, "waterfall_cave")))
	var people := {}
	c.age_days = 20 * Calendar.DAYS_PER_YEAR
	assert_true(_has(Guidance.hints(c, d, 1.0, 20, people), "court") == false, "no family hints without people")
	people["someone"] = new_character()
	assert_true(_has(Guidance.hints(c, d, 1.0, 20, people), "court them"))
	var spouse := Npcs.spawn(people, d, seeded_rng(), {"gender": "female" if c.gender == "male" else "male", "region": "qingshi_village"})
	spouse.age_days = 20 * Calendar.DAYS_PER_YEAR
	Family.marry(c, spouse, Family.ranks(d, c.gender)[0])
	assert_eq(Children.check_conception(c, spouse, d), "")
	assert_true(_has(Guidance.hints(c, d, 1.0, 20, people), "try for a child with %s" % spouse.name))


func test_tribulation_warning_at_the_bottleneck() -> void:
	var d := data()
	var c := new_character()
	for i in d.realms.size() - 1:
		if Tribulation.has_tribulation(d, i + 1):
			c.realm_index = i
			break
	c.stage = d.realms[c.realm_index].stage_count() - 1
	c.qi = d.realms[c.realm_index].qi_required(c.stage)
	assert_true(Cultivation.can_attempt_breakthrough(c, d))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Heavenly Tribulation"))


func test_newcomer_points_to_elder_mo_until_talked() -> void:
	var c := _fresh()
	var hints := Guidance.hints(c, data(), 1.0, 5, {}, {}, "qingshi_village")
	assert_true(hints[0].contains("Elder Mo"))
	hints = Guidance.hints(c, data(), 1.0, 5, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "teaches a breathing technique for free"))
	assert_false(_has(hints, "Ask Elder Mo"))


func test_newcomer_pill_hint_precedes_cultivation_hint() -> void:
	var c := _fresh()
	c.inventory = {"qi_gathering_pill": 1}
	var hints := Guidance.hints(c, data(), 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(hints[0].contains("Use your Qi Gathering Pill"))
	var pill_at := 0
	var qi_at := 0
	for i in hints.size():
		if hints[i].contains("Use your"):
			pill_at = i
		if hints[i].contains("more qi to reach"):
			qi_at = i
	assert_true(pill_at < qi_at)


func test_headman_chores_hint_only_in_village_until_done() -> void:
	var c := _fresh()
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "qingshi_village"), "Headman Zhou"))
	assert_false(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "misty_forest"), "Headman Zhou"))
	flags.merge({"chore_herbs_done": true, "chore_boar_done": true, "chore_roof_done": true})
	assert_false(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "qingshi_village"), "Headman Zhou"))


func test_no_newcomer_hints_past_qi_refining() -> void:
	var c := _fresh()
	c.realm_index = 2
	c.inventory = {"qi_gathering_pill": 1}
	var hints := Guidance.hints(c, data(), 1.0, 10, {}, {}, "qingshi_village")
	assert_false(_has(hints, "Elder Mo"))
	assert_false(_has(hints, "Use your"))
	assert_false(_has(hints, "Headman Zhou"))


func test_newcomer_pill_hint_skips_harmful_pills() -> void:
	var c := _fresh()
	c.inventory = {"blood_essence_pill": 1, "blood_demon_pill": 1}
	var hints := Guidance.hints(c, data(), 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_false(_has(hints, "Use your"))
	c.inventory["qi_gathering_pill"] = 1
	hints = Guidance.hints(c, data(), 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Use your Qi Gathering Pill"))


func test_better_qi_hint_names_the_best_reachable_spot() -> void:
	var c := _fresh()
	c.realm_index = 1
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(hints, "Meditation at Cloud-Sea Cliff (2x qi) in Azure Peak gathers qi x2.5 faster than here."))


func test_better_qi_hint_respects_travel_gating() -> void:
	var c := _fresh()
	c.realm_index = 0
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_false(_has(hints, "Meditation at"))


func test_better_qi_hint_absent_at_the_best_spot_or_bottleneck() -> void:
	var c := _fresh()
	c.realm_index = 1
	assert_false(_has(Guidance.hints(c, data(), 1.0, 20, {}, {}, "azure_peak"), "Meditation at"))
	assert_false(_has(Guidance.hints(c, data(), 1.0, 20), "Meditation at"))
	c.stage = data().realms[1].stage_count() - 1
	c.qi = Cultivation.qi_required(c, data()) * 10.0
	assert_false(_has(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"), "Meditation at"))


func test_recap_names_character_place_and_next_step() -> void:
	var c := _fresh()
	c.name = "Lin"
	var lines := Guidance.recap(c, data(), {}, 0, "qingshi_village")
	assert_true(lines.size() >= 2 and lines.size() <= 3)
	assert_true(lines[0].begins_with("Lin, "))
	assert_true(lines[0].contains("in Qingshi Village."))
	assert_eq(lines[1], Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 0)[0])


func test_recap_adds_a_different_warning_line() -> void:
	var c := _fresh()
	c.age_days = (Cultivation.lifespan_years(c, data()) - 2) * Calendar.DAYS_PER_YEAR
	var lines := Guidance.recap(c, data(), {}, 0, "qingshi_village")
	assert_true(_has(lines, "of life remain"))


func test_loaded_save_starts_the_log_with_a_recap() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Hermit", gs.data, seeded_rng())
	gs.start_session(c)
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	var history: Array = _root().get_node("EventBus").history
	assert_true(history.size() >= 2)
	assert_true(String(history[0]["text"]).begins_with("Hermit, "))
	for entry: Dictionary in history:
		assert_false(String(entry["text"]).contains("%") or String(entry["text"]).contains("{"))
	gs.end_session()


# --- GUIDE-005: outgrown cultivation method ---------------------------------

func _outgrown() -> CharacterData:
	var c := _fresh()
	c.techniques["verdant_spring_method"] = {"level": 1, "xp": 0.0}
	c.main_method = "verdant_spring_method"
	c.realm_index = data().realm_index_of("core_formation")
	return c


func test_outgrown_method_hint_names_cap_and_rate() -> void:
	var c := _outgrown()
	var hints := Guidance.hints(c, data(), 1.0, 20)
	assert_true(_has(hints, "Verdant Spring Method teaches nothing past Foundation Establishment"))
	assert_true(_has(hints, "fallen to x%s" % String.num(data().method_over_cap_rate, 2)))
	assert_true(_has(hints, "Look for the"), "points at a manual")
	for h in hints:
		if h.contains("teaches nothing past"):
			assert_false(h.contains("%") or h.contains("{"), h)


func test_outgrown_method_hint_names_a_known_better_method() -> void:
	var c := _outgrown()
	c.techniques["azure_cloud_heart_sutra"] = {"level": 1, "xp": 0.0}
	var hints := Guidance.hints(c, data(), 1.0, 20)
	assert_true(_has(hints, "you know the Azure Cloud Heart Sutra"))
	for h in hints:
		assert_false(h.contains("Look for the") and not h.contains("no fighting style"), h)


func test_method_hint_warns_before_outgrowing_and_is_absent_when_fine() -> void:
	assert_false(_has(Guidance.hints(_fresh(), data(), 1.0, 20), "teaches nothing"))
	var c := _outgrown()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.stage = data().realms[c.realm_index].stage_names.size() - 1
	c.qi = 1.0e12
	assert_true(Cultivation.is_at_bottleneck(c, data()))
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20), "stops at Foundation Establishment"))


func test_outgrown_method_is_a_warning_in_the_journal() -> void:
	var c := _outgrown()
	var rows := Guidance.journal(c, data(), {}, 0, c.home_region)
	var found := false
	for row in rows:
		if String(row["text"]).contains("teaches nothing past"):
			found = true
			assert_eq(row["tone"], "warning")
	assert_true(found)


func test_chance_text_format() -> void:
	var c := _fresh()
	c.attributes["fortune"] = 14
	var text := Guidance.chance_text(c, data())
	assert_true(text.begins_with("Base "), text)
	assert_true(text.contains("Fortune 14 4%"), text)
	assert_true(text.ends_with("= %d%%." % roundi(Cultivation.breakthrough_chance(c, data()) * 100)), text)
	c.breakthrough_bonus = 5.0
	assert_true(Guidance.chance_text(c, data()).ends_with("(capped at 99%)."))
	assert_false(text.contains("{"))


func test_pill_source_hint_for_next_realm() -> void:
	var c := _fresh()
	c.realm_index = 1
	var hint := Guidance.pill_source_hint(c, data())
	assert_true(hint.contains("Pill"), hint)
	assert_true(hint.contains("(+"), hint)
	for item: Dictionary in data().items.values():
		if String(item.get("effects", {}).get("breakthrough_realm", "")) == "foundation_establishment":
			c.add_item(item["id"], 1)
	assert_eq(Guidance.pill_source_hint(c, data()), "")
	c.inventory = {}
	c.breakthrough_pill = "foundation_establishment"
	assert_eq(Guidance.pill_source_hint(c, data()), "")


func test_meditation_preview_forms() -> void:
	var c := _fresh()
	c.realm_index = 1
	var normal := Guidance.meditation_preview(c, data(), 1, 1.8)
	assert_true(normal.begins_with("About +"))
	assert_true(normal.contains("x1.8 qi here"))
	var big := Guidance.meditation_preview(c, data(), 3600, 1.0)
	assert_true(big.contains("reaches the bottleneck after"))
	var realm: RealmDef = data().realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	var stuck := Guidance.meditation_preview(c, data(), 30, 1.0)
	assert_true(stuck.contains("bottleneck"))
	for t in [normal, big, stuck]:
		assert_false(t.contains("%") or t.contains("{"))


# --- GUIDE-007: try something new --------------------------------------------

func _veteran() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.known_recipes.clear()
	for key in LifeStats.KEYS:
		c.life_stats[key] = 1
	return c


func test_untried_explore_hint_and_age_gates() -> void:
	var c := _veteran()
	c.life_stats["encounters"] = 0
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 400), "Explore the wilds"))
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", Guidance.UNTRIED_MIN_DAYS - 1), "Explore the wilds"), "too early")
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", Guidance.UNTRIED_MIN_DAYS), "Explore the wilds"), "from the third month")
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", -1), "Explore the wilds"), "no clock")
	c.realm_index = 0
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 200), "Explore the wilds"), "not for Mortals")


func test_untried_recipe_hint() -> void:
	var c := _veteran()
	c.life_stats["items_crafted"] = 0
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 400), "You know a recipe"), "no recipe known")
	c.known_recipes.append("any_recipe")
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 400), "You know a recipe"))


func test_untried_secret_realm_hint_and_done_character() -> void:
	var c := _veteran()
	c.life_stats["realm_floors_cleared"] = 0
	var d := data()
	var def := {"id": "test_realm", "name": "Test Realm", "region": "misty_forest", "period_years": 5, "offset_years": 1, "open_days": 60,
		"min_realm": "qi_refining", "max_realm": "qi_refining", "floors": []}
	d.secret_realms["test_realm"] = def
	var open_day := Calendar.DAYS_PER_YEAR
	assert_true(_has(Guidance.hints(c, d, 1.0, 99, {}, {}, "", open_day), "Test Realm is open: delve for treasure."))
	assert_false(_has(Guidance.hints(c, d, 1.0, 99, {}, {}, "", open_day + 100), "delve for treasure"), "closed")
	c.life_stats["realm_floors_cleared"] = 1
	assert_false(_has(Guidance.hints(c, d, 1.0, 99, {}, {}, "", open_day), "delve for treasure"))
	d.secret_realms.erase("test_realm")
	assert_eq(Guidance._untried_hint(c, d, open_day), "", "someone who has done everything gets nothing")


func test_untried_hint_does_not_duplicate_and_respects_limit() -> void:
	var c := _veteran()
	c.life_stats["encounters"] = 0
	var all := Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 400)
	var seen := {}
	for h in all:
		assert_false(seen.has(h), "duplicate hint: " + h)
		seen[h] = true
	var idx := -1
	for i in all.size():
		if all[i].contains("Explore the wilds"):
			idx = i
	assert_gt(idx, -1)
	assert_false(_has(Guidance.hints(c, data(), 1.0, idx, {}, {}, "", 400), "Explore the wilds"), "limit cuts it")
	assert_true(_has(Guidance.hints(c, data(), 1.0, idx + 1, {}, {}, "", 400), "Explore the wilds"))


## FH-030: honest newcomer hints and the first-goals ladder.
func test_mortal_sect_hint_is_not_a_recommendation() -> void:
	var c := _fresh()
	var hint := Guidance._sect_hint(c, data())
	assert_true(hint.contains("Reach Qi Refining"))
	assert_true(hint.contains("Azure Cloud"))
	assert_false(hint.begins_with("As a rogue cultivator you could join Blood Lotus"))
	if hint.contains("Blood Lotus"):
		assert_true(hint.contains("demonic"))


func test_qi_refining_rogue_sect_hint_wording_unchanged() -> void:
	var c := _fresh()
	c.realm_index = 1
	var hint := Guidance._sect_hint(c, data())
	assert_true(hint == "" or hint.begins_with("As a rogue cultivator you could join"))


func test_one_elder_mo_line_mentions_breathing() -> void:
	var c := _fresh()
	c.techniques = {}
	var n := 0
	for h in Guidance._newcomer_hints(c, data(), {}, "qingshi_village"):
		if h.contains("Elder Mo"):
			n += 1
			assert_true(h.contains("breathing technique"))
	assert_eq(n, 1)
	c.techniques = {"basic_breathing": {"level": 1}}
	assert_false(_has(Guidance._newcomer_hints(c, data(), {}, "qingshi_village"), "technique"))


func test_first_goals_ladder_and_journal_section() -> void:
	var c := _fresh()
	var goals := Guidance.first_goals(c, data(), {})
	assert_eq(goals.size(), 7)
	for g in goals:
		assert_false(g["done"])
		for bad in ["%", "{", "<null>"]:
			assert_false(String(g["text"]).contains(bad))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_eq(section.size(), 7)
	assert_eq(section.filter(func(e: Dictionary) -> bool: return e["tone"] == "warning").size(), 1)
	assert_eq(section[0]["tone"], "warning")
	assert_true(String(section[0]["text"]).begins_with("[ ] "))
	c.techniques = {"basic_breathing": {"level": 1}}
	assert_false(Guidance.first_goals(c, data(), {})[2]["done"])
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	assert_true(Guidance.first_goals(c, data(), {})[2]["done"])
	c.realm_index = 1
	c.stage = 2
	c.sect = {"id": data().sects.keys()[0], "rank": 0, "contribution": 0, "spent": 0}
	LifeStats.add(c, "fights_won")
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_true(Guidance.first_goals_done(c, data(), flags))
	var after := Guidance.journal(c, data(), flags, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_true(after.is_empty())


func test_first_goals_hidden_past_qi_refining() -> void:
	# An old save past Qi Refining with no Elder Mo flag or life stats must not keep the ladder.
	var c := _fresh()
	c.realm_index = 2
	c.techniques = {"basic_breathing": {"level": 1}}
	assert_false(Guidance.first_goals_done(c, data(), {}))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_true(section.is_empty())


func _notice_ids(notices: Array[Dictionary]) -> Array:
	return notices.map(func(n: Dictionary) -> String: return n["id"])


func test_unlock_notices_body_tempering_needs_the_realm() -> void:
	var d := data()
	var c := _fresh()
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {})).has("body_tempering"))
	c.realm_index = 1
	var notices := Guidance.unlock_notices(c, d, {})
	assert_true(_notice_ids(notices).has("body_tempering"))
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {"notice_body_tempering": true})).has("body_tempering"))


func test_unlock_notices_new_roads() -> void:
	var d := data()
	var c := _fresh()
	var ids := _notice_ids(Guidance.unlock_notices(c, d, {}))
	assert_false(ids.any(func(i: String) -> bool: return i.begins_with("road_")))
	c.realm_index = 1
	var notices := Guidance.unlock_notices(c, d, {})
	ids = _notice_ids(notices)
	assert_true(ids.has("road_azure_peak"))
	assert_true(ids.has("road_withered_bone_marsh"))
	assert_false(ids.has("road_myriad_peaks_ridge"))
	for n in notices:
		if n["id"] == "road_azure_peak":
			assert_true(String(n["text"]).contains("7 days"))
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {"notice_road_azure_peak": true})).has("road_azure_peak"))


func test_unlock_notices_dao_insight() -> void:
	var d := data()
	var c := _fresh()
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {})).has("dao"))
	Dao.gain_levels(c, d, d.dao_insights.keys()[0], 1)
	assert_true(_notice_ids(Guidance.unlock_notices(c, d, {})).has("dao"))


func test_unlock_notices_artifact_functions() -> void:
	var d := data()
	var c := _fresh()
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {})).has("inner_world"))
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.artifact_energy = 1500
	var notices := Guidance.unlock_notices(c, d, {})
	assert_true(_notice_ids(notices).has("inner_world"))
	assert_false(_notice_ids(notices).has("spirit_garden"), "the garden needs the inner world first")
	assert_true(String(notices.filter(func(n: Dictionary) -> bool: return n["id"] == "inner_world")[0]["text"]).contains("Inner World"))
	assert_false(String(notices.filter(func(n: Dictionary) -> bool: return n["id"] == "inner_world")[0]["text"]).contains("("), "no key named in core text")


func test_unlock_notices_rival() -> void:
	var d := data()
	var c := _fresh()
	var people := {}
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {}, people)).has("rival"))
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var notices := Guidance.unlock_notices(c, d, {}, people)
	assert_true(_notice_ids(notices).has("rival"))
	assert_true(String(notices.filter(func(n: Dictionary) -> bool: return n["id"] == "rival")[0]["text"]).contains(rival.name))


func _breakthrough_lines(c: CharacterData) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for e in Guidance.journal(c, data(), {}, 0, "qingshi_village"):
		if String(e.get("section", "")) == "Breakthrough":
			lines.append(e)
	return lines


func _line_starting(lines: Array[Dictionary], prefix: String) -> Dictionary:
	for e in lines:
		if String(e["text"]).begins_with(prefix):
			return e
	return {}


func test_journal_breakthrough_shows_odds_and_pill_source() -> void:
	var c := _fresh()
	c.realm_index = 1
	var realm: RealmDef = data().realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	var lines := _breakthrough_lines(c)
	var odds := _line_starting(lines, "Odds now: ")
	assert_false(odds.is_empty())
	assert_true(String(odds["text"]).ends_with("%."), String(odds["text"]))
	assert_false(_line_starting(lines, "To raise them: ").is_empty())
	for e in lines:
		assert_false(String(e["text"]).contains("{"))
	for item: Dictionary in data().items.values():
		if String(item.get("effects", {}).get("breakthrough_realm", "")) == "foundation_establishment":
			c.add_item(item["id"], 1)
	assert_true(_line_starting(_breakthrough_lines(c), "To raise them: ").is_empty())


func test_journal_prepare_line_only_close_to_the_bottleneck() -> void:
	var c := _fresh()
	c.realm_index = 1
	var realm: RealmDef = data().realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage) - Cultivation.qi_per_day(c, data(), 1.0) * 10.0
	var days := Cultivation.days_to_bottleneck(c, data(), 1.0)
	assert_true(days >= 1 and days <= 30, str(days))
	var prepare := _line_starting(_breakthrough_lines(c), "Prepare: ")
	assert_false(prepare.is_empty())
	assert_eq(String(prepare["tone"]), "dim")
	c.stage = 0
	c.qi = 0.0
	assert_true(Cultivation.days_to_bottleneck(c, data(), 1.0) > 30)
	assert_true(_line_starting(_breakthrough_lines(c), "Prepare: ").is_empty())

func test_long_waits_read_in_years() -> void:
	var c := _fresh()
	c.realm_index = 5
	c.stage = 0
	c.qi = 0.0
	var days := Cultivation.days_to_bottleneck(c, data(), 1.0)
	assert_true(days > 720, str(days))
	var line := _line_starting(_breakthrough_lines(c), "About ")
	assert_true(String(line.get("text", "")).contains("years of meditation"), str(line))
	var goals := Guidance.goals(c, data(), {})
	assert_true(" ".join(goals).contains("years of meditation"), str(goals))

func test_sell_hint() -> void:
	var d := data()
	var c := _fresh()
	assert_eq(Guidance._sell_hint(c, d, "qingshi_village"), "", "nothing to sell")
	c.add_item("spirit_herb", 10)
	assert_eq(Guidance._sell_hint(c, d, "qingshi_village"), "", "below the minimum")
	c.add_item("spirit_herb", 30)
	var total := Items.sell_price(d, "spirit_herb") * 40
	var hint := Guidance._sell_hint(c, d, "qingshi_village")
	assert_true(total >= Guidance.SELL_HINT_MIN)
	assert_true(hint.contains("Wandering Merchant"), hint)
	assert_true(hint.contains("%d spirit stones" % total), hint)
	assert_true(hint.contains("herbs"), hint)
	assert_true(Guidance.hints(c, d, 1.0, 99, {}, {}, "qingshi_village").has(hint))
	assert_eq(Guidance._sell_hint(c, d, ""), "")
	assert_eq(Guidance._sell_hint(c, d, "misty_forest"), "", "no merchant in the region")


# --- GOAL-003: mid-game goals ------------------------------------------------

func _goal_lines(c: CharacterData, flags: Dictionary = {}, clan: ClanData = null) -> PackedStringArray:
	var out: PackedStringArray = []
	for e in Guidance.journal(c, data(), flags, 0, "qingshi_village", 1.0, {}, [], clan):
		if e["section"] == "Goals":
			out.append(String(e["text"]))
	return out


func test_newcomer_sees_first_goals_not_goals() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.stage = 2
	assert_true(_goal_lines(c).is_empty())


func test_disciple_goals_have_realm_and_rank_lines() -> void:
	var c := new_character()
	c.realm_index = 2
	c.stage = 1
	c.sect = {"id": data().sects.keys()[0], "rank": 0, "contribution": 0, "spent": 0}
	var lines := _goal_lines(c)
	assert_true(lines.size() >= 2)
	assert_true(lines[0].begins_with("Reach "))
	assert_true(_has(lines, "Become "))
	for l in lines:
		for bad in ["%d", "{", "<null>", "null"]:
			assert_false(l.contains(bad))


func test_rogue_goal_names_clan_and_final_realm_has_no_realm_line() -> void:
	var c := new_character()
	c.realm_index = 2
	c.sect = {}
	assert_true(_has(Guidance.goals(c, data(), {}), "Found a clan: "))
	c.realm_index = data().realms.size() - 1
	for l in Guidance.goals(c, data(), {}):
		assert_false(l.begins_with("Reach "))


func test_profession_goal_line() -> void:
	var c := CharacterData.new()
	c.realm_index = 1
	assert_false(_has(Guidance.goals(c, data(), {}), "Become "))
	c.professions["alchemist"] = {"rank": 0, "xp": 10.0}
	var def: ProfessionDef = data().professions["alchemist"]
	var want := "Become %s Alchemist: %d more xp" % [data().profession_rank_names[1], ceili(def.xp_to_next(0) - 10.0)]
	assert_true(_has(Guidance.goals(c, data(), {}), want), str(Guidance.goals(c, data(), {})))
	assert_true(Guidance.goals(c, data(), {}).size() <= 4)
	for l in Guidance.goals(c, data(), {}):
		assert_false(l.contains("_") or l.contains("%"), l)
	c.professions["alchemist"] = {"rank": Professions.max_rank(data()), "xp": 0.0}
	assert_false(_has(Guidance.goals(c, data(), {}), "more xp"))
	c.professions = {"doctor": {"rank": 0, "xp": 0.0}}
	assert_true(_has(Guidance.goals(c, data(), {}), "Doctor: "), str(Guidance.goals(c, data(), {})))
	for l in Guidance.goals(c, data(), {}):
		assert_false(l.contains("workshop"), l)


func test_rank_goal_without_trial_uses_requirement_helpers() -> void:
	var d := GameData.load_from_dir()
	var sect_id: String = d.sects.keys()[0]
	var sect: SectDef = d.sects[sect_id]
	sect.ranks[1].erase("trial")
	sect.ranks[1].erase("min_realm")
	sect.ranks[1]["contribution"] = 500
	var c := new_character()
	c.realm_index = 2
	c.stage = 1
	c.sect = {"id": sect_id, "rank": 0, "contribution": 0, "spent": 0}
	var rank_name: String = sect.rank_name(1)
	var line := ""
	for l in Guidance.goals(c, d, {}):
		if l.begins_with("Become "):
			line = l
	assert_true(line.begins_with("Become %s:" % rank_name) and line.contains("contribution"), line)
	c.sect["contribution"] = 500
	for l in Guidance.goals(c, d, {}):
		assert_false(l.begins_with("Become "), "met requirements, trial-free: no rank line")
	sect.ranks[1]["trial"] = "wolf"
	var found := false
	for l in Guidance.goals(c, d, {}):
		if l.contains("you can seek promotion"):
			found = true
	assert_true(found)


func test_unlock_notices_secret_realms_follow_the_realm() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 1
	var ids := _notice_ids(Guidance.unlock_notices(c, d, {}))
	for realm_id: String in d.secret_realms:
		var def: Dictionary = d.secret_realms[realm_id]
		var open := String(def["min_realm"]) == "qi_refining"
		assert_eq(ids.has("secret_realm_" + realm_id), open, realm_id)
	assert_false(ids.has("clan"))
	assert_false(ids.any(func(i: String) -> bool: return i.begins_with("promotion_")))
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {"notice_secret_realm_verdant_remnant": true})).has("secret_realm_verdant_remnant"))
	for n in Guidance.unlock_notices(c, d, {}):
		if n["id"] == "secret_realm_verdant_remnant":
			assert_true(String(n["text"]).contains("Verdant Remnant") and String(n["text"]).contains("5 years"))


func test_unlock_notices_promotion_trial() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 2
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {})).any(func(i: String) -> bool: return i.begins_with("promotion_")))
	c.sect["contribution"] = 500
	var notices := Guidance.unlock_notices(c, d, {})
	assert_true(_notice_ids(notices).has("promotion_azure_cloud_sect_1"))
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {"notice_promotion_azure_cloud_sect_1": true})).has("promotion_azure_cloud_sect_1"))


func test_unlock_notices_clan() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.inventory = {"spirit_stone": 1000}
	c.abode = "waterfall_cave"
	assert_true(_notice_ids(Guidance.unlock_notices(c, d, {})).has("clan"))
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {}, {}, ClanData.new())).has("clan"))


## TRAV-001: no road notice for a region you have already visited.
func test_unlock_notices_skip_visited_regions() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 1
	assert_true(_notice_ids(Guidance.unlock_notices(c, d, {})).has("road_azure_peak"))
	Exploration.visit(c, "azure_peak")
	assert_false(_notice_ids(Guidance.unlock_notices(c, d, {})).has("road_azure_peak"))
	assert_true(_notice_ids(Guidance.unlock_notices(c, d, {})).has("road_withered_bone_marsh"))


## GUIDE-014: roads you haven't taken.
func test_unexplored_routes_nearest_first_and_visit_clears() -> void:
	var d := data()
	var c := _fresh()
	var roads := Guidance.unexplored_routes(c, d, "qingshi_village")
	assert_eq(roads[0]["to"], "misty_forest")
	for r in roads:
		assert_true(Exploration.check_travel(c, d, "qingshi_village", r["to"])["ok"])
	Exploration.visit(c, "misty_forest")
	for r in Guidance.unexplored_routes(c, d, "qingshi_village"):
		assert_true(r["to"] != "misty_forest")


func test_unexplored_routes_skip_realm_gated() -> void:
	var d := data()
	var c := _fresh()
	for r in d.regions["qingshi_village"]["routes"]:
		if String(r.get("min_realm", "")) != "":
			for u in Guidance.unexplored_routes(c, d, "qingshi_village"):
				assert_true(u["to"] != r["to"])


func test_unexplored_hint_waits_for_day_ten() -> void:
	var d := data()
	var c := _fresh()
	assert_false(_has(Guidance.hints(c, d, 1.0, 99, {}, {}, "qingshi_village", 5), "have never been to"))
	assert_false(_has(Guidance.hints(c, d, 1.0, 99, {}, {}, "qingshi_village", -1), "have never been to"))
	var hints := Guidance.hints(c, d, 1.0, 99, {}, {}, "qingshi_village", 10)
	assert_true(_has(hints, "You have never been to Misty Forest; the road from here is open."))


func test_unexplored_journal_lines_capped_at_two() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realms.size() - 1
	var n := 0
	for row in Guidance.journal(c, d, {}, 0, "qingshi_village"):
		if String(row["text"]).begins_with("Unexplored: "):
			n += 1
	assert_true(n >= 1 and n <= 2)
	Exploration.visit(c, "misty_forest")
	for row in Guidance.journal(c, d, {}, 0, "qingshi_village"):
		assert_false(String(row["text"]).begins_with("Unexplored: Misty Forest"))
	assert_eq(Guidance.journal(c, d, {}, 0, "").filter(func(r: Dictionary) -> bool: return String(r["text"]).begins_with("Unexplored")).size(), 0)


func test_journal_in_season_line_needs_visited_region_and_season() -> void:
	var d := data()
	var c := _fresh()
	Exploration.visit(c, "qingshi_village")
	var spring := Guidance.journal(c, d, {}, 10, "qingshi_village").filter(func(r: Dictionary) -> bool: return String(r["text"]).begins_with("In season: "))
	assert_true(spring.size() >= 1 and spring.size() <= 2)
	var autumn := Guidance.journal(c, d, {}, 200, "qingshi_village").filter(func(r: Dictionary) -> bool: return String(r["text"]).begins_with("In season: Spirit Herb"))
	assert_eq(autumn.size(), 0)
	assert_eq(Guidance.journal(c, d, {}, -1, "qingshi_village").filter(func(r: Dictionary) -> bool: return String(r["text"]).begins_with("In season: ")).size(), 0)


func test_discovery_rumor_in_journal_until_discovered() -> void:
	var c := _fresh()
	var rows := Guidance.journal(c, data(), {"discovered_qingshi_village": true}, 0, "qingshi_village")
	var found := false
	for r in rows:
		if String(r["text"]).begins_with("Rumor: ") and String(r["text"]).contains("Misty Forest"):
			found = true
	assert_true(found)
	var flags := {}
	for id: String in data().regions:
		flags["discovered_" + id] = true
	assert_eq(Guidance.discovery_rumors(c, data(), flags, "qingshi_village").size(), 0)


func test_discovery_rumor_hidden_when_region_gated() -> void:
	var c := _fresh()
	var d := data()
	var routes: Array = d.regions["qingshi_village"]["routes"]
	var saved: Variant = routes.duplicate(true)
	for route in routes:
		if route["to"] == "misty_forest":
			route["min_realm"] = d.realms[d.realms.size() - 1]["id"]
	d.regions["qingshi_village"]["routes"] = routes
	for rumor in Guidance.discovery_rumors(c, d, {}, "qingshi_village"):
		assert_false(rumor.contains("Misty Forest"), rumor)
	d.regions["qingshi_village"]["routes"] = saved


func test_discovery_rumor_validator() -> void:
	var d := data()
	var saved: Variant = d.regions["qingshi_village"]["discovery"]
	d.regions["qingshi_village"].erase("discovery")
	d.load_errors.clear()
	d._validate()
	assert_true(d.load_errors.size() > 0)
	d.regions["qingshi_village"]["discovery"] = saved


func test_every_discovery_has_a_rumor() -> void:
	for id: String in data().regions:
		var r: Dictionary = data().regions[id]
		if String(r.get("discovery", "")) == "":
			continue
		var rumor := String(r.get("discovery_rumor", ""))
		assert_true(rumor.length() > 20, id + " has a discovery but no discovery_rumor")
		assert_false(rumor.contains(String(r["discovery"])), id + ": the rumor must not name the discovery id")


# --- GUIDE-017: craft-now hints ----------------------------------------------

func _crafter() -> CharacterData:
	var c := _veteran()
	c.inventory = {"spirit_herb": 2, "dew_grass": 1}
	return c


func _journal_has(rows: Array[Dictionary], fragment: String) -> bool:
	for r in rows:
		if String(r["text"]).contains(fragment):
			return true
	return false


func test_craftable_now_lists_only_makeable_recipes() -> void:
	var c := _crafter()
	var d := data()
	assert_true(Guidance.craftable_now(c, d).has("qi_gathering_pill"))
	assert_false(Guidance.craftable_now(c, d).has("meridian_mending_pill"), "above rank / no ingredients")
	c.inventory = {"spirit_herb": 2}
	assert_false(Guidance.craftable_now(c, d).has("qi_gathering_pill"), "missing dew grass")


func test_workshop_place_prefers_current_region() -> void:
	var d := data()
	assert_eq(Guidance.workshop_place(d, "qingshi_village"), "Village Workshop in Qingshi Village")
	assert_true(Guidance.workshop_place(d, "").contains(" in "))


func test_journal_names_craftable_recipe_and_workshop() -> void:
	var c := _crafter()
	var rows := Guidance.journal(c, data(), {}, 5, "qingshi_village")
	assert_true(_journal_has(rows, "You have everything to make Qi Gathering Pill"))
	assert_true(_journal_has(rows, "Village Workshop in Qingshi Village"))
	c.inventory = {}
	assert_false(_journal_has(Guidance.journal(c, data(), {}, 5, "qingshi_village"), "You have everything to make"))


func test_craft_hint_names_recipe_until_five_crafts() -> void:
	var c := _crafter()
	c.life_stats["items_crafted"] = 2
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 400), "You have what Qi Gathering Pill needs: craft it at Village Workshop in Qingshi Village."))
	c.life_stats["items_crafted"] = 5
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 400), "You have what"))


func test_herb_here_hint_for_a_crafter_short_of_herbs() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	var hint := Guidance.herb_here_hint(c, data(), "qingshi_village")
	var herb_name := String(data().items["spirit_herb"]["name"])
	var place := ""
	for p: Dictionary in data().regions["qingshi_village"]["places"]:
		if String(p.get("type", "")) == "gather":
			place = String(p["display_name"])
			break
	assert_true(hint.begins_with("%s grows at %s: gather it to refine %s" % [herb_name, place, data().recipes["qi_gathering_pill"]["name"]]), hint)
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 400), "grows at"))
	# Reviewer: a Mortal newcomer on day 0 who has never crafted hears it too.
	c.realm_index = 0
	c.life_stats["items_crafted"] = 0
	c.life_stats["encounters"] = 0
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 0), "grows at"), "no realm or day gate")
	var no_gather := ""
	for region_id: String in data().regions:
		var has_gather := false
		for p: Dictionary in data().regions[region_id].get("places", []):
			has_gather = has_gather or String(p.get("type", "")) == "gather"
		if not has_gather:
			no_gather = region_id
			break
	if no_gather != "":
		assert_eq(Guidance.herb_here_hint(c, data(), no_gather), "", "no gather place")
	c.realm_index = 1
	c.life_stats["items_crafted"] = 1
	c.life_stats["encounters"] = 1
	c.inventory = {"spirit_herb": 2, "dew_grass": 1}
	assert_eq(Guidance.herb_here_hint(c, data(), "qingshi_village"), "", "craft-now takes over")
	c.inventory = {}
	c.professions.clear()
	assert_eq(Guidance.herb_here_hint(c, data(), "qingshi_village"), "", "no profession")
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.life_stats["items_crafted"] = Guidance.CRAFT_HINT_MAX_CRAFTS
	assert_eq(Guidance.herb_here_hint(c, data(), "qingshi_village"), "", "faded")


func test_recap_names_waiting_hunt_letter_and_renown_capped_at_two() -> void:
	var c := _fresh()
	var base := Guidance.recap(c, data(), {}, 100, "qingshi_village")
	assert_false(_has(base, "hunting"))
	assert_false(_has(base, "letter waits"))
	assert_false(_has(base, "Your name is"))
	Bounties.take(c, data(), "iron_back_boar_bounty", 100)
	var hunt := Guidance.recap(c, data(), {}, 100, "qingshi_village")
	assert_true(_has(hunt, "You are hunting"))
	assert_true(_has(hunt, "60 days left"))
	Letters.remember(c, data(), "A letter from Mei: " + "x".repeat(80), 90)
	var both := Guidance.recap(c, data(), {}, 100, "qingshi_village")
	assert_true(_has(both, "Mei's letter waits: " + "x".repeat(60) + "..."))
	assert_false(_has(Guidance.recap(c, data(), {}, 200, "qingshi_village"), "letter waits"), "old letters are not news")
	c.renown["qingshi_village"] = 100000
	var capped := Guidance.recap(c, data(), {}, 100, "qingshi_village")
	assert_true(_has(capped, "hunting") and _has(capped, "letter waits"))
	assert_false(_has(capped, "Your name is"), "at most two waiting lines")
	c.bounty = {}
	assert_true(_has(Guidance.recap(c, data(), {}, 100, "qingshi_village"), "Your name is"))


func test_first_combat_manual_names_the_merchant_and_survives_breathing() -> void:
	var c := _fresh()
	c.techniques = {}
	var d := data()
	var found := Guidance.first_combat_manual(c, d, "qingshi_village")
	assert_eq(found.get("item", ""), "manual_iron_fist")
	assert_eq(found.get("merchant", ""), "Wandering Merchant")
	assert_eq(found.get("price", 0), 15)
	var hint := Guidance.first_combat_hint(c, d, "qingshi_village")
	assert_true(hint.contains("Wandering Merchant") and hint.contains("15 spirit stones"), hint)
	c.techniques = {"basic_breathing": {"level": 1, "xp": 0.0}}
	assert_true(Guidance.first_combat_hint(c, d, "qingshi_village") != "")
	assert_true(_has(Guidance.hints(c, d, 1.0, 5, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village"), "no fighting style"))
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	assert_true(Guidance.first_combat_manual(c, d, "qingshi_village").is_empty())
	assert_eq(Guidance.first_combat_hint(c, d, "qingshi_village"), "")


func test_first_combat_hint_default_limit_for_fresh_player() -> void:
	var c := _fresh()
	c.techniques = {}
	assert_true(_has(Guidance.hints(c, data(), 1.0, 5, {}, {}, "qingshi_village"), "no fighting style"))


func test_first_combat_hint_falls_back_to_a_source() -> void:
	var c := _fresh()
	c.techniques = {}
	var found := Guidance.first_combat_manual(c, data(), "")
	assert_false(found.is_empty())
	assert_eq(found["merchant"], "")
	assert_true(Guidance.first_combat_hint(c, data(), "").contains("Look for the"))


func test_first_combat_manual_skips_lifespan_burning_arts() -> void:
	var c := _fresh()
	c.techniques = {}
	var d := GameData.load_from_dir()
	var iron: TechniqueDef = d.techniques["iron_fist"]
	iron.activation = {"lifespan_cost": 5}
	var found := Guidance.first_combat_manual(c, d, "qingshi_village")
	assert_true(found.is_empty() or found.get("technique", "") != "iron_fist", "burning art skipped")


func test_first_combat_hint_acknowledges_a_body_art() -> void:
	var c := _fresh()
	c.techniques = {"stone_skin": {"level": 1, "xp": 0.0}}
	var hint := Guidance.first_combat_hint(c, data(), "qingshi_village")
	assert_true(hint.begins_with("Your body art guards you, but you know no fighting style."), hint)


func test_practice_hint_for_a_low_level_fighting_style() -> void:
	var c := _fresh()
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var hint := Guidance.practice_hint(c, data())
	assert_true(hint.contains("Practise Iron Fist") and hint.contains("level 1 now"), hint)
	var hints := Guidance._newcomer_hints(c, data(), {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Practise Iron Fist"))
	assert_false(_has(hints, "no fighting style"))
	c.techniques["iron_fist"]["level"] = 3
	assert_eq(Guidance.practice_hint(c, data()), "")
	assert_false(_has(Guidance._newcomer_hints(c, data(), {Guidance.ELDER_MO_FLAG: true}, "qingshi_village"), "no fighting style"))
	c.techniques = {}
	assert_eq(Guidance.practice_hint(c, data()), "")


func test_every_region_with_a_merchant_sells_a_fighting_style() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 1
	c.techniques = {}
	for region_id: String in d.regions.keys():
		var has_merchant := false
		for place: Dictionary in d.regions[region_id].get("places", []):
			if place.get("type", "") == "merchant":
				has_merchant = true
		if not has_merchant:
			continue
		var found := Guidance.first_combat_manual(c, d, region_id)
		assert_true(String(found.get("merchant", "")) != "", "%s: no merchant sells a combat manual (%s)" % [region_id, found])


# --- Fights you can win (GUIDE-021) ---------------------------------------------

func _fighter() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = 3
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}, "stone_skin": {"level": 2, "xp": 0.0}}
	return c


func test_fair_fights_are_even_or_better_sorted_and_capped() -> void:
	var c := _fighter()
	var fights := Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village")
	assert_true(fights.size() <= Guidance.FAIR_FIGHTS_MAX)
	for i in fights.size():
		assert_true(float(fights[i]["chance"]) >= Guidance.FAIR_FIGHT_MIN_CHANCE)
		if i > 0:
			assert_true(float(fights[i - 1]["chance"]) >= float(fights[i]["chance"]))
	assert_eq(fights, Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village"))


func test_bare_rogue_gets_first_combat_hint_instead() -> void:
	var c := _fresh()
	c.sect = {}
	c.techniques = {}
	var fights := Guidance.fair_fights(c, data(), {"chore_boar_done": true}, c.age_days, "qingshi_village")
	for f in fights:
		assert_eq(f["kind"], "explore", "only wilds foes are left for a bare rogue")
	if not fights.is_empty():
		return  # GUIDE-030: a fair wilds foe replaces the hint
	var hint := Guidance.first_combat_hint(c, data(), "qingshi_village")
	var lines: Array[String] = []
	for e in Guidance.journal(c, data(), {"chore_boar_done": true}, c.age_days, "qingshi_village"):
		if e["section"] == "Fights you can win":
			lines.append(String(e["text"]))
	var elsewhere := false
	for e in Guidance.journal(c, data(), {"chore_boar_done": true}, c.age_days, "qingshi_village"):
		elsewhere = elsewhere or (e["section"] != "Fights you can win" and e["text"] == hint)
	assert_eq(lines, [hint] if hint != "" and not elsewhere else [])
	assert_true(hint == "" or elsewhere or lines.size() == 1)


func test_fair_fights_skip_missions_on_cooldown() -> void:
	var c := _fighter()
	var kinds: Array = Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village").map(func(f: Dictionary) -> String: return f["kind"])
	assert_true(kinds.has("mission"), "baseline lists a mission")
	for id in data().sect_missions:
		c.mission_cooldowns[id] = c.age_days + 5
	for f in Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village"):
		assert_true(f["kind"] != "mission")


func test_active_hunt_shows_as_your_hunt() -> void:
	var c := _fighter()
	c.sect = {}
	c.realm_index = 3
	c.stage = 5
	var id: String = data().bounties.keys()[0]
	Bounties.take(c, data(), id, c.age_days)
	var texts: Array = Guidance.fair_fights(c, data(), {}, c.age_days, String(data().bounties[id]["region"])).map(func(f: Dictionary) -> String: return f["text"])
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("Your hunt:")), str(texts))


## GUIDE-028: an unfair first bounty offer does not hide a fair one behind it.
func test_fair_fights_look_past_an_unfair_first_bounty() -> void:
	var d := GameData.load_from_dir()
	var c := _fighter()
	c.sect = {}
	var base := {"region": "qingshi_village", "reward_stones": 10, "days": 30, "cooldown_days": 30, "text": "x"}
	var hard := base.duplicate()
	hard["id"] = "test_hard_bounty"
	hard["enemy"] = "stone_hide_boar_king"
	var easy := base.duplicate()
	easy["id"] = "test_easy_bounty"
	easy["enemy"] = "wild_boar"
	d.bounties = {"test_hard_bounty": hard, "test_easy_bounty": easy}
	assert_true(Combat.win_chance(c, d, d.enemies["stone_hide_boar_king"]) < Guidance.FAIR_FIGHT_MIN_CHANCE)
	assert_true(Combat.win_chance(c, d, d.enemies["wild_boar"]) >= Guidance.FAIR_FIGHT_MIN_CHANCE)
	var fights := Guidance.fair_fights(c, d, {}, c.age_days, "qingshi_village")
	var bounty_enemies: Array = fights.filter(func(f: Dictionary) -> bool: return f["kind"] == "bounty").map(func(f: Dictionary) -> String: return f["enemy"])
	assert_eq(bounty_enemies, [String(d.enemies["wild_boar"]["name"])])


func test_fairer_fight_note() -> void:
	assert_eq(Guidance.fairer_fight_note([], "Wolf"), "")
	var entries: Array = [{"text": "Bounty: Wolf in Marsh (Even, 50 in 100)", "enemy": "Wolf"}]
	assert_eq(Guidance.fairer_fight_note(entries, "Wolf"), "")
	assert_eq(Guidance.fairer_fight_note(entries, "Boar"), " A fairer fight: Bounty: Wolf in Marsh (Even, 50 in 100).")



## GUIDE-024: the mission hint does not count fights the player would likely lose.
func test_mission_hint_skips_deadly_fights() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var wolf := "patrol_misty_peaks"
	var enemy: Dictionary = d.enemies[String(d.sect_missions[wolf]["enemy"])]
	var weak := Combat.win_chance(c, d, enemy, 20) < 0.5
	assert_true(weak, "a bare QR1 disciple is outmatched by the mist wolf")
	c.stage = 1
	var hint := Guidance._mission_hint(c, d, {})
	assert_true(hint == "" or hint.contains("ready") or hint.contains("dangerous"))
	var strong := new_character()
	strong.realm_index = 2
	strong.stage = 5
	strong.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_false(Guidance._mission_too_dangerous(strong, d, wolf), "a strong Foundation character counts it")
	c.stage = 0
	assert_true(Guidance._mission_too_dangerous(c, d, wolf))

func test_mission_too_dangerous_matches_rating() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	var enemy_id := String(d.sect_missions["patrol_misty_peaks"]["enemy"])
	var expected := Combat.win_chance(c, d, d.enemies[enemy_id]) < 0.5
	assert_eq(Guidance.mission_too_dangerous(c, d, enemy_id), expected)
	assert_false(Guidance.mission_too_dangerous(c, d, "no_such_enemy"))

func _qr(stage: int, stones: int) -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = stage
	c.inventory = {}
	c.breakthrough_pill = ""
	if stones > 0:
		c.add_item("spirit_stone", stones)
	return c


func test_pill_saving_goal_late_qi_refining() -> void:
	assert_false(_has(Guidance.goals(_qr(5, 20), data(), {}), "Save for"))
	var goals := Guidance.goals(_qr(6, 20), data(), {})
	assert_true(_has(goals, "Save for a Foundation Establishment Pill (+25 percent)"))
	assert_true(_has(goals, "you have 20"))
	assert_false(_has(goals, "%"))
	assert_true(_has(Guidance.goals(_qr(6, 400), data(), {}), "you can afford it now"))


func test_pill_saving_goal_skipped_when_held_or_other_realm() -> void:
	var c := _qr(6, 20)
	c.add_item("foundation_establishment_pill", 1)
	assert_false(_has(Guidance.goals(c, data(), {}), "Save for"))
	var fe := _qr(0, 20)
	fe.realm_index = 2
	assert_false(_has(Guidance.goals(fe, data(), {}), "Save for"))
	assert_eq(Guidance.next_realm_pill(_qr(6, 0), data()).get("id", ""), "foundation_establishment_pill")

func test_pill_saving_goal_at_foundation() -> void:
	var d := data()
	var late := _qr(0, 20)
	late.realm_index = 2
	late.stage = d.realms[2].stage_count() - 3
	var goals := Guidance.goals(late, d, {})
	assert_true(_has(goals, "Save for a Core Forming Pill (+25 percent)"))
	assert_true(_has(goals, "you have 20"))
	assert_true(Guidance.pill_gap_note(late, d, []).begins_with("%d stones short" % (3000 - 20)))
	var early := _qr(0, 20)
	early.realm_index = 2
	early.stage = d.realms[2].stage_count() - 4
	assert_false(_has(Guidance.goals(early, d, {}), "Save for"))
	assert_eq(Guidance.pill_gap_note(early, d, []), "")
	late.add_item("core_forming_pill", 1)
	assert_false(_has(Guidance.goals(late, d, {}), "Save for"))


func _deed_texts(c: CharacterData, flags: Dictionary) -> Array:
	var out: Array = []
	for f in Guidance.fair_fights(c, data(), flags, c.age_days, "qingshi_village"):
		if f["kind"] == "deed":
			out.append(String(f["text"]))
	return out


func test_fair_fights_include_open_chore_fights() -> void:
	var c := _fighter()
	c.sect = {}
	var texts := _deed_texts(c, {})
	assert_eq(texts.size(), 1)
	assert_true(String(texts[0]).begins_with("Headman Zhou: Drive off the wild boar"))
	assert_true(_deed_texts(c, {"chore_boar_done": true}).is_empty(), "done chore is gone")



func test_breakthrough_risk_text() -> void:
	var d := data()
	var c := new_character()
	assert_eq(Guidance.breakthrough_risk_text(c, d), "")
	c.stage = d.realms[c.realm_index].stage_count() - 1
	c.qi = d.realms[c.realm_index].qi_required(c.stage)
	var text := Guidance.breakthrough_risk_text(c, d)
	assert_true(text.contains("%d percent" % roundi(d.realms[1].failure_qi_loss * 100)), text)
	assert_true(text.contains("in 100 chance of an injury"), text)
	# A realm with a tribulation is covered by the tribulation screen.
	for i in d.realms.size() - 1:
		if Tribulation.has_tribulation(d, i + 1):
			c.realm_index = i
			break
	c.stage = d.realms[c.realm_index].stage_count() - 1
	c.qi = d.realms[c.realm_index].qi_required(c.stage)
	assert_eq(Guidance.breakthrough_risk_text(c, d), "")


func test_foundation_goals_ladder_and_journal_section() -> void:
	var c := _fresh()
	c.realm_index = 2
	var goals := Guidance.foundation_goals(c, data(), {})
	assert_eq(goals.size(), 5)
	for g in goals:
		assert_false(g["done"])
	assert_true(Guidance.foundation_goals_active(c, data(), {}))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Foundation goals")
	assert_eq(section.size(), 5)
	assert_eq(section[0]["tone"], "warning")
	assert_eq(section[1]["tone"], "normal")
	c.stage = 1
	c.abode = "any_abode"
	c.body_stage = 1
	goals = Guidance.foundation_goals(c, data(), {})
	assert_true(goals[0]["done"] and goals[2]["done"] and goals[3]["done"])
	assert_false(goals[1]["done"])
	assert_false(goals[4]["done"])
	c.sect = {"id": data().sects.keys()[0], "rank": 2, "contribution": 0, "spent": 0}
	var beaten := {Guidance.beat_realm_flag("foundation_establishment"): true}
	assert_false(Guidance.foundation_goals_active(c, data(), beaten))
	var after := Guidance.journal(c, data(), beaten, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Foundation goals")
	assert_true(after.is_empty())


func test_foundation_goals_clan_and_realm_limits() -> void:
	var c := _fresh()
	c.realm_index = 2
	assert_true(Guidance.foundation_goals(c, data(), {}, ClanData.new())[4]["done"])
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 5)
	c.realm_index = 7
	assert_false(Guidance.foundation_goals_active(c, data(), {}))
	assert_true(Guidance.active_goal_ladder(c, data(), {}).is_empty())
	c.realm_index = 1
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 7)


## The HUD's ladder stays put once all its goals are done, so the last one is still announced.
func test_goal_ladder_keeps_a_finished_ladder() -> void:
	var c := _fresh()
	c.realm_index = 2
	c.stage = 1
	c.abode = "x"
	c.body_stage = 1
	assert_false(Guidance.foundation_goals_active(c, data(), {Guidance.beat_realm_flag("foundation_establishment"): true}, ClanData.new()))
	assert_eq(Guidance.goal_ladder_id(c), "foundation")
	assert_eq(Guidance.goal_ladder("foundation", c, data(), {}, ClanData.new()).size(), 5)
	c.realm_index = 1
	assert_eq(Guidance.goal_ladder_id(c), "first")
	c.realm_index = 7
	assert_eq(Guidance.goal_ladder_id(c), "")
	assert_true(Guidance.goal_ladder("", c, data(), {}).is_empty())


func _peak_foundation() -> CharacterData:
	var c := _fresh()
	c.realm_index = 2
	c.stage = data().realms[2].stage_count() - 1
	return c


func test_tribulation_note_warns_when_unprepared() -> void:
	var c := _peak_foundation()
	var note := Guidance.tribulation_note(c, data())
	assert_true(String(note["text"]).contains("Heavenly Tribulation ahead"))
	assert_true(String(note["text"]).contains("would not survive"))
	assert_eq(note["tone"], "warning")
	var entries := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return String(e["text"]).begins_with("Heavenly Tribulation"))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["section"], "Breakthrough")


func test_tribulation_note_normal_when_sturdy_and_hidden_elsewhere() -> void:
	var c := _peak_foundation()
	c.attributes["constitution"] = 100000
	var note := Guidance.tribulation_note(c, data())
	assert_eq(note["tone"], "normal")
	assert_false(String(note["text"]).contains("would not survive"))
	c.stage = 1
	assert_true(Guidance.tribulation_note(c, data()).is_empty())
	var q := _fresh()
	q.realm_index = 1
	q.stage = 8
	assert_true(Guidance.tribulation_note(q, data()).is_empty())


func _share_at_constitution(c: CharacterData, constitution: int) -> float:
	c.attributes["constitution"] = constitution
	var p := Tribulation.preview(c, data(), c.realm_index + 1)
	return float(p["expected_damage"]) / float(int(p["max_hp"]) + int(p["shield"]))


func _peak_with_share(low: float, high: float) -> CharacterData:
	var c := _peak_foundation()
	var con := 10
	while con < 100000 and _share_at_constitution(c, con) >= high:
		con += 2
	assert_true(_share_at_constitution(c, con) >= low, "found a constitution with share in [%.2f, %.2f)" % [low, high])
	return c


func test_tribulation_note_close_call() -> void:
	var c := _peak_with_share(Guidance.CLOSE_CALL_SHARE, 1.0)
	var note := Guidance.tribulation_note(c, data())
	assert_true(String(note["text"]).contains("It will be close"))
	assert_false(String(note["text"]).contains("would not survive"))
	assert_eq(note["tone"], "warning")


func test_tribulation_note_plain_when_well_under_and_no_when_over() -> void:
	var sturdy := _peak_foundation()
	sturdy.attributes["constitution"] = 100000
	var note := Guidance.tribulation_note(sturdy, data())
	assert_eq(note["tone"], "normal")
	assert_false(String(note["text"]).contains("close"))
	var weak := _peak_foundation()
	assert_true(String(Guidance.tribulation_note(weak, data())["text"]).contains("would not survive"))


func test_tribulation_note_names_heart_demon() -> void:
	var c := _peak_foundation()
	assert_false(String(Guidance.tribulation_note(c, data())["text"]).contains("heart demon"))
	c.alignment = -1000
	assert_true(String(Guidance.tribulation_note(c, data())["text"]).contains("heart demon"))


func test_fair_fights_list_exploration_foes_when_little_else() -> void:
	var c := _fighter()
	c.sect = {}
	var wild: Array = Guidance.fair_fights(c, data(), {"chore_boar_done": true}, c.age_days, "misty_forest")
	var explore := wild.filter(func(f: Dictionary) -> bool: return f["kind"] == "explore")
	assert_true(explore.size() <= Guidance.FAIR_FIGHT_EXPLORE_MAX)
	var foes := Exploration.eligible_fights(c, data(), data().regions["misty_forest"]["encounter_tags"], {}, Calendar.season_of(c.age_days), "misty_forest")
	assert_false(foes.is_empty(), "the forest has fight encounters")
	for f in explore:
		assert_true(String(f["text"]).begins_with("Explore here: "))
		assert_true(float(f["chance"]) >= Guidance.FAIR_FIGHT_MIN_CHANCE)


func test_eligible_fights_have_no_repeats_and_only_known_enemies() -> void:
	var c := _fighter()
	var foes := Exploration.eligible_fights(c, data(), ["forest", "wild"], {}, "spring", "misty_forest")
	var seen := {}
	for id in foes:
		assert_true(data().enemies.has(id))
		assert_false(seen.has(id))
		seen[id] = true


func test_deadly_exploration_foes_are_never_listed() -> void:
	var c := _fresh()
	c.sect = {}
	for f in Guidance.fair_fights(c, data(), {}, c.age_days, "misty_forest"):
		assert_true(float(f["chance"]) >= 0.7)

## GUIDE-029: the pill gap names the best-paying fair fight.
func test_pill_gap_note_names_a_paying_fight() -> void:
	var c := _qr(6, 20)
	var fights: Array = [{"text": "Bounty: Wolf in Marsh (Even, 50 in 100)", "stones": 40}, {"text": "Sect mission: X (Easy, 90 in 100)", "stones": 0}]
	var short := Guidance.next_realm_pill_price(c, data()) - 20
	assert_eq(Guidance.pill_gap_note(c, data(), fights), "%d stones short. Bounty: Wolf in Marsh pays 40." % short)


func test_pill_gap_note_generic_when_nothing_pays() -> void:
	var c := _qr(6, 20)
	var short := Guidance.next_realm_pill_price(c, data()) - 20
	assert_eq(Guidance.pill_gap_note(c, data(), []), "%d stones short. Bounties, sect missions and selling herbs and ore pay best." % short)


func test_pill_gap_note_quiet_when_affordable_or_early() -> void:
	assert_eq(Guidance.pill_gap_note(_qr(6, 4000), data(), []), "")
	assert_eq(Guidance.pill_gap_note(_qr(5, 20), data(), []), "")


func test_foundation_goal_beat_foundation_foe() -> void:
	var c := _fresh()
	c.realm_index = 2
	var flag := Guidance.beat_realm_flag("foundation_establishment")
	assert_eq(flag, "beat_realm_foundation_establishment")
	var row := Guidance.foundation_goals(c, data(), {})[1]
	assert_eq(row["text"], "Win a fight against a Foundation foe")
	assert_false(row["done"])
	assert_true(Guidance.foundation_goals(c, data(), {flag: true})[1]["done"])


func test_core_goals_rows_and_ladder() -> void:
	var c := _fresh()
	c.realm_index = 3
	var goals := Guidance.core_goals(c, data(), {})
	assert_eq(goals.size(), 4)
	for g in goals:
		assert_false(g["done"])
	assert_true(Guidance.core_goals_active(c, data(), {}))
	c.stage = 1
	c.body_stage = 4
	LifeStats.add(c, "realm_floors_cleared", 1)
	goals = Guidance.core_goals(c, data(), {Guidance.beat_realm_flag("core_formation"): true})
	for g in goals:
		assert_true(g["done"])
	assert_false(Guidance.core_goals_active(c, data(), {Guidance.beat_realm_flag("core_formation"): true}))
	assert_eq(Guidance.core_goals(c, data(), {})[1]["text"], "Win a fight against a Core Formation foe")


func test_core_goal_ladder_ids_and_journal() -> void:
	var c := _fresh()
	c.realm_index = 2
	assert_eq(Guidance.goal_ladder_id(c), "foundation")
	var section_of := func() -> Array:
		return Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Core Formation goals")
	assert_true(section_of.call().is_empty())
	c.realm_index = 3
	assert_eq(Guidance.goal_ladder_id(c), "core")
	assert_eq(Guidance.goal_ladder("core", c, data(), {}).size(), 4)
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 4)
	assert_eq(section_of.call().size(), 4)
	c.realm_index = 7
	assert_eq(Guidance.goal_ladder_id(c), "")
	assert_true(section_of.call().is_empty())


func test_nascent_goals_rows_and_ladder() -> void:
	var c := _fresh()
	c.realm_index = 4
	var goals := Guidance.nascent_goals(c, data(), {})
	assert_eq(goals.size(), 4)
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[3]["text"], "Temper your body to Indestructible Vajra Body")
	assert_true(Guidance.nascent_goals_active(c, data(), {}))
	assert_eq(Guidance.goal_ladder_id(c), "nascent")
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 4)
	var section := func() -> Array:
		return Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Nascent Soul goals")
	assert_eq(section.call().size(), 4)
	var flags := {Guidance.beat_realm_flag("nascent_soul"): true}
	c.stage = 1
	c.body_stage = 5
	LifeStats.add(c, "inheritances_claimed", 1)
	for g in Guidance.nascent_goals(c, data(), flags):
		assert_true(g["done"])
	assert_false(Guidance.nascent_goals_active(c, data(), flags))
	assert_eq(Guidance.goal_ladder_id(c), "nascent")
	c.realm_index = 3
	assert_true(Guidance.nascent_goals(c, data(), {})[0]["done"] == false)
	assert_false(Guidance.nascent_goals_active(c, data(), {}))


func test_soul_goals_rows_and_ladder() -> void:
	var c := _fresh()
	c.realm_index = 5
	var goals := Guidance.soul_goals(c, data(), {})
	var has_body := BodyTempering.stages(data()).size() > 5
	assert_eq(goals.size(), 4 if has_body else 3)
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[0]["text"], "Reach Soul Formation Middle")
	assert_true(Guidance.soul_goals_active(c, data(), {}))
	assert_eq(Guidance.goal_ladder_id(c), "soul")
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), goals.size())
	var section := func() -> Array:
		return Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Soul Formation goals")
	assert_eq(section.call().size(), goals.size())
	assert_eq(section.call()[0]["tone"], "warning")
	c.stage = 1
	assert_true(Guidance.soul_goals(c, data(), {})[0]["done"])
	LifeStats.add(c, "inheritances_claimed", 2)
	assert_eq(goals[2]["text"], "Claim a Soul Formation inheritance")
	assert_false(Guidance.soul_goals(c, data(), {})[2]["done"])
	assert_true(Guidance.soul_goals(c, data(), {Inheritances.claimed_flag("ghost_sovereign_hollow"): true})[2]["done"])
	assert_true(Guidance.soul_goals(c, data(), {Guidance.beat_realm_flag("soul_formation"): true})[1]["done"])
	c.realm_index = 7
	assert_eq(Guidance.goal_ladder_id(c), "")
	assert_false(Guidance.soul_goals_active(c, data(), {}))


## VOID-001: the Void Refinement ladder.
func test_void_goals_rows_and_ladder() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realm_index_of("void_refinement")
	assert_eq(c.realm_index, 6)
	var has_inh := Guidance._has_realm_inheritance(d, "void_refinement")
	var has_body := BodyTempering.stages(d).size() > 6
	var goals := Guidance.void_goals(c, d, {})
	assert_eq(goals.size(), 2 + (1 if has_inh else 0) + (1 if has_body else 0))
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[0]["text"], "Reach Void Refinement Middle")
	assert_true(Guidance.void_goals_active(c, d, {}))
	assert_eq(Guidance.goal_ladder_id(c), "void")
	assert_eq(Guidance.goal_ladder("void", c, d, {}).size(), goals.size())
	assert_eq(Guidance.active_goal_ladder(c, d, {}).size(), goals.size())
	var section := func() -> Array:
		return Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Void Refinement goals")
	assert_eq(section.call().size(), goals.size())
	assert_eq(section.call()[0]["tone"], "warning")
	c.stage = 1
	assert_true(Guidance.void_goals(c, d, {})[0]["done"])
	assert_true(Guidance.void_goals(c, d, {Guidance.beat_realm_flag("void_refinement"): true})[1]["done"])
	c.realm_index = 5
	assert_false(Guidance.void_goals_active(c, d, {}))
	c.realm_index = 6
	if not has_inh:
		d.inheritances["test_void_legacy"] = {"id": "test_void_legacy", "name": "Void Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
			"stages": [{"name": "Gate", "days": 1, "test": "realm", "min_realm": "void_refinement"}], "reward": {}}
		var with_row := Guidance.void_goals(c, d, {})
		assert_eq(with_row[2]["text"], "Claim a Void Refinement inheritance")
		assert_false(with_row[2]["done"])
		assert_true(Guidance.void_goals(c, d, {Inheritances.claimed_flag("test_void_legacy"): true})[2]["done"])


## INH-003: an open inheritance says how long it waits; under a year it is a warning.
func test_inheritance_opportunity_shows_time_left() -> void:
	var d := data()
	d.inheritances["test_legacy"] = {"id": "test_legacy", "name": "Test Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
		"stages": [{"name": "Gate", "days": 1, "test": "realm", "min_realm": "qi_refining"}], "reward": {}}
	var c := _fresh()
	c.realm_index = 1
	var find := func(today: int) -> Dictionary:
		for e in Guidance.journal(c, d, {}, today, "misty_forest"):
			if e["section"] == "Opportunities" and String(e["text"]).begins_with("Test Legacy"):
				return e
		return {}
	var near: Dictionary = find.call(5 * Calendar.DAYS_PER_YEAR - 100)
	assert_true(String(near["text"]).contains("(3 months left)"))
	assert_eq(near["tone"], "warning")
	var far: Dictionary = find.call(2 * Calendar.DAYS_PER_YEAR)
	assert_true(String(far["text"]).contains("(3 years left)"))
	assert_eq(far["tone"], "normal")


## GUIDE-031: a hint that only repeats the goal is dropped.
func test_drop_goal_echoes() -> void:
	var hints := PackedStringArray(["Ask Elder Mo in Qingshi Village where to begin", "Visit the market"])
	var kept := Guidance.drop_goal_echoes("Goal: Talk to Elder Mo in Qingshi Village", hints)
	assert_eq(Array(kept), ["Visit the market"])
	# the first word is ignored, so a goal without other capitalized words drops nothing
	assert_eq(Array(Guidance.drop_goal_echoes("Goal: Win your first fight", hints)), Array(hints))
	var qi := PackedStringArray(["Your Qi Refining is stalled.", "Qi is thin here."])
	assert_eq(Array(Guidance.drop_goal_echoes("Goal: Reach Qi Refining", qi)), ["Qi is thin here."])
	assert_eq(Array(Guidance.drop_goal_echoes("", hints)), Array(hints))



func _bitter_setup() -> Array:
	var d := data()
	var c := _fresh()
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	return [d, c, people, rival]


func _bitter_hint(hs: PackedStringArray) -> String:
	for h in hs:
		if h.contains("holds a grudge"):
			return h
	return ""


func test_bitter_rival_hint_with_cost() -> void:
	var s := _bitter_setup()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var people: Dictionary = s[2]
	var rival: CharacterData = s[3]
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	assert_eq(_bitter_hint(Guidance.hints(c, d, 1.0, 20, people, flags)), "", "proud: none")
	Karma.add_grudge(c, d, rival.id, 20)
	var cost := Karma.amends_cost(c, rival.id, d)
	c.add_item("spirit_stone", cost)
	var h := _bitter_hint(Guidance.hints(c, d, 1.0, 20, people, flags))
	assert_true(h.contains("Make amends (%d stones)" % cost), h)
	assert_true(h.contains(rival.name))


func test_bitter_rival_hint_unaffordable_unmet_and_dead() -> void:
	var s := _bitter_setup()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var people: Dictionary = s[2]
	var rival: CharacterData = s[3]
	Karma.add_grudge(c, d, rival.id, 20)
	var cost := Karma.amends_cost(c, rival.id, d)
	assert_eq(_bitter_hint(Guidance.hints(c, d, 1.0, 20, people, {})), "", "not met")
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	assert_true(_bitter_hint(Guidance.hints(c, d, 1.0, 20, people, flags)).contains("Amends would cost %d stones" % cost))
	rival.alive = false
	assert_eq(_bitter_hint(Guidance.hints(c, d, 1.0, 20, people, flags)), "", "dead")


## GUIDE-033: the rival bout as a fair fight.
func _rival_fighter() -> Array:
	var d := data()
	var c := _fighter()
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	rival.realm_index = 1
	rival.stage = 0
	return [d, c, people, rival]


func _rival_kinds(fights: Array[Dictionary]) -> Array:
	return fights.map(func(f: Dictionary) -> String: return f["kind"])


## A rival so far behind the player that the bout rates fair for certain; asserts that first.
func _fair_rival_fixture() -> Array:
	var s := _rival_fighter()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var rival: CharacterData = s[3]
	c.realm_index = 2
	c.stage = 8
	rival.realm_index = 1
	rival.stage = 0
	rival.techniques = {}
	assert_true(Combat.win_chance(c, d, Mentorship.spar_enemy(rival, d)) >= Guidance.FAIR_FIGHT_MIN_CHANCE, "fixture bout is fair")
	return s


func test_fair_fights_list_a_fair_rival_bout() -> void:
	var s := _fair_rival_fixture()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var people: Dictionary = s[2]
	var rival: CharacterData = s[3]
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	var fights := Guidance.fair_fights(c, d, flags, c.age_days, "qingshi_village", people, {rival.id: 20})
	assert_true(_rival_kinds(fights).has("rival"), "fair bout listed")
	for f in fights:
		if f["kind"] == "rival":
			assert_true(String(f["text"]).begins_with("Challenge %s" % rival.name))
	assert_false(_rival_kinds(Guidance.fair_fights(c, d, flags, c.age_days, "qingshi_village")).has("rival"), "no people: none")


func test_fair_fights_skip_the_rival_when_away_bitter_unmet_or_on_cooldown() -> void:
	var s := _fair_rival_fixture()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var people: Dictionary = s[2]
	var rival: CharacterData = s[3]
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	var favor := {rival.id: 20}
	var base := Guidance.fair_fights(c, d, flags, c.age_days, "qingshi_village", people, favor)
	assert_true(_rival_kinds(base).has("rival"), "listed at home")
	assert_false(_rival_kinds(Guidance.fair_fights(c, d, flags, c.age_days, "other_region", people, favor)).has("rival"), "elsewhere")
	assert_false(_rival_kinds(Guidance.fair_fights(c, d, {}, c.age_days, "qingshi_village", people, favor)).has("rival"), "unmet")
	var cool := c.age_days
	c.npc_action_days["spar:" + rival.id] = cool
	assert_false(_rival_kinds(Guidance.fair_fights(c, d, flags, cool, "qingshi_village", people, favor)).has("rival"), "cooldown")
	c.npc_action_days.erase("spar:" + rival.id)
	Karma.add_grudge(c, d, rival.id, 20)
	assert_false(_rival_kinds(Guidance.fair_fights(c, d, flags, c.age_days, "qingshi_village", people, favor)).has("rival"), "bitter")
	assert_true(base.size() <= Guidance.FAIR_FIGHTS_MAX)


# --- GUIDE-034: the journal says each goal once ------------------------------

func _reach_mentions(c: CharacterData, target: String) -> int:
	var n := 0
	for e in Guidance.journal(c, data(), {}, 0, "qingshi_village"):
		var section := String(e.get("section", ""))
		if (section == "Goals" or section == "Next steps") and String(e["text"]).contains(target):
			n += 1
	return n


func test_journal_foundation_peak_breakthrough_is_said_once() -> void:
	var c := _veteran()
	c.realm_index = 2
	c.stage = data().realms[2].stage_count() - 1
	c.qi = Cultivation.qi_required(c, data())
	assert_true(Cultivation.can_attempt_breakthrough(c, data()))
	assert_eq(_reach_mentions(c, "Core Formation"), 1)


func test_journal_newcomer_next_steps_keep_their_hints() -> void:
	var c := _fresh()
	var hint_lines := Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 0, {})
	var next: Array[String] = []
	for e in Guidance.journal(c, data(), {}, 0, "qingshi_village"):
		if String(e.get("section", "")) == "Next steps":
			next.append(String(e["text"]))
	assert_eq(next.size(), hint_lines.size())


func test_fallen_rival_journal_line_carries_record() -> void:
	var s := _bitter_setup()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var rival: CharacterData = s[3]
	rival.alive = false
	var flags := {Rivals.FIRST_MEETING_FLAG: true, Rivals.BOUTS_WON_FLAG: 3, Rivals.BOUTS_LOST_FLAG: 1}
	var out: Array[Dictionary] = []
	Guidance._rival_entry(out, c, d, flags, s[2])
	assert_eq(out[0]["text"], "Rival: %s (fallen; bouts 3 won, 1 lost)" % rival.name)
	out.clear()
	Guidance._rival_entry(out, c, d, {Rivals.FIRST_MEETING_FLAG: true}, s[2])
	assert_eq(out[0]["text"], "Rival: %s (fallen)" % rival.name)


## GRAT-001: the "Debts and grudges" journal section.
func _karma_npc(people: Dictionary, id: String, npc_name: String) -> CharacterData:
	var npc := CharacterData.new()
	npc.id = id
	npc.name = npc_name
	npc.home_region = "qingshi_village"
	people[id] = npc
	return npc


func _karma_lines(c: CharacterData, people: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	Guidance._karma_entries(out, c, data(), people)
	return out


func test_karma_entries_gratitude_tiers() -> void:
	var d := data()
	var c := _fresh()
	var people := {}
	_karma_npc(people, "a", "Ayla")
	_karma_npc(people, "b", "Bo")
	_karma_npc(people, "e", "Eve")
	c.gratitude = {"a": 70, "b": 45, "e": 10}
	var out := _karma_lines(c, people)
	assert_eq(out.size(), 3)
	assert_eq(out[0]["section"], "Debts and grudges")
	assert_eq(out[0]["text"], "Ayla owes you a debt of gratitude and would join a fight at your side in %s" % Exploration.region_name(d, "qingshi_village"))
	assert_eq(out[1]["text"], "Bo owes you a debt of gratitude and may send you gifts")
	assert_eq(out[2]["text"], "Eve owes you a debt of gratitude")


func test_karma_entries_grudges() -> void:
	var d := data()
	var c := _fresh()
	var people := {}
	_karma_npc(people, "h", "Hao")
	_karma_npc(people, "m", "Mei")
	_karma_npc(people, "r", "Rival")
	_karma_npc(people, "x", "Dead")
	people["x"].alive = false
	c.rival = "r"
	c.grudges = {"h": int(d.karma["hunt"]["min_grudge"]), "m": 5, "r": 90, "x": 80}
	var out := _karma_lines(c, people)
	assert_eq(out.size(), 2)
	assert_eq(out[0]["tone"], "warning")
	assert_true(String(out[0]["text"]).begins_with("Hao holds"))
	assert_true(String(out[0]["text"]).contains("ambush"))
	# GRAT-002: a hunting grudge names the amends cost and where to pay it.
	assert_true(String(out[0]["text"]).contains("amends cost %d stones" % Karma.amends_cost(c, "h", d)))
	assert_true(String(out[0]["text"]).ends_with("(in %s)" % Exploration.region_name(d, "qingshi_village")))
	assert_eq(out[1]["tone"], "dim")
	assert_false(String(out[1]["text"]).contains("ambush"))
	assert_false(String(out[1]["text"]).contains("amends"))


func test_karma_entries_cap_and_empty() -> void:
	var c := _fresh()
	assert_eq(_karma_lines(c, {}).size(), 0)
	var people := {}
	for i in 4:
		_karma_npc(people, "n%d" % i, "N%d" % i)
		c.gratitude["n%d" % i] = 10 + i
	var out := _karma_lines(c, people)
	assert_eq(out.size(), 3)
	assert_true(String(out[0]["text"]).begins_with("N3"))
	assert_eq(_karma_lines(_fresh(), people).size(), 0)


## GUIDE-036: a Soul Formation player late in the realm; the Void Refinement pill is injected.
func _void_pill_player(d: GameData) -> CharacterData:
	var c := _qr(0, 0)
	c.realm_index = 5
	c.stage = d.realms[5].stage_count() - 3
	d.recipes.erase("void_refinement_pill")  # C-127's real pill would be the source; these tests inject their own
	d.items.erase("void_refinement_pill")
	d.items["void_pill"] = {"id": "void_pill", "name": "Void Pill", "price": 9000, "tags": ["no_shop"], "effects": {"breakthrough_realm": "void_refinement", "breakthrough_bonus": 0.2}}
	return c


func test_pill_source_goal_recipe_and_auction() -> void:
	var d := GameData.load_from_dir()  # injects a pill, lot and recipe; keep the shared data() clean
	var c := _void_pill_player(d)
	assert_eq(Guidance.pill_source_goal(c, d), "")  # no source at all
	d.auction_houses["fallen_star_auction"]["lot_table"].append({"item": "void_pill", "base_price": 1, "weight": 1, "rarity": "epic"})
	assert_eq(Guidance.pill_source_goal(c, d), "Bid for a Void Pill at the Fallen Star Market auction.")
	d.recipes["void_pill"] = {"id": "void_pill", "profession": "alchemist", "output": {"item": "void_pill", "count": 1}}
	assert_eq(Guidance.pill_source_goal(c, d), "Find an alchemist to brew a Void Pill for Void Refinement.")
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	assert_eq(Guidance.pill_source_goal(c, d), "Brew a Void Pill for Void Refinement (Alchemist).")
	assert_true(_has(Guidance.goals(c, d, {}), "Brew a Void Pill"))
	assert_false(_has(Guidance.goals(c, d, {}), "Save for"))
	c.stage = 0
	assert_eq(Guidance.pill_source_goal(c, d), "")


func test_pill_source_goal_silent_when_a_shop_sells_it() -> void:
	var d := data()
	var c := _qr(6, 20)
	assert_eq(Guidance.pill_source_goal(c, d), "")
	assert_true(_has(Guidance.goals(c, d, {}), "Save for"))


func _renown_rows(c: CharacterData, d: GameData) -> Array:
	return Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return String(e["text"]).begins_with("Renown in "))


func test_journal_renown_line_shows_gap_to_next_title() -> void:
	var c := _fresh()
	var d := data()
	var tiers: Array = d.renown["tiers"]
	var next: Dictionary = tiers[1]
	var rows := _renown_rows(c, d)
	assert_eq(rows.size(), 1)
	var text := String(rows[0]["text"])
	assert_true(text.contains("0 (unknown)"))
	assert_true(text.contains("%d more for %s." % [int(next["min"]), String(next["title"])]))
	assert_true(text.contains("As %s, merchants there take %d percent off." % [String(next["title"]), roundi((1.0 - float(next["buy_mult"])) * 100)]))


func test_journal_renown_line_at_top_tier_and_without_config() -> void:
	var c := _fresh()
	var d := data()
	var tiers: Array = d.renown["tiers"]
	c.renown["qingshi_village"] = int((tiers[tiers.size() - 1] as Dictionary)["min"])
	var rows := _renown_rows(c, d)
	assert_eq(rows.size(), 1)
	assert_true(String(rows[0]["text"]).contains("the highest name there is"))
	d.renown = {}
	assert_eq(_renown_rows(c, d).size(), 0)

## C-127: a late Soul Formation player gets a goal for the real Void Piercing Pill (shops stock it like the other realm pills).
func test_pill_goal_names_void_piercing_pill() -> void:
	var d := GameData.load_from_dir()
	var c := _qr(0, 0)
	c.realm_index = 5
	c.stage = d.realms[5].stage_count() - 3
	assert_true(Guidance.pill_saving_goal(c, d).begins_with("Save for a Void Piercing Pill"), Guidance.pill_saving_goal(c, d))


func test_pill_source_goal_for_void_refinement_player() -> void:
	var c := _qr(0, 0)
	c.realm_index = 6
	c.stage = data().realms[6].stage_count() - 3
	assert_eq(data().realms[7].id, "body_integration")
	assert_eq(Guidance.pill_source_goal(c, data()), "Find an alchemist to brew a Body-Void Union Pill for Body Integration.")
