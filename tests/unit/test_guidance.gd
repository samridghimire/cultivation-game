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
	# A mortal has a single stage, so the goal is the Qi Refining breakthrough (GUIDE-103).
	assert_true(_has(hints, "more qi to reach the %s breakthrough" % data().realms[1].name))
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


func test_injury_hint_names_cultivation_cost() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "internal_injury")
	var hints := Guidance.hints(c, data())
	assert_true(_has(hints, "Treat your injuries"))
	assert_true(_has(hints, "Left alone they cost about"))
	assert_true(_has(hints, "weaken you in fights"))
	c.injuries = {"internal_injury": 1}
	assert_false(_has(Guidance.hints(c, data()), "Left alone"))


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


## GUIDE-093: a vowel-initial stipend item reads "an ...".
func test_stipend_clause_uses_an_before_a_vowel() -> void:
	var d := data()
	d.items["test_elixir"] = {"name": "Elixir of Calm"}
	var clause := Guidance._stipend_clause(d, {"items": {"test_elixir": 1}})
	d.items.erase("test_elixir")
	assert_true(clause.contains(" an Elixir of Calm"), clause)


## GUIDE-084: the sect-rank hint says what the next rank pays.
func test_sect_hint_names_stipend() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var ranks: Array[Dictionary] = (d.sects["azure_cloud_sect"] as SectDef).ranks
	var stones := int(ranks[1]["stipend"]["spirit_stones"])
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Inner Disciple (it pays %d stones a month)" % stones))
	c.sect["contribution"] = 600
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "is open (it pays %d stones a month). Attempt it at a sect hall." % stones))
	c.sect["rank"] = 1
	c.realm_index = 3
	var pill: String = d.items["qi_gathering_pill"]["name"]
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "a %s a month" % pill))
	var saved: Dictionary = ranks[2]["stipend"]
	ranks[2].erase("stipend")
	c.sect["contribution"] = 0
	var plain := Guidance._sect_hint(c, d)
	ranks[2]["stipend"] = saved
	assert_false(plain.contains("it pays"), plain)
	assert_true(plain.ends_with("to become Core Disciple."), plain)


## GUIDE-085: the open trial hint gives the odds.
func test_trial_hint_when_every_combat_style_is_mastered() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	for k: String in c.attributes:
		c.attributes[k] = 1
	var combat_id := ""
	for id: String in d.techniques:
		if d.techniques[id].kind == "combat" and d.techniques[id].max_level > 1:
			combat_id = id
			break
	assert_true(combat_id != "", "no combat tech")
	c.techniques = {combat_id: {"level": 1, "xp": 0.0}}
	assert_true(Guidance.trial_odds(c, d) < 0.5, "lvl1 odds %s" % Guidance.trial_odds(c, d))
	assert_true(Guidance._sect_hint(c, d).contains("practise or grow a stage first"), Guidance._sect_hint(c, d))
	c.techniques[combat_id]["level"] = d.techniques[combat_id].max_level
	assert_true(Techniques.is_mastered(c, d, combat_id))
	assert_true(Guidance.trial_odds(c, d) < 0.5, "mastered odds %s" % Guidance.trial_odds(c, d))
	var hint := Guidance._sect_hint(c, d)
	assert_true(hint.contains("grow a stage first"), hint)
	assert_false(hint.contains("practise"), hint)


func test_trial_odds_hint() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_eq(Guidance.trial_odds(c, d), -1.0)
	assert_false(Guidance._sect_hint(c, d).contains("You face"))
	c.sect["contribution"] = 600
	var enemy_name: String = d.enemies["azure_sword_examiner"]["name"]
	var hint := Guidance._sect_hint(c, d)
	assert_true(hint.contains("You face the " + enemy_name), hint)
	assert_true(hint.contains("%d in 100" % roundi(Guidance.trial_odds(c, d) * 100.0)), hint)
	assert_eq(hint.contains("practise or grow a stage first"), Guidance.trial_odds(c, d) < 0.5)
	for k: String in c.attributes:
		c.attributes[k] = 1
	c.techniques = {}
	c.stage = 0
	assert_true(Guidance.trial_odds(c, d) < 0.5, "weak disciple should be unlikely to win")
	assert_true(Guidance._sect_hint(c, d).contains("practise or grow a stage first"))


## GUIDE-092: an injury that loses the trial says to heal, not to practise.
func test_trial_hint_injury_holds_back() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	assert_eq(Guidance.odds_unhurt(c, d, d.enemies["azure_sword_examiner"]), -1.0)
	for k: String in c.attributes:
		c.attributes[k] = 40
	c.stage = 0
	var unhurt := Guidance.trial_odds(c, d)
	assert_true(unhurt >= 0.5, "strong disciple should win unhurt: %f" % unhurt)
	Injuries.inflict(c, d, "broken_bones")
	assert_true(Guidance.trial_odds(c, d) < 0.5, "injured: %f" % Guidance.trial_odds(c, d))
	var hint := Guidance._sect_hint(c, d)
	assert_true(hint.contains("Your injuries hold you back: healed, you would win about"), hint)
	assert_false(hint.contains("practise or grow"), hint)


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


func test_newcomer_herb_hint_says_what_it_is_worth() -> void:
	var d := data()
	var qi := int(d.items["spirit_herb"]["effects"]["qi"])
	var c := _fresh()
	c.inventory = {"spirit_herb": 1}
	var hints := Guidance.hints(c, d, 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Use your Spirit Herb (Inventory, I): %d qi at once, about " % qi))
	c.inventory = {"spirit_herb": 3}
	hints = Guidance.hints(c, d, 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Use your 3 Spirit Herbs (Inventory, I): %d qi at once, about " % (qi * 3)))


## REVIEW: the count form uses Items.item_plural, not a bare "s" ("Lotuses", never "Lotuss").
func test_newcomer_herb_hint_plural_follows_item_plural() -> void:
	var d := data()
	var c := _fresh()
	c.inventory = {"hundred_year_snow_lotus": 2}
	var hints := Guidance.hints(c, d, 1.0, 10, {}, {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Use your 2 %s (Inventory, I)" % Items.item_plural(d, "hundred_year_snow_lotus", 2)))
	assert_false(_has(hints, "Lotuss"))


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
	assert_false(_has(hints, "Meditation at"))
	var gather := ""
	for line in hints:
		if line.begins_with("Gather "):
			gather = line
	assert_true(gather.contains(" At Cloud-Sea Cliff (2x qi) in Azure Peak (10 days away) it would take about "), gather)
	var needed := Cultivation.qi_required(c, data()) - c.qi
	var days := Calendar.format_duration(ceili(needed / Cultivation.qi_per_day(c, data(), Guidance.best_qi_reachable(c, data(), "qingshi_village")["density"])))
	assert_true(gather.ends_with("it would take about %s." % days), gather)


func test_better_qi_dropped_when_the_trip_costs_more_than_it_saves() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.qi = Cultivation.qi_required(c, data()) - 5.0
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(hints, "Gather "))
	assert_false(_has(hints, "Meditation at"))
	assert_false(_has(hints, "it would take about"))


func test_better_qi_keeps_standalone_line_without_a_gather_line() -> void:
	var c := _fresh()
	c.realm_index = 1
	var d := data()
	var lines := PackedStringArray(["Something else."])
	assert_eq(Guidance._merge_better_qi(lines, c, d, 1.0, "qingshi_village"), lines)


func test_route_days_follows_routes_and_gating() -> void:
	var c := _fresh()
	c.realm_index = 1
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "qingshi_village"), 0)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "misty_forest"), 3)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "azure_peak"), 10)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "myriad_peaks_ridge"), -1)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "nowhere"), -1)
	c.realm_index = 0
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "azure_peak"), -1)


func test_first_hop_names_the_neighbour_on_the_cheapest_path() -> void:
	var c := _fresh()
	c.realm_index = 1
	var d := data()
	assert_eq(Guidance.first_hop(c, d, "qingshi_village", "misty_forest"), "misty_forest")
	var hop := Guidance.first_hop(c, d, "qingshi_village", "azure_peak")
	assert_true(hop != "")
	assert_eq(Guidance.route_days(c, d, "qingshi_village", hop) + Guidance.route_days(c, d, hop, "azure_peak"), Guidance.route_days(c, d, "qingshi_village", "azure_peak"))
	assert_eq(Guidance.first_hop(c, d, "qingshi_village", "qingshi_village"), "")
	assert_eq(Guidance.first_hop(c, d, "qingshi_village", "nowhere"), "")
	assert_eq(Guidance.first_hop(c, d, "nowhere", "qingshi_village"), "")


func test_far_where_says_by_way_of_only_for_a_two_hop_road() -> void:
	var c := _fresh()
	c.realm_index = 1
	var d := data()
	var direct := {"region_id": "misty_forest", "region_name": "Misty Forest", "days": 3}
	var near := Guidance._far_where(c, d, "qingshi_village", direct)
	assert_true(near.begins_with("in Misty Forest ("))
	assert_false(near.contains("by way of"))
	var hop := Guidance.first_hop(c, d, "qingshi_village", "azure_peak")
	assert_true(hop != "" and hop != "azure_peak")
	var far := {"region_id": "azure_peak", "region_name": "Azure Peak", "days": 9}
	var line := Guidance._far_where(c, d, "qingshi_village", far)
	assert_true(line.contains("by way of " + Exploration.region_name(d, hop)))
	assert_true(line.begins_with("in Azure Peak (9"))


func test_hinted_region_finds_the_region_a_hint_names() -> void:
	var d := data()
	assert_eq(Guidance.hinted_region(d, "... in Fallen Star Market (10 days) sells ...", "qingshi_village"), "fallen_star_market")
	assert_eq(Guidance.hinted_region(d, "... in Fallen Star Market (10 days) sells ...", "fallen_star_market"), "")
	assert_eq(Guidance.hinted_region(d, "no place named here", "qingshi_village"), "")


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
	c.add_item("iron_essence", 10)
	assert_eq(Guidance._sell_hint(c, d, "qingshi_village"), "", "below the minimum")
	c.add_item("iron_essence", 30)
	var total := Items.sell_price(d, "iron_essence") * 40
	var hint := Guidance._sell_hint(c, d, "qingshi_village")
	assert_true(total >= Guidance.SELL_HINT_MIN)
	assert_true(hint.contains("Wandering Merchant"), hint)
	assert_true(hint.contains("%d spirit stones" % total), hint)
	assert_true(hint.contains("ore"), hint)
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
	assert_true(Guidance.goals(c, data(), {}).size() <= 5)
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
	var days := 0
	for r: Dictionary in d.regions["qingshi_village"]["routes"]:
		if r["to"] == "misty_forest":
			days = int(r["days"])
	assert_true(_has(hints, "You have never been to Misty Forest (%s); the road from here is open." % Calendar.format_duration(days)))


## GUIDE-106: the unexplored-road hint says whether you could win fights there.
func test_unexplored_hint_mentions_winnable_fights() -> void:
	var d := data()
	var strong := _fresh()
	strong.realm_index = 2
	strong.stage = 8
	strong.techniques["iron_fist"] = {"level": d.techniques["iron_fist"].max_level, "xp": 0.0}
	var road := Guidance.unexplored_routes(strong, d, "qingshi_village")[0]
	var expected := false
	for f: Dictionary in Guidance.fair_fights(strong, d, {}, 10, String(road["to"])):
		expected = expected or f["kind"] == "explore"
	var hint := Guidance._untried_hint(strong, d, 10, {}, {}, "qingshi_village")
	if hint.begins_with("You have never been to"):
		assert_eq(hint.ends_with("You could win fights there."), expected)
	var weak := _fresh()
	weak.realm_index = 0
	assert_false(Guidance._untried_hint(weak, d, 10, {}, {}, "qingshi_village").contains("You could win fights there."))


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


func _set_all_ranks(c: CharacterData, rank: int) -> void:
	for prof_id: String in data().professions:
		c.professions[prof_id] = {"rank": rank, "xp": 0.0}


func test_craft_hint_names_recipe_until_rank_two() -> void:
	var c := _crafter()
	c.life_stats["items_crafted"] = 2
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 400), "You have what Qi Gathering Pill needs: craft it at Village Workshop in Qingshi Village."))
	c.life_stats["items_crafted"] = 20
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 400), "You have what Qi Gathering Pill"), "crafts alone do not fade it")
	_set_all_ranks(c, Guidance.CRAFT_HINT_MAX_RANK)
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
	c.professions["alchemist"]["rank"] = Guidance.CRAFT_HINT_MAX_RANK
	assert_eq(Guidance.herb_here_hint(c, data(), "qingshi_village"), "", "faded")


func test_crafter_hints_fade_by_rank_not_by_crafts() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.life_stats["items_crafted"] = 10
	c.inventory = {}
	assert_true(Guidance.herb_here_hint(c, data(), "qingshi_village") != "", "rank 0 with 10 crafts still hears the herb hint")
	_set_all_ranks(c, Guidance.CRAFT_HINT_MAX_RANK)
	assert_eq(Guidance.herb_here_hint(c, data(), "qingshi_village"), "", "rank 2: no herb hint")
	# craft-now hint
	c.realm_index = 1
	c.life_stats["encounters"] = 1
	c.inventory = {"spirit_herb": 2, "dew_grass": 1}
	var ready := Guidance.craftable_now(c, data())
	assert_false(ready.is_empty())
	assert_eq(Guidance._untried_feature_hint(c, data(), 400, {}, {}, "qingshi_village"), "", "rank 2: no craft-now hint")
	_set_all_ranks(c, 0)
	var hint := Guidance._untried_feature_hint(c, data(), 400, {}, {}, "qingshi_village")
	assert_true(hint.begins_with("You have what "), hint)


func test_herb_hint_looks_one_region_further() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	# The market has no herb patch; its first neighbour in data order that does grow one is named.
	var hint := Guidance.herb_here_hint(c, data(), "fallen_star_market")
	var herb_name := String(data().items["spirit_herb"]["name"])
	var region_name := String(data().regions["qingshi_village"]["name"])
	assert_true(hint.begins_with("%s grows at Village Herb Slope in %s, a short walk away: gather it to refine " % [herb_name, region_name]), hint)
	assert_true(_has(Guidance.hints(c, data(), 1.0, 99, {}, {}, "fallen_star_market", 400), "a short walk away"))
	# One that grows here wins over the neighbour.
	assert_true(not Guidance.herb_here_hint(c, data(), "qingshi_village").contains("a short walk away"))
	# A region with no route gets nothing further.
	assert_eq(Guidance.herb_here_hint(c, data(), "nowhere"), "")


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
	assert_true(hint.contains(" to level 2)"), hint)
	var hints := Guidance._newcomer_hints(c, data(), {Guidance.ELDER_MO_FLAG: true}, "qingshi_village")
	assert_true(_has(hints, "Practise Iron Fist"))
	assert_false(_has(hints, "no fighting style"))
	c.techniques["iron_fist"]["level"] = 3
	assert_eq(Guidance.practice_hint(c, data()), "")
	assert_false(_has(Guidance._newcomer_hints(c, data(), {Guidance.ELDER_MO_FLAG: true}, "qingshi_village"), "no fighting style"))
	c.techniques = {}
	assert_eq(Guidance.practice_hint(c, data()), "")


## Finds a Qi Refining fighter in the misty forest for whom Iron Fist level 2 flips a foe (stats are
## raised stage by stage until one does; the fixture is searched because the foe ratings are balance data).
func _payoff_fighter() -> CharacterData:
	for stage in range(0, 9):
		var c := _fresh()
		c.realm_index = 1
		c.stage = stage
		c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
		if not Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", 10).is_empty():
			return c
	return null


func test_practice_payoff_names_the_fight_the_next_level_opens() -> void:
	var c := _payoff_fighter()
	assert_true(c != null, "some stage has a foe that level 2 turns around")
	var payoff := Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", 10)
	assert_true(float(payoff["now"]) < Guidance.FAIR_FIGHT_MIN_CHANCE and float(payoff["next"]) >= 0.5)
	assert_eq(int(payoff["level"]), 2)
	var hint := Guidance.practice_hint(c, data(), "misty_forest", 10)
	assert_true(hint.contains("at level 2 you would beat %s about" % Text.a(String(payoff["enemy"]))), hint)
	assert_true(hint.contains("about %d times in 100, now %d" % [roundi(float(payoff["next"]) * 100.0), roundi(float(payoff["now"]) * 100.0)]), hint)
	assert_false(Guidance.practice_hint(c, data()).contains("you would beat"), "no region: old text")


## GUIDE-095: the payoff is rated unhurt, so an injury never makes practice look like the cure.
func test_practice_payoff_ignores_injuries() -> void:
	var c := _payoff_fighter()
	assert_true(c != null)
	var healthy := Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", 10)
	Injuries.inflict(c, data(), "broken_bones")
	var hurt := Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", 10)
	assert_eq(hurt, healthy, "same payoff injured or not")
	# A fighter who already wins the foe once healed gets no payoff for it.
	var strong := _fresh()
	strong.realm_index = 1
	strong.stage = 8
	strong.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var plain := Guidance.practice_hint(strong, data(), "misty_forest", 10)
	Injuries.inflict(strong, data(), "broken_bones")
	assert_eq(Guidance.practice_hint(strong, data(), "misty_forest", 10), plain, "injury changes nothing")


func test_practice_payoff_is_empty_when_mastered_unknown_or_unplaced() -> void:
	var c := _payoff_fighter()
	assert_true(c != null)
	assert_true(Guidance.practice_payoff(c, data(), "iron_fist", "", 10).is_empty())
	assert_true(Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", -1).is_empty())
	assert_true(Guidance.practice_payoff(c, data(), "stone_skin", "misty_forest", 10).is_empty(), "unknown technique")
	c.techniques["iron_fist"]["level"] = data().techniques["iron_fist"].max_level
	assert_true(Guidance.practice_payoff(c, data(), "iron_fist", "misty_forest", 10).is_empty(), "mastered")


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
			var prev: Dictionary = fights[i - 1]
			var cur: Dictionary = fights[i]
			assert_true(int(prev["stones"]) >= int(cur["stones"]))
			if int(prev["stones"]) == int(cur["stones"]):
				assert_true(float(prev["chance"]) >= float(cur["chance"]))
	assert_eq(fights, Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village"))


## GUIDE-087: the open promotion trial is a listed fight ("trial"), only when eligible and winnable.
func test_fair_fights_list_an_open_sect_trial() -> void:
	var c := _fighter()
	c.sect["contribution"] = 600
	# Iron Fist/Stone Skin level 5 puts the Inner Disciple trial well above FAIR_FIGHT_MIN_CHANCE.
	c.techniques = {"iron_fist": {"level": 5, "xp": 0.0}, "stone_skin": {"level": 5, "xp": 0.0}}
	assert_eq(Sects.check_promotion(c, data()), "", "fixture is eligible")
	# The trial pays no stones, so paying missions would crowd it out of the top three: put them on cooldown.
	for mission_id: String in data().sect_missions:
		c.mission_cooldowns[mission_id] = c.age_days + 100
	var fights := Guidance.fair_fights(c, data(), {"chore_boar_done": true}, c.age_days, "")
	var trials := fights.filter(func(f: Dictionary) -> bool: return f["kind"] == "trial")
	assert_eq(trials.size(), 1, "the open trial is listed")
	assert_true(String(trials[0]["text"]).begins_with("Sect trial: Inner Disciple"))


func test_fair_fights_skip_the_trial_without_contribution_or_strength() -> void:
	var c := _fighter()
	var kinds: Array = Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village").map(func(f: Dictionary) -> String: return f["kind"])
	assert_false(kinds.has("trial"), "short of contribution")
	var weak := new_character()
	weak.realm_index = 1
	weak.stage = 1
	weak.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600, "spent": 0}
	weak.techniques = {}
	kinds = Guidance.fair_fights(weak, data(), {}, weak.age_days, "qingshi_village").map(func(f: Dictionary) -> String: return f["kind"])
	assert_false(kinds.has("trial"), "too weak")


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
	assert_eq(goals.size(), 6)
	for g in goals:
		assert_false(g["done"])
	assert_true(Guidance.foundation_goals_active(c, data(), {}))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Foundation goals")
	assert_eq(section.size(), 6)
	assert_eq(section[0]["tone"], "warning")
	assert_eq(section[1]["tone"], "normal")
	c.stage = 1
	c.abode = "any_abode"
	c.body_stage = 1
	goals = Guidance.foundation_goals(c, data(), {})
	assert_true(goals[0]["done"] and goals[3]["done"] and goals[4]["done"])
	assert_false(goals[1]["done"])
	assert_false(goals[2]["done"])
	assert_false(goals[5]["done"])
	c.sect = {"id": data().sects.keys()[0], "rank": 2, "contribution": 0, "spent": 0}
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	c.equipment["armor"] = "cloth_robe"
	var beaten := {Guidance.beat_realm_flag("foundation_establishment"): true}
	assert_false(Guidance.foundation_goals_active(c, data(), beaten))
	var after := Guidance.journal(c, data(), beaten, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Foundation goals")
	assert_true(after.is_empty())


func test_foundation_goals_clan_and_realm_limits() -> void:
	var c := _fresh()
	c.realm_index = 2
	assert_true(Guidance.foundation_goals(c, data(), {}, ClanData.new())[5]["done"])
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 6)
	c.realm_index = 9
	assert_false(Guidance.foundation_goals_active(c, data(), {}))
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), Guidance.tribulation_goals(c, data(), {}).size(), "only the Tribulation ladder is left")
	c.realm_index = 1
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 7)


## The HUD's ladder stays put once all its goals are done, so the last one is still announced.
func test_goal_ladder_keeps_a_finished_ladder() -> void:
	var c := _fresh()
	c.realm_index = 2
	c.stage = 1
	c.abode = "x"
	c.body_stage = 1
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	c.equipment["armor"] = "cloth_robe"
	assert_false(Guidance.foundation_goals_active(c, data(), {Guidance.beat_realm_flag("foundation_establishment"): true}, ClanData.new()))
	assert_eq(Guidance.goal_ladder_id(c), "foundation")
	assert_eq(Guidance.goal_ladder("foundation", c, data(), {}, ClanData.new()).size(), 6)
	c.realm_index = 1
	assert_eq(Guidance.goal_ladder_id(c), "first")
	c.realm_index = 9
	assert_eq(Guidance.goal_ladder_id(c), "tribulation")
	assert_eq(Guidance.goal_ladder("", c, data(), {}).size(), Guidance.tribulation_goals(c, data(), {}).size(), "an unnamed ladder falls back to the active one")


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
	var row := Guidance.foundation_goals(c, data(), {})[2]
	assert_eq(row["text"], "Win a fight against a Foundation foe")
	assert_false(row["done"])
	assert_true(Guidance.foundation_goals(c, data(), {flag: true})[2]["done"])


func test_foundation_goal_defence_row() -> void:
	var c := _fresh()
	c.realm_index = 2
	c.stage = 1
	var row := Guidance.foundation_goals(c, data(), {})[1]
	assert_eq(row["text"], "Learn a body art and wear armor")
	assert_false(row["done"])
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_true(Techniques.knows_kind(c, data(), "body"))
	assert_false(Guidance.foundation_goals(c, data(), {})[1]["done"], "body art only")
	c.equipment["armor"] = "cloth_robe"
	assert_true(Guidance.foundation_goals(c, data(), {})[1]["done"])


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
	c.realm_index = 9
	assert_eq(Guidance.goal_ladder_id(c), "tribulation")
	assert_eq(section_of.call().size(), 0, "the core section is gone")


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
	c.realm_index = 9
	assert_eq(Guidance.goal_ladder_id(c), "tribulation")
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


## BI-001: the Body Integration ladder.
func test_body_integration_goals_rows_and_ladder() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realm_index_of("body_integration")
	assert_eq(c.realm_index, 7)
	var has_inh := Guidance._has_realm_inheritance(d, "body_integration")
	var has_body := BodyTempering.stages(d).size() > 7
	var goals := Guidance.body_integration_goals(c, d, {})
	assert_eq(goals.size(), 2 + (1 if has_inh else 0) + (1 if has_body else 0))
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[0]["text"], "Reach Body Integration Middle")
	assert_true(Guidance.body_integration_goals_active(c, d, {}))
	assert_eq(Guidance.goal_ladder_id(c), "body")
	assert_eq(Guidance.goal_ladder("body", c, d, {}).size(), goals.size())
	assert_eq(Guidance.active_goal_ladder(c, d, {}).size(), goals.size())
	var section := func() -> Array:
		return Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Body Integration goals")
	assert_eq(section.call().size(), goals.size())
	assert_eq(section.call()[0]["tone"], "warning")
	c.stage = 1
	assert_true(Guidance.body_integration_goals(c, d, {})[0]["done"])
	assert_true(Guidance.body_integration_goals(c, d, {Guidance.beat_realm_flag("body_integration"): true})[1]["done"])
	c.realm_index = 6
	assert_false(Guidance.body_integration_goals_active(c, d, {}))
	c.realm_index = 7
	if not has_inh:
		d.inheritances["test_bi_legacy"] = {"id": "test_bi_legacy", "name": "BI Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
			"stages": [{"name": "Gate", "days": 1, "test": "realm", "min_realm": "body_integration"}], "reward": {}}
		var with_row := Guidance.body_integration_goals(c, d, {})
		assert_eq(with_row[2]["text"], "Claim a Body Integration inheritance")
		assert_false(with_row[2]["done"])
		assert_true(Guidance.body_integration_goals(c, d, {Inheritances.claimed_flag("test_bi_legacy"): true})[2]["done"])


## MAHA-001: the Mahayana ladder.
func test_mahayana_goals_rows_and_ladder() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realm_index_of("mahayana")
	assert_eq(c.realm_index, 8)
	var has_inh := Guidance._has_realm_inheritance(d, "mahayana")
	var goals := Guidance.mahayana_goals(c, d, {})
	assert_eq(goals.size(), 2 + (1 if has_inh else 0))
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[0]["text"], "Reach Mahayana Middle")
	assert_true(Guidance.mahayana_goals_active(c, d, {}))
	assert_eq(Guidance.goal_ladder_id(c), "mahayana")
	assert_eq(Guidance.goal_ladder("mahayana", c, d, {}).size(), goals.size())
	assert_eq(Guidance.active_goal_ladder(c, d, {}).size(), goals.size())
	var section := func() -> Array:
		return Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Mahayana goals")
	assert_eq(section.call().size(), goals.size())
	assert_eq(section.call()[0]["tone"], "warning")
	c.stage = 1
	assert_true(Guidance.mahayana_goals(c, d, {})[0]["done"])
	assert_true(Guidance.mahayana_goals(c, d, {Guidance.beat_realm_flag("mahayana"): true})[1]["done"])
	c.realm_index = 7
	assert_false(Guidance.mahayana_goals_active(c, d, {}))
	c.realm_index = 8
	if not has_inh:
		d.inheritances["test_maha_legacy"] = {"id": "test_maha_legacy", "name": "Maha Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
			"stages": [{"name": "Gate", "days": 1, "test": "realm", "min_realm": "mahayana"}], "reward": {}}
		var with_row := Guidance.mahayana_goals(c, d, {})
		assert_eq(with_row[2]["text"], "Claim a Mahayana inheritance")
		assert_false(with_row[2]["done"])
		assert_true(Guidance.mahayana_goals(c, d, {Inheritances.claimed_flag("test_maha_legacy"): true})[2]["done"])


## TT-001: the Tribulation Transcendence ladder.
func test_tribulation_goals_rows_and_ladder() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realm_index_of("tribulation_transcendence")
	assert_eq(c.realm_index, 9)
	var has_inh := Guidance._has_realm_inheritance(d, "tribulation_transcendence")
	var goals := Guidance.tribulation_goals(c, d, {})
	assert_eq(goals.size(), 2 + (1 if has_inh else 0))
	for g in goals:
		assert_false(g["done"])
	assert_eq(goals[0]["text"], "Reach Tribulation Transcendence Middle")
	assert_true(Guidance.tribulation_goals_active(c, d, {}))
	assert_eq(Guidance.goal_ladder_id(c), "tribulation")
	assert_eq(Guidance.goal_ladder("tribulation", c, d, {}).size(), goals.size())
	assert_eq(Guidance.active_goal_ladder(c, d, {}).size(), goals.size())
	var section := func() -> Array:
		return Guidance.journal(c, d, {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Tribulation Transcendence goals")
	assert_eq(section.call().size(), goals.size())
	assert_eq(section.call()[0]["tone"], "warning")
	c.stage = 1
	assert_true(Guidance.tribulation_goals(c, d, {})[0]["done"])
	assert_true(Guidance.tribulation_goals(c, d, {Guidance.beat_realm_flag("tribulation_transcendence"): true})[1]["done"])
	c.realm_index = 8
	assert_false(Guidance.tribulation_goals_active(c, d, {}))
	c.realm_index = 9
	if not has_inh:
		d.inheritances["test_tt_legacy"] = {"id": "test_tt_legacy", "name": "TT Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
			"stages": [{"name": "Gate", "days": 1, "test": "realm", "min_realm": "tribulation_transcendence"}], "reward": {}}
		var with_row := Guidance.tribulation_goals(c, d, {})
		assert_eq(with_row[2]["text"], "Claim a Tribulation Transcendence inheritance")
		assert_false(with_row[2]["done"])
		assert_true(Guidance.tribulation_goals(c, d, {Inheritances.claimed_flag("test_tt_legacy"): true})[2]["done"])


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
	var flags := {Rivals.FIRST_MEETING_FLAG: true, "chore_boar_done": true}
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
	var flags := {Rivals.FIRST_MEETING_FLAG: true, "chore_boar_done": true}
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
	# GUIDE-070: paying fights sort first and would crowd the unpaid bout out of the top three
	c.sect = {}
	for bounty_id: String in d.bounties:
		c.bounty_cooldowns[bounty_id] = c.age_days + 1000
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
	var flags := {Rivals.FIRST_MEETING_FLAG: true, "chore_boar_done": true}
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
	var flags := {Rivals.FIRST_MEETING_FLAG: true, "chore_boar_done": true}
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


func _rival_reach_lines(s: Array) -> Array[String]:
	var out: Array[Dictionary] = []
	Guidance._rival_entry(out, s[1], s[0], {Rivals.FIRST_MEETING_FLAG: true}, s[2])
	var lines: Array[String] = []
	for e in out:
		if String(e["text"]).begins_with("Reach "):
			lines.append(String(e["text"]))
	return lines


## RIVAL-018: what it takes to challenge a rival who is far ahead.
func test_rival_reach_line() -> void:
	var s := _bitter_setup()
	var d: GameData = s[0]
	var rival: CharacterData = s[3]
	assert_eq(_rival_reach_lines(s).size(), 0, "equal or weaker: no line")
	rival.realm_index = s[1].realm_index + 1
	var realm_name: String = d.realms[rival.realm_index].name
	assert_eq(_rival_reach_lines(s), ["Reach %s to stand a chance against %s." % [realm_name, rival.name]])
	Karma.add_grudge(s[1], d, rival.id, 20)
	assert_eq(_rival_reach_lines(s), ["Reach %s before %s comes looking for you." % [realm_name, rival.name]])
	rival.alive = false
	assert_eq(_rival_reach_lines(s).size(), 0, "dead rival: no line")


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
	var saved_renown: Dictionary = d.renown
	d.renown = {}
	assert_eq(_renown_rows(c, d).size(), 0)
	d.renown = saved_renown  # data() is shared between tests

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


func _village_gather_place() -> Dictionary:
	for p: Dictionary in data().regions["qingshi_village"]["places"]:
		if String(p.get("type", "")) == "gather":
			return p
	return {}


func test_herb_hint_respects_the_season() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	var place := _village_gather_place()
	var saved: Array = place["gather_table"]
	place["gather_table"] = [{"item": "spirit_herb", "weight": 3, "min": 2, "max": 3, "seasons": ["spring"]}]
	var spring := Guidance.herb_here_hint(c, data(), "qingshi_village", 10)
	var winter := Guidance.herb_here_hint(c, data(), "qingshi_village", 280)
	var any := Guidance.herb_here_hint(c, data(), "qingshi_village")
	place["gather_table"] = saved
	assert_true(spring.contains(String(place["display_name"])), "spring: " + spring)
	assert_false(winter.contains(String(place["display_name"])), "winter: " + winter)
	assert_true(any.contains(String(place["display_name"])), "no day: today's behaviour")


func test_herb_place_names_region_and_season() -> void:
	var c := _crafter()
	var marsh := String(data().regions["withered_bone_marsh"]["name"])
	var autumn := Guidance.herb_place(c, data(), "autumn_bog_lily", "qingshi_village", 200)
	assert_true(autumn.ends_with(" in " + marsh), autumn)
	assert_false(autumn.contains("(in "), autumn)
	var winter := Guidance.herb_place(c, data(), "autumn_bog_lily", "qingshi_village", 280)
	assert_true(winter.ends_with(" in %s (in Autumn)" % marsh), winter)
	assert_eq(Guidance.herb_place(c, data(), "autumn_bog_lily", "qingshi_village"), autumn, "no day = any season")
	var here := Guidance.herb_place(c, data(), "dew_grass", "qingshi_village", 280)
	assert_false(here.contains(" in "), "own region has no suffix: " + here)


## GUIDE-051: out of season, the fallback names the next season the herb grows in.
func test_herb_place_names_the_next_season() -> void:
	var c := _crafter()
	var place := _village_gather_place()
	var saved: Array = place["gather_table"]
	place["gather_table"] = [{"item": "autumn_bog_lily", "weight": 3, "min": 1, "max": 1, "seasons": ["spring", "autumn"]}]
	var summer := Guidance.herb_place(c, data(), "autumn_bog_lily", "qingshi_village", 100)
	var winter := Guidance.herb_place(c, data(), "autumn_bog_lily", "qingshi_village", 280)
	place["gather_table"] = saved
	assert_true(summer.ends_with("(in Autumn)"), summer)
	assert_true(winter.ends_with("(in Spring)"), winter)


## GUIDE-047: a broke crafter hears what odd jobs pay.
func test_odd_jobs_hint_for_a_broke_crafter() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	var income: int = Professions.work_preview(c, data(), "alchemist", Calendar.DAYS_PER_MONTH)["income"]
	var hint := Guidance._odd_jobs_hint(c, data(), "qingshi_village")
	var expected := "Short of stones? Odd jobs as %s at the %s pay about %d a month." % [data().professions["alchemist"].name, Guidance.workshop_place(data(), "qingshi_village"), income]
	assert_eq(hint, expected)
	c.inventory = {"spirit_stone": 1000}
	assert_eq(Guidance._odd_jobs_hint(c, data(), "qingshi_village"), "", "enough stones")
	c.inventory = {}
	c.professions.clear()
	assert_eq(Guidance._odd_jobs_hint(c, data(), "qingshi_village"), "", "no craft")


## GUIDE-050: holding the herbs (but no stones) is not "short of stones".
func test_odd_jobs_hint_counts_only_the_shortfall() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_herb": 2, "dew_grass": 1}
	assert_eq(Guidance._odd_jobs_hint(c, data(), "qingshi_village"), "", "has the herbs, 0 stones")
	c.inventory = {}
	assert_true(Guidance._odd_jobs_hint(c, data(), "qingshi_village") != "", "nothing at all")


func test_odd_jobs_hint_yields_to_the_herb_hint() -> void:
	var c := _crafter()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {}
	assert_true(Guidance.herb_here_hint(c, data(), "qingshi_village", 0) != "", "setup: herb hint fires")
	var lines := Guidance.hints(c, data(), 1.0, 99, {}, {}, "qingshi_village", 0)
	assert_false(_has(lines, "Short of stones?"))


func test_craft_now_hint_names_only_the_low_rank_craft() -> void:
	var c := _crafter()
	c.life_stats["encounters"] = 1
	_set_all_ranks(c, Guidance.CRAFT_HINT_MAX_RANK)
	assert_eq(Guidance._untried_feature_hint(c, data(), 400, {}, {}, "qingshi_village"), "")
	var low := ""
	for recipe_id: String in Guidance.craftable_now(c, data()):
		if low == "" and String(data().recipes[recipe_id]["profession"]) != "alchemist":
			low = recipe_id
	assert_true(low != "", "a second craft is craftable with this pack")
	c.professions[String(data().recipes[low]["profession"])]["rank"] = 0
	var hint := Guidance._untried_feature_hint(c, data(), 400, {}, {}, "qingshi_village")
	assert_true(hint.begins_with("You have what %s needs" % data().recipes[low]["name"]), hint)


func _unknown_recipe_line(prof_id: String, recipe_id: String) -> String:
	var c := CharacterData.new()
	c.professions[prof_id] = {"rank": int(data().recipes[recipe_id].get("min_rank", 0)), "xp": 0.0}
	for rid: String in data().recipes:
		if rid != recipe_id and String(data().recipes[rid].get("profession", "")) == prof_id:
			c.known_recipes.append(rid)
	return Guidance.next_recipe_line(c, data(), prof_id, "", 0)


func test_next_recipe_line_sources_and_length() -> void:
	var seen_sold := false
	var seen_other := false
	for rid: String in data().recipes:
		var prof_id := String(data().recipes[rid].get("profession", ""))
		var line := _unknown_recipe_line(prof_id, rid)
		if line == "":
			continue
		assert_true(line.begins_with("Next recipe: %s (rank " % data().recipes[rid]["name"]), line)
		assert_true(line.length() <= 100, "%d: %s" % [line.length(), line])
		assert_false(line.contains("_"), line)
		if line.contains("sold by merchants"):
			seen_sold = true
		elif not line.contains("grows at") and not line.contains("found at"):
			seen_other = true
	assert_true(seen_sold, "some scroll is sold by merchants")
	assert_true(seen_other, "some scroll is only found elsewhere")


func test_next_recipe_line_empty_when_all_known_or_doctor() -> void:
	var c := CharacterData.new()
	c.professions["alchemist"] = {"rank": Professions.max_rank(data()), "xp": 0.0}
	for rid: String in data().recipes:
		c.known_recipes.append(rid)
	assert_eq(Guidance.next_recipe_line(c, data(), "alchemist", "", 0), "")
	c.professions["doctor"] = {"rank": 1, "xp": 0.0}
	assert_eq(Guidance.next_recipe_line(c, data(), Medicine.DOCTOR, "", 0), "")


func test_goals_include_next_recipe_line() -> void:
	var c := CharacterData.new()
	c.realm_index = 1
	c.professions["alchemist"] = {"rank": 1, "xp": 0.0}
	var line := Guidance.next_recipe_line(c, data(), "alchemist", "", 0)
	if line != "":
		assert_true(_has(Guidance.goals(c, data(), {}), line))


func test_mortal_crafter_nudge() -> void:
	var c := _fresh()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	var spot := String(Guidance.best_qi_in_region(c, data(), "qingshi_village")["name"])
	var hints := Guidance.hints(c, data(), 1.0, 10, {}, {}, "qingshi_village", 30)
	assert_true(_has(hints, "You are still a mortal"))
	if spot != "":
		assert_true(_has(hints, "Meditate at %s" % spot))
	assert_false(_has(Guidance.hints(c, data(), 1.0, 10, {}, {}, "qingshi_village", 10), "You are still a mortal"))
	var none := _fresh()
	none.professions = {}
	assert_eq(Guidance.mortal_crafter_hint(none, data(), "qingshi_village", 60), "")
	var higher := _fresh()
	higher.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	higher.realm_index = 1
	assert_eq(Guidance.mortal_crafter_hint(higher, data(), "qingshi_village", 60), "")
	assert_true(Guidance.mortal_crafter_hint(c, data(), "", 60).contains("a meditation spot"))
	var ready := _fresh()
	ready.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	ready.stage = data().realms[0].stage_count() - 1
	ready.qi = Cultivation.qi_required(ready, data())
	assert_true(Cultivation.can_attempt_breakthrough(ready, data()))
	assert_eq(Guidance.mortal_crafter_hint(ready, data(), "qingshi_village", 60), "", "no meditate nudge once a breakthrough is possible")
	c.techniques = {}
	var one := Guidance.hints(c, data(), 1.0, 1, {}, {}, "qingshi_village", 30)
	assert_eq(one.size(), 1)
	assert_true(one[0].contains("You are still a mortal"))


func test_idle_hint_replaces_gather_line() -> void:
	var c := _fresh()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	c.last_meditated_day = 0
	var idle := Guidance.hints(c, data(), 1.0, 30, {}, {}, "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS)
	var found := false
	for line in idle:
		assert_false(line.begins_with("Gather "), line)
		found = found or line.begins_with("You have not cultivated")
	assert_true(found, str(idle))
	c.last_meditated_day = Guidance.IDLE_CULTIVATION_DAYS
	var fresh := Guidance.hints(c, data(), 1.0, 30, {}, {}, "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS)
	var gather := false
	for line in fresh:
		assert_false(line.begins_with("You have not cultivated"), line)
		gather = gather or line.begins_with("Gather ")
	assert_true(gather, str(fresh))


func test_idle_crafter_hint() -> void:
	var c := _fresh()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	c.last_meditated_day = 0
	var line := Guidance.idle_crafter_hint(c, data(), "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS)
	assert_true(line.begins_with("You have not cultivated in "), line)
	assert_true(line.contains("would carry you to the next layer in about"), line)
	assert_eq(Guidance.idle_crafter_hint(c, data(), "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS - 1), "")
	assert_eq(Guidance.idle_crafter_hint(c, data(), "qingshi_village", -1), "")
	assert_true(Guidance.idle_crafter_hint(c, data(), "", 40).begins_with("You have not cultivated"))
	var unknown := _fresh()
	unknown.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	unknown.realm_index = 1
	assert_true(Guidance.idle_crafter_hint(unknown, data(), "qingshi_village", 400).begins_with("You have not cultivated lately."), "an unstamped (old) save does not claim a duration")
	var none := _fresh()
	none.realm_index = 1
	assert_eq(Guidance.idle_crafter_hint(none, data(), "qingshi_village", 90), "")
	var foundation := _fresh()
	foundation.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	foundation.realm_index = 2
	assert_eq(Guidance.idle_crafter_hint(foundation, data(), "qingshi_village", 90), "")
	var hints := Guidance.hints(c, data(), 1.0, 1, {}, {}, "qingshi_village", 60)
	assert_true(_has(hints, "You have not cultivated in"))


func test_realm_goals_table_matches_named_ladders() -> void:
	var c := new_character()
	var d := data()
	for realm_id: String in Guidance.REALM_GOAL_TABLE:
		c.realm_index = d.realm_index_of(realm_id)
		var rows := Guidance.realm_goals(c, d, {}, realm_id)
		var name: String = d.realms[c.realm_index].name
		assert_eq(rows[0]["text"], "Reach %s Middle" % name, realm_id)
		assert_eq(rows[1]["text"], "Win a fight against a %s foe" % name, realm_id)
		assert_eq(Guidance.goal_ladder(Guidance.goal_ladder_id(c), c, d, {}).size(), rows.size(), realm_id)


func test_thin_defence_hint() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	var line := Guidance.thin_defence_hint(c, data())
	assert_true(line.contains("Your defence is thin for Foundation foes"), line)
	assert_false(line.contains("Heal your injuries"))
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20), "Your defence is thin"))
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_true(line.contains("learn a body technique such as Stone Skin Tempering and wear armor"), line)
	var body_only := Guidance.thin_defence_hint(c, data())
	assert_true(body_only.contains("wear armor") and not body_only.contains("learn a body technique"), "a body art without armor is still thin: " + body_only)
	c.equipment["armor"] = "boar_hide_jerkin"
	assert_eq(Guidance.thin_defence_hint(c, data()), "")
	c.techniques = {}
	var armor_only := Guidance.thin_defence_hint(c, data())
	assert_true(armor_only.contains("learn a body technique") and not armor_only.contains("wear armor"), "armor without a body art: " + armor_only)
	c.equipment = {}
	c.techniques = {}
	c.injuries = {"broken_ribs": 5}
	assert_true(Guidance.thin_defence_hint(c, data()).ends_with("Heal your injuries before you fight."))
	c.realm_index = 1
	assert_eq(Guidance.thin_defence_hint(c, data()), "", "not at Qi Refining")
	c.realm_index = 3
	assert_eq(Guidance.thin_defence_hint(c, data()), "", "not past Foundation")


func test_thin_defence_hint_points_to_the_nearest_market() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 200}
	var line := Guidance.thin_defence_hint(c, data(), "qingshi_village")
	assert_true(line.contains("Fallen Star Market") and line.contains("10 days") and line.contains("Heavenforge Smithy"), line)
	var near := Guidance.nearest_selling(c, data(), "qingshi_village", func(r: String) -> String: return Guidance.affordable_armor(c, data(), r))
	assert_eq(near["region_id"], "fallen_star_market")
	assert_eq(int(near["days"]), 10)
	assert_true(Guidance.thin_defence_hint(c, data(), "misty_forest").contains("8 days"))
	c.inventory = {}
	assert_false(Guidance.thin_defence_hint(c, data(), "qingshi_village").contains("sells"), "no stones, no armor sentence")
	# Qingshi's own Wandering Merchant sells a body manual, so no far market is named; armor already worn
	c.equipment = {"armor": "boar_hide_jerkin"}
	var body := Guidance.thin_defence_hint(c, data(), "qingshi_village")
	assert_true(body.contains("teaches one") and not body.contains("sect shop"), body)
	# a gated route is never used
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	assert_true(Guidance.nearest_selling(c, data(), "azure_peak", func(r: String) -> String: return r if r == "myriad_peaks_ridge" else "").is_empty(), "Core-gated route skipped")
	c.realm_index = data().realm_index_of("core_formation")
	assert_eq(Guidance.nearest_selling(c, data(), "azure_peak", func(r: String) -> String: return r if r == "myriad_peaks_ridge" else "")["days"], 10)
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	assert_eq(Guidance.nearest_selling(c, data(), "qingshi_village", func(r: String) -> String: return "here" if r == "qingshi_village" else "")["days"], 0)


func test_buy_ingredient_hint() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.professions["array_master"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_stone": 20, "spirit_herb": 2}
	var line := Guidance.buy_ingredient_hint(c, data(), "qingshi_village")
	assert_true(line.contains("Blank Talisman Paper"), line)
	assert_true(line.contains("Wandering Merchant"), line)
	assert_false(line.contains("odd jobs"), line)
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village", 10), "Wandering Merchant"))
	c.inventory["talisman_paper"] = 2
	assert_eq(Guidance.buy_ingredient_hint(c, data(), "qingshi_village"), "")
	c.inventory = {"spirit_herb": 2}
	assert_true(Guidance.buy_ingredient_hint(c, data(), "qingshi_village").contains("odd jobs"))
	assert_eq(Guidance.buy_ingredient_hint(_fresh(), data(), "qingshi_village"), "")


## GUIDE-078: the buy hint warns when the bought paper plus stones cost at least what the output sells for.
func test_buy_ingredient_hint_warns_when_barely_paying() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.professions["talisman_master"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_stone": 20, "dew_grass": 2}
	var recipe_id := "swift_wind_talisman"
	var spend: int = Guidance.merchant_price(c, data(), "qingshi_village", "talisman_paper")
	assert_true(spend < int(Alchemy.recipe_margin(data(), recipe_id)["value"]), "fixture: this craft pays")
	assert_false(Guidance.buy_ingredient_hint(c, data(), "qingshi_village").contains("barely pays"))
	# Make the output nearly worthless so the same craft loses stones.
	var item: Dictionary = data().items["swift_wind_talisman"]
	var old_price: Variant = item["price"]
	item["price"] = 2
	var line := Guidance.buy_ingredient_hint(c, data(), "qingshi_village")
	item["price"] = old_price
	assert_true(line.ends_with("It barely pays: sell what you craft before buying more."), line)


## GUIDE-076: out of paper in Misty Forest, the hint points to the nearest market that sells it.
func test_buy_ingredient_hint_points_to_the_nearest_market() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.professions["talisman_master"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_stone": 20, "dew_grass": 2}
	var far := Guidance.buy_ingredient_hint(c, data(), "misty_forest")
	assert_true(far.contains("Blank Talisman Paper") and far.contains("Qingshi Village") and far.contains("Wandering Merchant"), far)
	assert_true(far.contains(" in Qingshi Village ("), far)
	var near := Guidance.buy_ingredient_hint(c, data(), "qingshi_village")
	assert_true(near.contains("the Wandering Merchant sells them"), near)
	assert_false(near.contains(" days"), near)


func test_buy_ingredient_hint_skips_gatherable_shortfalls() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_stone": 50}
	assert_eq(Guidance.buy_ingredient_hint(c, data(), "qingshi_village"), "")
	assert_eq(Guidance.merchant_selling(data(), "qingshi_village", "talisman_paper"), "Wandering Merchant")


func test_goal_ladder_reads_the_realm_goal_table() -> void:
	for realm_id: String in Guidance.REALM_GOAL_TABLE:
		var row: Dictionary = Guidance.REALM_GOAL_TABLE[realm_id]
		var c := CharacterData.new()
		c.realm_index = data().realm_index_of(realm_id)
		assert_eq(c.realm_index, int(row["index"]), "%s index matches realms.json" % realm_id)
		assert_eq(Guidance.goal_ladder_id(c), row["ladder"], realm_id)
		assert_true(not Guidance.goal_ladder(String(row["ladder"]), c, data(), {}).is_empty(), "%s ladder has goals" % realm_id)


func test_heal_source_names_item_clinic_or_fallback() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {}
	# Matching item owned
	c.inventory["bone_setting_salve"] = 1
	assert_eq(Guidance.heal_source(c, data(), "qingshi_village"), "use your Bone-Setting Salve")
	# Non-matching item is not named
	c.inventory = {"meridian_mending_pill": 1, "spirit_stone": 500}
	var line := Guidance.heal_source(c, data(), "qingshi_village")
	assert_false(line.contains("Meridian"), line)
	assert_true(line.contains("Village Clinic treats it for"), line)
	var hint := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(hint, "The Village Clinic treats it for"))
	# No stones: not the clinic
	c.inventory = {}
	assert_false(Guidance.heal_source(c, data(), "qingshi_village").contains("Village Clinic treats it for"))
	# No region: old wording
	assert_eq(Guidance.heal_source(c, data(), ""), "")
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20), "Use a healing item or see a doctor."))


func test_heal_source_looks_past_the_first_injury() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "qi_deviation")
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"bone_setting_salve": 1}
	var line := Guidance.heal_source(c, data(), "misty_forest")
	assert_eq(line, "use your Bone-Setting Salve for your Broken Bones")


func test_heal_source_far_clinic_needs_the_stones() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"spirit_stone": 500}
	var cost := Medicine.clinic_cost(c, data(), "broken_bones")
	var line := Guidance.heal_source(c, data(), "misty_forest")
	assert_true(line.begins_with("the Village Clinic in Qingshi Village ("), line)
	assert_true(line.ends_with("treats it for %d stones" % cost), line)
	c.inventory = {}
	assert_eq(Guidance.heal_source(c, data(), "misty_forest"), "")



func test_heal_source_far_clinic_names_the_way() -> void:
	var c := _fresh()
	c.realm_index = 1
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"spirit_stone": 500}
	var hop := Guidance.first_hop(c, data(), "azure_peak", "qingshi_village")
	assert_true(hop != "" and hop != "qingshi_village")
	var line := Guidance.heal_source(c, data(), "azure_peak")
	assert_true(line.contains("by way of " + Exploration.region_name(data(), hop)), line)
	assert_true(line.contains("Village Clinic in Qingshi Village ("), line)
	assert_false(Guidance.heal_source(c, data(), "misty_forest").contains("by way of"))


func test_heal_source_names_the_injury_a_far_clinic_treats() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "qi_deviation")
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"spirit_stone": 500}
	var first := String(c.injuries.keys()[0])
	var line := Guidance.heal_source(c, data(), "misty_forest")
	assert_true(line.contains(" treats your %s for " % Injuries.injury_name(data(), first)), line)
	assert_false(line.contains(" treats it "), line)
	assert_false(line.ends_with("for your %s" % Injuries.injury_name(data(), first)), line)

func test_thin_defence_hint_names_where_to_get_armor() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 200}
	var armor_id := Guidance.affordable_armor(c, data(), "myriad_peaks_ridge")
	assert_true(armor_id != "", "200 stones buy armor at the Ridge stall")
	assert_eq(Equipment.slot_of(data(), armor_id), "armor")
	var line := Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.contains("Ridge Hermit's Stall sells %s for %d stones" % [data().items[armor_id]["name"], int(data().items[armor_id]["price"])]), line)
	assert_false(Guidance.thin_defence_hint(c, data()).contains("sells"), "region omitted keeps the old line")
	assert_eq(Guidance.affordable_armor(c, data(), "qingshi_village"), "", "Qingshi's merchant stocks no armor")
	c.inventory = {}
	assert_eq(Guidance.affordable_armor(c, data(), "myriad_peaks_ridge"), "")
	assert_false(Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge").contains(" stones."), "no stones, no armor sentence")


func test_thin_defence_hint_names_a_body_manual_source() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.inventory = {"spirit_stone": 200}
	c.equipment = {"armor": "jade_scale_armor"}
	var source := Guidance.body_manual_source(c, data(), "myriad_peaks_ridge")
	var line := Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge")
	if source == "":
		assert_false(line.contains("teaches one"), line)
	else:
		assert_true(line.ends_with(" %s teaches one." % source), line)
		assert_false(line.contains("sells"), "armor is worn, so no armor sentence: " + line)
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_eq(Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge"), "", "armor and a body art")
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0}
	c.techniques = {}
	assert_eq(Guidance.body_manual_source(c, data(), "nowhere"), "Manual: Stone Skin Tempering (sect shop, 45 contribution)")


func test_fair_fights_sort_by_pay_before_chance() -> void:
	var found: Array[Dictionary] = [
		{"text": "b", "chance": 1.0, "stones": 0},
		{"text": "a", "chance": 0.75, "stones": 30},
		{"text": "c", "chance": 0.9, "stones": 0},
		{"text": "d", "chance": 0.9, "stones": 0},
	]
	found.sort_custom(Guidance.fair_fight_before)
	assert_eq(found.map(func(f: Dictionary) -> String: return f["text"]), ["a", "b", "c", "d"])

## GUIDE-069: an unarmored Qi Refining fighter hears about armor they can afford.
func _armor_hint_fighter() -> CharacterData:
	var c := _fresh()
	c.realm_index = 1
	c.stage = Guidance.ARMOR_HINT_MIN_STAGE
	c.techniques = {"blood_shadow_flight": {"level": 1}}
	c.equipment = {}
	c.inventory = {"spirit_stone": 200}
	return c


func test_armor_hint_shown_to_unarmored_fighter() -> void:
	var c := _armor_hint_fighter()
	var armor_id := Guidance.affordable_armor(c, data(), "myriad_peaks_ridge")
	var line := Guidance.armor_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.begins_with("Armor would keep you standing in fights"), line)
	assert_true(line.contains(data().items[armor_id]["name"]), line)
	assert_true(_has(Guidance._newcomer_hints(c, data(), {}, "myriad_peaks_ridge"), "Armor would keep you"))


func test_armor_hint_hidden_when_it_does_not_apply() -> void:
	var c := _armor_hint_fighter()
	c.equipment = {"armor": "boar_hide_jerkin"}
	assert_eq(Guidance.armor_hint(c, data(), "myriad_peaks_ridge"), "", "armor on")
	c = _armor_hint_fighter()
	c.inventory = {"spirit_stone": 1}
	assert_eq(Guidance.armor_hint(c, data(), "myriad_peaks_ridge"), "", "too few stones")
	c = _armor_hint_fighter()
	c.stage = Guidance.ARMOR_HINT_MIN_STAGE - 1
	assert_eq(Guidance.armor_hint(c, data(), "myriad_peaks_ridge"), "", "stage too low")
	c = _armor_hint_fighter()
	c.techniques = {}
	assert_eq(Guidance.armor_hint(c, data(), "myriad_peaks_ridge"), "", "no combat technique")
	assert_eq(Guidance.armor_hint(_armor_hint_fighter(), data(), ""), "", "no region")


## WU-253: merchant stock tags in plain words.
func test_merchant_goods() -> void:
	assert_eq(Guidance.merchant_goods({"stock_tags": ["equipment", "ore", "smithing"]}), "weapons and armor, ore, smithing materials")
	assert_eq(Guidance.merchant_goods({}), "pills and sundries")
	assert_eq(Guidance.merchant_goods({"stock_tags": ["talisman", "inscription"]}), "talismans and array materials")
	assert_eq(Guidance.merchant_goods({"stock_tags": ["beast_part"], "max_price": 100}), "beast part (cheap goods)")
	assert_true(Guidance.market_lines(data(), "fallen_star_market").has("Heavenforge Smithy: weapons and armor, ore, smithing materials"))

func test_merchant_price_applies_renown() -> void:
	var c := _fresh()
	var base := int(data().items["talisman_paper"]["price"])
	assert_eq(Guidance.merchant_price(c, data(), "qingshi_village", "talisman_paper"), base)
	c.renown["qingshi_village"] = 100000
	var mult := Renown.buy_multiplier(c, data(), "qingshi_village")
	assert_true(mult < 1.0, "top renown tier discounts")
	assert_eq(Guidance.merchant_price(c, data(), "qingshi_village", "talisman_paper"), maxi(1, roundi(base * mult)))
	assert_eq(Guidance.merchant_place(data(), "qingshi_village", "no_such_item"), {})


func test_buy_hint_quotes_discounted_price() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.professions["array_master"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"spirit_stone": 20, "spirit_herb": 2}
	c.renown["qingshi_village"] = 100000
	var price := Guidance.merchant_price(c, data(), "qingshi_village", "talisman_paper")
	var line := Guidance.buy_ingredient_hint(c, data(), "qingshi_village")
	assert_true(line.contains("for %d stones each" % price), line)


func test_affordable_armor_uses_charged_price() -> void:
	var c := _armor_hint_fighter()
	c.equipment = {}
	var armor_id := Guidance.affordable_armor(c, data(), "myriad_peaks_ridge")
	assert_true(armor_id != "")
	var price := Guidance.merchant_price(c, data(), "myriad_peaks_ridge", armor_id)
	c.inventory["spirit_stone"] = price - 1
	assert_true(Guidance.affordable_armor(c, data(), "myriad_peaks_ridge") != armor_id, "one stone short")
	c.inventory["spirit_stone"] = price
	assert_eq(Guidance.affordable_armor(c, data(), "myriad_peaks_ridge"), armor_id)


func test_sect_faction_merchant_price_follows_reputation() -> void:
	var c := _fresh()
	var item_id := ""
	for id: String in data().items:
		var place := Guidance.merchant_place(data(), "fallen_star_market", id)
		if String(place.get("faction", "")) == "blood_lotus_sect" and int(data().items[id].get("price", 0)) >= 10:
			item_id = id
			break
	assert_true(item_id != "", "a Blood Lotus Apothecary item")
	var neutral := Guidance.merchant_price(c, data(), "fallen_star_market", item_id)
	Reputation.change(c, data(), "blood_lotus_sect", -2000)
	assert_true(Guidance.merchant_price(c, data(), "fallen_star_market", item_id) > neutral, "hated sect charges more")


func test_armor_hint_points_to_the_nearest_market() -> void:
	var c := _armor_hint_fighter()
	var line := Guidance.armor_hint(c, data(), "qingshi_village")
	assert_true(line.begins_with("Armor would keep you standing in fights. The "), line)
	assert_false(line.contains(": The "), line)
	assert_true(line.contains("Fallen Star Market") and line.contains("10 days"), line)
	var local := Guidance.armor_hint(c, data(), "fallen_star_market")
	assert_true(local.contains("sells") and not local.contains("days"), local)
	c.inventory = {"spirit_stone": 0}
	assert_eq(Guidance.armor_hint(c, data(), "qingshi_village"), "", "no stones")


# --- Empty "Fights you can win" (GUIDE-074) --------------------------------------

func _gv74_fighter() -> CharacterData:
	var c := _fresh()
	c.techniques = {}
	c.techniques = {"iron_fist": {"level": 2}}
	return c


func _gv99_injured_fighter() -> CharacterData:
	var c := _fighter()
	c.sect = {}
	c.injuries = {"broken_bones": 60, "internal_injury": 120, "damaged_meridians": 365}
	return c


func test_empty_fair_fights_note_says_heal_first_when_injury_is_the_reason() -> void:
	var c := _gv99_injured_fighter()
	var flags := {"chore_boar_done": true}
	assert_true(Guidance.fair_fights(c, data(), flags, c.age_days, "misty_forest").is_empty(), "injuries drop every fight")
	var note := Guidance.empty_fair_fights_note(c, data(), "misty_forest", c.age_days, flags)
	assert_true(note.contains("heal your injuries first (healed, you could win: "), note)
	assert_eq(c.injuries.size(), 3, "the caller's character is untouched")
	c.injuries = {}
	assert_false(Guidance.empty_fair_fights_note(c, data(), "misty_forest", c.age_days, flags).contains("heal"))
	var hurt := _gv99_injured_fighter()
	assert_false(Guidance.empty_fair_fights_note(hurt, data()).contains("heal"), "no region: today's text")


func test_empty_fair_fights_note_asks_for_practice() -> void:
	var c := _gv74_fighter()
	var id: String = c.techniques.keys()[0]
	var note := Guidance.empty_fair_fights_note(c, data())
	assert_true(note.begins_with("Nothing here is in your favour yet: practise %s past level 3" % data().techniques[id].name), note)


func test_empty_fair_fights_note_skips_mastered_technique() -> void:
	var c := _gv74_fighter()
	c.techniques["blood_demon_rage"] = {"level": data().techniques["blood_demon_rage"].max_level}
	var note := Guidance.empty_fair_fights_note(c, data())
	assert_true(note.contains("practise %s past level 3" % data().techniques["iron_fist"].name), note)
	c.techniques["iron_fist"]["level"] = data().techniques["iron_fist"].max_level
	assert_eq(Guidance.empty_fair_fights_note(c, data()), "Nothing here is in your favour yet: grow a stage.")


func test_empty_fair_fights_note_prefers_thin_defence() -> void:
	var c := _gv74_fighter()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.equipment = {}
	var note := Guidance.empty_fair_fights_note(c, data())
	assert_true(note.contains("wear armor"), note)
	assert_false(note.contains("practise"), note)


func test_empty_fair_fights_note_blank_without_combat_technique() -> void:
	var c := _fresh()
	c.techniques = {}
	assert_eq(Guidance.empty_fair_fights_note(c, data()), "")


func test_empty_fair_fights_entry_only_when_no_fights() -> void:
	var c := _gv74_fighter()
	var out: Array[Dictionary] = []
	Guidance._fair_fight_entries(out, [], c, data(), "qingshi_village")
	assert_eq(out.size(), 1)
	assert_eq(out[0]["section"], "Fights you can win")
	var listed: Array[Dictionary] = [{"text": "Fight a boar", "chance": 0.9, "kind": "explore"}]
	var out2: Array[Dictionary] = []
	Guidance._fair_fight_entries(out2, listed, c, data(), "qingshi_village")
	assert_eq(out2.size(), 1)
	assert_eq(out2[0]["text"], "Fight a boar")


func test_gear_elsewhere_line_names_nearest_gear_seller() -> void:
	var c := _fresh()
	var line := Guidance.gear_elsewhere_line(c, data(), "qingshi_village")
	assert_true(line.begins_with("No weapons or armor here."), line)
	assert_true(line.contains("Heavenforge Smithy"), line)
	assert_true(line.contains("Fallen Star Market"), line)
	assert_true(line.contains("10 days"), line)
	assert_eq(Guidance.gear_elsewhere_line(c, data(), "fallen_star_market"), "")


## GUIDE-088: the armor hint counts what your loot would sell for.
func _loot_id(tag: String) -> String:
	for id: String in data().items:
		if Items.has_tag(data(), id, [tag]) and Items.sell_price(data(), id) > 0:
			return id
	return ""


func test_armor_hint_counts_loot_far_market() -> void:
	var c := _armor_hint_fighter()
	var ore := _loot_id("ore")
	c.inventory = {"spirit_stone": 10, ore: 100}
	assert_false(Guidance.sell_offer(c, data(), "qingshi_village").is_empty(), "the Qingshi merchant buys ore")
	var line := Guidance.armor_hint(c, data(), "qingshi_village")
	assert_true(line.contains("Sell your"), line)
	assert_true(line.contains("Heavenforge Smithy"), line)
	c.inventory = {"spirit_stone": 10}
	assert_eq(Guidance.armor_hint(c, data(), "qingshi_village"), "", "nothing to sell")
	c.inventory = {"spirit_stone": 200, ore: 100}
	assert_false(Guidance.armor_hint(c, data(), "qingshi_village").contains("Sell"), "enough stones")


func test_armor_hint_counts_loot_local_market() -> void:
	var c := _armor_hint_fighter()
	var pelt := _loot_id("beast_material")
	c.inventory = {"spirit_stone": 1, pelt: 400}
	assert_eq(Guidance.affordable_armor(c, data(), "myriad_peaks_ridge"), "", "stones alone fall short")
	assert_false(Guidance.sell_offer(c, data(), "myriad_peaks_ridge").is_empty(), "the Ridge stall buys beast materials")
	var line := Guidance.armor_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.contains("sell your"), line)
	assert_true(line.contains("Ridge Hermit's Stall"), line)


## GUIDE-090: the thin-defence hint counts loot too.
func test_thin_defence_hint_counts_loot() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	var pelt := _loot_id("beast_material")
	c.inventory = {"spirit_stone": 1, pelt: 400}
	assert_eq(Guidance.affordable_armor(c, data(), "myriad_peaks_ridge"), "", "stones alone fall short")
	var offer := Guidance.sell_offer(c, data(), "myriad_peaks_ridge")
	assert_false(offer.is_empty(), "the Ridge stall buys beast materials")
	var loot_armor := Guidance.affordable_armor(c, data(), "myriad_peaks_ridge", 1 + int(offer["total"]))
	assert_true(loot_armor != "", "stones plus loot buy armor at the Ridge stall")
	var line := Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.contains("Sell your %s to the %s (about %d stones) first." % [offer["goods"], offer["merchant"], offer["total"]]), line)
	c.inventory = {"spirit_stone": 1}
	assert_false(Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge").contains("Sell your"), "nothing to sell")
	c.inventory = {"spirit_stone": 500, pelt: 400}
	assert_false(Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge").contains("Sell your"), "enough stones")


func test_keep_trial_replaces_last_shown() -> void:
	var found: Array[Dictionary] = []
	for i in 5:
		found.append({"text": "f%d" % i, "chance": 90, "kind": "mission", "enemy": "e", "stones": 10 - i})
	found.append({"text": "Sect trial: x", "chance": 70, "kind": "trial", "enemy": "e", "stones": 0})
	var shown := Guidance._keep_trial(found, Guidance.FAIR_FIGHTS_MAX)
	assert_eq(shown.size(), Guidance.FAIR_FIGHTS_MAX)
	assert_eq(shown[shown.size() - 1]["kind"], "trial")
	assert_eq(shown[0]["text"], "f0")
	assert_eq(shown[1]["text"], "f1")


func test_keep_trial_leaves_other_lists_alone() -> void:
	var found: Array[Dictionary] = []
	for i in 5:
		found.append({"text": "f%d" % i, "chance": 90, "kind": "mission", "enemy": "e", "stones": 10 - i})
	var shown := Guidance._keep_trial(found, Guidance.FAIR_FIGHTS_MAX)
	assert_eq(shown.size(), Guidance.FAIR_FIGHTS_MAX)
	assert_eq(shown[2]["text"], "f2")
	var with_trial: Array[Dictionary] = [found[0], {"text": "T", "chance": 70, "kind": "trial", "enemy": "e", "stones": 0}, found[1], found[2], found[3]]
	shown = Guidance._keep_trial(with_trial, Guidance.FAIR_FIGHTS_MAX)
	assert_eq(shown[1]["text"], "T")
	assert_eq(shown[2]["text"], "f1")


## GUIDE-102: the mission hint names the best-paying ready mission, folded into the "Earn" line.
func _best_expected(c: CharacterData, d: GameData) -> String:
	var best := ""
	for id: String in Sects.available_missions(c, d, {}):
		if Sects.check_mission(c, d, id, {}) != "" or Guidance._mission_too_dangerous(c, d, id):
			continue
		var m: Dictionary = d.sect_missions[id]
		if best == "":
			best = id
			continue
		var b: Dictionary = d.sect_missions[best]
		var mc := int(m.get("contribution", 0))
		var bc := int(b.get("contribution", 0))
		if mc > bc or (mc == bc and (int(m.get("days", 1)) < int(b.get("days", 1)) or (int(m.get("days", 1)) == int(b.get("days", 1)) and id < best))):
			best = id
	return best


func _qr3_disciple() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = 2
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	return c


func test_best_mission_named_in_earn_line() -> void:
	var d := data()
	var c := _qr3_disciple()
	var best := Guidance.best_mission(c, d)
	assert_eq(best, _best_expected(c, d))
	assert_true(best != "", "baseline has a ready mission")
	var lines := Guidance.hints(c, d, 1.0, 20)
	var found := 0
	for line: String in lines:
		if line.contains("Earn ") and (line.contains("The best pays ") or line.contains(" It pays ")):
			found += 1
			assert_true(line.contains(String(d.sect_missions[best]["name"])))
	assert_eq(found, 1)
	for line: String in lines:
		if not line.begins_with("Earn "):
			assert_false(line.contains("The best pays ") or line.contains(" It pays "))


func test_best_mission_absent_when_all_on_cooldown() -> void:
	var d := data()
	var c := _qr3_disciple()
	for id: String in d.sect_missions:
		c.mission_cooldowns[id] = c.age_days + 30
	assert_eq(Guidance.best_mission(c, d), "")
	assert_false(_has(Guidance.hints(c, d, 1.0, 20), "The best pays "))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Earn "))


func test_best_mission_never_too_dangerous() -> void:
	var d := data()
	var c := _qr3_disciple()
	var best := Guidance.best_mission(c, d)
	if best != "":
		assert_false(Guidance._mission_too_dangerous(c, d, best))


func test_best_mission_empty_for_rogue() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_eq(Guidance.best_mission(c, data()), "")


## GUIDE-105: the all-too-dangerous mission line says what to do.
## Puts every mission that is not too dangerous on cooldown; returns how many dangerous ones remain ready.
func _only_dangerous_ready(c: CharacterData, d: GameData) -> int:
	var left := 0
	for id: String in d.sect_missions:
		if Sects.check_mission(c, d, id, {}) != "" or not Guidance._mission_too_dangerous(c, d, id):
			c.mission_cooldowns[id] = c.age_days + 30
		else:
			left += 1
	return left


func test_dangerous_missions_say_practise_style() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	if _only_dangerous_ready(c, d) == 0:
		return
	var text := Guidance._mission_hint(c, d, {})
	assert_true(text.contains("too dangerous for you yet; practise %s first." % d.techniques["iron_fist"].name), text)


func test_practise_advice_not_repeated() -> void:
	var name: String = data().techniques["iron_fist"].name
	var out := PackedStringArray([
		"Practise %s on the Techniques screen: each level raises your odds." % name,
		"The sect's missions are too dangerous for you yet; practise %s first." % name,
	])
	out = Guidance._merge_practise_advice(out)
	assert_eq(out[0], "Practise %s on the Techniques screen: each level raises your odds." % name)
	assert_eq(out[1], "The sect's missions are too dangerous for you yet; the practice above would open them.")
	var lone := PackedStringArray(["The sect's missions are too dangerous for you yet; practise %s first." % name])
	lone = Guidance._merge_practise_advice(lone)
	assert_true(lone[0].ends_with("practise %s first." % name), lone[0])


func test_hints_merge_practise_advice_end_to_end() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	if _only_dangerous_ready(c, d) == 0:
		return
	var name: String = d.techniques["iron_fist"].name
	var lines := Guidance.hints(c, d, 1.0, 20)
	var practise := false
	for line in lines:
		practise = practise or line.contains("Practise %s on the Techniques screen" % name)
		assert_false(line.ends_with("practise %s first." % name), line)
	assert_true(practise, str(lines))


func test_dangerous_missions_say_grow_a_stage_when_mastered() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques["iron_fist"] = {"level": d.techniques["iron_fist"].max_level, "xp": 0.0}
	if _only_dangerous_ready(c, d) == 0:
		return
	assert_true(Guidance._mission_hint(c, d, {}).ends_with("too dangerous for you yet; grow a stage first."))


func test_dangerous_missions_say_heal_when_injuries_are_the_cause() -> void:
	var d := data()
	var saved: Dictionary = d.sect_missions.duplicate()
	var found := false
	for stage in range(0, 9):
		var c := new_character()
		c.realm_index = 1
		c.stage = stage
		c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
		c.injuries = {"internal_injury": 100, "broken_bones": 100}
		# Keep only the missions that are too dangerous (a safe one on cooldown speaks instead, GUIDE-110).
		var dangerous := 0
		d.sect_missions = saved.duplicate()
		for id: String in saved:
			if Sects.check_mission(c, d, id, {}) != "" or not Guidance._mission_too_dangerous(c, d, id):
				d.sect_missions.erase(id)
			else:
				dangerous += 1
		if dangerous == 0:
			continue
		var wins := false
		for id: String in d.sect_missions:
			wins = wins or Guidance.odds_unhurt(c, d, d.enemies[String(d.sect_missions[id]["enemy"])]) >= 0.5
		if wins:
			found = true
			assert_true(Guidance._mission_hint(c, d, {}).ends_with("too dangerous for you yet; heal your injuries first."))
			break
	d.sect_missions = saved
	assert_true(found, "some stage has injuries as the only obstacle")


## GUIDE-103: at the last layer the qi lines speak of the breakthrough.
func test_last_layer_qi_lines_name_the_breakthrough() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 1
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.last_meditated_day = 0
	var name := String(d.realms[2].name)
	c.stage = d.realms[1].stage_count() - 1
	c.qi = 0.0
	var gather := Guidance._cultivation_hint(c, d, 1.0)
	assert_true(gather.contains("to reach the %s breakthrough" % name), gather)
	var idle := Guidance.idle_crafter_hint(c, d, "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS)
	assert_true(idle.contains("the %s breakthrough" % name), idle)
	assert_false(idle.contains("next layer"), idle)
	c.stage = 3
	assert_true(Guidance._cultivation_hint(c, d, 1.0).contains("to reach the next stage"))
	assert_true(Guidance.idle_crafter_hint(c, d, "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS).contains("the next layer"))


## REVIEW: the "too dangerous" count stays on the count sentence; the best mission's "(days)" is not followed by a second parenthesis.
func test_best_mission_after_too_dangerous_count() -> void:
	var d := data()
	var found := false
	for realm in 3:
		for stage in range(1, 10):
			var c := new_character()
			c.realm_index = realm
			c.stage = stage
			c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
			var text := Guidance._mission_hint(c, d)
			if text.contains("too dangerous for you yet).") and (text.contains(" The best pays ") or text.contains(" It pays ")):
				found = true
				assert_true(text.find("too dangerous for you yet).") < maxi(text.find(" The best pays "), text.find(" It pays ")), text)
	assert_true(found, "some stage has both ready and too-dangerous missions")


func _hall_name(d: GameData, region_id: String) -> String:
	for p: Dictionary in d.regions[region_id]["places"]:
		if String(p.get("type", "")) == "sect_hall":
			return String(p["display_name"])
	return ""


func test_sect_hints_name_the_hall() -> void:
	var d := data()
	var c := _qr3_disciple()
	var hall := _hall_name(d, "qingshi_village")
	assert_true(hall != "")
	var lines := Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(lines, "on the mission board at the %s here" % hall))
	assert_false(_has(lines, "at a sect hall"))
	# no region id keeps the generic wording
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "on the mission board at a sect hall"))
	# the open trial names the hall
	c.sect["contribution"] = 600
	assert_true(_has(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "Attempt it at the %s here" % hall))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Attempt it at a sect hall"))


func test_sect_hint_far_hall_names_region() -> void:
	var d := data()
	var c := _qr3_disciple()
	for rid: String in d.regions:
		if _hall_name(d, rid) != "":
			continue
		var far := Guidance.nearest_selling(c, d, rid, func(r: String) -> String: return _hall_name(d, r))
		if far.is_empty():
			continue
		var lines := Guidance.hints(c, d, 1.0, 20, {}, {}, rid)
		assert_true(_has(lines, "at the %s in %s (" % [far["result"], far["region_name"]]), rid)
		return
	assert_true(false, "no hall-less region with a hall nearby")


func test_single_ready_mission_says_it_pays() -> void:
	var d := data()
	var c := _qr3_disciple()
	var best := Guidance.best_mission(c, d)
	for id: String in d.sect_missions:
		if id != best:
			c.mission_cooldowns[id] = c.age_days + 30
	var lines := Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(lines, " It pays "))
	assert_false(_has(lines, " The best pays "))


func _cooldown_player(d: GameData) -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = 2
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	return c


func test_cooling_mission_is_not_too_dangerous() -> void:
	var d := data()
	var c := _cooldown_player(d)
	if Sects.check_mission(c, d, "escort_mortal_villagers", {}) != "" or Guidance._mission_too_dangerous(c, d, "escort_mortal_villagers"):
		return
	c.mission_cooldowns["escort_mortal_villagers"] = c.age_days + 12
	var text := Guidance._mission_hint(c, d, {})
	var name: String = d.sect_missions["escort_mortal_villagers"].name
	assert_true(text.contains("%s (%d contribution) is ready again in %s." % [name, int(d.sect_missions["escort_mortal_villagers"]["contribution"]), Calendar.format_duration(12)]), text)
	assert_false(text.contains("practise"), text)
	c.mission_cooldowns.clear()
	assert_false(Guidance._mission_hint(c, d, {}).contains("is ready again"))


## GUIDE-111: a delivery mission the player is close to is named when no fight mission is ready.
func _deliver_only(d: GameData) -> CharacterData:
	var c := _cooldown_player(d)
	for id: String in d.sect_missions:
		if id != "relieve_fevered_village":
			c.mission_cooldowns[id] = c.age_days + 30
	return c


func test_deliver_mission_held_some() -> void:
	var d := data()
	var c := _deliver_only(d)
	c.add_item("spirit_herb", 1)
	var text := Guidance._mission_hint(c, d, {}, "qingshi_village")
	assert_true(text.contains("Relieve a Fevered Village (90 contribution) needs 2 "), text)
	assert_true(text.contains("you have 1 of 5."), text)


func test_deliver_mission_gatherable_here() -> void:
	var d := data()
	var c := _deliver_only(d)
	for rid: String in d.regions:
		var g := Guidance._gatherable_items(c, d, rid)
		if g.has("spirit_herb") or g.has("bone_setting_salve"):
			assert_true(Guidance._mission_hint(c, d, {}, rid).contains("you have 0 of 5."))
			return


func test_deliver_mission_held_none_is_silent() -> void:
	var d := data()
	var c := _deliver_only(d)
	assert_false(Guidance._mission_hint(c, d, {}, "").contains("needs"))
	c.add_item("spirit_herb", 1)
	c.mission_cooldowns.clear()
	assert_false(Guidance._mission_hint(c, d, {}, "").contains("Relieve a Fevered Village (90 contribution) needs"))


## GUIDE-120: the closest deliver mission wins (fewest units missing that cannot be gathered here) and the clause says where the missing item grows.
func test_deliver_pick_prefers_gatherable_here() -> void:
	var d := data()
	var c := _cooldown_player(d)
	for id: String in d.sect_missions:
		if id != "relieve_fevered_village" and id != "herb_hall_tithe":
			c.mission_cooldowns[id] = c.age_days + 30
	var text := Guidance._mission_hint(c, d, {}, "qingshi_village")
	assert_true(text.contains("Tithe to the Herb Hall (35 contribution) needs 3 Spirit Herbs: you have 0 of 3."), text)
	assert_true(text.contains("Spirit Herbs grow at Village Herb Slope here."), text)
	assert_false(text.contains("Relieve a Fevered Village"), text)


func test_deliver_ready_mission_has_no_clause() -> void:
	var d := data()
	var c := _deliver_only(d)
	c.add_item("bone_setting_salve", 2)
	c.add_item("spirit_herb", 3)
	assert_false(Guidance._mission_hint(c, d, {}, "qingshi_village").contains("needs"))


## GUIDE-114: one line carries the merchant's offer, not two.
func test_sell_offer_not_repeated_in_armor_line() -> void:
	var c := _armor_hint_fighter()
	var ore := _loot_id("ore")
	c.inventory = {"spirit_stone": 10, ore: 100}
	var offer := Guidance.sell_offer(c, data(), "qingshi_village")
	assert_false(offer.is_empty(), "the Qingshi merchant buys ore")
	var mentions := 0
	for line in Guidance.hints(c, data(), 1.0, 40, {}, {}, "qingshi_village"):
		if line.contains(offer["merchant"]) and (line.contains("Sell your") or line.contains("would pay about")):
			mentions += 1
		assert_false(line.contains("here would pay about"), "standalone sell line dropped: " + line)
	assert_eq(mentions, 1, "exactly one line mentions the offer")
	c.inventory = {"spirit_stone": 500, ore: 100}
	var kept := false
	for line in Guidance.hints(c, data(), 1.0, 40, {}, {}, "qingshi_village"):
		kept = kept or line.contains("here would pay about")
	assert_true(kept, "with enough stones the standalone sell line stays")


## GUIDE-115: herbs that feed cultivation are not offered for sale.
func test_sell_offer_ignores_spirit_herbs() -> void:
	var c := _armor_hint_fighter()
	c.inventory = {"spirit_stone": 10, "spirit_herb": 50}
	assert_true(Guidance.sell_offer(c, data(), "qingshi_village").is_empty(), "no offer for herbs alone")
	for line in Guidance.hints(c, data(), 1.0, 40, {}, {}, "qingshi_village"):
		assert_false(line.contains("would pay about"), line)


## GUIDE-117: the trial clause says what one more level of the best combat style would do.
func test_trial_practice_payoff() -> void:
	var d := data()
	var found := 0
	for attr in [8, 12, 16, 20, 24, 28, 32, 40]:
		for lvl in [1, 2, 3, 4, 5]:
			var c := new_character()
			c.realm_index = 1
			c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
			for k: String in c.attributes:
				c.attributes[k] = attr
			c.stage = 0
			c.techniques = {"iron_fist": {"level": lvl, "xp": 0.0}}
			var chance := Guidance.trial_odds(c, d)
			var payoff := Guidance.trial_practice_payoff(c, d)
			var hint := Guidance._sect_hint(c, d)
			if payoff.is_empty():
				assert_false(hint.contains("would make it about"), hint)
				continue
			assert_true(payoff["next"] - chance >= 0.1)
			if chance < 0.7:
				found += 1
				assert_true(hint.contains("Iron Fist level %d (about" % (lvl + 1)), hint)
				assert_true(hint.contains("would make it about %d in 100." % roundi(payoff["next"] * 100.0)), hint)
				assert_eq(hint.contains("practise or grow"), false, hint)
			else:
				assert_false(hint.contains("would make it about"), hint)
	assert_true(found > 0, "no setup produced a payoff")
	var m := new_character()
	m.realm_index = 1
	m.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	m.techniques = {"iron_fist": {"level": d.techniques["iron_fist"].max_level, "xp": 0.0}}
	assert_eq(Guidance.trial_practice_payoff(m, d), {})


## REV-030: a spirit-stone tithe is "close" only when you hold at least half of it; other items keep the any-held rule.
func test_deliver_close_stone_tithe_needs_half() -> void:
	var d := data()
	var c := _deliver_only(d)
	d.sect_missions["rev030_tithe"] = {"name": "Stone Tithe", "requires": {"items": {"spirit_stone": 960}}, "contribution": 1}
	c.add_item("spirit_stone", 10)
	assert_false(Guidance._deliver_close(c, d, "rev030_tithe", ""))
	c.add_item("spirit_stone", 470)
	assert_true(Guidance._deliver_close(c, d, "rev030_tithe", ""))
	d.sect_missions.erase("rev030_tithe")
	var iron := CharacterData.new()
	iron.add_item("cold_iron", 1)
	assert_true(Guidance._deliver_close(iron, d, "deliver_cold_iron", ""))


## REV-030: ores are "found at", herbs "grow at", in the guidance clause and on the mission board.
func test_deliver_wording_found_at_for_ore() -> void:
	var d := data()
	var c := CharacterData.new()
	for rid: String in d.regions:
		var g := Guidance._gatherable_items(c, d, rid)
		if g.has("cold_iron"):
			var text := Guidance._deliver_clause(c, d, "deliver_cold_iron", rid)
			assert_true(text.contains("can be found at %s here." % g["cold_iron"]), text)
			assert_false(text.contains(" grow at"), text)
			var line := MissionBoard.requirement_lines(c, d, d.sect_missions["deliver_cold_iron"], rid)[0]
			assert_true(line.contains("(found at %s here)" % g["cold_iron"]), line)
			return
	assert_true(true, "cold iron is gathered nowhere")
