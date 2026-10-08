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
	assert_true(_has(hints, "learn a profession"))
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
	assert_false(_has(hints, "Look for the"))


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
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 100), "Explore the wilds"), "too early")
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", -1), "Explore the wilds"), "no clock")
	c.realm_index = 0
	assert_false(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "", 400), "Explore the wilds"), "not for Mortals")


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
	assert_eq(goals.size(), 6)
	for g in goals:
		assert_false(g["done"])
		for bad in ["%", "{", "<null>"]:
			assert_false(String(g["text"]).contains(bad))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_eq(section.size(), 6)
	assert_eq(section.filter(func(e: Dictionary) -> bool: return e["tone"] == "warning").size(), 1)
	assert_eq(section[0]["tone"], "warning")
	assert_true(String(section[0]["text"]).begins_with("[ ] "))
	c.techniques = {"basic_breathing": {"level": 1}}
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
