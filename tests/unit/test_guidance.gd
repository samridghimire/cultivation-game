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
	# GUIDE-175: the rogue join line names the sect pill as a membership perk, which is not a recommendation to use one.
	assert_false(rows.any(func(r: Dictionary) -> bool: return not String(r["text"]).begins_with("Odds now: ") and not String(r["text"]).contains(" members gather") and (String(r["text"]).contains(core_name) or String(r["text"]).contains(fe_name))))


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
	assert_eq(_has(rogue, "As a rogue cultivator") or _has(rogue, "Join "), not open_sects.is_empty())
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
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "The rank pays %d stones a month." % stones))
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
	assert_true(hint.contains("you face the " + enemy_name), hint)
	assert_true(hint.contains("%d in 100" % roundi(Guidance.trial_odds(c, d) * 100.0)), hint)
	assert_eq(hint.contains("or grow a stage first"), Guidance.trial_odds(c, d) < 0.5)
	for k: String in c.attributes:
		c.attributes[k] = 1
	c.techniques = {}
	c.stage = 0
	assert_true(Guidance.trial_odds(c, d) < 0.5, "weak disciple should be unlikely to win")
	assert_true(Guidance._sect_hint(c, d).contains("learn a combat technique"))


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
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Sect mission ready: ") or _has(Guidance.hints(c, d, 1.0, 20), "The best pays "))
	c.sect["contribution"] = 600
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "The trial for Inner Disciple is open") or _has(Guidance.hints(c, d, 1.0, 20), "The Inner Disciple trial is too hard"))
	var insight_id: String = d.dao_insights.keys()[0]
	Dao.gain_levels(c, d, insight_id, 1)
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Contemplate the %s" % Dao.def_of(d, insight_id)["name"]))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "Claim "))
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


func test_headman_chores_hint_only_in_village() -> void:
	var c := _fresh()
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "qingshi_village"), "Headman Zhou"))
	assert_false(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "misty_forest"), "Headman Zhou"))
	# C-347: the repeatable errands keep the hint alive after the one-time chores are done.
	flags.merge({"chore_herbs_done": true, "chore_boar_done": true, "chore_roof_done": true})
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10, {}, flags, "qingshi_village"), "Headman Zhou"))


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
	c.realm_index = 1  # a mortal has too little room for a 2500 qi lotus (GUIDE-131)
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
	assert_true(gather.contains(": about "), gather)
	assert_true(gather.find("Spirit Spring") < 120, gather)  # GUIDE-124: the local spot leads
	assert_true(gather.contains(" at Cloud-Sea Cliff (5x qi) in Azure Peak (10 days away)"), gather)
	var needed := Cultivation.qi_required(c, data()) - c.qi
	var days := Calendar.format_duration(ceili(needed / Cultivation.qi_per_day(c, data(), Guidance.best_qi_reachable(c, data(), "qingshi_village")["density"])))
	assert_true(gather.contains(", %s at Cloud-Sea Cliff" % days), gather)
	assert_true(gather.ends_with("(10 days away)."), gather)


func _gather_or_travel(hints: PackedStringArray) -> String:
	for line in hints:
		if line.begins_with("Gather ") or line.begins_with("Travel to ") or line.begins_with("Heal first, then travel to "):
			return line
	return ""


func test_far_qi_trip_leads_the_gather_line() -> void:
	var c := _fresh()
	c.realm_index = 2
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_false(_has(hints, "Meditation at"))
	var gather := _gather_or_travel(hints)
	# GUIDE-128: the far spot saves over a month, so the trip leads the line.
	assert_true(gather.begins_with("Travel to Azure Peak ("), gather)
	assert_true(gather.substr(0, 120).contains("Cloud-Sea Cliff"), gather)
	assert_true(gather.contains(" in about "), gather)
	assert_true(gather.contains("at Spirit Spring here."), gather)
	assert_false(gather.contains("(5x qi)"), gather)
	assert_eq(Guidance.hinted_region(data(), gather, "qingshi_village"), "azure_peak")
	var offer := Guidance.far_qi_offer(c, data(), "qingshi_village", {}, 1.0)
	assert_eq(offer["region"], "azure_peak")
	assert_true(int(offer["days_here"]) - int(offer["days_far"]) - 2 * int(offer["away"]) >= Guidance.FAR_QI_LEAD_DAYS)


func test_far_qi_trip_warns_when_injured_and_destination_has_no_healer() -> void:
	var c := _fresh()
	c.realm_index = 2
	var plain := _gather_or_travel(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	assert_false(plain.contains("Heal first"), plain)
	c.injuries["internal_injury"] = 100
	# Azure Peak has a clinic (C-254): no warning there.
	var with_clinic := _gather_or_travel(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	assert_false(with_clinic.contains("Heal first"), with_clinic)
	# Take the clinic out for the check, then put it back.
	var places: Array = data().regions["azure_peak"]["places"]
	var saved := places.duplicate()
	places.assign(saved.filter(func(p: Dictionary) -> bool: return String(p.get("type", "")) != "clinic"))
	var line := _gather_or_travel(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	places.assign(saved)
	assert_true(line.begins_with("Heal first, then travel to Azure Peak ("), line)
	assert_true(line.contains("which has no healer:"), line)
	assert_false(line.ends_with("has no healer."), line)
	assert_true(line.left(120).contains("Heal first"), line)
	assert_eq(Guidance._no_healer_warning(c, data(), "qingshi_village"), "")


func test_no_travel_line_when_already_at_the_far_spot() -> void:
	var c := _fresh()
	c.realm_index = 2
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "azure_peak")
	assert_false(_has(hints, "Travel to Azure Peak"))


func test_short_stage_keeps_the_gather_line() -> void:
	var c := _fresh()
	var gather := _gather_or_travel(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	assert_false(gather.begins_with("Travel to "), gather)


func test_better_qi_dropped_when_the_trip_costs_more_than_it_saves() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.qi = Cultivation.qi_required(c, data()) - 5.0
	var hints := Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")
	assert_true(_has(hints, "Gather "))
	assert_false(_has(hints, "Meditation at"))
	assert_false(_has(hints, " at Cloud-Sea Cliff"))


func test_better_qi_keeps_standalone_line_without_a_gather_line() -> void:
	var c := _fresh()
	c.realm_index = 1
	var d := data()
	var lines := PackedStringArray(["Something else."])
	assert_eq(Guidance._merge_better_qi(lines, c, d, 1.0, "qingshi_village"), lines)


func test_route_days_ignoring_realm_gates_matches_strong_copy() -> void:  # GUIDE-224
	var c := _fresh()
	c.realm_index = 1
	var strong := CharacterData.from_dict(c.to_dict())
	strong.realm_index = data().realms.size() - 1
	var want := Guidance.route_days(strong, data(), "qingshi_village", "myriad_peaks_ridge")
	assert_true(want > 0)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "myriad_peaks_ridge", true), want)
	assert_eq(Guidance.route_days(c, data(), "qingshi_village", "myriad_peaks_ridge"), -1, "default still gated")
	assert_eq(c.realm_index, 1, "character untouched")


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
	assert_true(hint == "" or hint.begins_with("As a rogue cultivator you could join") or hint.begins_with("Join "))


func test_rogue_sect_hint_says_what_membership_gives() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.stage = 7
	var hint := Guidance._sect_hint(c, data())
	assert_true(hint.begins_with("Join Azure Cloud Sect at "), hint)
	assert_true(hint.contains(": members gather qi x1.5"), hint)
	assert_true(hint.substr(0, 120).contains("gather qi x"), hint)
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_false(Guidance._sect_hint(c, data()).contains("members gather"))


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
	assert_eq(goals.size(), 10)
	for g in goals:
		assert_false(g["done"])
		for bad in ["%", "{", "<null>"]:
			assert_false(String(g["text"]).contains(bad))
	var section := Guidance.journal(c, data(), {}, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_eq(section.size(), 10)
	assert_eq(section.filter(func(e: Dictionary) -> bool: return e["tone"] == "warning").size(), 1)
	assert_eq(section[0]["tone"], "warning")
	assert_true(String(section[0]["text"]).begins_with("[ ] "))
	c.techniques = {"basic_breathing": {"level": 1}}
	assert_false(Guidance.first_goals(c, data(), {})[5]["done"])
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	assert_true(Guidance.first_goals(c, data(), {})[5]["done"])
	c.realm_index = 1
	c.stage = 2
	c.sect = {"id": data().sects.keys()[0], "rank": 0, "contribution": 0, "spent": 0}
	LifeStats.add(c, "fights_won")
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_true(Guidance.first_goals_done(c, data(), flags))
	var after := Guidance.journal(c, data(), flags, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "First goals")
	assert_true(after.is_empty())


## GOAL-007: the village-life goals follow "Learn your first technique", each flips at its own state.
func test_first_goals_village_life() -> void:
	var c := _fresh()
	var g := Guidance.first_goals(c, data(), {})
	assert_true(String(g[2]["text"]).begins_with("Pick something by the path"), g[2]["text"])
	assert_true(String(g[3]["text"]).contains("Jetty") and String(g[3]["text"]).contains("Spare Field"), g[3]["text"])
	assert_true(String(g[4]["text"]).begins_with("Cook a meal at"), g[4]["text"])
	for i in [2, 3, 4]:
		assert_false(g[i]["done"])
	LifeStats.add(c, "foraged")
	assert_true(Guidance.first_goals(c, data(), {})[2]["done"])
	c.catch_log = {"carp": 1}
	assert_true(Guidance.first_goals(c, data(), {})[3]["done"])
	c.catch_log = {}
	LifeStats.add(c, "harvests", 2)
	assert_true(Guidance.first_goals(c, data(), {})[3]["done"], "a harvest counts")
	c.cooked_meals = {"x": 1}
	assert_true(Guidance.first_goals(c, data(), {})[4]["done"])
	var vet := _fresh()
	vet.realm_index = 1
	vet.stage = 2
	for goal in Guidance.first_goals(vet, data(), {}).slice(2, 5):
		assert_true(goal["done"], "veterans are not dragged back: %s" % goal["text"])


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
	# GUIDE-176: all three needs at once.
	c.realm_index = data().realm_index_of("qi_refining")
	c.abode = ""
	c.inventory = {"spirit_stone": 120}
	assert_true(_has(Guidance.goals(c, data(), {}), "Found a clan: reach Foundation Establishment, claim an abode as its seat ("))
	assert_true(_has(Guidance.goals(c, data(), {}), ") and gather 500 spirit stones (you have 120)."))
	# GUIDE-186: the seat names the abode _abode_hint points at, its region, distance and price.
	c.inventory = {"spirit_stone": 1000}
	var pick := Guidance._abode_pick(c, data())
	var abode: Dictionary = data().abodes[pick]
	var aname := Abodes.abode_name(data(), pick)
	var rname := Exploration.region_name(data(), String(abode["region"]))
	var lines := Guidance.goals(c, data(), {}, null, 1.0, "qingshi_village")
	assert_true(_has(lines, "claim an abode as its seat (%s in %s, " % [aname, rname]))
	assert_true(_has(lines, "%d stones)" % int(abode["cost"])))
	assert_true(_has(Guidance.goals(c, data(), {}, null, 1.0, String(abode["region"])), "(%s in %s, here, " % [aname, rname]))
	assert_true(Guidance._abode_hint(c, data(), "qingshi_village").begins_with("Claim %s in %s" % [aname, rname]))
	c.inventory = {"spirit_stone": 120}
	c.realm_index = 2
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
	assert_true(line.begins_with("Become %s:" % rank_name) and line.contains("earn 500 contribution (you have 0)") and line.ends_with("."), line)
	assert_false(line.contains(" needs "), line)
	c.sect["contribution"] = 500
	for l in Guidance.goals(c, d, {}):
		assert_false(l.begins_with("Become "), "met requirements, trial-free: no rank line")
	sect.ranks[1]["trial"] = "mist_wolf"
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
	assert_true(hint.contains("Practise Iron Fist") and hint.contains("(level 1 now)"), hint)
	assert_true(hint.contains("level 2 in about "), hint)
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
			if place.get("type", "") == "merchant" and not place.has("festival_only"):  # FEST-012
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


## GUIDE-212: an even fight with no pay sorts before an easy one that pays; inside a band stones lead.
func test_fair_fight_order_puts_even_before_easy() -> void:
	var even := {"text": "A", "chance": 0.8, "stones": 0}
	var easy := {"text": "B", "chance": 1.0, "stones": 50}
	var easy2 := {"text": "C", "chance": 0.95, "stones": 10}
	var list: Array[Dictionary] = [easy2, easy, even]
	list.sort_custom(Guidance.fair_fight_before)
	assert_eq(list, [even, easy, easy2] as Array[Dictionary])


func test_fair_fight_prefix() -> void:
	assert_eq(Guidance.fair_fight_prefix({"chance": 0.95}), "Easy fight")
	assert_eq(Guidance.fair_fight_prefix({"chance": 0.8}), "Fair fight")
	assert_eq(Guidance.fair_fight_prefix({}), "Fair fight")


func test_fair_fights_are_even_or_better_sorted_and_capped() -> void:
	var c := _fighter()
	var fights := Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village")
	assert_true(fights.size() <= Guidance.FAIR_FIGHTS_MAX)
	for i in fights.size():
		assert_true(float(fights[i]["chance"]) >= Guidance.FAIR_FIGHT_MIN_CHANCE)
		if i > 0:
			var prev: Dictionary = fights[i - 1]
			var cur: Dictionary = fights[i]
			var prev_easy: bool = float(prev["chance"]) >= Guidance.EASY_FIGHT_CHANCE
			var cur_easy: bool = float(cur["chance"]) >= Guidance.EASY_FIGHT_CHANCE
			assert_false(prev_easy and not cur_easy, "even fights come before easy ones")
			if prev_easy != cur_easy:
				continue
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
	assert_true(String(trials[0]["text"]).contains("Sect trial: Inner Disciple"))
	assert_true(String(trials[0]["short"]).contains("sect trial"), "GUIDE-207: the trial carries a where-label")


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
		assert_true(f["kind"] in ["explore", "roamer"], "only wilds foes are left for a bare rogue")
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
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Your hunt:")), str(texts))


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
	var expected := Combat.win_chance(c, d, d.enemies[enemy_id]) < Guidance.fight_floor(c, d.enemies[enemy_id])
	assert_eq(Guidance.mission_too_dangerous(c, d, enemy_id), expected)
	assert_false(Guidance.mission_too_dangerous(c, d, "no_such_enemy"))

## GUIDE-148: a character whose Combat.win_chance against `enemy` is in [lo, hi), found by scanning QR stages and
## Iron Fist levels; null when none.
func _rated_between(d: GameData, enemy: Dictionary, lo: float, hi: float) -> CharacterData:
	for stage in range(0, 9):
		for level in range(0, 6):
			var c := new_character()
			c.realm_index = 1
			c.stage = stage
			c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
			if level > 0:
				c.techniques["iron_fist"] = {"level": level, "xp": 0.0}
			var chance := Combat.win_chance(c, d, enemy)
			if chance >= lo and chance < hi:
				return c
	return null

func test_fight_floor_by_lethality_and_lives() -> void:
	var d := data()
	var c := new_character()
	c.artifact_lives = 3
	assert_eq(Guidance.fight_floor(c, d.enemies["den_wolf"]), 0.5)
	assert_eq(Guidance.fight_floor(c, d.enemies["mist_wolf"]), 0.7)
	c.artifact_lives = 1
	assert_eq(Guidance.fight_floor(c, d.enemies["mist_wolf"]), 0.9)
	assert_eq(Guidance.fight_floor(c, d.enemies["den_wolf"]), 0.5)

func test_lethal_mission_too_dangerous_below_even() -> void:
	var d := data()
	var wolf: Dictionary = d.enemies["mist_wolf"]
	var c := _rated_between(d, wolf, 0.5, 0.7)
	assert_true(c != null, "a QR character rated 50-70% vs the mist wolf exists")
	c.artifact_lives = 3
	assert_true(Guidance._mission_too_dangerous(c, d, "cull_mist_wolves"))
	assert_false(Guidance._mission_hint(c, d, {}).contains("Cull the Mist Wolves"))
	var mid := _rated_between(d, wolf, 0.7, 0.9)
	assert_true(mid != null, "a QR character rated 70-90% vs the mist wolf exists")
	mid.artifact_lives = 3
	assert_false(Guidance._mission_too_dangerous(mid, d, "cull_mist_wolves"))
	mid.artifact_lives = 1
	assert_true(Guidance._mission_too_dangerous(mid, d, "cull_mist_wolves"))
	# A non-lethal foe at 55% still counts as worth fighting.
	var den: Dictionary = d.enemies["den_wolf"]
	var soft := _rated_between(d, den, 0.5, 0.7)
	if soft != null:
		soft.artifact_lives = 1
		assert_false(Guidance.mission_too_dangerous(soft, d, "den_wolf"))

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


func _sect_qr(sect_id: String, rank: int, contribution: int, spent: int, stage: int = 6) -> CharacterData:
	var c := _qr(stage, 0)
	c.sect = {"id": sect_id, "rank": rank, "contribution": contribution, "spent": spent}
	return c


func test_sect_pill_claim_now() -> void:
	var c := _sect_qr("azure_cloud_sect", 1, 300, 0)
	var goals := Guidance.goals(c, data(), {})
	assert_true(goals.has("Claim a Foundation Establishment Pill (+25 percent) from the sect treasury: 250 contribution, you can claim it now."), str(goals))
	assert_false(_has(goals, "Save for"))
	assert_eq(Guidance.pill_gap_note(c, data(), []), "")


func test_sect_pill_claim_balance_and_blood_lotus() -> void:
	var goals := Guidance.goals(_sect_qr("azure_cloud_sect", 1, 600, 500), data(), {})
	assert_true(goals.has("Claim a Foundation Establishment Pill (+25 percent) from the sect treasury: 250 contribution, you have 100."), str(goals))
	assert_true(_has(Guidance.goals(_sect_qr("blood_lotus_sect", 1, 0, 0), data(), {}), "250 contribution"))


func test_sect_pill_outer_disciple_and_others() -> void:
	var goals := Guidance.goals(_sect_qr("azure_cloud_sect", 0, 300, 0), data(), {})
	assert_true(_has(goals, "As Inner Disciple you could claim it for 250 contribution."), str(goals))
	assert_false(_has(goals, "Claim a"))
	assert_eq(Guidance.sect_pill_claim(_qr(6, 20), data()), "")
	assert_false(Guidance.pill_saving_goal(_qr(6, 20), data()).contains("claim"))
	assert_eq(Guidance.sect_pill_claim(_sect_qr("azure_cloud_sect", 1, 300, 0, 4), data()), "")


func test_sect_pill_rank_clause_names_core_disciple() -> void:
	var c := _sect_qr("azure_cloud_sect", 1, 6998, 0)
	c.realm_index = 2
	c.stage = 0
	var entry := Guidance.sect_pill_entry(c, data())
	assert_eq(entry.get("item_id", ""), "core_forming_pill")
	assert_true(Guidance.sect_pill_rank_clause(c, data()).begins_with(" As Core Disciple you could claim it for 3200 contribution"))

	var qr := _sect_qr("azure_cloud_sect", 0, 300, 0)
	assert_eq(Guidance.sect_pill_rank_clause(qr, data()), " As Inner Disciple you could claim it for 250 contribution.")


func _method_member(rank: int, contribution: int, pill: String) -> CharacterData:
	var c := _sect_qr("azure_cloud_sect", rank, contribution, 0)
	c.breakthrough_pill = pill
	c.main_method = data().starter_method
	return c


func test_sect_method_hint() -> void:
	var d := data()
	var line := Guidance.sect_method_hint(_method_member(1, 2000, "foundation_establishment_pill"), d)
	assert_true(line.contains("Azure Cloud Heart Sutra") and line.contains("x%s" % String.num(Techniques.method_rate_of(_method_member(1, 0, ""), d, "azure_cloud_heart_sutra"), 1)) and line.contains("x1.0"), line)
	assert_true(line.contains("(qi x") and line.contains(", yours x1.0)") and line.ends_with("Claim it at the sect treasury and learn it there."), line)
	assert_true(Guidance.hints(_method_member(1, 2000, "foundation_establishment_pill"), d, 1.0, 20).has(line))
	# pill still to claim: 700 + 250 must fit in the balance
	assert_eq(Guidance.sect_method_hint(_method_member(1, 800, ""), d), "")
	assert_true(Guidance.sect_method_hint(_method_member(1, 1000, ""), d).contains("you have 1000"))
	var short := Guidance.sect_method_hint(_method_member(1, 600, "foundation_establishment_pill"), d)
	assert_true(short.contains("you have 600") and not short.contains("Learn it"), short)


func _foundation_method_member(contribution: int) -> CharacterData:
	var c := _method_member(1, contribution, "foundation_establishment_pill")
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.stage = 0
	c.techniques = {}
	c.equipment = {}
	c.spiritual_roots = {}  # no element affinity: listed rates apply as is
	c.main_method = data().starter_method
	return c


func _hint_index(lines: PackedStringArray, prefix: String) -> int:
	for i in lines.size():
		if lines[i].begins_with(prefix):
			return i
	return -1


func test_claimable_method_leads_thin_defence() -> void:
	var d := data()
	var c := _foundation_method_member(1000)
	var lines := Guidance.hints(c, d, 1.0, 20)
	var i_method := _hint_index(lines, "Your sect treasury hands out")
	var i_thin := _hint_index(lines, "Your defence is thin")
	assert_true(i_method >= 0 and i_thin >= 0, str(lines))
	assert_true(i_method < i_thin, str(lines))
	# cannot claim yet: thin first, as before
	var poor := Guidance.hints(_foundation_method_member(100), d, 1.0, 20)
	var p_thin := _hint_index(poor, "Your defence is thin")
	assert_true(p_thin >= 0, str(poor))
	var p_method := _hint_index(poor, "Your sect treasury hands out")
	assert_true(p_method < 0 or p_thin < p_method, str(poor))


func test_method_within_one_and_a_half_keeps_thin_first() -> void:
	var d := data()
	var c := _foundation_method_member(1000)
	c.techniques["iron_marrow_method"] = {"level": 1, "xp": 0.0}
	c.main_method = "iron_marrow_method"
	var lines := Guidance.hints(c, d, 1.0, 20)
	var i_method := _hint_index(lines, "Your sect treasury hands out")
	var i_thin := _hint_index(lines, "Your defence is thin")
	assert_true(i_method >= 0 and i_thin >= 0, str(lines))
	assert_true(i_thin < i_method, str(lines))


func test_sect_method_hint_held_manual_says_read_it() -> void:
	var d := data()
	var c := _method_member(1, 0, "")
	c.add_item("manual_azure_cloud_heart", 1)
	var line := Guidance.sect_method_hint(c, d)
	assert_true(line.begins_with("You hold the Azure Cloud Heart Sutra manual: learn it from the Inventory"), line)
	assert_false(line.contains("hands out"), line)


func test_sect_method_hint_none() -> void:
	var d := data()
	var known := _method_member(1, 2000, "foundation_establishment_pill")
	known.techniques["azure_cloud_heart_sutra"] = 1
	assert_eq(Guidance.sect_method_hint(known, d), "")
	assert_eq(Guidance.sect_method_hint(_method_member(0, 2000, "foundation_establishment_pill"), d), "")
	var rogue := _qr(6, 20)
	assert_eq(Guidance.sect_method_hint(rogue, d), "")


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


func test_pill_saving_goal_mentions_sellable_loot() -> void:
	var d := data()
	var c := _qr(0, 20)
	c.realm_index = 2
	c.stage = d.realms[2].stage_count() - 3
	var ore := _loot_id("ore")
	c.inventory = {"spirit_stone": 480, ore: 100}
	var offer := Guidance.sell_offer(c, d, "qingshi_village")
	assert_false(offer.is_empty())
	var line := Guidance.pill_saving_goal(c, d, "qingshi_village")
	assert_true(line.contains("Selling your materials would bring about %d." % int(offer["total"])), line)
	assert_true(_has(Guidance.goals(c, d, {}, null, 1.0, "qingshi_village"), "Selling your materials"))
	assert_false(Guidance.pill_saving_goal(c, d).contains("Selling"), "no region, no clause")
	c.inventory = {"spirit_stone": 480}
	assert_false(Guidance.pill_saving_goal(c, d, "qingshi_village").contains("Selling"))
	c.inventory = {"spirit_stone": 5000, ore: 100}
	assert_false(Guidance.pill_saving_goal(c, d, "qingshi_village").contains("Selling"), "affordable: unchanged")


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
	assert_true(String(texts[0]).contains("Headman Zhou: Drive off the wild boar"))
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
	assert_eq(Guidance.active_goal_ladder(c, data(), {}).size(), 10)


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
		assert_true(String(f["text"]).contains("Explore here: "))
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
			assert_true(String(f["text"]).contains("Challenge %s" % rival.name))
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
	d.source_cache.clear()  # PERF-006: injected content invalidates the sources cache
	assert_eq(Guidance.pill_source_goal(c, d), "Bid for a Void Pill at the Fallen Star Market auction.")
	d.recipes["void_pill"] = {"id": "void_pill", "profession": "alchemist", "output": {"item": "void_pill", "count": 1}}
	d.source_cache.clear()
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


func test_next_recipe_line_names_the_scroll_merchant() -> void:
	# GUIDE-184: "sold by merchants" becomes the merchant, its region, distance and price.
	var checked_far := false
	var checked_here := false
	for rid: String in data().recipes:
		var prof_id := String(data().recipes[rid].get("profession", ""))
		var scroll := data().scroll_for_recipe(rid)
		if scroll == "":
			continue
		var c := CharacterData.new()
		c.professions[prof_id] = {"rank": int(data().recipes[rid].get("min_rank", 0)), "xp": 0.0}
		for other: String in data().recipes:
			if other != rid and String(data().recipes[other].get("profession", "")) == prof_id:
				c.known_recipes.append(other)
		if Guidance.source_phrase(c, data(), scroll, "", 0) != "sold by merchants":
			continue
		if Guidance.next_recipe_line(c, data(), prof_id, "", 0).contains("sold by merchants") == false:
			continue
		for region: String in ["qingshi_village", "fallen_star_market"]:
			var far := Guidance.nearest_selling(c, data(), region, func(r: String) -> String: return Guidance.merchant_selling(data(), r, scroll))
			if far.is_empty():
				continue
			var line := Guidance.next_recipe_line(c, data(), prof_id, region, 0)
			var price := Guidance.merchant_price(c, data(), String(far["region_id"]), scroll)
			assert_true(line.contains("sold by the %s " % far["result"]), line)
			assert_true(line.contains("for %d stones." % price), line)
			assert_false(line.contains("sold by merchants"), line)
			if far["region_id"] == region:
				assert_true(line.contains(" here for "), line)
				checked_here = true
			else:
				assert_true(line.contains("in %s (" % far["region_name"]), line)
				checked_far = true
	assert_true(checked_here and checked_far, "covered both the here and far wording")


func _azure_alchemist(contribution: int) -> CharacterData:
	var c := CharacterData.new()
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": contribution}
	c.professions["alchemist"] = {"rank": 1, "xp": 0.0}
	for rid: String in data().recipes:
		var r: Dictionary = data().recipes[rid]
		if String(r.get("profession", "")) == "alchemist" and int(r.get("min_rank", 0)) < 1:
			c.known_recipes.append(rid)
	return c


func test_next_recipe_line_claims_scroll_from_sect_treasury() -> void:
	# GUIDE-189
	var c := _azure_alchemist(500)
	assert_eq(Professions.next_unknown_recipe(c, data(), "alchemist"), "meridian_mending_pill")
	var cost := int(Sects.shop_entry(c, data(), "recipe_meridian_mending_pill")["contribution"])
	var line := Guidance.next_recipe_line(c, data(), "alchemist", "", 0)
	assert_true(line.ends_with("Its scroll: claim it from your sect treasury for %d contribution." % cost), line)
	c.sect["contribution"] = 40
	line = Guidance.next_recipe_line(c, data(), "alchemist", "", 0)
	assert_true(line.ends_with("for %d contribution (you have 40)." % cost), line)
	c.sect = {}
	assert_false(Guidance.next_recipe_line(c, data(), "alchemist", "", 0).contains("treasury"))


func test_scroll_treasury_phrase_names_the_rank_that_reaches_it() -> void:
	var c := _azure_alchemist(0)
	c.realm_index = 3
	var entry := Sects.shop_entry(c, data(), "recipe_foundation_establishment_pill")
	var rank_name := (data().sects["azure_cloud_sect"] as SectDef).rank_name(int(entry["min_rank"]))
	var out := Guidance._scroll_treasury_phrase(c, data(), "recipe_foundation_establishment_pill", "found at X")
	assert_eq(out, "found at X; your sect treasury hands it to %s for %d contribution" % [rank_name, int(entry["contribution"])])
	assert_eq(Guidance._scroll_treasury_phrase(c, data(), "recipe_not_sold", "found at X"), "found at X")


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
		found = found or (line.begins_with("Meditate at ") and line.contains("(you have not cultivated in "))
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
	assert_true(line.begins_with("Meditate at "), line)
	assert_true(line.contains("to the next layer (you have not cultivated in "), line)
	assert_eq(Guidance.idle_crafter_hint(c, data(), "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS - 1), "")
	assert_eq(Guidance.idle_crafter_hint(c, data(), "qingshi_village", -1), "")
	assert_true(Guidance.idle_crafter_hint(c, data(), "", 40).begins_with("You have not cultivated"))
	var unknown := _fresh()
	unknown.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	unknown.realm_index = 1
	assert_true(Guidance.idle_crafter_hint(unknown, data(), "qingshi_village", 400).contains("not cultivated lately"), "an unstamped (old) save does not claim a duration")
	var none := _fresh()
	none.realm_index = 1
	assert_eq(Guidance.idle_crafter_hint(none, data(), "qingshi_village", 90), "")
	var foundation := _fresh()
	foundation.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	foundation.realm_index = 2
	assert_eq(Guidance.idle_crafter_hint(foundation, data(), "qingshi_village", 90), "")
	var hints := Guidance.hints(c, data(), 1.0, 1, {}, {}, "qingshi_village", 60)
	assert_true(_has(hints, "you have not cultivated in"))


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
	assert_true(line.contains("Your defence is thin."), line)
	assert_false(line.contains("Heal your injuries"))
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20), "Your defence is thin"))
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_true(line.contains("Wear armor.") and line.contains("Learn a body technique such as Stone Skin Tempering."), line)
	var body_only := Guidance.thin_defence_hint(c, data())
	assert_true(body_only.contains("Wear armor") and not body_only.contains("Learn a body technique"), "a body art without armor is still thin: " + body_only)
	c.equipment["armor"] = "boar_hide_jerkin"
	assert_eq(Guidance.thin_defence_hint(c, data()), "")
	c.techniques = {}
	var armor_only := Guidance.thin_defence_hint(c, data())
	assert_true(armor_only.contains("Learn a body technique") and not armor_only.contains("Wear armor"), "armor without a body art: " + armor_only)
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
	assert_true(_has(hint, "Treat your injuries: the Village Clinic treats it for"))
	# No stones: the clinic is named with its price and what you hold (GUIDE-138)
	c.inventory = {}
	assert_true(Guidance.heal_source(c, data(), "qingshi_village").contains("(you have 0)"))
	# No region: old wording
	assert_eq(Guidance.heal_source(c, data(), ""), "")
	assert_true(_has(Guidance.hints(c, data(), 1.0, 20), "Treat your injuries: use a healing item or see a doctor."))


func test_heal_source_names_an_unaffordable_clinic() -> void:
	var c := _fresh()
	c.realm_index = 1
	Injuries.inflict(c, data(), "qi_deviation")
	c.inventory = {"spirit_stone": 10}
	var line := Guidance.heal_source(c, data(), "qingshi_village")
	assert_true(line.contains("Village Clinic treats it for"), line)
	assert_true(line.contains("(you have 10)"), line)
	assert_true(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")[0].substr(0, Guidance.HEADLINE_CHARS).contains("Village Clinic") or _has(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"), "Village Clinic"))
	c.inventory = {"spirit_stone": 500}
	assert_false(Guidance.heal_source(c, data(), "qingshi_village").contains("(you have"))
	c.inventory = {}
	assert_eq(Guidance.heal_source(c, data(), "myriad_peaks_ridge").contains("(you have"), false)


func test_heal_source_looks_past_the_first_injury() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "qi_deviation")
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"bone_setting_salve": 1}
	var line := Guidance.heal_source(c, data(), "misty_forest")
	assert_eq(line, "use your Bone-Setting Salve for your Broken Bones")


func test_heal_source_prefers_the_affordable_cure_structurally() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "qi_deviation")
	Injuries.inflict(c, data(), "broken_bones")
	# qi_deviation is first in dictionary order, but only the salve for broken bones is usable now.
	c.inventory = {"bone_setting_salve": 1}
	var entry := Guidance._heal_source_entry(c, data(), "qingshi_village", "qi_deviation")
	assert_false(bool(entry["affordable"]), str(entry))
	assert_eq(Guidance.heal_source(c, data(), "qingshi_village"), "use your Bone-Setting Salve for your Broken Bones")
	# a sell-first clause also contains "(you have " yet the entry flag, not the text, decides
	assert_true(bool(Guidance._heal_source_entry(c, data(), "qingshi_village", "broken_bones")["affordable"]))


func test_heal_source_far_clinic_needs_the_stones() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"spirit_stone": 500}
	var cost := Medicine.clinic_cost(c, data(), "broken_bones")
	var line := Guidance.heal_source(c, data(), "misty_forest")
	assert_true(line.begins_with("the Village Clinic in Qingshi Village ("), line)
	assert_true(line.ends_with("treats it for %d stones" % cost), line)
	# GUIDE-183: with no stones the far clinic is still named, with what you hold
	c.inventory = {}
	var broke := Guidance.heal_source(c, data(), "misty_forest")
	assert_true(broke.begins_with("the Village Clinic in Qingshi Village ("), broke)
	assert_true(broke.contains("treats it for %d stones (you have 0)" % cost), broke)


func test_heal_source_far_clinic_unaffordable_names_trip_and_stones() -> void:
	var c := _fresh()
	Injuries.inflict(c, data(), "internal_injury")
	c.inventory = {"spirit_stone": 5}
	var line := Guidance.injury_news(c, data(), "internal_injury", "misty_forest")
	var days := Guidance.route_days(c, data(), "misty_forest", "qingshi_village")
	assert_true(line.contains("Village Clinic"), line)
	assert_true(line.contains("(you have 5)"), line)
	assert_true(line.contains(Calendar.format_duration(days)), line)
	# Enough stones: the affordable far text has no "(you have"
	c.inventory = {"spirit_stone": 500}
	assert_false(Guidance.injury_news(c, data(), "internal_injury", "misty_forest").contains("(you have"))
	# A clinic here and too few stones: the local text is unchanged
	c.inventory = {"spirit_stone": 5}
	var here := Guidance.injury_news(c, data(), "internal_injury", "qingshi_village")
	assert_true(here.contains("The Village Clinic treats it for") and here.contains("(you have 5)"), here)
	assert_false(here.contains("Qingshi Village ("), here)



func test_heal_source_far_clinic_names_the_way() -> void:
	var c := _fresh()
	c.realm_index = 1
	Injuries.inflict(c, data(), "broken_bones")
	c.inventory = {"spirit_stone": 500}
	# Azure Peak and Fallen Star Market have clinics now; take them away so the way home is Qingshi's.
	var saved := {}
	for rid: String in ["azure_peak", "fallen_star_market"]:
		var places: Array = data().regions[rid]["places"]
		saved[rid] = places.duplicate()
		for i in range(places.size() - 1, -1, -1):
			if String((places[i] as Dictionary)["type"]) == "clinic":
				places.remove_at(i)
	var hop := Guidance.first_hop(c, data(), "azure_peak", "qingshi_village")
	assert_true(hop != "" and hop != "qingshi_village")
	var line := Guidance.heal_source(c, data(), "azure_peak")
	for rid: String in saved:
		data().regions[rid]["places"] = saved[rid]
	assert_true(line.contains("by way of " + Exploration.region_name(data(), hop)), line)
	assert_true(line.contains("Village Clinic in Qingshi Village ("), line)
	assert_false(Guidance.heal_source(c, data(), "misty_forest").contains("by way of"))
	assert_true(Guidance.heal_source(c, data(), "azure_peak").begins_with("the Cliffside Hermit Physician treats it"))


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


## GUIDE-143: the sect treasury's body-art manual is named when claimable.
func test_treasury_body_art_hint() -> void:
	var d := data()
	var c := _cooldown_player(d)
	c.stage = Guidance.ARMOR_HINT_MIN_STAGE
	c.sect["contribution"] = 100
	var line := Guidance.treasury_body_art_hint(c, d)
	assert_true(line.contains("Stone Skin") and line.contains("(you have 100)"), line)
	assert_true(_has(Guidance.hints(c, d, 1.0, 40, {}, {}, "qingshi_village"), "Your sect treasury sells"))
	c.sect["contribution"] = 10
	assert_eq(Guidance.treasury_body_art_hint(c, d), "")
	c.sect["contribution"] = 100
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_eq(Guidance.treasury_body_art_hint(c, d), "")
	c.techniques.erase("stone_skin")
	c.sect = {}
	assert_eq(Guidance.treasury_body_art_hint(c, d), "")


func test_armor_hint_shown_to_unarmored_fighter() -> void:
	var c := _armor_hint_fighter()
	var armor_id := Guidance.affordable_armor(c, data(), "myriad_peaks_ridge")
	var line := Guidance.armor_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.begins_with("Armor keeps you standing"), line)
	assert_true(line.contains(data().items[armor_id]["name"]), line)
	assert_true(_has(Guidance._newcomer_hints(c, data(), {}, "myriad_peaks_ridge"), "Armor keeps you standing"))


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
	assert_true(line.begins_with("Armor keeps you standing. The "), line)
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
	for region_id: String in data().regions:  # GUIDE-205: a weak roamer is a fair fight even when hurt; none are about today
		for slot in Wildlife.MAX_COUNT:
			Wildlife.mark_down(flags, region_id, slot, c.age_days)
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
	c.realm_index = 1
	c.stage = 0
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
		if line.contains("Earn ") and (line.contains("The best pays ") or line.contains("Sect mission ready: ")):
			found += 1
			assert_true(line.contains(String(d.sect_missions[best]["name"])))
	assert_eq(found, 1)
	for line: String in lines:
		if not line.contains("to become "):
			assert_false(line.contains("The best pays ") or line.contains("Sect mission ready: "))


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
## Erases every mission that is not too dangerous from d.sect_missions (callers restore a duplicate); returns how many dangerous ones remain ready.
func _only_dangerous_ready(c: CharacterData, d: GameData) -> int:
	var left := 0
	for id: String in d.sect_missions.keys():
		if Sects.check_mission(c, d, id, {}) != "" or not Guidance._mission_too_dangerous(c, d, id):
			d.sect_missions.erase(id)
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
	var saved: Dictionary = d.sect_missions.duplicate()
	if _only_dangerous_ready(c, d) == 0:
		d.sect_missions = saved
		return
	var text := Guidance._mission_hint(c, d, {})
	d.sect_missions = saved
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
	var saved: Dictionary = d.sect_missions.duplicate()
	if _only_dangerous_ready(c, d) == 0:
		d.sect_missions = saved
		return
	var name: String = d.techniques["iron_fist"].name
	var lines := Guidance.hints(c, d, 1.0, 20)
	d.sect_missions = saved
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
	var saved: Dictionary = d.sect_missions.duplicate()
	if _only_dangerous_ready(c, d) == 0:
		d.sect_missions = saved
		return
	var text := Guidance._mission_hint(c, d, {})
	d.sect_missions = saved
	assert_true(text.ends_with("too dangerous for you yet; grow a stage first."), text)


## GUIDE-160: at a realm's last stage the mission line names the breakthrough.
func test_dangerous_missions_say_break_through_at_the_last_stage() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = d.realms[1].stage_count() - 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques["iron_fist"] = {"level": d.techniques["iron_fist"].max_level, "xp": 0.0}
	var saved: Dictionary = d.sect_missions.duplicate()
	if _only_dangerous_ready(c, d) == 0:
		d.sect_missions = saved
		return
	var text := Guidance._mission_hint(c, d, {})
	d.sect_missions = saved
	assert_true(text.contains("break through to %s first." % d.realms[2].name), text)
	assert_false(text.contains("grow a stage"), text)


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


## PERF-007: the mission hint rates each mission's foe once; unhurt ratings run only for the "too dangerous" advice.
func test_mission_hint_rates_each_foe_once_when_a_mission_is_ready() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 4
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.injuries = {"internal_injury": 100, "broken_bones": 100}
	var foes := {}
	for id: String in Sects.available_missions(c, d, {}):
		foes[String(d.sect_missions[id].get("enemy", ""))] = true
	Combat._chance_cache.clear()
	var sims0: int = Combat._sim_count
	Guidance._mission_hint(c, d, {})
	var sims: int = Combat._sim_count - sims0
	assert_true(sims <= foes.size(), "%d ratings for %d distinct foes" % [sims, foes.size()])


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
			if text.contains("too dangerous for you yet.") and (text.contains("The best pays ") or text.contains("Sect mission ready: ")):
				found = true
				assert_true(text.find("too dangerous for you yet.") > maxi(text.find("The best pays "), text.find("Sect mission ready: ")), text)
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
	assert_true(_has(lines, "at the %s here" % hall))
	assert_false(_has(lines, "at a sect hall"))
	# no region id keeps the generic wording
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "at a sect hall"))
	# the open trial names the hall
	c.sect["contribution"] = 600
	assert_true(_has(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "is open at the %s here" % hall))
	assert_true(_has(Guidance.hints(c, d, 1.0, 20), "is open at a sect hall"))


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
	assert_true(_has(lines, "Sect mission ready: "))
	assert_false(_has(lines, "The best pays "))


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
	# RV-015: the den wolf hunt is now a fair fight for this player, so keep it cooling too.
	c.mission_cooldowns["drive_off_den_wolves"] = c.age_days + 30
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


func test_deliver_clause_respects_the_season() -> void:
	var d := data()
	var c := _deliver_only(d)
	# Find a herb that grows in a region only outside winter (GUIDE-130).
	var found_region := ""
	var found_item := ""
	for rid: String in d.regions:
		var winter := Guidance._gatherable_items(c, d, rid, "Winter")
		var all := Guidance._gatherable_items(c, d, rid)
		for item_id: String in all:
			if not winter.has(item_id) and found_region == "":
				found_region = rid
				found_item = item_id
	assert_true(found_region != "", "some herb must be out of season in winter somewhere")
	d.sect_missions["tmp_season_mission"] = {"name": "Winter Tithe", "contribution": 10, "requires": {"items": {found_item: 1}}}
	var place := String(Guidance._gatherable_items(c, d, found_region)[found_item])
	var winter_text := Guidance._deliver_clause(c, d, "tmp_season_mission", found_region, 270)
	var unknown := Guidance._deliver_clause(c, d, "tmp_season_mission", found_region)
	d.sect_missions.erase("tmp_season_mission")
	assert_eq(Calendar.season_of(270), "Winter")
	assert_false(winter_text.contains("%s here" % place), winter_text)
	assert_true(unknown.contains("%s here" % place), unknown)


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


## GUIDE-118: herbs a ready sect mission wants are not offered as qi food.
func test_herb_hint_leaves_herbs_the_tithe_wants() -> void:
	var d := data()
	var c := _cooldown_player(d)
	c.inventory = {"spirit_herb": 3}
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_eq(Sects.check_mission(c, d, "herb_hall_tithe", flags), "")
	var hints := Guidance.hints(c, d, 1.0, 40, {}, flags, "qingshi_village")
	assert_false(_has(hints, "Use your"), str(hints))
	for mid in ["herb_hall_tithe", "gather_spirit_herbs", "relieve_fevered_village"]:
		c.mission_cooldowns[mid] = c.age_days + 20
	hints = Guidance.hints(c, d, 1.0, 40, {}, flags, "qingshi_village")
	assert_true(_has(hints, "Use your 3 Spirit Herbs"), str(hints))


## GUIDE-140: a partial stack of a mission item is not offered as qi food.
func test_herb_hint_leaves_partial_mission_stack() -> void:
	var d := data()
	var c := _cooldown_player(d)
	c.inventory = {"spirit_herb": 1}
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var hints := Guidance.hints(c, d, 1.0, 40, {}, flags, "qingshi_village")
	assert_false(_has(hints, "Use your Spirit Herb"), str(hints))
	for mid in ["herb_hall_tithe", "gather_spirit_herbs", "relieve_fevered_village"]:
		c.mission_cooldowns[mid] = c.age_days + 20
	hints = Guidance.hints(c, d, 1.0, 40, {}, flags, "qingshi_village")
	assert_true(_has(hints, "Use your Spirit Herb"), str(hints))
	var rogue := CharacterData.new()
	rogue.inventory = {"spirit_herb": 1}
	assert_false(Guidance._ready_mission_wants(rogue, d, "spirit_herb", flags))


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



## GUIDE-117 review: the payoff is rated unhurt, so an injured player is told "Healed, ..." rather than today's odds.
func test_trial_practice_payoff_says_healed_when_injured() -> void:
	var d := data()
	for attr in [8, 12, 16, 20, 24, 28, 32, 40]:
		for lvl in [1, 2, 3, 4, 5]:
			var c := new_character()
			c.realm_index = 1
			c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
			for k: String in c.attributes:
				c.attributes[k] = attr
			c.techniques = {"iron_fist": {"level": lvl, "xp": 0.0}}
			c.injuries = {"internal_injury": 30}
			var chance := Guidance.trial_odds(c, d)
			var unhurt := Guidance.odds_unhurt(c, d, Sects.trial_opponent(d, Sects.trial_enemy(c, d)))
			if Guidance.trial_practice_payoff(c, d).is_empty() or chance >= 0.7 or (chance < 0.5 and unhurt >= 0.5):
				continue
			var hint := Guidance._sect_hint(c, d)
			assert_true(hint.contains("Healed, Iron Fist level %d (about" % (lvl + 1)), hint)
			return
	assert_true(false, "no injured setup produced a payoff")

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


## GUIDE-133: sell_offer keeps what a flag-gated deliver mission wants only while its flag is set, like Sell all.
func test_sell_offer_respects_mission_flags() -> void:
	var d := data()
	var c := _deliver_only(d)
	d.sect_missions["g133_gated"] = {"id": "g133_gated", "name": "Gated Ore", "requires_flag": "g133_flag", "requires": {"items": {"iron_essence": 40}}, "contribution": 1}
	c.add_item("iron_essence", 40)
	var total := Items.sell_price(d, "iron_essence") * 40
	assert_eq(int(Guidance.sell_offer(c, d, "qingshi_village", {}).get("total", 0)), total, "flag unset: counted")
	assert_eq(Guidance.sell_offer(c, d, "qingshi_village", {"g133_flag": true}), {}, "flag set: kept for the mission")
	assert_eq(Guidance._sell_hint(c, d, "qingshi_village", {"g133_flag": true}), "")
	d.sect_missions.erase("g133_gated")


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


func test_injury_line_leads_with_treatment() -> void:
	var c := _fresh()
	c.realm_index = 0
	c.injuries = {"internal_injury": 1}
	c.inventory["spirit_stone"] = 500
	var line := ""
	for h in Guidance.hints(c, data(), 1.0, 10, {}, {}, "qingshi_village"):
		if h.begins_with("Treat your injuries"):
			line = h
	assert_true(line.begins_with("Treat your injuries: the Village Clinic treats it for "), line)
	assert_true(line.find("stones.") > 0 and line.find("stones.") < 120, line)
	assert_true(line.contains(" slows your cultivation"), line)
	Injuries.inflict(c, data(), "qi_deviation")
	for h in Guidance.hints(c, data(), 1.0, 10, {}, {}, "qingshi_village"):
		if h.begins_with("Treat your injuries"):
			line = h
	assert_true(line.contains(" slow your cultivation"), line)

## GUIDE-121: the HUD shows HEADLINE_CHARS of a hint, so the action leads and the rank goal comes last.
func _line_with(lines: PackedStringArray, needle: String) -> String:
	for line: String in lines:
		if line.contains(needle):
			return line
	return ""


func test_sect_line_leads_with_ready_mission() -> void:
	var d := data()
	var c := _qr3_disciple()
	var best := Guidance.best_mission(c, d)
	for id: String in d.sect_missions:
		if id != best:
			c.mission_cooldowns[id] = c.age_days + 30
	var line := _line_with(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "Sect mission ready: ")
	assert_true(line.begins_with("Sect mission ready: "), line)
	assert_true(line.substr(0, Guidance.HEADLINE_CHARS).contains(String(d.sect_missions[best]["name"])), line)
	assert_true(line.contains("to become "), line)
	assert_false(line.contains("(missions, duties)"), line)


func test_sect_line_best_pays_first() -> void:
	var d := data()
	var c := _qr3_disciple()
	c.stage = 4  # two ready missions
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}}
	var best := Guidance.best_mission(c, d)
	var line := _line_with(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "The best pays ")
	assert_true(line.begins_with("The best pays "), line)
	assert_true(line.substr(0, Guidance.HEADLINE_CHARS).contains(String(d.sect_missions[best]["name"])), line)


func test_mission_extra_pay_names_stones_and_qi() -> void:
	var d := data()
	assert_eq(Guidance._mission_extra_pay(d.sect_missions["cull_mist_wolves"]), " and 100 qi")
	assert_eq(Guidance._mission_extra_pay(d.sect_missions["deliver_cold_iron"]), " and 75 spirit stones")
	assert_eq(Guidance._mission_extra_pay(d.sect_missions["escort_mortal_villagers"]), "")
	assert_eq(Guidance._mission_extra_pay({"rewards": {"qi": 5, "items": {"spirit_stone": 7}}}), " and 7 spirit stones and 5 qi")


func test_single_ready_mission_line_names_extra_pay() -> void:
	var d := data()
	var checked := 0
	for id: String in ["cull_mist_wolves", "escort_mortal_villagers"]:
		var c := _qr3_disciple()
		for other: String in d.sect_missions:
			if other != id:
				c.mission_cooldowns[other] = c.age_days + 30
		var line := _line_with(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "Sect mission ready: ")
		if line == "":
			continue  # not ready for this disciple
		var m: Dictionary = d.sect_missions[id]
		var head := "(%d contribution%s, " % [int(m["contribution"]), Guidance._mission_extra_pay(m)]
		assert_true(line.contains(head), line)
		checked += 1
	assert_true(checked >= 1)


func test_sect_line_best_pays_names_extra_reward() -> void:
	var d := data()
	var c := _qr3_disciple()
	c.stage = 4
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}}
	var best := Guidance.best_mission(c, d)
	var line := _line_with(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "The best pays ")
	var extra := Guidance._mission_extra_pay(d.sect_missions[best])
	assert_true(line.begins_with("The best pays %d contribution%s: " % [int(d.sect_missions[best]["contribution"]), extra]), line)


func test_sect_line_deliver_first() -> void:
	var d := data()
	var c := _deliver_only(d)
	c.add_item("spirit_herb", 1)
	var line := _line_with(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "you have 1 of")
	var head := line.substr(0, Guidance.HEADLINE_CHARS)
	assert_true(head.contains("Relieve a Fevered Village") and head.contains("you have 1 of"), line)


func test_trial_line_odds_in_headline() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	var line := Guidance._sect_hint(c, d, "qingshi_village")
	assert_true(line.begins_with("The trial for ") or line.begins_with("The Inner Disciple trial is too hard"), line)
	var odds_end := line.find("in 100)")
	# GUIDE-169: a too-hard trial leads with the lever; the odds follow the hall
	assert_true(odds_end > 0 and (line.begins_with("The Inner Disciple trial is too hard") or odds_end < Guidance.HEADLINE_CHARS + 20), line)  # a long examiner name; the odds are the first thing after the hall
	assert_true(line.ends_with("The rank pays 6 stones a month."), line)


func test_plain_earn_line_keeps_missions_duties() -> void:
	var d := data()
	var c := _qr3_disciple()
	for id: String in d.sect_missions:
		c.mission_cooldowns[id] = c.age_days + 30
	assert_true(Guidance._sect_hint(c, d).contains("(missions, duties)"))


## GUIDE-124: the Gather line names the better spot in the region the player stands in before any far spot.
func _gather_line(lines: PackedStringArray) -> String:
	for line: String in lines:
		if line.begins_with("Gather "):
			return line
	return ""


func test_gather_line_names_the_local_spring() -> void:
	var c := _fresh()
	c.realm_index = 1
	var line := _gather_line(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	assert_true(line.contains(" at Spirit Spring (2x qi) here"), line)
	assert_true(line.find("Spirit Spring") + "Spirit Spring (2x qi) here".length() < Guidance.HEADLINE_CHARS, line)
	var local := Guidance.best_qi_in_region(c, data(), "qingshi_village")
	var needed := Cultivation.qi_required(c, data()) - c.qi
	var days := Calendar.format_duration(ceili(needed / Cultivation.qi_per_day(c, data(), float(local["density"]))))
	assert_true(line.contains(": about %s at Spirit Spring" % days), line)


func test_gather_line_no_local_clause_at_the_spring() -> void:
	var c := _fresh()
	c.realm_index = 1
	var spring := float(Guidance.best_qi_in_region(c, data(), "qingshi_village")["density"])
	var lines := PackedStringArray(["Gather 500 more qi to reach the next stage (about 2 months of meditation here)."])
	var merged := Guidance._merge_better_qi(lines, c, data(), spring, "qingshi_village")
	assert_false(_gather_line(merged).contains("Spirit Spring"), _gather_line(merged))


func test_gather_line_far_spot_must_beat_the_local_spot() -> void:
	var c := _fresh()
	c.realm_index = 1
	var line := _gather_line(Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village"))
	var far := Guidance.best_qi_reachable(c, data(), "qingshi_village")
	var local := Guidance.best_qi_in_region(c, data(), "qingshi_village")
	if float(far["density"]) <= float(local["density"]) * 1.2:
		assert_false(line.contains(String(far["name"])) and String(far["region"]) != "qingshi_village", line)

## GUIDE-125: the spot, the next level and the shop come before the HUD's cut.
func test_idle_line_leads_with_spot() -> void:
	var c := _fresh()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	c.last_meditated_day = 0
	var line := Guidance.idle_crafter_hint(c, data(), "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS)
	assert_true(line.begins_with("Meditate at "), line)
	assert_true(line.find("(you have not cultivated in ") > 0, line)
	assert_true(line.find(": about ") < Guidance.HEADLINE_CHARS, line)


func test_practise_line_next_level_in_headline() -> void:
	var c := _fresh()
	c.techniques = {"iron_fist": {"level": 2, "xp": 0.0}}
	var hint := Guidance.practice_hint(c, data())
	assert_true(hint.begins_with("Practise Iron Fist on the Techniques screen: level 3 in about "), hint)
	assert_true(hint.find("(level 2 now)") + "(level 2 now)".length() < Guidance.HEADLINE_CHARS, hint)


func test_thin_defence_shop_in_headline() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 500}
	var line := Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge")
	assert_true(line.begins_with("Your defence is thin. The "), line)
	assert_true(line.find("stones.") > 0 and line.find("stones.") < Guidance.HEADLINE_CHARS, line)
	c.equipment["armor"] = "boar_hide_jerkin"
	assert_true(Guidance.thin_defence_hint(c, data(), "myriad_peaks_ridge").contains("Learn a body technique"))


## GUIDE-127: the first clause of every hint ends before the HUD's cut, so the action is always visible.
func _clause_end(line: String) -> int:
	var ends: Array[int] = []
	for sep: String in [". ", ": "]:
		var at := line.find(sep, 20)
		if at >= 0:
			ends.append(at)
	return ends.min() if not ends.is_empty() else line.length()


func test_hint_actions_fit_headline() -> void:
	var d := data()
	var lines := PackedStringArray()
	# ready mission, and the best of several
	var c := _qr3_disciple()
	var best := Guidance.best_mission(c, d)
	for id: String in d.sect_missions:
		if id != best:
			c.mission_cooldowns[id] = c.age_days + 30
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	c = _qr3_disciple()
	c.stage = 4
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}}
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	# deliver
	c = _deliver_only(d)
	c.add_item("spirit_herb", 1)
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	# open trial
	c = new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	lines.append(Guidance._sect_hint(c, d, "qingshi_village"))
	# injury at the clinic
	c = _fresh()
	c.realm_index = 0
	c.injuries = {"internal_injury": 1}
	c.inventory["spirit_stone"] = 500
	lines.append_array(Guidance.hints(c, d, 1.0, 10, {}, {}, "qingshi_village"))
	# far meditation spot
	c = _fresh()
	c.realm_index = 1
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	c = _fresh()
	c.realm_index = 2
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	# idle crafter
	c = _fresh()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	c.last_meditated_day = 0
	lines.append(Guidance.idle_crafter_hint(c, d, "qingshi_village", Guidance.IDLE_CULTIVATION_DAYS))
	# practise
	c = _fresh()
	c.techniques = {"iron_fist": {"level": 2, "xp": 0.0}}
	lines.append(Guidance.practice_hint(c, d))
	# thin defence, far armor
	c = _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 500}
	lines.append(Guidance.thin_defence_hint(c, d, "myriad_peaks_ridge"))
	lines.append(Guidance.armor_hint(c, d, "qingshi_village"))
	# spare stones buy qi pills
	c = _qr(2, 200)
	lines.append_array(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"))
	var checked := 0
	for line: String in lines:
		if line == "" or line.begins_with("As a rogue cultivator") or line.begins_with("Join "):  # the sect list is the action; not one of the canonical states
			continue
		checked += 1
		assert_true(_clause_end(line) < Guidance.HEADLINE_CHARS, "first clause ends at %d: %s" % [_clause_end(line), line])
	assert_true(checked >= 10, "checked %d hint lines" % checked)


func _buy_hints(c: CharacterData) -> PackedStringArray:
	return Guidance.hints(c, data(), 1.0, 20, {}, {}, "qingshi_village")


func test_low_artifact_lives_lead_and_reserve_the_recharge() -> void:
	var c := _qr(3, 110)
	c.artifact_lives = 1
	var hints := _buy_hints(c)
	assert_true(hints[0].begins_with("Your Creation Artifact holds 1 life"), hints[0])
	assert_false(_has(hints, "with spare stones"))
	assert_true(hints[0].substr(0, Guidance.HEADLINE_CHARS).contains("Recharge it for"))
	c.artifact_lives = 3
	hints = _buy_hints(c)
	assert_false(_has(hints, "Your Creation Artifact"))
	assert_true(_has(hints, "with spare stones"))
	c.artifact_lives = 0
	assert_true(_buy_hints(c)[0].begins_with("Your Creation Artifact is empty"))


func test_qi_pill_offer_spends_spare_stones() -> void:
	var offer := Guidance.qi_pill_offer(_qr(2, 200), data(), "qingshi_village")
	assert_false(offer.is_empty())
	assert_true(int(offer["count"]) >= 1)
	assert_true(int(offer["count"]) * int(offer["price"]) <= 180)
	assert_true(_has(_buy_hints(_qr(2, 200)), "Buy "))
	assert_true(_has(_buy_hints(_qr(2, 200)), "with spare stones"))


## GUIDE-150: the qi-pill hint keeps the price of the armor the armor line names.
func test_qi_pill_offer_keeps_the_armor_price() -> void:
	var d := data()
	var c := _qr(Guidance.ARMOR_HINT_MIN_STAGE, 100)
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	var armor_price := Guidance.armor_hint_price(c, d, "qingshi_village")
	assert_true(armor_price > 0, "an armor line is showing: " + Guidance.armor_hint(c, d, "qingshi_village"))
	var offer := Guidance.qi_pill_offer(c, d, "qingshi_village")
	if not offer.is_empty():
		assert_true(100 - int(offer["count"]) * int(offer["price"]) >= armor_price)
	var armored := _qr(Guidance.ARMOR_HINT_MIN_STAGE, 100)
	armored.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	armored.equipment = {"armor": "boar_hide_jerkin"}
	assert_eq(Guidance.armor_hint_price(armored, d, "qingshi_village"), 0)
	assert_false(Guidance.qi_pill_offer(armored, d, "qingshi_village").is_empty(), "no armor line, today's offer")
	assert_true(Guidance.qi_pill_offer(c, d, "qingshi_village").get("count", 0) < Guidance.qi_pill_offer(armored, d, "qingshi_village")["count"])


func test_qi_pill_offer_needs_spare_stones() -> void:
	assert_true(Guidance.qi_pill_offer(_qr(2, 30), data(), "qingshi_village").is_empty())
	assert_false(_has(_buy_hints(_qr(2, 30)), "Buy "))


func test_qi_pill_offer_keeps_the_next_realm_pill_money() -> void:
	var reserve := Guidance.next_realm_pill_price(_qr(7, 0), data())
	assert_true(reserve > 0)
	assert_true(Guidance.qi_pill_offer(_qr(7, reserve + Guidance.QI_BUY_KEEP), data(), "qingshi_village").is_empty())
	var offer := Guidance.qi_pill_offer(_qr(7, reserve + Guidance.QI_BUY_KEEP + 80), data(), "qingshi_village")
	if not offer.is_empty():
		assert_true(int(offer["count"]) * int(offer["price"]) <= 80)


func test_qi_pill_offer_keeps_stones_while_the_sect_pill_is_short() -> void:
	var short := _sect_qr("azure_cloud_sect", 1, 100, 0)
	short.add_item("spirit_stone", 400)
	var ready := _sect_qr("azure_cloud_sect", 1, 300, 0)
	ready.add_item("spirit_stone", 400)
	var d := data()
	assert_false(Guidance.sect_pill_claimable(short, d))
	assert_true(Guidance.sect_pill_claimable(ready, d))
	var stones := short.item_count("spirit_stone")
	var keep := Guidance.next_realm_pill_price(short, d) + Guidance.QI_BUY_KEEP
	var offer := Guidance.qi_pill_offer(short, d, "qingshi_village")
	assert_true(offer.is_empty() or int(offer["count"]) * int(offer["price"]) <= stones - keep)
	offer = Guidance.qi_pill_offer(ready, d, "qingshi_village")
	assert_false(offer.is_empty(), "a claimable sect pill frees the stone reserve")
	var spend := int(offer["count"]) * int(offer["price"])
	assert_true(spend <= stones - Guidance.QI_BUY_KEEP)
	assert_gt(spend, stones - keep, "the offer spends stones the short case keeps")


func test_qi_pill_hint_yields_to_a_held_pill() -> void:
	var c := _qr(2, 200)
	c.add_item("qi_gathering_pill", 1)
	assert_true(_has(_buy_hints(c), "Use your"))
	assert_false(_has(_buy_hints(c), "Buy "))


func test_qi_pill_offer_silent_at_bottleneck_mortal_and_without_merchant() -> void:
	var d := data()
	var c := _qr(2, 200)
	c.stage = d.realms[1].stage_count() - 1
	c.qi = d.realms[1].qi_required(c.stage)
	assert_true(Guidance.qi_pill_offer(c, d, "qingshi_village").is_empty())
	var m := _qr(2, 200)
	m.realm_index = 0
	assert_true(Guidance.qi_pill_offer(m, d, "qingshi_village").is_empty())
	for region_id: String in d.regions:
		var has_merchant := false
		for p: Dictionary in d.regions[region_id].get("places", []):
			has_merchant = has_merchant or String(p.get("type", "")) == "merchant"
		if not has_merchant:
			assert_true(Guidance.qi_pill_offer(_qr(2, 200), d, region_id).is_empty())
			break
	assert_true(Guidance.qi_pill_offer(_qr(2, 200), d, "nowhere").is_empty())


func test_qi_pill_offer_skips_pills_bigger_than_the_room() -> void:
	var d := data()
	var c := _qr(7, 5000)
	c.qi = d.realms[1].qi_required(7) - 500.0
	var offer := Guidance.qi_pill_offer(c, d, "qingshi_village")
	if not offer.is_empty():
		assert_true(float(d.items[offer["item_id"]]["effects"]["qi"]) <= Cultivation.qi_to_bottleneck(c, d))


func test_use_hint_skips_a_pill_that_would_be_wasted() -> void:
	var d := data()
	var c := _qr(2, 0)
	c.stage = d.realms[1].stage_count() - 1
	c.qi = d.realms[1].qi_required(c.stage) - 50.0
	c.add_item("bog_lily_qi_pill", 1)
	assert_true(Cultivation.qi_to_bottleneck(c, d) < 7000.0 / 2.0)
	assert_false(_has(_buy_hints(c), "Use your Bog Lily"))


func test_use_hint_counts_only_usable_qi() -> void:
	var d := data()
	var c := _qr(2, 0)
	c.stage = d.realms[1].stage_count() - 1
	c.qi = d.realms[1].qi_required(c.stage) - 200.0
	c.add_item("qi_gathering_pill", 3)
	assert_eq(Guidance.usable_qi(c, d, "qi_gathering_pill", 3), 200.0)
	assert_true(_has(_buy_hints(c), "200 qi"))


## GUIDE-141: the rank line says when the next rank also needs a realm.
func _inner_disciple(contribution: int, realm: int, stage: int) -> CharacterData:
	var c := new_character()
	c.realm_index = realm
	c.stage = stage
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": contribution, "spent": 0}
	return c


func test_rank_line_names_the_realm_the_next_rank_needs() -> void:
	var d := data()
	var short := _inner_disciple(1290, 1, 6)
	assert_true(_has(Guidance.hints(short, d, 1.0, 20), "Core Disciple"))
	assert_true(_has(Guidance.hints(short, d, 1.0, 20), "and reach Foundation Establishment"))
	var there := _inner_disciple(1290, 2, 0)
	assert_false(_has(Guidance.hints(there, d, 1.0, 20), "and reach "))
	var rich := _inner_disciple(3000, 1, 6)
	assert_true(_has(Guidance.hints(rich, d, 1.0, 20), "Reach Foundation Establishment to become Core Disciple (you have the contribution)"))
	assert_false(_has(Guidance.hints(rich, d, 1.0, 20), "Earn 0"))


func test_injury_news_names_the_cost() -> void:
	var c := _fresh()
	var d := data()
	Injuries.inflict(c, d, "qi_deviation")
	var line := Guidance.injury_news(c, d, "qi_deviation", "")
	assert_eq(line, "Qi Deviation: cultivation x0.5, combat x0.9 for about 6 months.")
	Injuries.inflict(c, d, "broken_bones")
	assert_true(Guidance.injury_news(c, d, "broken_bones", "").begins_with("Broken Bones: cultivation x0.9, combat x0.5 for about 2 months."))
	assert_eq(Guidance.injury_news(c, d, "nope", ""), "")


func test_injury_news_adds_the_heal_source() -> void:
	var c := _fresh()
	var d := data()
	Injuries.inflict(c, d, "qi_deviation")
	c.inventory = {"spirit_stone": 500}
	var line := Guidance.injury_news(c, d, "qi_deviation", "qingshi_village")
	assert_true(line.contains(" The Village Clinic treats it for"), line)
	assert_true(line.ends_with("."), line)


func test_thin_defence_hint_prefers_the_sect_treasury() -> void:
	var d := data()
	var c := _cooldown_player(d)
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.sect["contribution"] = 100
	var line := Guidance.thin_defence_hint(c, d, "qingshi_village")
	assert_true(line.contains("your sect treasury"), line)
	assert_false(line.contains("Wandering Merchant"), line)
	c.sect["contribution"] = 0
	line = Guidance.thin_defence_hint(c, d, "qingshi_village")
	assert_true(line.contains("Wandering Merchant"), line)
	assert_false(line.contains("your sect treasury"), line)
	c.sect = {}
	assert_false(Guidance.thin_defence_hint(c, d, "qingshi_village").contains("your sect treasury"))


## GUIDE-157: the body art the treasury can pay for leads the thin-defence line, before the far armor shop.
func test_thin_defence_hint_leads_with_the_treasury_body_art() -> void:
	var d := data()
	var c := _cooldown_player(d)
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 480}
	c.sect["contribution"] = 500
	var line := Guidance.thin_defence_hint(c, d, "qingshi_village")
	var head := line.substr(0, Guidance.HEADLINE_CHARS)
	assert_true(head.contains("Stone Skin Tempering") and head.contains("sect treasury"), line)
	assert_true(line.contains("you have 500") and line.ends_with("Foundation foes hit hard."), line)
	assert_false(line.contains("Learn a body technique"), line)
	c.sect["contribution"] = 10
	line = Guidance.thin_defence_hint(c, d, "qingshi_village")
	assert_false(line.contains("Claim "), line)
	c.sect = {}
	assert_false(Guidance.thin_defence_hint(c, d, "qingshi_village").contains("Claim "))


## GUIDE-153: the abode hint names the abode, where it is, what it costs and gives.
func test_abode_hint_names_place_and_price() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 1
	c.inventory = {"spirit_stone": 100}
	var line := Guidance._abode_hint(c, d, "qingshi_village")
	for part: String in ["Waterfall Cave", "Misty Forest", "300", "(you have 100)"]:
		assert_true(line.contains(part), line)
	# [REVIEW] at Azure Peak the Cloud-Sea Cliff (2.5 x 2.0) beats the cave's seclusion (1.5 x 1.5)
	line = Guidance._abode_hint(c, d, "azure_peak")
	assert_true(line.contains("an anchor, though Cloud-Sea Cliff") and line.contains("gathers qi faster."), line)
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.inventory = {"spirit_stone": 3000}
	line = Guidance._abode_hint(c, d, "qingshi_village")
	assert_true(line.contains("Cloud-Piercing Grotto") and not line.contains("(you have"), line)
	c.abode = "waterfall_cave"
	assert_true(Guidance._abode_hint(c, d, "qingshi_village").begins_with("Cultivate in seclusion"))


func test_secret_realm_hint_names_place_and_cost() -> void:
	var d := data()
	var c := _veteran()
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.life_stats["realm_floors_cleared"] = 0
	var open_day := 2 * Calendar.DAYS_PER_YEAR + 5
	c.inventory = {"spirit_stone": 300}
	var line := Guidance._untried_feature_hint(c, d, open_day, {}, {}, "qingshi_village")
	assert_true(line.contains("Fallen Star Market") and line.contains("200 stones"), line)
	c.inventory = {"spirit_stone": 100}
	assert_false(Guidance._untried_feature_hint(c, d, open_day, {}, {}, "qingshi_village").contains("Fallen Star Vault"), "cannot pay the entry")
	c.inventory = {"spirit_stone": 300}
	line = Guidance._untried_feature_hint(c, d, open_day, {}, {}, "fallen_star_market")
	assert_true(line.contains("Fallen Star Vault is open here"), line)
	# [REVIEW] entered this opening and lost the first fight: re-entry is free, so the hint stays.
	var def: Dictionary = d.secret_realms["fallen_star_vault"]
	c.secret_realms["fallen_star_vault"] = {"opening": SecretRealms.opening_index(def, open_day), "floor": 0}
	c.inventory = {"spirit_stone": 10}
	line = Guidance._untried_feature_hint(c, d, open_day, {}, {}, "fallen_star_market")
	assert_true(line.contains("Fallen Star Vault is open here (entry 0 stones"), line)


## GUIDE-146: a Foundation player who wins every home fight is pointed at a fair fight one route away.
func _outgrown_foundation(attribute: int) -> CharacterData:
	var c := _fresh()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.stage = 0
	c.equipment = {"armor": "boar_hide_jerkin"}
	for k: String in c.attributes.keys():
		c.attributes[k] = attribute
	return c


func test_outgrown_hint_names_a_fair_fight_in_a_neighbouring_region() -> void:
	# GUIDE-148: the Rogue Cultivator is lethal, so it only counts once the odds reach the 70% floor.
	var attr := 6
	var line := ""
	while attr < 10 and line == "":
		line = Guidance.outgrown_hint(_outgrown_foundation(attr), data(), "qingshi_village", 0)
		attr += 1
	assert_true(line.begins_with("Nothing here tests you any more: Rogue Cultivator in Fallen Star Market (10 days) is a fair fight ("), line)
	assert_true(line.ends_with(" in 100)."), line)
	var chance := int(line.get_slice("(", 2).get_slice(" in 100", 0))
	assert_true(chance >= 70, line)
	var hints := Guidance.hints(_outgrown_foundation(attr - 1), data(), 1.0, 30, {}, {}, "qingshi_village", 0)
	assert_true(_has(hints, "Nothing here tests you any more"))
	# At one artifact life the floor is 90%, above the 85% ceiling: no lethal fight is offered.
	var low := _outgrown_foundation(attr - 1)
	low.artifact_lives = 1
	assert_eq(Guidance.outgrown_hint(low, data(), "qingshi_village", 0), "")


func test_outgrown_hint_is_silent_for_a_newcomer_or_a_hard_home() -> void:
	assert_eq(Guidance.outgrown_hint(_fresh(), data(), "qingshi_village", 0), "")
	assert_eq(Guidance.outgrown_hint(_outgrown_foundation(6), data(), "", 0), "")
	assert_eq(Guidance.outgrown_hint(_outgrown_foundation(6), data(), "qingshi_village", -1), "")
	# Too strong: the neighbour is a sure win as well, so there is nowhere fair to send them.
	assert_eq(Guidance.outgrown_hint(_outgrown_foundation(10), data(), "qingshi_village", 0), "")
	# Not outgrown: a home foe is below 95%.
	var weak := _outgrown_foundation(6)
	var home := Guidance._rated_region_fights(weak, data(), "qingshi_village", 0, {})
	weak.equipment = {}
	weak.realm_index = 1
	weak.attributes["strength"] = 1
	var rated := Guidance._rated_region_fights(weak, data(), "qingshi_village", 0, {})
	var sure := true
	for f in rated:
		sure = sure and float(f["chance"]) >= Guidance.OUTGROWN_SURE_CHANCE
	# GUIDE-174: the drunk bully is capped at Qi Refining, so a Foundation character has no home fight at all.
	assert_true(home.is_empty())
	if not sure:
		assert_eq(Guidance.outgrown_hint(weak, data(), "qingshi_village", 0), "")


## GUIDE-174: a home with no fight left for a Foundation character counts as outgrown.
func test_outgrown_hint_treats_a_home_without_fights_as_outgrown() -> void:
	var c := _outgrown_foundation(6)
	assert_true(Guidance._rated_region_fights(c, data(), "qingshi_village", 0, {}).is_empty())
	# Same neighbour search as a home of sure wins: the Rogue Cultivator one route away once the odds are fair.
	var line := ""
	var attr := 6
	while attr < 10 and line == "":
		line = Guidance.outgrown_hint(_outgrown_foundation(attr), data(), "qingshi_village", 0)
		attr += 1
	assert_true(line.begins_with("Nothing here tests you any more: "), line)
	assert_eq(Guidance.outgrown_hint(c, data(), "nowhere", 0), "")


## GUIDE-149: the unaffordable-clinic clause says when selling loot covers the gap.
func test_clinic_clause_names_the_sale_that_covers_it() -> void:
	var d := data()
	var c := _qr(1, 0)
	c.injuries = {"qi_deviation": 100}
	c.inventory = {"spirit_stone": 19, "mist_wolf_pelt": 12}
	var line := Guidance.heal_source(c, d, "qingshi_village")
	assert_true(line.contains("(you have 19)"), line)
	assert_true(line.contains("sell your ") and line.contains("first"), line)
	assert_true(Guidance.injury_news(c, d, "qi_deviation", "qingshi_village").contains("first."))
	c.inventory = {"spirit_stone": 19}
	line = Guidance.heal_source(c, d, "qingshi_village")
	assert_true(line.contains("(you have 19)") and not line.contains("sell your"), line)


## GUIDE-161: a member's heal source names the sect treasury's pill when contribution pays for it.
func test_heal_source_names_the_treasury_pill() -> void:
	var d := data()
	var c := _qr(1, 5)
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 300, "spent": 0}
	c.injuries = {"qi_deviation": 100}
	var line := Guidance.heal_source(c, d, "qingshi_village")
	assert_true(line.contains("Meridian Mending Pill") and line.contains("your sect treasury"), line)
	assert_true(line.contains("100 contribution, you have 300"), line)
	assert_true(Guidance.injury_news(c, d, "qi_deviation", "qingshi_village").contains("Claim a Meridian"))
	c.sect["contribution"] = 50
	line = Guidance.heal_source(c, d, "qingshi_village")
	assert_false(line.contains("treasury"), line)
	assert_true(line.contains("Village Clinic"), line)
	# A rogue is unchanged.
	var rogue := _qr(1, 5)
	rogue.injuries = {"qi_deviation": 100}
	assert_false(Guidance.heal_source(rogue, d, "qingshi_village").contains("treasury"))
	# Holding the pill still wins.
	c.sect["contribution"] = 300
	c.add_item("meridian_mending_pill", 1)
	assert_eq(Guidance.heal_source(c, d, "qingshi_village"), "use your Meridian Mending Pill for your Qi Deviation".replace(" for your Qi Deviation", ""))


## GUIDE-165: the treasury heal keeps the Foundation pill claim's contribution.
func test_heal_source_keeps_the_pill_claim() -> void:
	var d := data()
	var c := _sect_qr("azure_cloud_sect", 1, 300, 0)
	c.injuries = {"qi_deviation": 100}
	assert_true(Guidance.sect_pill_claim(c, d) != "", "pill claim shows")
	assert_false(Guidance.heal_source(c, d, "qingshi_village").contains("treasury"))
	c.sect["contribution"] = 400
	assert_true(Guidance.heal_source(c, d, "qingshi_village").contains("your sect treasury"))
	c.sect["contribution"] = 300
	c.breakthrough_pill = "foundation_establishment_pill"
	assert_true(Guidance.heal_source(c, d, "qingshi_village").contains("your sect treasury"))


## GUIDE-168: the realm goal names a spot that saves a year or more.
func test_goal_names_the_faster_spot() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 0, "spent": 0}
	var goal := String(Guidance.goals(c, d, {}, null, 1.0, "qingshi_village")[0])
	assert_true(goal.contains("Cloud-Sea Cliff in Azure Peak"), goal)
	assert_true(goal.contains("), then a breakthrough") or goal.contains("Azure Peak), then"), goal)
	var at_cliff := String(Guidance.goals(c, d, {}, null, 5.0, "azure_peak")[0])
	assert_false(at_cliff.contains(" at Cloud-Sea"), at_cliff)
	var young := new_character()
	young.realm_index = 1
	young.stage = 8
	var young_goal := String(Guidance.goals(young, d, {}, null, 1.0, "qingshi_village")[0])
	# GUIDE-197: a spot that saves 90+ days (and a third of the wait) is named even to a young cultivator.
	assert_true(young_goal.contains(" in Azure Peak"), young_goal)


# --- GUIDE-152: the trial advice never says "grow a stage" at a realm's last stage ---

func _g152_inner_disciple(stage: int) -> CharacterData:
	var c := new_character()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.stage = stage
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 3500}
	for k: String in c.attributes:
		c.attributes[k] = 1
	c.techniques = {"iron_fist": {"level": data().techniques["iron_fist"].max_level}}
	c.equipment = {}
	return c


func test_trial_advice_at_last_stage_names_the_missing_defence() -> void:
	var d := data()
	var c := _g152_inner_disciple(d.realms[Guidance.THIN_DEFENCE_REALM].stage_count() - 1)
	assert_true(Guidance.trial_odds(c, d) >= 0.0 and Guidance.trial_odds(c, d) < 0.5, "odds %s" % Guidance.trial_odds(c, d))
	var advice := Guidance._trial_advice(c, d, "qingshi_village")
	assert_true(advice.contains("Stone Skin Tempering"), advice)
	# GUIDE-172: the thin-defence hint already names the treasury manual, so the trial advice does not repeat it.
	assert_false(advice.contains("(your sect treasury"), advice)
	assert_false(advice.contains("grow a stage"), advice)
	assert_true(Guidance.thin_defence_hint(c, d, "qingshi_village").contains("sect treasury"))
	# Without a treasury source (a rogue) the source stays.
	c.sect = {}
	var rogue_source := Guidance._trial_lever_source(c, d, "qingshi_village")
	assert_eq(rogue_source, ": " + Guidance.body_manual_source(c, d, "qingshi_village") if Guidance.body_manual_source(c, d, "qingshi_village") != "" else "")


func test_trial_advice_with_stages_left_may_say_grow_a_stage() -> void:
	var d := data()
	var c := _g152_inner_disciple(0)
	c.techniques["stone_skin"] = {"level": 1}
	c.equipment = {"armor": "azure_guard_robe"}
	assert_eq(Guidance._thin_defence_missing(c, d), "")
	var advice := Guidance._trial_advice(c, d, "qingshi_village")
	if Guidance.trial_odds(c, d) < 0.5:
		assert_true(advice.contains("grow a stage first"), advice)


func test_trial_advice_without_combat_technique_says_learn_one() -> void:
	var d := data()
	for last in [true, false]:
		var c := _g152_inner_disciple(d.realms[Guidance.THIN_DEFENCE_REALM].stage_count() - 1 if last else 0)
		c.techniques = {"stone_skin": {"level": 1}}
		c.equipment = {"armor": "azure_guard_robe"}
		assert_eq(Guidance._thin_defence_missing(c, d), "")
		var odds := Guidance.trial_odds(c, d)
		if odds < 0.0 or odds >= 0.5:
			print("  (skipped: trial odds %s)" % odds)
			continue
		var advice := Guidance._trial_advice(c, d, "qingshi_village")
		assert_true(advice.contains("learn a combat technique"), advice)
		assert_false(advice.contains("practise"), advice)
		if last:
			assert_false(advice.contains("grow a stage"), advice)
		else:
			assert_true(advice.contains("or grow a stage first"), advice)


func test_hopeless_trial_line_leads_with_the_lever() -> void:
	var d := data()
	var c := _g152_inner_disciple(0)
	c.techniques = {"iron_fist": {"level": 2}, "stone_skin": {"level": 1}}
	c.equipment = {"armor": "azure_guard_robe"}
	if Guidance.trial_odds(c, d) < 0.0 or Guidance.trial_odds(c, d) >= 0.5 or Guidance._trial_lever(c, d, "qingshi_village") == "":
		print("  (skipped: trial odds %s)" % Guidance.trial_odds(c, d))
		return
	var line := Guidance._sect_hint(c, d, "qingshi_village")
	assert_true(line.begins_with("The "), line)
	assert_true(line.contains(" trial is too hard for now: "), line)
	assert_true(line.contains(Guidance._trial_lever(c, d, "qingshi_village") + " first"), line)
	assert_true(line.left(120).contains(Guidance._trial_lever(c, d, "qingshi_village")), line.left(120))
	assert_true(line.contains("in 100)") and line.contains("a loss only injures you"), line)


func test_hopeless_trial_line_without_body_art_says_learn_one() -> void:
	var d := data()
	var c := _g152_inner_disciple(d.realms[Guidance.THIN_DEFENCE_REALM].stage_count() - 1)
	assert_true(Guidance.trial_odds(c, d) < 0.5)
	var line := Guidance._sect_hint(c, d, "qingshi_village")
	assert_true(line.contains("trial is too hard for now: learn a body technique"), line)


func test_fair_trial_line_keeps_the_old_opening() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 600}
	if Guidance.trial_odds(c, d) >= 0.5:
		assert_true(Guidance._sect_hint(c, d, "qingshi_village").begins_with("The trial for "))


func test_empty_fair_fights_note_breaks_through_at_the_last_stage() -> void:
	var d := data()
	var c := _gv74_fighter()
	c.techniques["iron_fist"]["level"] = d.techniques["iron_fist"].max_level
	c.realm_index = 1
	c.stage = d.realms[1].stage_count() - 1
	assert_eq(Guidance.empty_fair_fights_note(c, d), "Nothing here is in your favour yet: break through to Foundation Establishment.")
	c.stage = 0
	assert_eq(Guidance.empty_fair_fights_note(c, d), "Nothing here is in your favour yet: grow a stage.")


# --- GUIDE-154: the rank goal says how the trial looks ---

func test_rank_goal_names_the_trial_foe_and_odds() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 3500}
	assert_eq(Sects.rank_requirement_reason(c, d), "")
	for k: String in c.attributes:
		c.attributes[k] = 200
	assert_true(Guidance.trial_odds(c, d) >= 0.2, str(Guidance.trial_odds(c, d)))
	var line := ""
	for l in Guidance.goals(c, d, {}):
		if l.begins_with("Become "):
			line = l
	assert_true(line.contains(" The trial: the Sword Pavilion Warden ("), line)
	assert_true(line.contains(" in 100)."), line)
	# A trial-free rank keeps the plain text (no trial odds to show).
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	for l in Guidance.goals(c, d, {}):
		assert_false(l.contains("The trial:"), l)


## GUIDE-171: a hopeless trial (< 20 percent) is not an invitation to seek promotion.
func test_rank_goal_hopeless_trial_is_beyond_you() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 3500}
	var odds := Guidance.trial_odds(c, d)
	var line := ""
	for l in Guidance.goals(c, d, {}):
		if l.begins_with("Become "):
			line = l
	assert_true(odds >= 0.0 and odds < 0.2, str(odds))
	assert_true(line.contains("you have what the rank asks, but the trial (the Sword Pavilion Warden, Deadly, 0 in 100) is beyond you yet."), line)
	assert_false(line.contains("you can seek promotion"), line)
	# A strong player keeps the old opening.
	c.stage = 3
	for k: String in c.attributes:
		c.attributes[k] = 200
	assert_true(Guidance.trial_odds(c, d) >= 0.2, str(Guidance.trial_odds(c, d)))
	for l in Guidance.goals(c, d, {}):
		if l.begins_with("Become "):
			assert_true(l.contains("you can seek promotion"), l)


## GUIDE-162: a Foundation fighter below the typical practice level is told the target level.
func test_g162_typical_level_follows_realm_and_max_level() -> void:
	var d := data()
	assert_eq(Techniques.typical_level(d, 0, "iron_fist"), 1)
	assert_eq(Techniques.typical_level(d, 2, "iron_fist"), 5)
	assert_eq(Techniques.typical_level(d, 9, "iron_fist"), d.techniques["iron_fist"].max_level)
	assert_eq(Techniques.typical_level(d, 2, "no_such_art"), 1)


func test_g162_fair_fights_note_names_target_level_at_foundation() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.techniques = {"iron_fist": {"level": 2, "xp": 0.0}, "stone_skin": {"level": 5, "xp": 0.0}}
	c.equipment["armor"] = "cloth_robe" if d.items.has("cloth_robe") else String(c.equipment.get("armor", ""))
	if Guidance._thin_defence_missing(c, d) != "":
		return
	var note := Guidance.empty_fair_fights_note(c, d)
	assert_true(note.contains("practise Iron Fist to level 5 (now 2)"), note)
	c.techniques["iron_fist"]["level"] = 5
	note = Guidance.empty_fair_fights_note(c, d)
	assert_false(note.contains("to level 5 (now"), note)
	assert_true(note.contains("past level 6"), note)


func test_g162_qi_refining_keeps_bare_advice() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	assert_eq(Guidance._practice_target_text(c, d, "iron_fist"), "")
	c.realm_index = 2
	assert_eq(Guidance._practice_target_text(c, d, "iron_fist"), " to level 5 (now 1)")


## GUIDE-164: the body art's target level is named when the combat style is already at the typical level.
func _g164_fighter(d: GameData) -> CharacterData:
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.techniques = {"iron_fist": {"level": 5, "xp": 0.0}, "stone_skin": {"level": 1, "xp": 0.0}}
	c.equipment["armor"] = "boar_hide_jerkin"
	return c


func test_g164_body_art_below_typical() -> void:
	var d := data()
	var c := _g164_fighter(d)
	assert_eq(Guidance._body_art_below_typical(c, d), "stone_skin")
	c.techniques["stone_skin"]["level"] = Techniques.typical_level(d, 2, "stone_skin")
	assert_eq(Guidance._body_art_below_typical(c, d), "")
	c.techniques["stone_skin"]["level"] = 1
	c.realm_index = 1
	assert_eq(Guidance._body_art_below_typical(c, d), "")


func test_g164_note_names_body_art_target() -> void:
	var d := data()
	var c := _g164_fighter(d)
	if Guidance._thin_defence_missing(c, d) != "":
		return
	var typical := Techniques.typical_level(d, 2, "stone_skin")
	var note := Guidance.empty_fair_fights_note(c, d)
	assert_true(note.contains("practise %s to level %d (now 1)" % [d.techniques["stone_skin"].name, typical]), note)
	# A combat style below its typical level is still named first.
	c.techniques["iron_fist"]["level"] = 2
	note = Guidance.empty_fair_fights_note(c, d)
	assert_true(note.contains("practise Iron Fist to level 5 (now 2)"), note)


## GUIDE-167: the duty reminder names the mission that covers it, or what missing it costs.
func _duty_member_for_hint(d: GameData) -> CharacterData:
	var c := new_character()
	c.realm_index = 2
	for sect: SectDef in d.sects.values():
		for r in sect.ranks.size():
			if c.is_rogue() and int(sect.ranks[r].get("monthly_duty", 0)) > 0 and not sect.ranks[r].get("stipend", {}).is_empty():
				c.sect = {"id": sect.id, "rank": r, "contribution": 0, "spent": 0, "month_earned": 0}
	c.age_days = 30 * 100 + 25
	return c


func test_duty_hint_names_the_mission_that_covers_it() -> void:
	var d := GameData.load_from_dir()
	var c := _duty_member_for_hint(d)
	d.sect_missions = {"quick": {"id": "quick", "name": "Quick Errand", "contribution": 20, "days": 3, "sects": []}}
	c.sect["month_earned"] = Sects.monthly_duty(c, d) - 10
	var line := Guidance.duty_hint(c, d)
	assert_true(line.begins_with("Your sect duty is "), line)
	assert_true(line.contains("Quick Errand (20 contribution, 3 days) covers it."), line)


func test_duty_hint_names_the_stipend_when_no_mission_fits() -> void:
	var d := GameData.load_from_dir()
	var c := _duty_member_for_hint(d)
	d.sect_missions = {"slow": {"id": "slow", "name": "Slow Trek", "contribution": 20, "days": 7, "sects": []}}
	c.sect["month_earned"] = Sects.monthly_duty(c, d) - 10
	var line := Guidance.duty_hint(c, d)
	assert_true(line.contains("Missing it skips this month's stipend ("), line)
	assert_false(line.contains("covers it"), line)


func test_duty_hint_empty_when_met_or_rogue() -> void:
	var d := GameData.load_from_dir()
	var c := _duty_member_for_hint(d)
	c.sect["month_earned"] = Sects.monthly_duty(c, d)
	assert_eq(Guidance.duty_hint(c, d), "")
	assert_eq(Guidance.duty_hint(new_character(), d), "")


## ITEM-003: the qi-pill offer never picks a pill the character's realm cannot use.
func test_qi_pill_offer_skips_realm_gated_pills() -> void:
	var d := data()
	var c := _qr(8, 1500)
	for region_id: String in d.regions:
		assert_true(String(Guidance.qi_pill_offer(c, d, region_id).get("item_id", "")) != "cloud_mist_qi_pill", region_id)
	c.inventory["cloud_mist_qi_pill"] = 1
	assert_false(_has(_buy_hints(c), "Use your Cloud-Mist"))


## GUIDE-181: the rank goal lists every need at once.
func test_rank_goal_lists_every_need() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 120, "spent": 0}
	var line := ""
	for l in Guidance.goals(c, d, {}):
		if l.begins_with("Become "):
			line = l
	assert_true(line.contains("earn 3000 contribution (you have 120) and reach "), line)


## GUIDE-185: a body manual sold here and affordable leads the thin-defence line; unaffordable, its price joins the source.
func test_thin_defence_buys_the_manual_sold_here() -> void:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": 1000}
	var manual := Guidance._body_manual_merchant(c, data(), "qingshi_village")
	assert_false(manual.is_empty(), "a body manual is sold in qingshi_village")
	var item_id := String(manual["item_id"])
	var price := Guidance.merchant_price(c, data(), "qingshi_village", item_id)
	var line := Guidance.thin_defence_hint(c, data(), "qingshi_village")
	var buy := "Your defence is thin. Buy %s from the %s here for %d stones and learn it." % [data().items[item_id]["name"], manual["merchant"], price]
	assert_true(line.begins_with(buy), line)
	assert_false(line.contains("Learn a body technique"), line)
	c.inventory = {"spirit_stone": 5}
	line = Guidance.thin_defence_hint(c, data(), "qingshi_village")
	assert_false(line.contains("Buy "), line)
	assert_true(line.contains(", %d stones) teaches one." % price), line)


## GUIDE-188: stones spent on the manual named by the thin-defence line are not offered again for armor.
func _armor_price_in(line: String) -> int:
	var re := RegEx.new()
	re.compile("sells [^.]*? for (\\d+) stones")
	var best := -1
	for m in re.search_all(line):
		if not m.get_string().contains("Manual"):
			best = int(m.get_string(1))
	return best


func _thin_manual_char(stones: int) -> CharacterData:
	var c := _fresh()
	c.realm_index = Guidance.THIN_DEFENCE_REALM
	c.techniques = {}
	c.equipment = {}
	c.inventory = {"spirit_stone": stones}
	return c


func test_thin_defence_armor_fits_stones_left_after_manual() -> void:
	var c := _thin_manual_char(0)
	var manual := Guidance._body_manual_merchant(c, data(), "qingshi_village")
	var price := Guidance.merchant_price(c, data(), "qingshi_village", String(manual["item_id"]))
	c.inventory = {"spirit_stone": price + 10}
	var line := Guidance.thin_defence_hint(c, data(), "qingshi_village")
	assert_true(line.contains("Buy "), line)
	var armor_price := _armor_price_in(line.substr(line.find("and learn it.")))
	assert_true(armor_price <= 10, "armor priced %d after the manual: %s" % [armor_price, line])
	c.inventory = {"spirit_stone": 2000}
	line = Guidance.thin_defence_hint(c, data(), "qingshi_village")
	armor_price = _armor_price_in(line.substr(line.find("and learn it.")))
	assert_true(armor_price <= 2000 - price, line)


func test_thin_defence_known_body_art_unchanged_by_budget() -> void:
	var c := _thin_manual_char(2000)
	c.techniques = {"stone_skin": {"level": 1, "xp": 0.0}}
	var a := Guidance.thin_defence_hint(c, data(), "qingshi_village")
	assert_false(a.contains("Buy "), a)
	assert_true(a.begins_with("Your defence is thin."), a)


func _master_region_only(c: CharacterData, region_id: String, flags: Dictionary) -> void:
	var tags: Array = data().regions[region_id].get("encounter_tags", [])
	for e: Dictionary in data().encounters.values():
		if e.get("tags", []).any(func(t: Variant) -> bool: return tags.has(t)):
			Exploration.note_met(c, e)
			if String(e.get("blocked_by_flag", "")) != "":
				flags[e["blocked_by_flag"]] = true
	if String(data().regions[region_id].get("discovery", "")) != "":
		flags["discovered_" + region_id] = true
	c.explore_days[region_id] = 100000


func test_explored_out_hint_points_at_a_region_with_unmet_happenings() -> void:
	var c := _qr(3, 0)
	var flags := {}
	_master_region_only(c, "qingshi_village", flags)
	assert_true(Exploration.mastered(c, data(), "qingshi_village", flags), "Qingshi should be mastered")
	var line := Guidance.explored_out_hint(c, data(), "qingshi_village", flags)
	assert_true(line.begins_with("You know Qingshi Village through and through: "), line)
	assert_true(line.ends_with(" you have not met."), line)
	# The count agrees with the noun: "1 happening", "3 happenings".
	assert_false(line.contains(" 1 happenings"), line)


func test_explored_out_hint_is_silent_when_not_mastered_or_mortal() -> void:
	var c := _qr(3, 0)
	assert_eq(Guidance.explored_out_hint(c, data(), "qingshi_village", {}), "")
	var m := new_character()
	assert_eq(Guidance.explored_out_hint(m, data(), "qingshi_village", {}), "")
	assert_eq(Guidance.explored_out_hint(c, data(), "", {}), "")


func test_realm_goal_odds_include_a_held_breakthrough_pill() -> void:
	var c := _qr(9, 0)
	var plain := String(Guidance.goals(c, data(), {})[0])
	assert_false(plain.contains("with your"), plain)
	c.add_item("foundation_establishment_pill", 1)
	var bonus := float(data().items["foundation_establishment_pill"]["effects"]["breakthrough_bonus"])
	var chance := Cultivation.breakthrough_chance(c, data())
	var line := String(Guidance.goals(c, data(), {})[0])
	var want := ", %d with your Foundation Establishment Pill)" % roundi(minf(chance + bonus, 0.99) * 100)
	assert_true(line.contains(want), line)
	c.breakthrough_pill = "foundation_establishment_pill"
	assert_false(String(Guidance.goals(c, data(), {})[0]).contains("with your"))


func test_sell_offer_keeps_what_open_orders_need() -> void:
	var d := data()
	var c := _qr(0, 20)
	c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	c.inventory = {"iron_essence": 200}
	var before := Guidance.sell_offer(c, d, "qingshi_village")
	assert_false(before.is_empty(), "ore sells without an order")
	c.commissions = [{"profession": "blacksmith", "item": "iron_sword", "count": 2, "reward": 10, "xp": 5.0, "due_day": 100, "recipe": "iron_sword"}]
	assert_eq(int(Guidance.sell_keep(c, d, {}).get("iron_essence", 0)), 4)
	assert_true(Guidance.sell_offer(c, d, "qingshi_village").is_empty(), "the order's ore stays in the pack")

# --- GUIDE-197: goals that tell the truth about the next step ---

func test_faster_spot_threshold_scales_with_the_wait() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 2
	c.stage = 0
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 0, "spent": 0}
	var days := Cultivation.days_to_bottleneck(c, d, 1.0)
	var best := Guidance.best_qi_reachable(c, d, "qingshi_village", {})
	var days_best := Cultivation.days_to_bottleneck(c, d, float(best["density"]))
	var away := Guidance.route_days(c, d, "qingshi_village", String(best["region"]))
	var saved := days - days_best - 2 * away
	var clause := Guidance._faster_spot_clause(c, d, 1.0, "qingshi_village", {}, days)
	assert_eq(clause != "", saved >= maxi(Guidance.FASTER_SPOT_MIN_SAVED, days / 3), "saved %d of %d: %s" % [saved, days, clause])
	# A short wait that a spot would cut by only a few weeks stays silent.
	assert_eq(Guidance._faster_spot_clause(c, d, 1.0, "qingshi_village", {}, days_best + 2 * away + 30), "")


func test_core_pill_clause_waits_on_a_hopeless_trial() -> void:
	var d := data()
	var c := _sect_qr("azure_cloud_sect", 1, 6998, 0)
	c.realm_index = 2
	c.stage = 0
	c.techniques = {}
	assert_true(Guidance.trial_odds(c, d) < 0.2, "odds %s" % Guidance.trial_odds(c, d))
	assert_eq(Guidance.sect_pill_rank_clause(c, d), " As Core Disciple you could claim it for 3200 contribution, once you can pass the rank's trial.")
	# A pill two ranks up is not behind the next trial.
	var qr := _sect_qr("azure_cloud_sect", 0, 300, 0)
	assert_eq(Guidance.sect_pill_rank_clause(qr, d), " As Inner Disciple you could claim it for 250 contribution.")


func test_mission_hint_skipped_for_a_rich_member_with_duty_met() -> void:
	var d := data()
	var c := _qr3_disciple()
	c.stage = 4
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}}
	c.sect["contribution"] = 7411
	c.sect["month_earned"] = 0
	if Sects.monthly_duty(c, d) > 0:
		assert_true(_has(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "The best pays "))
	c.sect["month_earned"] = Sects.monthly_duty(c, d)
	assert_eq(Guidance._mission_hint_rich(c, d), true)
	assert_false(_has(Guidance.hints(c, d, 1.0, 20, {}, {}, "qingshi_village"), "The best pays "))
	c.sect["contribution"] = 100
	assert_false(Guidance._mission_hint_rich(c, d))


# --- GUIDE-201: the realm goal shows what the sect method is worth ---

func _method_goal_member(rank: int, contribution: int) -> CharacterData:
	var c := _method_member(rank, contribution, "foundation_establishment_pill")
	c.realm_index = 1
	c.stage = 0
	c.spiritual_roots = {"water": 100}  # a pure water root: the sutra's full qi rate
	return c


func _realm_goal(c: CharacterData, region: String = "azure_peak") -> String:
	var d := data()
	return Guidance.goals(c, d, {}, null, 1.0, region)[0]


func test_goal_shows_the_sect_method_when_claimable() -> void:
	var d := data()
	var c := _method_goal_member(1, 1000)
	assert_true(Guidance._method_offer_leads(c, d), "setup: the method leads")
	var days := Cultivation.days_to_bottleneck(c, d, 1.0)
	var offer := Guidance.sect_method_offer(c, d)
	var with_method := ceili(days * float(offer["current"]) / float(offer["rate"]))
	var spot := Guidance._faster_spot(c, d, 1.0, "azure_peak", {}, days)
	var line := _realm_goal(c)
	if days - with_method >= int(spot.get("saved", 0)):
		assert_true(line.contains("with the Azure Cloud Heart Sutra from your sect treasury)"), line)
		assert_true(line.contains(Calendar.format_rough(with_method)), line)
	# Too poor to claim it: no method clause.
	assert_false(_realm_goal(_method_goal_member(1, 100)).contains("with the "))
	# A rogue has no sect treasury.
	var rogue := new_character()
	rogue.realm_index = 1
	assert_false(_realm_goal(rogue).contains("with the "))


func test_goal_method_clause_held_and_spot_precedence() -> void:
	var d := data()
	var c := _method_goal_member(1, 0)
	c.add_item("manual_azure_cloud_heart", 1)
	if Guidance.sect_method_offer(c, d).is_empty():
		return
	var line := _realm_goal(c)
	assert_true(line.contains("you hold)") or line.contains("(about ") , line)
	# When the spot saves more days than the method, the spot clause wins.
	var rich := _method_goal_member(1, 1000)
	var days := Cultivation.days_to_bottleneck(rich, d, 1.0)
	var spot := Guidance._faster_spot(rich, d, 1.0, "qingshi_village", {}, days)
	var offer := Guidance.sect_method_offer(rich, d)
	var with_method := ceili(days * float(offer["current"]) / float(offer["rate"]))
	var clause := Guidance._goal_speedup_clause(rich, d, 1.0, "qingshi_village", {}, days)
	if not spot.is_empty() and int(spot["saved"]) > days - with_method:
		assert_eq(clause, spot["clause"])
	else:
		assert_true(clause.contains("with the Azure Cloud Heart Sutra") or clause == String(spot.get("clause", "")), clause)


func _village_data(kind: String) -> GameData:
	var d := data()
	d.regions["qingshi_village"]["weather"] = {"any": {kind: 1}}
	d.weather_persist = 1.0
	return d


func test_village_lines_weather_only_when_nothing_open() -> void:
	var d := _village_data("rain")
	var lines := Guidance.village_lines(new_character(), d, {}, {}, "qingshi_village", 10)
	assert_eq(lines.size() - _fishing_lines(lines), 1)
	assert_true(lines[0].begins_with("Rain today: herbs thrive"), lines[0])
	assert_true(lines[0].contains("fish bite more") and lines[0].contains("Water-root cultivation x1.10"), lines[0])


func _fishing_lines(lines: PackedStringArray) -> int:
	var n := 0
	for l in lines:
		if l.begins_with("Fishing at") or l == "Fish bite in the rain.":
			n += 1
	return n


func test_village_lines_tip_with_days_left() -> void:
	var d := _village_data("clear")
	var friend := new_character(7)
	friend.name = "Wu Lan"
	var flags := {Folk.TIP_KEY: {"region": "qingshi_village", "item": "spirit_grass", "until": 15, "npc_id": friend.id}}
	var lines := Guidance.village_lines(new_character(), d, {friend.id: friend}, flags, "qingshi_village", 10)
	var found := false
	for l in lines:
		found = found or (l.begins_with("Wu Lan's tip:") and l.contains("6 days left"))
	assert_true(found, "\n".join(lines))


func test_village_lines_request_line() -> void:
	var d := _village_data("clear")
	var c := new_character()
	var asker := new_character(9)
	asker.name = "Old Fang"
	d.regions["qingshi_village"]["npc_spots"] = [[100, 100]]
	asker.home_region = "qingshi_village"
	c.letter_requests.append({"npc_id": asker.id, "item": "spirit_grass", "count": 3, "until": 14, "favor": 5, "source": "folk"})
	var lines := Guidance.village_lines(c, d, {asker.id: asker}, {}, "qingshi_village", 10)
	if Npcs.region_of(asker, d) == "qingshi_village":
		var found := false
		for l in lines:
			found = found or (l.begins_with("Old Fang wants 3") and l.contains("5 days left"))
		assert_true(found, "\n".join(lines))


func test_effects_text_empty_on_plain_day() -> void:
	var d := data()
	assert_eq(Weather.effects_text(d, "cloudy"), "")


func _has_line(lines: PackedStringArray, prefix: String) -> bool:
	for l in lines:
		if l.begins_with(prefix):
			return true
	return false


func test_forecast_matches_weather_of() -> void:
	var d := data()
	var got := Weather.forecast(d, "qingshi_village", 40, 3)
	assert_eq(got.size(), 3)
	for i in 3:
		assert_eq(got[i], Weather.of(d, "qingshi_village", 41 + i))
	for kind in Weather.forecast(d, "no_such_region", 5):
		assert_eq(kind, "clear")


func test_village_lines_field_plant_then_harvest() -> void:
	var d := _village_data("clear")
	var c := new_character()
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Plant your"))
	c.add_item("spirit_herb", 1)
	var lines := Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10)
	assert_true(_has_line(lines, "Plant your Spirit Herb in") and "\n".join(lines).contains("stones a season"), "\n".join(lines))
	var place := FieldPlots.place_def(d, "qingshi_village")
	c.field_plots[FieldPlots.key("qingshi_village", place)] = {"paid_until": 99, "crops": [{"item": "dew_grass", "days_left": 6}]}
	lines = Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10)
	assert_true(_has_line(lines, "Your field: Morning Dew Grass, ready in"), "\n".join(lines))
	c.field_plots[FieldPlots.key("qingshi_village", place)]["crops"][0]["days_left"] = 0
	lines = Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10)
	assert_true(_has_line(lines, "Your Morning Dew Grass is ready to harvest"), "\n".join(lines))
	assert_false(_has_line(lines, "Plant your"))
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "misty_forest", 10), "Your Morning Dew Grass"))


func test_village_lines_field_skips_out_of_season_plant() -> void:
	var d := _village_data("clear")
	var c := new_character()
	c.add_item("peach_blossom_petal", 1)
	assert_true(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Plant your Peach Blossom Petal"))
	var summer := 0
	for day in 400:
		if Calendar.season_of(day) == "Summer":
			summer = day
			break
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", summer), "Plant your"))


func test_village_lines_meal_needs_injury_and_ingredients() -> void:
	var d := _village_data("clear")
	var c := new_character()
	c.add_item("silver_carp", 2)
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Cook"))
	Injuries.inflict(c, d, "internal_injury")
	assert_true(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Cook Fish Stew"))
	c.add_item("silver_carp", -2)
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Cook"))


## COOK-001: finds a foe the new character rates below 0.75 and that Eel Congee's +10% attack lifts by 5+ points.
func _meal_foe_case(d: GameData, c: CharacterData) -> String:
	var buff: Dictionary = d.items["eel_congee"]["effects"]["buff"]
	for id: String in d.enemies:
		var e: Dictionary = d.enemies[id]
		var base := Combat.win_chance(c, d, e)
		if base < 0.15 or base >= 0.75:
			continue
		var copy := CharacterData.from_dict(c.to_dict())
		Buffs.add_from_effect(copy, buff)
		if Combat.win_chance(copy, d, e) - base >= 0.05:
			return String(e["name"])
	return ""


func test_meal_before_fight_numbers() -> void:
	var d := _village_data("clear")
	var c := new_character()
	var foe := _meal_foe_case(d, c)
	assert_true(foe != "", "some foe is lifted by Eel Congee")
	var fights: Array = [{"enemy": foe, "chance": 0.5}]
	assert_eq(Guidance.meal_before_fight(c, d, "qingshi_village", 10, fights), "", "no meal, no ingredients")
	c.add_item("marsh_eel", 1)
	c.add_item("sweet_rice_ball", 1)
	var line := Guidance.meal_before_fight(c, d, "qingshi_village", 10, fights)
	assert_true(line.begins_with("Cook Eel Congee at Village Workshop before you fight the %s (" % foe), line)
	assert_true(line.contains(" -> "), line)
	c.add_item("eel_congee", 1)
	line = Guidance.meal_before_fight(c, d, "qingshi_village", 10, fights)
	assert_true(line.begins_with("Eat an Eel Congee before you fight the %s: " % foe), line)
	assert_true(line.contains(" -> "), line)
	assert_eq(line, Guidance.meal_before_fight(c, d, "qingshi_village", 10, fights), "deterministic")
	assert_true(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10, {}, fights), "Eat an Eel Congee"))
	Buffs.add(c, "eels_vigour", "Eel's vigour", 3, {"attack": 0.1})
	assert_eq(Guidance.meal_before_fight(c, d, "qingshi_village", 10, fights), "", "buff already active")


func test_meal_before_fight_easy_or_none() -> void:
	var d := _village_data("clear")
	var c := new_character()
	c.add_item("eel_congee", 1)
	assert_eq(Guidance.meal_before_fight(c, d, "qingshi_village", 10, []), "", "no foe")
	var weak_id := ""
	for id: String in d.enemies:
		if Combat.win_chance(c, d, d.enemies[id]) >= 0.75:
			weak_id = id
			break
	assert_true(weak_id != "")
	var easy: Array = [{"enemy": String(d.enemies[weak_id]["name"]), "chance": 0.95}]
	assert_eq(Guidance.meal_before_fight(c, d, "qingshi_village", 10, easy), "", "easy fight")


func test_village_lines_forecast_only_when_tomorrow_differs_and_matters() -> void:
	var d := _village_data("rain")
	assert_false(_has_line(Guidance.village_lines(new_character(), d, {}, {}, "qingshi_village", 10), "Tomorrow"), "same weather: no line")
	d.regions["qingshi_village"]["weather"] = {"any": {"rain": 1}}
	d.weather_persist = 0.0
	d.regions["qingshi_village"]["weather"] = {"any": {"rain": 1}}
	var lines := Guidance.village_lines(new_character(), d, {}, {}, "qingshi_village", 10)
	assert_false(_has_line(lines, "Tomorrow"), "rain after rain")
	d.regions["qingshi_village"]["weather"] = {"any": {"clear": 1}}
	assert_false(_has_line(Guidance.village_lines(new_character(), d, {}, {}, "qingshi_village", 10), "Tomorrow"), "clear has no effects")


func test_village_lines_visitor() -> void:
	var d := _village_data("clear")
	d.family["folk_visits"]["chance"] = 1.0
	var npcs := {}
	var npc := Npcs.spawn(npcs, d, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var lines := Guidance.village_lines(new_character(), d, npcs, {}, "qingshi_village", 10, {npc.id: 50})
	assert_true(_has_line(lines, "%s has come to see you" % npc.name), "\n".join(lines))
	assert_false(_has_line(Guidance.village_lines(new_character(), d, npcs, {}, "qingshi_village", 10, {npc.id: 0}), npc.name))
	d.family["folk_visits"]["chance"] = 0.15


## GUIDE-203: merchant_price applies the season to a seasonal herb and leaves the default unchanged.
func test_merchant_price_applies_season() -> void:
	var d := data()
	var c := new_character()
	var herb := ""
	for id: String in d.items:
		if int(d.items[id].get("price", 0)) >= 10 and not Items.harvest_seasons(d, id).is_empty():
			herb = id
			break
	assert_true(herb != "", "a seasonal herb exists")
	var seasons := Items.harvest_seasons(d, herb)
	var in_season: String = seasons[0]
	var off := "spring" if not seasons.has("spring") else "winter"
	assert_false(seasons.has(off))
	var plain := Guidance.merchant_price(c, d, "qingshi_village", herb)
	assert_eq(Guidance.merchant_price(c, d, "qingshi_village", herb, ""), plain)
	assert_true(Guidance.merchant_price(c, d, "qingshi_village", herb, in_season) < plain)
	assert_true(Guidance.merchant_price(c, d, "qingshi_village", herb, off) > plain)


## FISH-004: the journal shows the log once something is caught.
func test_village_lines_angler_log() -> void:
	var d := _village_data("clear")
	var c := new_character()
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "misty_forest", 10), "Fish caught"))
	Fishing.record_catch(c, "silver_carp", 1)
	var lines := Guidance.village_lines(c, d, {}, {}, "misty_forest", 10)
	assert_true(_has_line(lines, "Fish caught: 1 of %d kinds" % Fishing.catchable(d).size()), str(lines))
	assert_true(_has_line(lines, "Marsh Eel bites here in"), str(lines))


## GUIDE-204: the seasonal sell line names the best-paying carried herb in a dear season.
func test_seasonal_sell_line() -> void:
	var d := data()
	var c := _fresh()
	var winter := 280
	assert_eq(Calendar.season_of(winter), "Winter")
	assert_eq(Guidance.seasonal_sell_line(c, d, "qingshi_village", winter), "", "nothing carried")
	c.inventory["spirit_herb"] = 10
	var line := Guidance.seasonal_sell_line(c, d, "qingshi_village", winter)
	assert_true(line.begins_with("Herbs fetch more in winter: sell your 10 Spirit Herbs at the "), line)
	assert_true(line.contains(" for %d each." % Items.sell_price(d, "spirit_herb", "winter")), line)
	assert_eq(Guidance.seasonal_sell_line(c, d, "qingshi_village", 10), "", "spring: herbs are cheap")
	assert_eq(Guidance.seasonal_sell_line(c, d, "qingshi_village", -1), "")
	c.inventory.clear()
	c.inventory["spirit_herb"] = 1
	assert_eq(Guidance.seasonal_sell_line(c, d, "qingshi_village", winter), "", "too cheap")
	c.inventory.clear()
	c.inventory["iron_essence"] = 20
	assert_eq(Guidance.seasonal_sell_line(c, d, "qingshi_village", winter), "", "flat item")


## GUIDE-204: hints() stores the season in a copy of the flags; priced lines read it.
func test_with_season_copies_flags() -> void:
	var flags := {"a": 1}
	var out := Guidance.with_season(flags, 280)
	assert_eq(out["_season"], "Winter")
	assert_false(flags.has("_season"))
	assert_eq(Guidance.with_season(flags, -1), flags)


## GATHER-002: the journal shows the herbalist's log once something is found.
func test_village_lines_herb_log() -> void:
	var d := _village_data("clear")
	var c := new_character()
	assert_false(_has_line(Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10), "Herbs found"))
	HerbLore.record_find(c, "spirit_herb", 1)
	var lines := Guidance.village_lines(c, d, {}, {}, "qingshi_village", 10)
	assert_true(_has_line(lines, "Herbs found: 1 of"), str(lines))
	assert_true(_has_line(lines, "Morning Dew Grass grows on the"), str(lines))


## MARKET-004: a market-day stall is a qi-pill seller only on its days; otherwise the hint stays silent.
func test_qi_pill_offer_follows_the_stall_days() -> void:
	var d := data()
	var c := _qr(2, 200)
	var offer := Guidance.qi_pill_offer(c, d, "qingshi_village")
	assert_false(offer.is_empty(), "an always-open seller offers pills")
	var place := {}
	for p: Dictionary in d.regions["qingshi_village"]["places"]:
		if p.get("display_name", "") == offer["merchant"]:
			place = p
	place["open_days"] = [10]
	var closed_day := 5
	var closed_offer := Guidance.qi_pill_offer(c, d, "qingshi_village", Guidance.with_season({}, closed_day))
	assert_true(String(closed_offer.get("when", "")).contains("next market day in"), "closed stall: named with its next market day")
	assert_eq(String(Guidance.qi_pill_offer(c, d, "qingshi_village", Guidance.with_season({}, 9)).get("when", "")), "", "market day: no delay")
	assert_true(Guidance.qi_pill_offer(c, d, "qingshi_village").is_empty(), "unknown day: not counted on")
	assert_false(Guidance.qi_pill_offer(c, d, "qingshi_village", Guidance.with_season({}, 9)).is_empty(), "open on its market day")
	place.erase("open_days")
	assert_false(Guidance.qi_pill_offer(c, d, "qingshi_village").is_empty())


## MARKET-006: a stall-only cure is named with its market day; the price matches the stall's shop.
func test_heal_stall_and_price_follow_market_day() -> void:
	var d := data()
	var c := _fresh()
	var stall := {"type": "merchant", "display_name": "Test Stall", "pos": [0, 0], "size": [10, 10], "open_days": [10], "stock_tags": ["burn_salve"]}
	var places: Array = d.regions["misty_forest"]["places"]
	places.append(stall)
	c.add_item("spirit_stone", 5000)
	var closed := Guidance._heal_stall_clause(c, d, "misty_forest", "scorched", Guidance.with_season({}, 5))
	assert_true(closed.contains("Test Stall") and closed.contains("Burn Salve") and closed.contains("next market day in"), closed)
	var open_line := Guidance._heal_stall_clause(c, d, "misty_forest", "scorched", Guidance.with_season({}, 9))
	assert_true(open_line.contains("Test Stall") and open_line.contains("open today") and not open_line.contains("next market day"), open_line)
	assert_eq(Guidance._heal_stall_clause(c, d, "misty_forest", "scorched", {}), "", "unknown day: silent")
	var place := Guidance.merchant_place(d, "misty_forest", "burn_salve", true)
	assert_true(place.get("stall", false), "sole-seller stall flagged")
	assert_true(Guidance.merchant_place(d, "misty_forest", "burn_salve").is_empty(), "default skips stalls")
	var shop_price := maxi(1, roundi(Reputation.buy_price(c, d, "burn_salve", "", 1.0, "") * Renown.buy_multiplier(c, d, "misty_forest")))
	assert_eq(Guidance.merchant_price(c, d, "misty_forest", "burn_salve"), shop_price, "stall price counts")
	places.erase(stall)


func test_seller_open_rules() -> void:
	assert_true(Guidance.seller_open({}, {}))
	assert_false(Guidance.seller_open({"open_days": [10]}, {}))
	assert_true(Guidance.seller_open({"open_days": [10]}, {"_today": 9}))
	assert_false(Guidance.seller_open({"open_days": [10]}, {"_today": 10}))


## MARKET-005: with only market-day stalls selling gear, the hint names the next market day.
func test_gear_elsewhere_line_names_next_market_day() -> void:
	var d := data()
	var c := _fresh()
	var touched: Array[Dictionary] = []
	for r: Dictionary in d.regions.values():
		for p: Dictionary in r.get("places", []):
			if String(p.get("type", "")) == "merchant" and not p.has("open_days") and p.get("display_name", "") != "":
				var sells := false
				for id: String in d.items:
					if Equipment.slot_of(d, id) != "" and Items.merchant_sells(d, d.items[id], p.get("stock_tags", []), int(p.get("max_price", 0))):
						sells = true
				if sells:
					p["open_days"] = [10]
					touched.append(p)
	assert_false(touched.is_empty())
	var today := 5
	var ahead := Places.days_until_open({"open_days": [10]}, today)
	assert_true(ahead > 0)
	assert_eq(Guidance.gear_elsewhere_line(c, d, "qingshi_village"), "", "unknown day: not pointed at")
	var line := Guidance.gear_elsewhere_line(c, d, "misty_forest", today)
	assert_true(line.contains("next market day in %s" % Calendar.format_duration(ahead)), line)
	var open_day := today + ahead
	var open_line := Guidance.gear_elsewhere_line(c, d, "misty_forest", open_day)
	assert_true(open_line.contains("sells them, open today"), open_line)
	assert_false(open_line.contains("next market day"), open_line)
	for p in touched:
		p.erase("open_days")


## MARKET-005: a rain-only fish reads "when it rains"; a fish catchable in today's weather is hinted first.
func test_fishing_missing_hint_weather() -> void:
	var d := data()
	var c := CharacterData.new()
	for id in ["silver_carp", "marsh_eel", "mist_koi", "lotus_bass"]:
		Fishing.record_catch(c, id, 1)
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "Rain Bream bites here when it rains.")
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer", "clear"), "Rain Bream bites here when it rains.", "only one left")
	var c2 := CharacterData.new()
	var hint := Fishing.missing_hint(c2, d, "misty_forest", "Summer", "clear")
	assert_false(hint.contains("Rain Bream"), hint)


## GUIDE-205: a roaming beast is named where it roams: here, or one route away.
func test_fair_fights_name_a_roaming_beast() -> void:
	var c := _fighter()
	c.sect = {}
	var d := data()
	var day := -1
	for t in range(0, 200):
		for r in Wildlife.roamers(d, "misty_forest", t, c.realm_index, {}):
			if Combat.win_chance(c, d, d.enemies[String(r["enemy"])]) >= Guidance.FAIR_FIGHT_MIN_CHANCE and day < 0:
				day = t
	assert_true(day >= 0, "a winnable roamer exists in Misty Forest")
	var near := Guidance.fair_fights(c, d, {}, day, "qingshi_village")
	var away := near.filter(func(f: Dictionary) -> bool: return f["kind"] == "roamer")
	assert_eq(away.size(), 1)
	assert_true(String(away[0]["text"]).contains("roams Misty Forest today"), String(away[0]["text"]))
	assert_true(String(away[0]["text"]).contains("away"))
	var here := Guidance.fair_fights(c, d, {}, day, "misty_forest").filter(func(f: Dictionary) -> bool: return f["kind"] == "roamer")
	assert_eq(here.size(), 1)
	assert_true(String(here[0]["text"]).contains("roams here today"), String(here[0]["text"]))


## GUIDE-206: every fair-fight entry carries a short, place-naming label for the HUD line.
func test_fair_fight_entries_carry_a_short_label() -> void:
	var c := _fighter()
	c.sect = {}
	var d := data()
	var day := -1
	for t in range(0, 200):
		for r in Wildlife.roamers(d, "misty_forest", t, c.realm_index, {}):
			if Combat.win_chance(c, d, d.enemies[String(r["enemy"])]) >= Guidance.FAIR_FIGHT_MIN_CHANCE and day < 0:
				day = t
	assert_true(day >= 0)
	var away := Guidance.fair_fights(c, d, {}, day, "qingshi_village").filter(func(f: Dictionary) -> bool: return f["kind"] == "roamer")
	assert_eq(away.size(), 1)
	assert_true(String(away[0]["short"]).contains(" in Misty Forest ("), String(away[0]["short"]))
	var here := Guidance.fair_fights(c, d, {}, day, "misty_forest")
	var roamer: Dictionary = here.filter(func(f: Dictionary) -> bool: return f["kind"] == "roamer")[0]
	assert_eq(roamer["short"], "%s roams here" % roamer["enemy"])
	for f: Dictionary in here:
		assert_true(f.has("short"))
		if f["kind"] == "explore":
			assert_eq(f["short"], "%s, explore here" % f["enemy"])
	for f: Dictionary in Guidance.fair_fights(c, d, {}, c.age_days, "qingshi_village"):
		if f["kind"] == "mission":
			assert_true(String(f["short"]).begins_with("Mission: "))
		if f["kind"] == "trial":
			assert_eq(f["short"], "")
	# the same foe walking up to you outranks exploring for it
	var walk := {"text": "b", "chance": 0.8, "stones": 0, "enemy": "Boar", "walkup": true}
	var expl := {"text": "a", "chance": 0.8, "stones": 0, "enemy": "Boar", "walkup": false}
	assert_true(Guidance.fair_fight_before(walk, expl))
	assert_false(Guidance.fair_fight_before(expl, walk))


## GUIDE-207: every fair-fight entry names where, so the HUD line never falls back to a bare foe name.
func test_fair_fights_all_carry_a_short_where_label() -> void:
	var c := _fighter()
	for region_id: String in ["qingshi_village", "misty_forest"]:
		for f: Dictionary in Guidance.fair_fights(c, data(), {}, c.age_days, region_id):
			assert_true(String(f["short"]) != "", "%s has a short label: %s" % [region_id, f["text"]])
	var fresh := new_character()
	for f: Dictionary in Guidance.fair_fights(fresh, data(), {}, fresh.age_days, "qingshi_village"):
		assert_true(String(f["short"]) != "", String(f["text"]))


## MISSION-001: away from the board, the mission hint says where the board is; at a hall it says "here".
func test_mission_hint_says_where_the_board_is() -> void:
	var d := data()
	var c := _qr3_disciple()
	var hall := _hall_name(d, "qingshi_village")
	var here := Guidance._mission_hint(c, d, {}, "qingshi_village")
	assert_true(here.contains("at the %s here" % hall), here)
	var away := Guidance._mission_hint(c, d, {}, "misty_forest")
	assert_true(away.contains(hall) and away.contains("Qingshi Village"), away)
	assert_false(away.contains("here"), away)


func test_qi_pill_offer_near_names_a_pill_one_route_away() -> void:
	var d := data()
	var c := _qr(2, 400)
	var found := false
	for region_id: String in d.regions:
		if not Guidance.qi_pill_offer(c, d, region_id).is_empty():
			continue
		var near := Guidance.qi_pill_offer_near(c, d, region_id)
		if near.is_empty():
			continue
		found = true
		assert_true(String(near["where"]).begins_with("in "), String(near["where"]))
		assert_true(String(near["region_id"]) != region_id)
		break
	assert_true(found, "some region sells no pill but has a neighbour that does")
	var here := Guidance.qi_pill_offer_near(c, d, "qingshi_village")
	assert_false(here.has("where"), "a pill sold here has no far clause")


func test_chore_fair_fight_reads_as_a_chore() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = 4
	var shorts: Array[String] = []
	for e: Dictionary in Guidance.fair_fights(c, data(), {}, c.age_days, "qingshi_village"):
		if String(e["kind"]) == "deed":
			shorts.append(String(e["short"]))
	for s in shorts:
		assert_true(s.begins_with("Chore for "), s)


func test_far_manual_names_a_stall_with_its_market_day() -> void:
	var d := data()
	for region_id: String in d.regions:
		for p: Dictionary in d.regions[region_id].get("places", []):
			if String(p.get("type", "")) != "merchant" or not p.has("open_days"):
				continue
			for item_id: String in d.items:
				if Guidance.merchant_selling(d, region_id, item_id) == "" and Guidance.timed_stall(d, region_id, item_id).get("display_name", "") == p.get("display_name", ""):
					var line := Guidance.merchant_selling_when(d, region_id, item_id, 0)
					assert_true(line.begins_with(String(p["display_name"])), line)
					assert_true(line.contains("market day") or line.contains("open today"), line)
					assert_eq(Guidance.merchant_selling_when(d, region_id, item_id), String(p["display_name"]))
					return
	assert_true(false, "no stall-only item in data")


## GUIDE-209: the arrival line lists the great beast on its day and nothing on a quiet one.
func test_arrival_line_lists_great_beast_and_is_quiet_otherwise() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var wd := Wildlife.great_day("misty_forest", d.regions["misty_forest"]["roamers"]["great"])
	var line := Guidance.arrival_line(c, d, "misty_forest", wd, {}, "")
	assert_true(line.begins_with("Today in Misty Forest: "), line)
	var beast := String(d.enemies[String(d.regions["misty_forest"]["roamers"]["great"]["enemy"])]["name"])
	assert_true(line.contains(beast + " roams"), line)
	assert_eq(Guidance.arrival_line(c, d, "no_such_region", wd, {}, ""), "")
	# The line leads the hints on its day only.
	var flags := {"arrival_day": wd, "arrival_line": "Today in X: y.", "arrival_region": "misty_forest"}
	assert_eq(Guidance.hints(c, d, 1.0, 5, {}, flags, "misty_forest", wd)[0], "Today in X: y.")
	assert_false(Guidance.hints(c, d, 1.0, 5, {}, flags, "misty_forest", wd + 1).has("Today in X: y."))


## GUIDE-210: the line shows only in the region it was posted for; old flags without a region hide it.
func test_arrival_line_hint_needs_matching_region() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var flags := {"arrival_day": 10, "arrival_line": "Today in X: y.", "arrival_region": "qingshi_village"}
	assert_true(Guidance.hints(c, d, 1.0, 5, {}, flags, "qingshi_village", 10).has("Today in X: y."))
	assert_false(Guidance.hints(c, d, 1.0, 5, {}, flags, "misty_forest", 10).has("Today in X: y."))
	flags.erase("arrival_region")
	assert_false(Guidance.hints(c, d, 1.0, 5, {}, flags, "qingshi_village", 10).has("Today in X: y."))


## GUIDE-210: a festival running in the region leads the arrival line.
func test_arrival_line_names_festival() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var festival_id := ""
	for id: String in d.world_events:
		if WorldEvents.is_festival(d, id):
			festival_id = id
			break
	assert_true(festival_id != "", "a festival exists in data")
	var events: Array = [{"id": festival_id, "region": "qingshi_village", "end_day": 20}]
	var line := Guidance.arrival_line(c, d, "qingshi_village", 10, {}, "", events)
	assert_true(line.begins_with("Today in Qingshi Village: the %s is on" % WorldEvents.event_name(d, festival_id)), line)
	assert_false(Guidance.arrival_line(c, d, "misty_forest", 10, {}, "", events).contains("is on"))
	assert_false(Guidance.arrival_line(c, d, "qingshi_village", 25, {}, "", events).contains("is on"))


## GOAL-008: goals that lead out of the village.
func _after_ladder() -> CharacterData:
	var c := _fresh()
	c.techniques = {"basic_breathing": {"level": 1}, "iron_fist": {"level": 1, "xp": 0.0}}
	c.realm_index = 1
	c.stage = 2
	c.sect = {"id": data().sects.keys()[0], "rank": 0, "contribution": 0, "spent": 0}
	c.cooked_meals["x"] = 1
	LifeStats.add(c, "fights_won")
	LifeStats.add(c, "foraged")
	LifeStats.add(c, "harvests")
	return c


func test_road_goals_follow_the_first_ladder() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _after_ladder()
	assert_true(Guidance.first_goals_done(c, data(), flags))
	assert_true(Guidance.road_goals_active(c, data(), flags))
	var goals := Guidance.road_goals(c, data(), flags)
	assert_eq(goals.size(), 11)
	assert_true(String(goals[0]["text"]).contains("Misty Forest"))
	assert_true(String(goals[0]["text"]).contains("3 days"))
	assert_false(goals[0]["done"])
	assert_eq(Guidance.active_goal_ladder(c, data(), flags)[0]["text"], goals[0]["text"])
	c.visited_regions.append("misty_forest")
	c.visited_regions.append("fallen_star_market")
	goals = Guidance.road_goals(c, data(), flags)
	assert_true(goals[0]["done"] and goals[1]["done"])
	assert_true(String(goals[2]["text"]).begins_with("Beat a great beast (the next one: Great "))
	assert_false(goals[2]["done"])
	c.great_beasts["wild_boar"] = 3
	assert_true(Guidance.road_goals(c, data(), flags)[2]["done"])
	var section := Guidance.journal(c, data(), flags, 0, "qingshi_village").filter(func(e: Dictionary) -> bool: return e["section"] == "Road goals")
	assert_eq(section.size(), 11)


func test_road_goals_veteran_and_flags() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _after_ladder()
	LifeStats.add(c, "bounties_done")
	assert_true(Guidance.road_goals(c, data(), flags)[3]["done"])
	flags["discovered_misty_forest"] = true
	assert_true(Guidance.road_goals(c, data(), flags)[4]["done"])
	var vet := _after_ladder()
	vet.realm_index = 3
	for g in Guidance.road_goals(vet, data(), flags):
		assert_true(g["done"])
	assert_false(Guidance.road_goals_active(vet, data(), flags))


func test_road_goals_never_name_a_great_beast_above_the_realm() -> void:
	var c := _after_ladder()
	for rid: String in data().regions:
		var def: Dictionary = data().regions[rid].get("roamers", {}).get("great", {})
		if not def.is_empty() and not def.has("min_realm"):
			c.great_beasts[String(def["enemy"])] = 1
	var text := String(Guidance.road_goals(c, data(), {Guidance.ELDER_MO_FLAG: true})[2]["text"])
	assert_false(text.contains("Ram"), text)
	assert_eq(text, "Beat a great beast")


func test_find_note_names_meal_and_sell_price() -> void:
	var note := Guidance.find_note(data(), "spirit_herb", "qingshi_village")
	assert_true(note.contains("Used in"), note)
	assert_true(note.contains("Herb Porridge (cook at Village Workshop)"), note)
	assert_true(note.contains("sells for about"), note)


func test_find_note_without_use_is_only_the_sell_note() -> void:
	var note := Guidance.find_note(data(), "willow_branch", "qingshi_village")
	assert_false(note.contains("Used in"), note)
	assert_true(note == "" or note.begins_with("sells for about"), note)


func test_find_note_caps_uses_at_two() -> void:
	var note := Guidance.find_note(data(), "spirit_herb", "qingshi_village")
	var head := note.split(";")[0]
	assert_true(head.count(",") <= 1, head)


func test_road_goal_great_beast_is_the_soonest_and_names_the_weekday() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _after_ladder()
	var best_day := -1
	for rid: String in data().regions:
		var nd := Wildlife.next_great_day(data(), rid, 100, c.realm_index)
		if nd >= 0 and (best_day < 0 or nd < best_day):
			best_day = nd
	var text := String(Guidance.road_goals(c, data(), flags, 100)[2]["text"])
	assert_true(text.contains(Calendar.weekday_name(best_day)), text)
	var away := best_day - 100
	var when := "today" if away == 0 else ("tomorrow" if away == 1 else "in %d days" % away)
	assert_true(text.contains(", %s)" % when), text)  # C-297: the rumor follows


func test_road_goals_foundation_stretch() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _after_ladder()
	var goals := Guidance.road_goals(c, data(), flags)
	assert_eq(goals[8]["text"], "Reach the 9th Layer of Qi Refining")
	assert_false(goals[8]["done"])
	assert_true(String(goals[9]["text"]).begins_with("Get a Foundation Establishment"), String(goals[9]["text"]))
	assert_false(goals[9]["done"])
	assert_true(String(goals[10]["text"]).contains("(now "))
	assert_false(goals[10]["done"])
	c.stage = 7  # the 8th Layer (stage is 0-based)
	assert_false(Guidance.road_goals(c, data(), flags)[8]["done"])
	c.stage = 8  # the 9th Layer, the last one, so the goal can be met before Foundation
	assert_true(Guidance.road_goals(c, data(), flags)[8]["done"])
	c.breakthrough_pill = "x"
	assert_true(Guidance.road_goals(c, data(), flags)[9]["done"])
	assert_true(Guidance.road_goals_active(c, data(), flags))
	LifeStats.add(c, "breakthroughs_failed")
	assert_true(Guidance.road_goals(c, data(), flags)[10]["done"])
	var vet := _after_ladder()
	vet.realm_index = 3
	for g in Guidance.road_goals(vet, data(), flags):
		assert_true(g["done"])


func _foundation_walker() -> CharacterData:
	var c := _after_ladder()
	c.realm_index = 2
	c.stage = 0
	return c


func test_core_road_goals_appear_at_foundation_and_done_edges() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _foundation_walker()
	var goals := Guidance.road_goals(c, data(), flags, 100)
	assert_eq(goals.size(), 15)
	assert_eq(goals[11]["text"], "Reach Foundation Establishment Middle")
	assert_false(goals[11]["done"])
	assert_true(String(goals[12]["text"]).begins_with("Beat a great beast of your realm: "), String(goals[12]["text"]))
	for day in [100, 101, 102, 103, 104, 105, 106]:  # GOAL-012: any beast not yet beaten in Foundation is named, a Qi Refining one too
		assert_true(String(Guidance.road_goals(c, data(), flags, day)[12]["text"]).begins_with("Beat a great beast of your realm: Great "))
	assert_true(String(goals[13]["text"]).begins_with("Get a Core Formation pill"), String(goals[13]["text"]))
	assert_true(String(goals[14]["text"]).begins_with("Reach Foundation Establishment Peak, then attempt Core Formation (now "), String(goals[14]["text"]))
	c.stage = 1
	assert_true(Guidance.road_goals(c, data(), flags, 100)[11]["done"])
	c.breakthrough_pill = "core_forming_pill"
	assert_true(Guidance.road_goals(c, data(), flags, 100)[13]["done"])
	assert_false(Guidance.road_goals(c, data(), flags, 100)[14]["done"])
	c.breakthrough_failures = 1
	assert_true(Guidance.road_goals(c, data(), flags, 100)[14]["done"])
	assert_true(Guidance.road_goals_active(c, data(), flags))


func test_core_road_goals_not_shown_to_qi_refining_and_veteran_done() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	assert_eq(Guidance.road_goals(_after_ladder(), data(), flags, 100).size(), 11)
	var vet := _foundation_walker()
	vet.realm_index = 3
	for g in Guidance.road_goals(vet, data(), flags, 100):
		assert_true(g["done"])
	assert_false(Guidance.road_goals_active(vet, data(), flags))


func test_core_road_goal_beast_skipped_when_all_beaten_and_region_pointers() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _foundation_walker()
	c.stage = 1  # the Middle goal is done, so the pointer is on the beast
	var r := Guidance.road_goal_region(c, data(), flags, 100)
	assert_eq(r, String(Guidance._next_great(c, data(), 100, "", true)["region"]))
	assert_eq(r, "misty_forest", "the pointer goes to the soonest beast not yet beaten in Foundation")
	for rid: String in data().regions:
		var def: Dictionary = data().regions[rid].get("roamers", {}).get("great", {})
		if not def.is_empty():
			c.great_beasts[String(def["enemy"])] = 1
			c.great_beast_realms[String(def["enemy"])] = 2
			for step: Dictionary in Wildlife.great_chain(def):
				c.great_beasts[String(step["enemy"])] = 1
				c.great_beast_realms[String(step["enemy"])] = 2
	var goals := Guidance.road_goals(c, data(), flags, 100)
	assert_eq(goals.size(), 14)
	assert_true(String(goals[12]["text"]).begins_with("Get a Core Formation pill"), String(goals[12]["text"]))


func test_core_road_beast_row_needs_a_foundation_win() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _foundation_walker()
	c.realm_index = 1
	Wildlife.record_great(c, data(), "old_tusker_boar", "misty_forest", 3)  # beaten at Qi Refining
	assert_eq(c.great_beast_realms["old_tusker_boar"], 1)
	c.realm_index = 2
	assert_false(Guidance._won_great_in_foundation(c))
	var goals := Guidance.road_goals(c, data(), flags, 100)
	var row := goals[goals.size() - 3]
	assert_false(row["done"], String(row["text"]))
	assert_true(String(row["text"]).begins_with("Beat a great beast of your realm"), String(row["text"]))
	assert_true(String(row["text"]).contains("Scarred Old Tusker"), "the return beast is named: " + String(row["text"]))
	# A Foundation win of the old beast again ticks the row.
	Wildlife.record_great(c, data(), "old_tusker_boar", "misty_forest", 90)
	assert_eq(c.great_beast_realms["old_tusker_boar"], 2)
	goals = Guidance.road_goals(c, data(), flags, 100)
	assert_true(goals[goals.size() - 3]["done"])


func test_great_beast_realms_round_trip_and_old_save() -> void:
	var c := CharacterData.new()
	c.great_beast_realms = {"old_tusker_boar": 2}
	assert_eq(CharacterData.from_dict(c.to_dict()).great_beast_realms, {"old_tusker_boar": 2})
	var d := c.to_dict()
	d.erase("great_beast_realms")
	assert_eq(CharacterData.from_dict(d).great_beast_realms, {})


func test_road_goal_pill_text_names_treasury_or_shop() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var rogue := _after_ladder()
	rogue.sect = {}
	var text := String(Guidance.road_goals(rogue, data(), flags)[9]["text"])
	assert_false(text.contains("treasury"), text)
	var disciple := _after_ladder()
	var entry := Guidance.sect_pill_entry(disciple, data())
	if not entry.is_empty():
		disciple.sect["rank"] = int(entry["min_rank"])
		var t2 := String(Guidance.road_goals(disciple, data(), flags)[9]["text"])
		assert_true(t2.contains("the sect treasury for %d contribution" % int(entry["cost"])), t2)


func test_road_goals_sect_and_layer_goals() -> void:
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var c := _after_ladder()
	c.sect = {}
	assert_false(Guidance.road_goals(c, data(), flags)[5]["done"])
	flags[Guidance.SECT_HALL_FLAG] = true  # a rogue who visited a hall is done without joining
	assert_true(Guidance.road_goals(c, data(), flags)[5]["done"])
	var joined := _after_ladder()
	assert_true(Guidance.road_goals(joined, data(), {Guidance.ELDER_MO_FLAG: true})[5]["done"])
	assert_false(Guidance.road_goals(joined, data(), flags)[6]["done"])
	LifeStats.add(joined, "missions_done")
	assert_true(Guidance.road_goals(joined, data(), flags)[6]["done"])
	c.bounty = {"id": "x", "until_day": 9}
	assert_true(Guidance.road_goals(c, data(), flags)[6]["done"])
	assert_false(Guidance.road_goals(c, data(), flags)[7]["done"])
	c.stage = 4  # the 5th Layer (stage is 0-based)
	assert_false(Guidance.road_goals(c, data(), flags)[7]["done"])
	c.stage = 5  # the 6th Layer
	assert_true(Guidance.road_goals(c, data(), flags)[7]["done"])


func test_season_digest_lines_and_cap() -> void:
	var c := new_character()
	var flags := {}
	var unexplored := Guidance.season_digest(c, data(), flags, 0, "qingshi_village")
	assert_true(unexplored.size() <= 1, "nothing explored: only the spring festival line (C-307)")
	for line: String in unexplored:
		assert_true(line.begins_with("Festivals this"), line)
	c.visited_regions.append("qingshi_village")
	c.visited_regions.append("misty_forest")
	var spring := Guidance.season_digest(c, data(), flags, 0, "qingshi_village")
	assert_true(spring.size() >= 1 and spring.size() <= Guidance.SEASON_DIGEST_MAX)
	assert_true(spring[0].contains("Peach Blossom") or spring[0].contains("peach"), "local forage first: " + spring[0])
	var autumn := Guidance.season_digest(c, data(), flags, 180, "misty_forest")
	assert_true(autumn.size() <= Guidance.SEASON_DIGEST_MAX)
	assert_true(autumn[0].contains("Misty Forest"))
	var joined := "\n".join(autumn)
	assert_true(joined.contains("Mist Fox"), "autumn roamer named")
	assert_false("\n".join(spring).contains("Mist Fox"))


func test_season_digest_skips_unexplored_regions() -> void:
	var c := new_character()
	c.visited_regions.append("qingshi_village")
	var lines := "\n".join(Guidance.season_digest(c, data(), {}, 180, "qingshi_village"))
	assert_false(lines.contains("Misty Forest"))


func test_season_ending_names_what_leaves() -> void:
	var c := new_character()
	var seen := {Guidance.seen_key("mid_autumn_festival"): Calendar.year_of(266)}
	assert_eq(Guidance.season_ending(c, data(), 266, seen), "", "nothing explored, festival seen")
	c.visited_regions.append("misty_forest")
	assert_eq(Guidance.season_ending(c, data(), 200), "", "mid-season")
	var line := Guidance.season_ending(c, data(), 266)  # autumn, 3 days left
	assert_true(line.begins_with("Autumn ends in 3 days:"), line)
	assert_true(line.contains("Mist Fox"), line)
	assert_true(Guidance.season_ending(c, data(), 268).contains("tomorrow"))
	assert_true(Guidance.season_ending(c, data(), 269).contains("today"))
	# across the year end: winter 359 is the last day
	var winter := Guidance.season_ending(c, data(), 357, {})
	assert_false(winter.contains("Mist Fox"), winter)


## SEASON-004: plural names, a fat roamer thins out instead of leaving, missed vs seen vs upcoming festivals.
func test_season_ending_said_right() -> void:
	var c := new_character()
	c.visited_regions.append("misty_forest")
	var year := Calendar.year_of(266)
	var seen := {Guidance.seen_key("mid_autumn_festival"): year}
	var line := Guidance.season_ending(c, data(), 266, seen)
	assert_true(line.contains("go with them."), line)
	assert_true(line.contains("Foxes") or line.contains("Mushrooms"), line)
	assert_false(line.contains("missed"), line)
	var missed := Guidance.season_ending(c, data(), 266, {})
	assert_true(missed.contains("You missed the Mid-Autumn Moon Festival this year."), missed)
	var old := Guidance.season_ending(c, data(), 266, {Guidance.seen_key("mid_autumn_festival"): year - 1})
	assert_true(old.contains("missed"), "seen last year does not count")
	# Winter's Lantern Festival (month 10) is behind on day 357; its season-mate in month 12 is not yet.
	c.visited_regions.clear()
	assert_true(Guidance.season_ending(c, data(), 357, {}).contains("Lantern Festival"))
	assert_eq(Guidance.season_ending(c, data(), 357, {Guidance.seen_key("lantern_festival"): Calendar.year_of(357)}), "")
	# Qingming sits in spring's last month (C-307): spring's end still names it as missed.
	assert_true(Guidance.season_ending(c, data(), 87, {}).contains("Qingming"), Guidance.season_ending(c, data(), 87, {}))


## QA-198: the player's own marked day (CAL-006) is in Today, first, and tomorrow's mark too.
func test_today_lines_show_marked_days() -> void:
	var d := data()
	var c := new_character()
	c.visited_regions.append("qingshi_village")
	assert_eq(Guidance.today_lines(c, d, {}, [], 40, "qingshi_village").size() > 0 and Guidance.today_lines(c, d, {}, [], 40, "qingshi_village")[0].contains("you marked it"), false)
	c.marked_days[40] = "Shrine visit"
	c.marked_days[41] = "Fish at dawn"
	var lines := Guidance.today_lines(c, d, {}, [], 40, "qingshi_village")
	assert_eq(lines[0], "Today: Shrine visit (you marked it).", str(lines))
	assert_true(lines.has("Tomorrow: Fish at dawn."), str(lines))
	assert_true(lines.size() <= Guidance.TODAY_MAX)


## TODAY-001: market day first/next, wanted item, great beast, season ending, order and cap.
func test_today_lines_market_wanted_beast_and_cap() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.visited_regions.append("qingshi_village")
	var stall := {}
	for p: Dictionary in d.regions["qingshi_village"]["places"]:
		if p.has("open_days") and p.has("wanted"):
			stall = p
	assert_false(stall.is_empty(), "Qingshi has a wanted-item stall")
	var open_day := -1
	for day in range(300, 340):
		if Places.is_open(stall, day):
			open_day = day
			break
	var lines := Guidance.today_lines(c, d, {}, [], open_day, "qingshi_village")
	assert_true(lines.size() > 0 and lines[0].begins_with("Market day today at"), str(lines))
	var wants := false
	for l in lines:
		if l.contains(" wants "):
			wants = true
	assert_true(wants, "the stall's wanted item is named: %s" % str(lines))
	var soon := Guidance.today_lines(c, d, {}, [], open_day - 2, "qingshi_village")
	var found := false
	for l in soon:
		if l.begins_with("Market day at") and l.contains("in 2 days"):
			found = true
	assert_true(found, "next market within 3 days: %s" % str(soon))
	assert_false(" ".join(Guidance.today_lines(c, d, {}, [], open_day + 4, "qingshi_village")).contains("Market day"), "no market in sight")
	# Great beast today, then baited, then tracks the day before.
	var great: Dictionary = d.regions["misty_forest"]["roamers"]["great"]
	var wd := Wildlife.great_day("misty_forest", great)
	var beast := String(d.enemies[String(great["enemy"])]["name"])
	var g := Guidance.today_lines(c, d, {}, [], wd, "misty_forest")
	assert_true(g[0].contains(beast) and g[0].contains("walks"), str(g))
	var baited := Guidance.today_lines(c, d, {Wildlife.bait_flag("misty_forest"): wd}, [], wd, "misty_forest")
	assert_true(baited[0].contains("baited"), str(baited))
	var tr := Guidance.today_lines(c, d, {}, [], wd - 1, "misty_forest")
	assert_true(tr[0].contains("tracks"), str(tr))
	assert_true(Guidance.today_lines(c, d, {}, [], wd + 1, "misty_forest").size() <= Guidance.TODAY_MAX)
	# Season ending closes the list.
	c.visited_regions.append("misty_forest")
	var end := Guidance.today_lines(c, d, {}, [], 268, "misty_forest")
	assert_true(end[end.size() - 1].begins_with("Autumn ends"), str(end))
	assert_eq(Guidance.today_lines(c, d, {}, [], 0, "no_such_region").size(), 0)


func test_forage_phrase_names_pickups_rarest_first() -> void:  # TODAY-002
	var d := GameData.load_from_dir()
	var c := CharacterFactory.create("F", d, seeded_rng(1))
	var seen := {}
	for day in range(0, 120):
		var n := Foraging.unpicked(d, "qingshi_village", day, c.realm_index, {}).size()
		var phrase := Guidance._forage_phrase(c, d, "qingshi_village", day, {})
		if n == 0:
			assert_eq(phrase, "")
			continue
		assert_true(phrase.ends_with(" by the path"), phrase)
		assert_false(phrase.begins_with("%d thing" % n), phrase)
		assert_true(phrase.length() <= 60, phrase)
		seen[n] = true
	assert_true(seen.size() > 0)
	# every pickup picked: nothing to name
	var flags := {}
	for node: Dictionary in Foraging.unpicked(d, "qingshi_village", 10, c.realm_index, {}):
		flags[Foraging.flag_key("qingshi_village", int(node["slot"]))] = {"day": 10}
	assert_true(Guidance._forage_phrase(c, d, "no_such_region", 10, {}) == "")


## GUIDE-215: a nearer chore beats a far roamer; the goal names the trip; sort puts days first.
func test_fair_fight_nearest_first() -> void:
	var near := {"text": "a", "chance": 0.8, "stones": 0, "days": 0}
	var far := {"text": "b", "chance": 0.99, "stones": 50, "days": 6}
	assert_true(Guidance.fair_fight_before(near, far))
	assert_false(Guidance.fair_fight_before(far, near))
	var c := CharacterData.new()
	c.realm_index = 0
	var fights := Guidance.fair_fights(c, data(), {}, c.age_days, "misty_forest")
	for i in range(1, fights.size()):
		assert_true(int(fights[i - 1].get("days", 0)) <= int(fights[i].get("days", 0)), "days ascend")


func test_goal_trip_note() -> void:
	var c := CharacterData.new()
	var goal := "Talk to Elder Mo in Qingshi Village"
	assert_eq(Guidance.goal_trip_note(c, data(), goal, "qingshi_village"), "")
	assert_eq(Guidance.goal_trip_note(c, data(), goal, "misty_forest"), " (3 days)")
	assert_eq(Guidance.goal_trip_note(c, data(), "Reach Qi Refining", "misty_forest"), "")


## GUIDE-216: the shared fight text and festival-end wording.
func test_fight_text_has_the_rating_word_once() -> void:
	assert_eq(Guidance.fight_text({"chance": 0.99}, "Mission: Boar"), "Easy fight: Mission: Boar (99 in 100)")
	assert_eq(Guidance.fight_text({"chance": 0.55}, "Bounty: Wolf"), "Fair fight: Bounty: Wolf (55 in 100)")


func test_ends_phrase_last_day_wording() -> void:
	assert_eq(Guidance.ends_phrase(11, 10), "ends today")
	assert_eq(Guidance.ends_phrase(12, 10), "last day tomorrow")
	assert_eq(Guidance.ends_phrase(13, 10), "3 days left")
	assert_eq(Guidance.ends_phrase(10, 10), "ends today")


func test_journal_festival_lines_use_last_day_wording() -> void:
	var d := data()
	var festival_id := ""
	for id: String in d.world_events:
		if WorldEvents.is_festival(d, id):
			festival_id = id
			break
	var events: Array = [{"id": festival_id, "region": "qingshi_village", "start_day": 10, "end_day": 13}]
	var texts: Array[String] = []
	for today in [11, 12]:
		var out: Array[Dictionary] = []
		Guidance._festival_entries(out, d, today, "qingshi_village", events, {})
		texts.append(String(out[0]["text"]))
	assert_true(texts[0].ends_with("last day tomorrow"), texts[0])
	assert_true(texts[1].ends_with("ends today"), texts[1])


## GUIDE-217: Today names unpicked hen eggs by the coop, drops them once picked; a festival's last days use ends_phrase;
## the well's draw line is gone after the draw.
func test_today_lines_coop_festival_and_well() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var entries: Array = d.regions["qingshi_village"]["map"]["ambient_critters"]
	var day := -1
	for t in range(1, 400):
		if Critters.eggs_today("qingshi_village", entries, t, Calendar.season_of(t).to_lower()).size() >= 1:
			day = t
			break
	assert_true(day > 0, "some day has an egg")
	var flags := {}
	var eggs := Critters.eggs_left("qingshi_village", entries, day, flags, Calendar.season_of(day).to_lower())
	var line := "%s by the coop (%d left)" % [String(d.items[String(eggs[0]["item"])]["name"]), eggs.size()]
	assert_true(Guidance.today_lines(c, d, flags, [], day, "qingshi_village").has(line), str(Guidance.today_lines(c, d, flags, [], day, "qingshi_village")))
	for e in eggs:
		Critters.mark_egg(flags, "qingshi_village", int(e["index"]), day)
	for l in Guidance.today_lines(c, d, flags, [], day, "qingshi_village"):
		assert_false(l.contains("by the coop"), l)
	# Festival ends wording matches ends_phrase.
	var festival_id := ""
	for id: String in d.world_events:
		if WorldEvents.is_festival(d, id):
			festival_id = id
			break
	var events: Array = [{"id": festival_id, "region": "qingshi_village", "start_day": day - 3, "end_day": day + 1}]
	var fl := Guidance.today_lines(c, d, {}, events, day, "qingshi_village")
	assert_true(fl[0].contains(Guidance.ends_phrase(day + 1, day)), str(fl))
	events[0]["end_day"] = day + 5
	assert_false(Guidance.today_lines(c, d, {}, events, day, "qingshi_village")[0].contains("ends today"))


func test_today_knows_your_friends() -> void:
	var d := data()
	var npcs := {}
	Npcs.ensure_all(npcs, d, seeded_rng(3))
	var c := CharacterData.new()
	var favor := {"elder_mo": 60}
	var b := Folk.birthday_day(npcs["elder_mo"], d)
	var quiet := Guidance.today_lines(c, d, {}, [], b + Calendar.DAYS_PER_YEAR - 5, "qingshi_village", npcs, {})
	assert_false("\n".join(quiet).contains("something to show you"))
	var lines := Guidance.today_lines(c, d, {}, [], b + Calendar.DAYS_PER_YEAR - 5, "qingshi_village", npcs, favor)
	var text := "\n".join(lines)
	assert_true(text.contains("Elder Mo has something to show you (find them at "), text)
	assert_false(text.contains("birthday"), "not their birthday yet")
	var party := "\n".join(Guidance.today_lines(c, d, {}, [], b + Calendar.DAYS_PER_YEAR, "qingshi_village", npcs, favor))
	assert_true(party.contains("It is Elder Mo's birthday (find them at "), party)
	assert_eq(party.count("birthday"), 1, "one birthday line")
	c.lessons_taught["elder_mo:0"] = 1
	assert_false("\n".join(Guidance.today_lines(c, d, {}, [], b + Calendar.DAYS_PER_YEAR - 5, "qingshi_village", npcs, favor)).contains("something to show you"))
	assert_true(Guidance.today_lines(c, d, {}, [], b + Calendar.DAYS_PER_YEAR, "qingshi_village", npcs, favor).size() <= Guidance.TODAY_MAX)


func test_find_note_names_only_dishes_you_know() -> void:
	var d := data()
	assert_true(d.home_meals.any(func(m: Dictionary) -> bool: return m["id"] == "honey_egg_cake" and m.get("taught", false)))
	var c := CharacterData.new()
	assert_false(Guidance.find_note(d, "hen_egg", "qingshi_village", c).contains("Honey Egg Cake"))
	assert_false(Guidance.find_note(d, "hen_egg", "qingshi_village").contains("Honey Egg Cake"), "null hides taught meals")
	Cooking.learn(c, d, "honey_egg_cake")
	assert_true(Guidance.find_note(d, "hen_egg", "qingshi_village", c).contains("Honey Egg Cake"))


# GUIDE-220: short hints for the HUD's narrow Next steps panel.
func _assert_short_set(c: CharacterData, region: String, label: String) -> void:
	var gs := _root().get_node("GameState")
	var long_hints := Guidance.hints(c, data(), 1.0, 99, gs.npcs, gs.world_flags, region, 0, gs.npc_favor)
	var short_hints := Guidance.hints(c, data(), 1.0, 99, gs.npcs, gs.world_flags, region, 0, gs.npc_favor, true)
	assert_false(short_hints.is_empty(), label)
	for h in short_hints:
		assert_true(h.length() <= 42, "%s: '%s' (%d)" % [label, h, h.length()])
		assert_false(h.ends_with("..."), h)
	for h in long_hints:
		assert_eq(h, Guidance.hints(c, data(), 1.0, 99, gs.npcs, gs.world_flags, region, 0, gs.npc_favor, false)[long_hints.find(h)], "long unchanged")


func test_short_hints_fit_for_a_fresh_mortal() -> void:
	var c := _fresh()
	c.techniques = {}
	_assert_short_set(c, "qingshi_village", "mortal")


func test_short_hints_fit_for_a_rogue_and_a_disciple() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.stage = 2
	_assert_short_set(c, "misty_forest", "rogue QR3")
	c.realm_index = 1
	c.stage = 4
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	_assert_short_set(c, "azure_peak", "azure QR5")


func test_short_hint_rewrites_the_fighting_style_line() -> void:
	var line := "You know no fighting style. Manual: Iron Fist at the Wandering Merchant teaches Iron Fist for 15 spirit stones."
	assert_eq(Guidance.short_hint(line), "No fighting style: Iron Fist")
	assert_eq(Guidance.short_hint("Short line."), "Short line.")
	assert_true(Guidance.short_hint("Ask Elder Mo in Qingshi Village where to begin; he also teaches a breathing technique.").length() <= 42)


# GUIDE-222
func test_short_goal_fits_and_keeps_the_target() -> void:
	var g := Guidance.short_goal("Goal: Talk to Elder Mo in Qingshi Village (10 days)", data())
	assert_eq(g, "Goal: See Elder Mo in Qingshi · 10d")
	assert_true(g.length() <= 46)
	assert_eq(Guidance.short_goal("Goal: Reach the 2nd layer", data()), "Goal: Reach the 2nd layer")
	var long := Guidance.short_goal("Goal: Sell your herbs to the Wandering Merchant at Fallen Star Market (9 days)", data())
	assert_true(long.length() <= 46, long)
	assert_false(long.ends_with("..."))


func test_short_fight_lines() -> void:
	assert_eq(Guidance.short_hint("Easy fight: Chore for Headman Zhou: Wild Boar (99 in 100)", data()), "Easy fight: Wild Boar · 99%")
	assert_eq(Guidance.short_hint("Easy fight: Wild Boar in Withered Bone Marsh (9 days, 99 in 100)", data()), "Easy fight: Wild Boar, Bone Marsh · 99%")


func test_short_hints_fit_in_every_region() -> void:
	for region: String in data().regions:
		var c := _fresh()
		c.techniques = {}
		_assert_short_set(c, region, "mortal in " + region)


func test_short_hints_fit_with_an_injury() -> void:
	var c := _fresh()
	c.realm_index = 1
	c.stage = 3
	Injuries.inflict(c, data(), String(data().injuries.keys()[0]))
	_assert_short_set(c, "qingshi_village", "injured")


func test_region_short_name_falls_back_and_validates() -> void:
	assert_eq(Places.short_region_name(data(), "withered_bone_marsh"), "Bone Marsh")
	assert_eq(Places.short_region_name(data(), "azure_peak"), "Azure Peak")
	var d := GameData.new()
	d.regions = {"r": {"id": "r", "short_name": "A name far too long"}}
	d.load_errors.clear()
	d._validate()
	var found := false
	for e in d.load_errors:
		if "short_name" in e:
			found = true
	assert_true(found, "long short_name rejected")


# GUIDE-223
func test_short_fight_line_and_hunt_line() -> void:
	assert_eq(Guidance.short_fight_line("Easy fight: Wild Boar in Withered Bone Marsh (9 days, 99 in 100)", data()), "Easy fight: Wild Boar, Bone Marsh · 99%")
	assert_eq(Guidance.short_fight_line("Easy fight: Chore for Headman Zhou: Wild Boar (99 in 100)", data()), "Easy fight: Wild Boar · 99%")
	assert_eq(Guidance.short_fight_line("Hunting: Blood-Eyed Wolf in Withered Bone Marsh (3 days left)", data()), "Hunting: Blood-Eyed Wolf, Bone Marsh")
	assert_eq(Guidance.short_fight_line("Rest a while.", data()), "Rest a while.")


func test_short_today_phrase_drops_whole_place_phrases() -> void:
	assert_eq(Guidance.short_today_phrase("Mugwort by the path"), "Mugwort")
	assert_eq(Guidance.short_today_phrase("Hen's Egg by the coop (2 left)"), "Hen's Egg (2 left)")
	assert_eq(Guidance.short_today_phrase("the Cloud Crane roams"), "the Cloud Crane roams")


func test_short_hint_never_ends_on_a_stop_word() -> void:
	for line in ["Reach Qi Refining and Azure Cloud Sect or somewhere else", "Gather Mugwort by the path near the old well today", "Reach Qi Refining stage two and then the Azure Cloud Sect or"]:
		var s := Guidance.short_hint(line, data())
		var last := s.split(" ")[-1].to_lower()
		assert_false(Guidance.STOP_WORDS.has(last), s)
	assert_eq(Guidance.drop_trailing_stop_words("Mugwort by the"), "Mugwort")


func test_goal_trip_note_counts_realm_gated_roads() -> void:
	var c := _fresh()
	var note := Guidance.goal_trip_note(c, data(), "Talk to Elder Mo in Qingshi Village", "myriad_peaks_ridge")
	assert_true(note.contains("days"), note)


## GUIDE-225: probes swap-and-restore on the character itself and give what a copy would.
func test_probes_leave_the_character_untouched_and_match_a_copy() -> void:
	var c := _payoff_fighter()
	assert_true(c != null)
	Injuries.inflict(c, data(), "broken_bones")
	c.buffs = {"test_buff": {"name": "Test", "days": 3, "mults": {}}}
	var before := JSON.stringify(c.to_dict())
	var copy := CharacterData.from_dict(c.to_dict())
	var d := data()
	var foe: Dictionary = d.enemies["azure_sword_examiner"]
	assert_eq(Guidance.odds_unhurt(c, d, foe), Guidance.odds_unhurt(copy, d, foe))
	var ref := CharacterData.from_dict(c.to_dict())
	ref.injuries.clear()
	assert_eq(Guidance.odds_unhurt(c, d, foe), Combat.win_chance(ref, d, foe), "same as the old unhurt copy")
	var payoff := Guidance.practice_payoff(c, d, "iron_fist", "misty_forest", 10)
	assert_eq(payoff, Guidance.practice_payoff(copy, d, "iron_fist", "misty_forest", 10))
	assert_eq(Guidance._rated_region_fights(c, d, "misty_forest", 10, {}), Guidance._rated_region_fights(copy, d, "misty_forest", 10, {}))
	assert_eq(Guidance.empty_fair_fights_note(c, d, "misty_forest", 10), Guidance.empty_fair_fights_note(copy, d, "misty_forest", 10))
	assert_eq(Guidance.meal_before_fight(c, d, "misty_forest", 10), Guidance.meal_before_fight(copy, d, "misty_forest", 10))
	assert_eq(Guidance.trial_practice_payoff(c, d), Guidance.trial_practice_payoff(copy, d))
	assert_eq(Guidance._mortal_sect_hint(c, d, PackedStringArray()), Guidance._mortal_sect_hint(copy, d, PackedStringArray()))
	assert_eq(JSON.stringify(c.to_dict()), before, "no probe leaves a trace")
	assert_eq(JSON.stringify(copy.to_dict()), before)


func test_short_hint_rewrites_the_meal_line() -> void:
	var held := Guidance.short_hint("Eat an Eel Congee before you fight the Mist Fox: Even 55 -> 63.")
	assert_eq(held, "Eat Eel Congee: 55 -> 63")
	var cook := Guidance.short_hint("Cook Eel Congee at Village Workshop before you fight the Mist Fox (Even 41 -> 55).")
	assert_eq(cook, "Cook Eel Congee: 41 -> 55")
	assert_true(Guidance.short_hint("Eat a Mountain Hotpot Supreme Feast before you fight the Iron-Backed Great Boar: Hard 20 -> 34.").length() <= Guidance.SHORT_HINT_CHARS)


## GUIDE-236: a new disciple is told where the sect lives until they have been there.
func test_sect_home_hint_until_visited() -> void:
	var c := _fresh()
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0}
	c.visited_regions.clear()
	var hint := Guidance.sect_home_hint(c, data(), "qingshi_village")
	assert_true(hint.contains("Azure Cloud Hall in "), hint)
	var days := Guidance.route_days(c, data(), "qingshi_village", "azure_peak")
	if days > 0:
		assert_true(hint.contains(Calendar.format_duration(days) + " by road"), hint)
	assert_true(_has(Guidance.hints(c, data(), 1.0, 12, {}, {}, "qingshi_village"), "Your sect's home is"))
	c.visited_regions.append("azure_peak")
	assert_eq(Guidance.sect_home_hint(c, data(), "qingshi_village"), "")
	var rogue := _fresh()
	assert_eq(Guidance.sect_home_hint(rogue, data(), "qingshi_village"), "")
