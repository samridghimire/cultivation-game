extends TestCase
## Integration tests through the GameState / SaveManager autoloads.

const TEST_SLOT := "_test_slot"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


func _start(seed_value: int = 4242) -> CharacterData:
	var gs := _game_state()
	var c := CharacterFactory.create("Integration", gs.data, seeded_rng(seed_value))
	c.spiritual_roots = {"fire": 80}  # guarantee a usable root
	gs.start_session(c)
	return c


func test_cultivating_advances_time_and_age() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var age_before := c.age_days
	c.realm_index = 1  # a month of meditation must not hit the first bottleneck
	_game_state().cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(clock.total_days, Calendar.DAYS_PER_MONTH)
	assert_eq(c.age_days, age_before + Calendar.DAYS_PER_MONTH)
	assert_gt(c.qi, 0.0)


func test_mortal_can_reach_qi_refining() -> void:
	var c := _start()
	var gs := _game_state()
	for i in 24:
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			break
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_true(Cultivation.can_attempt_breakthrough(c, gs.data), "should hit the mortal bottleneck within 2 years")
	for i in 50:
		if c.realm_index > 0:
			break
		gs.attempt_breakthrough()
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(c.realm_index, 1)


func test_failed_breakthrough_posts_a_hint() -> void:
	var c := _start()
	var gs := _game_state()
	var failed := false
	for i in 20:
		c.realm_index = 1
		c.stage = gs.data.realms[1].stage_count() - 1
		Cultivation.add_qi(c, gs.data, 1e12)
		c.breakthrough_bonus = -5.0
		EventBus.clear_history()
		gs.attempt_breakthrough()
		if c.realm_index == 1:
			failed = true
			break
	assert_true(failed)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("raise your odds") or String(e["text"]).contains("(+")))
	gs.end_session()


func test_player_dies_of_old_age() -> void:
	var c := _start()
	var gs := _game_state()
	c.spiritual_roots = {}  # no cultivation, so lifespan never grows
	for i in 100:
		if not c.alive:
			break
		gs.perform_deed("help_villager")
		gs.work_profession("doctor", Calendar.DAYS_PER_YEAR)
	assert_false(c.alive)
	assert_true(c.cause_of_death != "")


func test_save_and_load_round_trip() -> void:
	var c := _start()
	var gs := _game_state()
	var saves := _root().get_node("SaveManager")
	gs.cultivate(Calendar.DAYS_PER_YEAR)
	gs.perform_deed("kill_villager")
	var expected: Dictionary = c.to_dict()
	var expected_days: int = _root().get_node("GameClock").total_days
	assert_true(saves.save_game(TEST_SLOT))
	gs.end_session()
	assert_true(saves.load_game(TEST_SLOT))
	assert_eq(gs.player.to_dict(), expected)
	assert_eq(_root().get_node("GameClock").total_days, expected_days)
	assert_true(gs.world_flags.get("villager_dead", false))
	DirAccess.remove_absolute(saves.save_path(TEST_SLOT))
	gs.end_session()


func test_join_and_leave_sect() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	assert_eq(c.sect.get("id", ""), "blood_lotus_sect")
	# Already in a sect: second join is refused and changes nothing.
	gs.join_sect("myriad_treasure_pavilion")
	assert_eq(c.sect.get("id", ""), "blood_lotus_sect")
	gs.leave_sect()
	assert_true(c.is_rogue())
	gs.leave_sect()  # leaving while rogue is harmless
	assert_true(c.is_rogue())
	gs.end_session()


func test_attend_lecture_once_a_month() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	c.alignment = 0
	gs.attend_lecture()  # rogue: refused, no time passes
	assert_eq(clock.total_days, 0)
	gs.join_sect("blood_lotus_sect")
	var qi_before := c.qi
	gs.attend_lecture()
	assert_gt(c.qi, qi_before)
	assert_eq(clock.total_days, 2)
	var qi_after := c.qi
	gs.attend_lecture()  # same month: refused
	assert_eq(c.qi, qi_after)
	assert_eq(clock.total_days, 2)
	gs.end_session()


## RV-013: a lecture at a bottleneck says so instead of "(+0 qi)".
func test_attend_lecture_at_bottleneck_message() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	var realm: RealmDef = gs.data.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.attend_lecture()
	EventBus.message_posted.disconnect(_collect_post)
	var text := "\n".join(_zero_round_posts)
	assert_false(text.contains("+0 qi"), text)
	assert_true(text.contains("bottleneck"), text)
	gs.end_session()


func test_join_sect_rejects_wrong_alignment() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 500
	gs.join_sect("blood_lotus_sect")
	assert_true(c.is_rogue())
	gs.end_session()


func test_buy_item_quantity_buys_all_or_nothing() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory["spirit_stone"] = 50
	gs.buy_item("qi_gathering_pill", "", 4)  # 60 > 50
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	gs.buy_item("qi_gathering_pill", "", 3)
	assert_eq(c.item_count("qi_gathering_pill"), 3)
	assert_eq(c.item_count("spirit_stone"), 5)
	gs.end_session()


func test_buy_item_spends_stones() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory["spirit_stone"] = 20
	gs.buy_item("qi_gathering_pill")  # price 15
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.item_count("spirit_stone"), 5)
	gs.buy_item("qi_gathering_pill")  # cannot afford
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.item_count("spirit_stone"), 5)
	gs.end_session()


func test_sell_crafted_talisman_pays_material_capped_price() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory = {"golden_bell_talisman": 3}
	gs.sell_item("golden_bell_talisman", 2)
	assert_eq(c.item_count("golden_bell_talisman"), 1)
	assert_eq(c.item_count("spirit_stone"), 2 * Items.sell_price(gs.data, "golden_bell_talisman"))
	assert_gt(30, c.item_count("spirit_stone"))  # not the old 15 stones apiece
	gs.end_session()


func test_use_item_consumes_and_applies() -> void:
	var c := _start()
	var gs := _game_state()
	gs.use_item("qi_gathering_pill")  # none owned: refused
	assert_eq(c.qi, 0.0)
	c.add_item("qi_gathering_pill", 1)
	gs.use_item("qi_gathering_pill")
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	assert_gt(c.qi, 0.0)
	gs.end_session()


func test_work_profession_pays_and_gives_contribution() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	var stones_before := c.item_count("spirit_stone")
	gs.work_profession("talisman_master", Calendar.DAYS_PER_MONTH)  # favored by Blood Lotus
	assert_eq(clock.total_days, Calendar.DAYS_PER_MONTH)
	assert_gt(c.item_count("spirit_stone"), stones_before)
	assert_gt(int(c.sect["contribution"]), 0)
	gs.end_session()


func test_work_profession_promotes_in_sect() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	c.sect["contribution"] = 399
	gs.work_profession("talisman_master", Calendar.DAYS_PER_MONTH)
	assert_gt(int(c.sect["contribution"]), 399)
	assert_eq(Sects.check_promotion(c, gs.data), "", "enough contribution: the Blood Disciple trial opens")
	gs.end_session()


func test_work_profession_rogue_has_no_contribution() -> void:
	var c := _start()
	var gs := _game_state()
	gs.work_profession("alchemist", Calendar.DAYS_PER_MONTH)
	assert_true(c.sect.is_empty())
	gs.end_session()


func _arm_blood_drinker(c: CharacterData) -> void:
	c.add_item("blood_drinker_saber", 1)
	Equipment.equip(c, _game_state().data, "blood_drinker_saber")


func test_fight_with_evil_weapon_burns_a_year() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	var before := Cultivation.years_left(c, gs.data)
	gs.fight("wild_boar")
	assert_true(c.alive)
	assert_eq(Cultivation.years_left(c, gs.data), before - 1)
	gs.end_session()


func test_evil_weapon_drinking_last_year_kills_of_old_age() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	c.age_days = (Cultivation.lifespan_years(c, gs.data) - 1) * Calendar.DAYS_PER_YEAR
	gs.fight("wild_boar")
	assert_false(c.alive)
	assert_true(c.cause_of_death.contains("weapon drinks the last"))
	gs.end_session()


func test_violent_death_does_not_also_drain_lifespan() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	var doom := {"id": "doom", "name": "Doom", "realm": "tribulation", "stage": 9, "hp": 100000, "attack": 100000, "defense": 100000, "speed": 100, "lethal": true, "techniques": [], "rewards": {}}
	gs.fight_enemy(doom)
	assert_eq(c.lifespan_spent_years, 0, "a respawned soul keeps its years; the saber drinks only after survived fights")
	gs.end_session()


func test_lost_fight_posts_advice() -> void:
	var c := _start()
	var gs := _game_state()
	var foe := {"id": "t", "name": "Test Foe", "realm": "foundation_establishment", "stage": 5, "hp": 500, "attack": 500, "defense": 500, "speed": 50, "techniques": [], "rewards": {}}
	gs.fight_enemy(foe)
	assert_true(c.alive)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("far above you")))
	assert_true(gs.last_loss_advice.contains("far above you"))
	var report := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(report)
	report.show_fight("Test Foe", false, PackedStringArray(["start", "end"]), gs.last_loss_advice)
	assert_true(report._log.get_parsed_text().contains("far above you"), "the report carries the advice")
	report.show_fight("Test Foe", true, PackedStringArray(["start", "end"]), gs.last_loss_advice)
	assert_false(report._log.get_parsed_text().contains("far above you"), "no advice after a win")
	report.queue_free()
	gs.end_session()


func test_fight_spoils_show_sell_price() -> void:
	var c := _start()
	c.realm_index = 2
	var gs := _game_state()
	var weak := {"id": "w", "name": "Weak Foe", "realm": "mortal", "stage": 0, "hp": -50, "attack": -50, "defense": -50, "speed": 0, "techniques": [], "rewards": {"items": {"mist_wolf_pelt": 1, "spirit_stone": 3}}}
	assert_true(gs.fight_enemy(weak))
	var price := Items.sell_price(gs.data, "mist_wolf_pelt")
	assert_true(price > 0)
	var joined := "|".join(gs.last_fight_spoils)
	assert_true(joined.contains("(sells for %d)" % price), joined)
	assert_false(joined.contains("Spirit Stone (sells"), "stones carry no price note")
	assert_false(joined.contains("each"), "a single item has no 'each'")
	weak["rewards"] = {"items": {"mist_wolf_pelt": 3}}
	assert_true(gs.fight_enemy(weak))
	assert_true("|".join(gs.last_fight_spoils).contains("(sells for %d each)" % price), "|".join(gs.last_fight_spoils))
	gs.end_session()


func test_fight_spoils_in_report() -> void:
	var c := _start()
	c.realm_index = 2
	var gs := _game_state()
	var weak := {"id": "w", "name": "Weak Foe", "realm": "mortal", "stage": 0, "hp": -50, "attack": -50, "defense": -50, "speed": 0, "techniques": [], "rewards": {"items": {"spirit_stone": 8}}}
	assert_true(gs.fight_enemy(weak))
	assert_false(gs.last_fight_spoils.is_empty(), "a win records its spoils")
	var report := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(report)
	report.show_fight("Weak Foe", true, PackedStringArray(["start", "end"]), "", gs.last_fight_spoils)
	assert_true(report._log.get_parsed_text().contains("Spoils:"))
	assert_true(report._log.get_parsed_text().contains("Spirit Stone"))
	report.show_fight("Weak Foe", false, PackedStringArray(["start", "end"]), "", gs.last_fight_spoils)
	assert_false(report._log.get_parsed_text().contains("Spoils:"), "no spoils line on a loss")
	var strong := {"id": "t", "name": "Test Foe", "realm": "foundation_establishment", "stage": 5, "hp": 500, "attack": 500, "defense": 500, "speed": 50, "techniques": [], "rewards": {}}
	gs.fight_enemy(strong)
	assert_true(gs.last_fight_spoils.is_empty(), "spoils are cleared between fights")
	assert_true(c.alive)
	report.queue_free()
	gs.end_session()


func test_choose_gender_once_for_old_saves() -> void:
	var c := _start()
	var gs := _game_state()
	c.gender = ""
	gs.choose_gender("dragon")
	assert_eq(c.gender, "")
	gs.choose_gender("female")
	assert_eq(c.gender, "female")
	gs.choose_gender("male")
	assert_eq(c.gender, "female", "gender can only be picked once")


func test_gathering_skips_realm_gated_finds() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 0
	var table := [{"item": "nine_leaf_soul_grass", "weight": 1, "min": 1, "max": 1, "min_realm": "foundation_establishment"}]
	gs.gather(table, 5)
	assert_eq(c.item_count("nine_leaf_soul_grass"), 0, "too shallow to find it")
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	gs.gather(table, 5)
	assert_gt(c.item_count("nine_leaf_soul_grass"), 0)


func test_deed_with_enemy_needs_a_win() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 0
	c.stage = 0
	var alignment_before := c.alignment
	gs.perform_deed("free_bandit_captives")
	assert_false(gs.world_flags.get("bandit_camp_gone", false), "a mortal loses to the bandit lord")
	assert_eq(c.alignment, alignment_before)
	assert_true(c.alive, "the bandit lord is not lethal")
	c.injuries.clear()  # the beating's injuries would halve a Foundation cultivator's strength
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	gs.perform_deed("free_bandit_captives")
	assert_true(gs.world_flags.get("bandit_camp_gone", false), "a Foundation cultivator wins and frees them")
	assert_gt(c.alignment, alignment_before)


func test_promotion_trial_and_stipend() -> void:
	var c := _start()
	var gs := _game_state()
	var ranks := (gs.data.sects["blood_lotus_sect"] as SectDef).ranks
	ranks[1]["trial"] = "wild_boar"
	c.alignment = -300
	gs.join_sect("blood_lotus_sect")
	gs.attempt_promotion_trial()
	assert_eq(int(c.sect["rank"]), 0, "not enough contribution for the trial yet")
	c.sect["contribution"] = 400
	c.realm_index = gs.data.realm_index_of("foundation_establishment")  # beats a boar for sure
	var days_before: int = _root().get_node("GameClock").total_days
	gs.attempt_promotion_trial()
	ranks[1].erase("trial")
	assert_eq(int(c.sect["rank"]), 1, "winning the trial promotes")
	assert_gt(_root().get_node("GameClock").total_days, days_before)
	assert_true(c.alive)
	# The promotion month waives the duty, so the stipend is paid at month end.
	var stones := c.item_count("spirit_stone")
	gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(c.item_count("spirit_stone"), stones + int(Sects.stipend(c, gs.data)["spirit_stones"]))
	gs.end_session()


func test_auction_bid_and_save() -> void:
	var c := _start()
	var gs := _game_state()
	var house := "fallen_star_auction"
	var def := Auctions.house(gs.data, house)
	assert_eq(gs.auction_lots(house).size(), 0, "no auction on day 0")
	gs._pass_time(int(def["offset_days"]))
	gs.current_region = String(def["region"])
	var lots: Array = gs.auction_lots(house)
	assert_eq(lots.size(), int(def["lots"]))
	var amount := int(lots[0]["npc_max"]) + 1
	c.add_item("spirit_stone", amount)
	var stones := c.item_count("spirit_stone")
	var days: int = _root().get_node("GameClock").total_days
	assert_eq(gs.check_bid(house, 0, amount), "")
	gs.bid(house, 0, amount)
	assert_eq(c.item_count("spirit_stone"), stones - amount)
	assert_eq(_root().get_node("GameClock").total_days, days, "bidding takes no time")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_eq(String(gs.auction_lots(house)[0]["sold"]), "player", "sold lots survive a save")
	assert_true(gs.check_bid(house, 0, amount).contains("already been sold"))
	gs.end_session()


func test_story_event_without_npc() -> void:
	var c := _start()
	var gs := _game_state()
	assert_eq(gs.pending_event, String(gs.data.artifact.get("intro_event", "")), "a new character has the intro event pending")
	assert_false(gs.start_event("no_such_dialogue"))
	gs.start_pending_event()
	assert_eq(gs.pending_event, "")
	assert_true(gs.in_dialogue())
	assert_true(gs.world_flags.get(gs.INTRO_EVENT_FLAG, false))
	var view: Dictionary = gs.dialogue_view()
	assert_eq(String(view["speaker"]), "", "the opening is narration")
	var steps := 0
	while gs.in_dialogue() and steps < 10:
		gs.choose_dialogue(int(gs.dialogue_view()["choices"][-1]["index"]))
		steps += 1
	assert_false(gs.in_dialogue(), "the event ends")
	assert_eq(gs.dialogue_event, "")
	assert_true(c.alive)
	assert_false(gs.start_event(gs.data.artifact["intro_event"], gs.INTRO_EVENT_FLAG), "the intro never repeats")
	gs.end_session()


func test_loaded_save_skips_the_intro_event() -> void:
	_start()
	var gs := _game_state()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_eq(gs.pending_event, "")
	gs.start_pending_event()
	assert_false(gs.in_dialogue())
	gs.end_session()


func test_fight_summary_is_one_line_with_its_spoils() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = gs.data.realm_index_of("qi_refining")
	var bus := _root().get_node("EventBus")
	var before: int = bus.history.size()
	gs.fight("wild_boar")
	var lines: Array = bus.history.slice(before).map(func(e: Dictionary) -> String: return e["text"])
	for line: String in lines:
		assert_false(line.begins_with("("), "spoils are not posted as an orphan line: %s" % line)
	var summary: Array = lines.filter(func(l: String) -> bool: return l.begins_with("The Wild Boar collapses."))
	assert_eq(summary.size(), 1, str(lines))
	assert_true(String(summary[0]).contains("Boar Hide"), "the spoils ride on the summary: %s" % summary[0])
	assert_true(String(summary[0]).contains(" round, ") or String(summary[0]).contains(" rounds, "), summary[0])
	assert_false(String(summary[0]).contains("1 rounds"), summary[0])
	gs.end_session()


func test_place_names_in_sentences_drop_map_hints() -> void:
	assert_eq(GameData.plain_name("Cloud-Sea Cliff (2x qi)"), "Cloud-Sea Cliff")
	assert_eq(GameData.plain_name("Waterfall Cave (abode)"), "Waterfall Cave")
	assert_eq(GameData.plain_name("Meditation Rock"), "Meditation Rock")
	var gs := _game_state()
	assert_eq(Abodes.abode_name(gs.data, "waterfall_cave"), "Waterfall Cave")
	assert_eq(CreationArtifact.anchor_name(gs.data, "azure_cliff"), "Cloud-Sea Cliff (Azure Peak)")


func test_long_cultivation_stops_at_the_bottleneck() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	var needed := Cultivation.days_to_bottleneck(c, gs.data, gs.region_qi_density() * Sects.cultivation_bonus(c, gs.data))
	assert_gt(needed, 0)
	assert_true(needed < Calendar.DAYS_PER_YEAR * 10)
	gs.cultivate(needed + 500)
	assert_eq(clock.total_days, needed)
	assert_true(Cultivation.is_at_bottleneck(c, gs.data))
	gs.cultivate(30)
	assert_eq(clock.total_days, needed)


var _zero_round_posts: Array[String] = []


func _collect_post(text: String, _category: String) -> void:
	_zero_round_posts.append(text)


## FH-015: a foe felled by a talisman before any exchange posts no "0 rounds".
func test_fight_won_in_zero_rounds_posts_no_round_count() -> void:
	var c := _start()
	var gs := _game_state()
	var foe: Dictionary = gs.data.enemies["wild_boar"].duplicate(true)
	foe["id"] = "t_glass_boar"
	foe["hp"] = 1
	gs.data.enemies["t_glass_boar"] = foe
	c.add_item("fire_strike_talisman", 5)
	CombatTalismans.ready_talisman(c, gs.data, "fire_strike_talisman")
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.fight("t_glass_boar")
	EventBus.message_posted.disconnect(_collect_post)
	var text := "\n".join(_zero_round_posts)
	assert_false(text.contains("0 rounds"), text)
	assert_true(text.contains("before it could strike"), text)
	gs.end_session()


## FH-025: exploring for a while sums up quiet days in one line.
func test_explore_many_quiet_days_post_one_summary() -> void:
	_start()
	var gs := _game_state()
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	var start_day: int = _root().get_node("GameClock").total_days
	var days: int = gs.explore_many(7, ["t_no_such_tag"])
	EventBus.message_posted.disconnect(_collect_post)
	assert_eq(days, 7)
	assert_eq(_root().get_node("GameClock").total_days, start_day + 7)
	var text := "\n".join(_zero_round_posts)
	assert_true(text.contains("find nothing of note"), text)
	assert_false(text.contains("You search the area"), text)
	var lines: Array = gs.data.regions[gs.current_region]["quiet_lines"]
	assert_true(lines.any(func(l): return text.ends_with(String(l))), text)
	gs.end_session()


## FH-025: an encounter on day one stops the exploring there.
func test_explore_many_stops_when_something_happens() -> void:
	_start()
	var gs := _game_state()
	gs.data.encounters["t_ex_find"] = {"id": "t_ex_find", "tags": ["t_ex"], "weight": 1, "text": "You find a stone.", "effects": {}, "days": 1}
	var start_day: int = _root().get_node("GameClock").total_days
	var days: int = gs.explore_many(7, ["t_ex"])
	assert_eq(days, 1)
	assert_eq(_root().get_node("GameClock").total_days, start_day + 1)
	assert_eq(gs.explore_many(99, ["t_no_such_tag"]), 30, "clamped to 30 days")
	gs.data.encounters.erase("t_ex_find")
	gs.end_session()


## STAT-001: fights, fleeing and breakthroughs feed the life record.
func test_life_stats_track_actions() -> void:
	var c := _start()
	var gs := _game_state()
	var foe: Dictionary = gs.data.enemies["wild_boar"].duplicate(true)
	foe["id"] = "t_stat_boar"
	# Enemy stats are modifiers on realm power; make the foe a 1-hp, harmless, undodging target
	# so the win does not depend on the seed.
	foe["hp"] = -1000
	foe["attack"] = -1000
	foe["speed"] = -1000
	gs.data.enemies["t_stat_boar"] = foe
	assert_true(gs.fight_enemy(foe))
	assert_eq(LifeStats.get_stat(c, "fights_won"), 1)
	gs.pending_threat = "wild_boar"
	gs.face_threat(false)
	assert_eq(LifeStats.get_stat(c, "threats_fled"), 1)
	for i in 24:
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			break
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_true(Cultivation.can_attempt_breakthrough(c, gs.data))
	gs.attempt_breakthrough()
	assert_eq(LifeStats.get_stat(c, "breakthroughs") + LifeStats.get_stat(c, "breakthroughs_failed"), 1)
	gs.end_session()


func test_milestone_posted_on_player_change() -> void:
	var c := _start()
	var gs := _game_state()
	LifeStats.add(c, "fights_won")
	EventBus.clear_history()
	EventBus.player_changed.emit()
	assert_true(c.milestones.has("first_fight"))
	var posted := EventBus.history.filter(func(m): return String(m["text"]).begins_with("Milestone: First Blood"))
	assert_eq(posted.size(), 1)
	EventBus.player_changed.emit()
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).begins_with("Milestone: First Blood")).size(), 1)


func test_journal_entries_on_new_game() -> void:
	_start()
	var entries: Array[Dictionary] = _game_state().journal_entries()
	assert_false(entries.is_empty())
	assert_true(entries.any(func(e: Dictionary) -> bool: return e["section"] == "First goals"))


func _duty_warnings() -> int:
	var n := 0
	for m: Dictionary in _root().get_node("EventBus").history:
		if String(m["text"]).begins_with("Your sect duty is"):
			n += 1
	return n


func _start_duty_member(earned: int) -> CharacterData:
	var c := _start()
	c.realm_index = 2
	for sect: SectDef in _game_state().data.sects.values():
		for r in sect.ranks.size():
			if c.is_rogue() and int(sect.ranks[r].get("monthly_duty", 0)) > 0:
				c.sect = {"id": sect.id, "rank": r, "contribution": 0, "spent": 0, "month_earned": earned}
	c.age_days = 30 * 100 + 20
	return c


func test_duty_reminder_posts_once_when_seven_days_remain() -> void:
	var c := _start_duty_member(0)
	_game_state().cultivate(5)  # day 20 -> 25
	assert_eq(_duty_warnings(), 1)
	_game_state().cultivate(2)
	assert_eq(_duty_warnings(), 1)


func test_no_duty_reminder_when_duty_met() -> void:
	var c := _start_duty_member(0)
	c.sect["month_earned"] = Sects.monthly_duty(c, _game_state().data)
	_game_state().cultivate(5)
	assert_eq(_duty_warnings(), 0)


func test_loading_does_not_reannounce_milestones() -> void:
	var c := _start()
	var gs := _game_state()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	# A save written before the milestone was announced (e.g. a month-end autosave mid-action)
	var player_dict: Dictionary = saved["player"]
	player_dict["milestones"] = []
	player_dict["life_stats"] = {"fights_won": 1}
	var reached: Array = []
	var cb := func(id: String, _n: String) -> void: reached.append(id)
	var bus := _root().get_node("EventBus")
	bus.milestone_reached.connect(cb)
	gs.load_save_dict(saved)
	bus.milestone_reached.disconnect(cb)
	assert_eq(reached.size(), 0, str(reached))
	assert_true(gs.player.milestones.has("first_fight"), "awarded silently on load")
	assert_true(c != null)
	gs.end_session()


func test_spar_does_not_count_as_a_fight() -> void:
	var c := _start()
	var gs := _game_state()
	gs.fight_enemy(Sects.trial_opponent(gs.data, "rogue_cultivator"))
	assert_eq(LifeStats.get_stat(c, "fights_won") + LifeStats.get_stat(c, "fights_lost"), 0)
	gs.end_session()


func test_commission_ordered_and_delivered() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	gs.cultivate(Calendar.DAYS_PER_MONTH + 1)
	assert_eq(c.commissions.size(), 1)
	var order: Dictionary = c.commissions[0]
	c.add_item(order["item"], int(order["count"]))
	var stones := c.item_count("spirit_stone")
	gs.deliver_commission(0)
	assert_eq(c.item_count("spirit_stone"), stones + int(order["reward"]))
	assert_eq(c.commissions.size(), 0)
	gs.end_session()


func test_meditation_preview_describes_qi() -> void:
	_start()
	var text: String = _game_state().meditation_preview(30, 1.0)
	assert_true(text != "")
	assert_true(text.contains("qi"))


func test_explore_outlook_is_a_line() -> void:
	_start()
	var text: String = _game_state().explore_outlook()
	assert_true(text != "")
	assert_true(text.contains("%"))


func test_new_year_posts_a_review_once_and_restores_snapshot() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	assert_true(c.year_start_realm != "", "a new session stores a snapshot")
	LifeStats.add(c, "deeds_done", 2)
	var seen: Array = []
	var cb := func(year: int, lines: PackedStringArray, _start: int) -> void: seen.append([year, lines])
	bus.year_reviewed.connect(cb)
	clock.advance(Calendar.DAYS_PER_YEAR)
	bus.year_reviewed.disconnect(cb)
	assert_eq(seen.size(), 1)
	assert_true("You did 2 deeds." in (seen[0][1] as PackedStringArray))
	var posted := 0
	for m in bus.history:
		if String(m["text"]) == "You did 2 deeds.":
			posted += 1
	assert_eq(posted, 1)
	assert_eq(c.year_start_stats.get("deeds_done", 0), 2)
	# an old save (no snapshot) just stores one on the next new year
	c.year_start_realm = ""
	c.year_start_stats = {}
	clock.advance(Calendar.DAYS_PER_YEAR)
	assert_eq(seen.size(), 1)
	assert_true(c.year_start_realm != "")
	assert_eq(gs.player, c)


func test_meditation_line_shows_progress() -> void:
	var c := _start()
	c.realm_index = 1
	_game_state().cultivate(Calendar.DAYS_PER_MONTH)
	var lines: Array = _root().get_node("EventBus").history.filter(func(m): return String(m["text"]).begins_with("You cultivate for"))
	assert_false(lines.is_empty())
	var text := String(lines[-1]["text"])
	assert_true(text.contains("qi to"))
	assert_false(text.contains("%") or text.contains("{"))
	assert_true(_game_state().days_to_next_stage(1.0) != 0)


func _last_text() -> String:
	return String(_root().get_node("EventBus").history[-1]["text"])


func test_path_shift_announced_on_any_alignment_change() -> void:
	var c := _start()
	var gs := _game_state()
	var eb := _root().get_node("EventBus")
	eb.clear_history()
	eb.player_changed.emit()
	assert_eq(eb.history.filter(func(m): return String(m["text"]).contains("Your path has shifted")).size(), 0)
	c.alignment = -400
	eb.clear_history()
	eb.player_changed.emit()
	eb.player_changed.emit()
	var shifted: Array = eb.history.filter(func(m): return String(m["text"]).contains("Your path has shifted"))
	assert_eq(shifted.size(), 1)
	assert_eq(String(shifted[0]["category"]), "karma")
	c.alignment -= 1
	eb.clear_history()
	eb.player_changed.emit()
	assert_eq(eb.history.filter(func(m): return String(m["text"]).contains("Your path has shifted")).size(), 0)
	gs.end_session()


func test_messages_use_words_not_raw_numbers() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 2
	var npc := CharacterFactory.create("Li Wei", gs.data, seeded_rng(9))
	npc.id = "li_wei"
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	gs.npcs["li_wei"] = npc
	var eb := _root().get_node("EventBus")
	eb.clear_history()
	gs.chat("li_wei")
	if eb.history.size() > 0 and _last_text().contains("talking with"):
		assert_true(_last_text().contains("to court"), _last_text())
	c.alignment = 210
	gs._announced_tier = "Virtuous"
	eb.clear_history()
	gs.hostile_act("li_wei", "humiliate")
	var texts: Array = eb.history.map(func(m): return String(m["text"]))
	assert_true(texts.any(func(t: String) -> bool: return t.contains("You humiliate Li Wei before onlookers.")), str(texts))
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Your path has shifted: you are now Neutral.")), str(texts))
	for t: String in texts:
		assert_false(t.contains("%") or t.contains("{") or t.contains("li_wei"), t)
	gs.end_session()


func test_sell_all_pays_sum_with_one_message() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory = {"spirit_herb": 3, "iron_essence": 2}
	var before := c.item_count("spirit_stone")
	var expected := 3 * Items.sell_price(gs.data, "spirit_herb") + 2 * Items.sell_price(gs.data, "iron_essence")
	var stones: int = gs.sell_all(["spirit_herb", "iron_essence"])
	assert_eq(stones, expected)
	assert_eq(c.item_count("spirit_stone"), before + expected)
	assert_eq(c.item_count("spirit_herb"), 0)


func test_unlock_notice_is_posted_once() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	gs.world_flags.erase("notice_body_tempering")
	var before := EventBus.posted_count
	gs.check_unlock_notices()
	assert_true(gs.world_flags.get("notice_body_tempering", false))
	assert_gt(EventBus.posted_count, before)
	var after := EventBus.posted_count
	gs.check_unlock_notices()
	assert_eq(EventBus.posted_count, after)


## RV-010: an old save with no notice flags is marked quietly on load.
func test_loading_an_old_save_marks_notices_without_posting() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 3
	Dao.gain_levels(c, gs.data, gs.data.dao_insights.keys()[0], 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	var flags: Dictionary = saved["world_flags"]
	for k in flags.keys():
		if String(k).begins_with("notice_"):
			flags.erase(k)
	var before: int = EventBus.history.size()
	gs.load_save_dict(saved)
	gs.check_unlock_notices()
	var texts: Array = EventBus.history.slice(before).map(func(e: Dictionary) -> String: return e["text"])
	for t: String in texts:
		assert_false(t.contains("temper your body") or t.contains("Contemplate"), t)
	assert_true(gs.world_flags.get("notice_body_tempering", false))
	assert_true(gs.world_flags.get("notice_dao", false))
	gs.end_session()


func test_save_with_some_notice_flags_still_announces_new_features() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 3
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	var flags: Dictionary = saved["world_flags"]
	for k in flags.keys():
		if String(k).begins_with("notice_"):
			flags.erase(k)
	flags["notice_rival"] = true
	var before: int = EventBus.posted_count
	gs.load_save_dict(saved)
	gs.check_unlock_notices()
	assert_true(gs.world_flags.get("notice_body_tempering", false))
	assert_gt(EventBus.posted_count, before, "the new feature is announced")
	gs.end_session()


## YEAR-002: a seclusion that crosses two new years posts one review titled for both.
func test_long_seclusion_reviews_both_years() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	clock.advance(Calendar.DAYS_PER_YEAR / 2) # mid-year, still the year of the snapshot
	LifeStats.add(c, "deeds_done", 1)
	var start_year := c.year_start_year
	assert_true(start_year >= 1, "the snapshot remembers its year")
	var seen: Array = []
	var cb := func(year: int, _lines: PackedStringArray, start: int) -> void: seen.append([year, start])
	bus.year_reviewed.connect(cb)
	clock.advance(Calendar.DAYS_PER_YEAR * 3 / 2 + 40) # crosses two new years
	bus.year_reviewed.disconnect(cb)
	assert_eq(seen.size(), 1, "one review for the whole stretch")
	assert_eq(LifeStats.review_title(seen[0][1], seen[0][0]), "Years %d-%d" % [start_year, seen[0][0] - 1])
	assert_eq(c.year_start_year, seen[0][0], "the new snapshot is for the current year")
	assert_eq(LifeStats.review_title(seen[0][0], seen[0][0] + 1), "Year %d" % seen[0][0], "a normal year")
	assert_eq(LifeStats.review_title(0, 5), "Year 4", "old saves have no start year")
	assert_eq(LifeStats.review_title(1, 2), "Year 1", "the first year")
	assert_eq(LifeStats.review_title(3, 6), "Years 3-5", "a seclusion across years")
	assert_eq(CharacterData.from_dict(c.to_dict()).year_start_year, c.year_start_year)
	assert_eq(CharacterData.from_dict({}).year_start_year, 0)


func test_ask_pointers() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var npc := CharacterFactory.create("Elder Lu", gs.data, seeded_rng(9))
	npc.id = "elder_lu"
	npc.age_days = 40 * Calendar.DAYS_PER_YEAR
	npc.realm_index = 2
	gs.npcs["elder_lu"] = npc
	gs.npc_favor["elder_lu"] = 25
	var clock := _root().get_node("GameClock")
	var eb := _root().get_node("EventBus")
	var day: int = clock.total_days
	eb.clear_history()
	gs.ask_pointers("elder_lu")
	assert_eq(clock.total_days, day + 1)
	assert_true(c.techniques["iron_fist"]["xp"] > 0.0 or c.techniques["iron_fist"]["level"] > 1)
	assert_true(_last_text().contains("points out a flaw") or eb.history.any(func(m): return String(m["text"]).contains("points out a flaw")))
	eb.clear_history()
	gs.ask_pointers("elder_lu")
	assert_eq(clock.total_days, day + 1, "no time passes when refused")
	assert_true(_last_text().contains("recently"), _last_text())
	gs.end_session()


func test_spar_with_npc() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 3
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	c.inventory = {"spirit_stone": 50}
	var npc := CharacterFactory.create("Sparring Friend", gs.data, seeded_rng(9))
	npc.id = "friend"
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	npc.realm_index = 4
	gs.npcs["friend"] = npc
	gs.npc_favor["friend"] = 15
	var clock := _root().get_node("GameClock")
	var day: int = clock.total_days
	var won_before := LifeStats.get_stat(c, "fights_won")
	var lost_before := LifeStats.get_stat(c, "fights_lost")
	var spar_rules: Dictionary = gs.data.family["mentorship"]["spar"]
	var spar_days := int(spar_rules["days"])
	spar_rules["days"] = 3
	gs.spar_with("friend")
	spar_rules["days"] = spar_days
	assert_eq(clock.total_days, day + 3, "a spar takes the spar rule's days")
	assert_eq(c.item_count("spirit_stone"), 50, "a spar takes no stones")
	assert_true(c.injuries.is_empty())
	assert_eq(LifeStats.get_stat(c, "fights_won"), won_before)
	assert_eq(LifeStats.get_stat(c, "fights_lost"), lost_before)
	assert_true(c.techniques["iron_fist"]["xp"] > 0.0 or c.techniques["iron_fist"]["level"] > 1)
	var eb := _root().get_node("EventBus")
	eb.clear_history()
	gs.spar_with("friend")
	assert_true(_last_text().contains("recently"), _last_text())
	gs.end_session()


## TRAV-001: travel records each region once; old saves gain their current region.
func test_travel_records_visited_regions() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	assert_eq(c.visited_regions, [gs.data.start_region] as Array[String])
	assert_eq(LifeStats.get_stat(c, "regions_visited"), 1)
	var target := String(gs.data.regions[gs.data.start_region]["routes"][0]["to"])
	gs.travel(target)
	assert_true(Exploration.visited(c, target))
	assert_eq(c.visited_regions.size(), 2)
	gs.travel(gs.data.start_region)
	gs.travel(target)
	assert_eq(c.visited_regions.size(), 2)
	assert_eq(LifeStats.get_stat(c, "regions_visited"), 2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_eq(gs.player.visited_regions.size(), 2)


func test_old_save_without_visited_regions_gets_current_region() -> void:
	var gs := _game_state()
	_start()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	saved["player"].erase("visited_regions")
	saved["player"]["life_stats"] = {}
	gs.load_save_dict(saved)
	assert_eq(gs.player.visited_regions, [gs.current_region] as Array[String])
	assert_eq(LifeStats.get_stat(gs.player, "regions_visited"), 1)


func test_friendly_spar_report_reads_like_a_spar() -> void:
	var c := _start()
	var gs := _game_state()
	var foe := {"id": "t", "name": "Test Foe", "realm": "foundation_establishment", "stage": 5, "hp": 500, "attack": 500, "defense": 500, "speed": 50, "techniques": [], "rewards": {}, "spar": true, "friendly": true}
	gs.fight_enemy(foe)
	assert_true(c.alive)
	assert_true(gs.last_fight_friendly)
	var days := int(gs.data.family["mentorship"]["spar"]["cooldown_days"])
	assert_true(gs.last_loss_advice.begins_with("No harm done. You can spar again in %d" % days), gs.last_loss_advice)
	assert_false(gs.last_loss_advice.contains("far above you"))
	var report := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(report)
	report.show_fight("Test Foe", false, PackedStringArray(["start", "end"]), gs.last_loss_advice, gs.last_fight_spoils, [], 0, 0, gs.last_fight_friendly)
	assert_true(report._title.text.begins_with("Friendly spar"), report._title.text)
	assert_true(report._log.get_parsed_text().contains("No harm done"))
	# A real loss is unchanged.
	foe.erase("friendly")
	foe.erase("spar")
	gs.fight_enemy(foe)
	assert_false(gs.last_fight_friendly)
	assert_true(gs.last_loss_advice.contains("far above you"), gs.last_loss_advice)
	report.show_fight("Test Foe", false, PackedStringArray(["start", "end"]), gs.last_loss_advice, gs.last_fight_spoils, [], 0, 0, gs.last_fight_friendly)
	assert_true(report._title.text.begins_with("Defeat"))
	report.queue_free()
	gs.end_session()


func _count_messages(text: String) -> int:
	var n := 0
	for m: Dictionary in _root().get_node("EventBus").history:
		if m["text"] == text:
			n += 1
	return n


## TRAV-002: the first arrival in a region posts its first_visit text once.
func test_first_visit_text_posts_once() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var line := String(gs.data.regions["misty_forest"]["first_visit"])
	gs.travel("misty_forest")
	assert_true(gs.last_arrival_first_visit)
	assert_eq(_count_messages(line), 1)
	gs.travel(gs.data.start_region)  # the start region counts as already visited
	assert_false(gs.last_arrival_first_visit)
	gs.travel("misty_forest")
	assert_false(gs.last_arrival_first_visit)
	assert_eq(_count_messages(line), 1)
	gs.end_session()


## ENC-003: exploring counts the encounter that happened.
func test_explore_counts_met_encounter() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	gs.travel("misty_forest")
	gs.explore()
	var total := 0
	for n in c.encounter_counts.values():
		total += int(n)
	assert_true(total <= 1)
	if total == 1:
		assert_eq(c.encounter_counts.size(), 1)
	gs.end_session()


## C-043: every region has a first_visit line.
func test_every_region_has_first_visit() -> void:
	var d := GameData.load_from_dir()
	for id in d.regions:
		assert_true(String(d.regions[id].get("first_visit", "")).strip_edges() != "", "%s needs a first_visit" % id)


func test_first_visit_validator_rejects_empty() -> void:
	var d := GameData.load_from_dir()
	assert_eq(d.load_errors.size(), 0)
	d.regions["misty_forest"]["first_visit"] = ""
	d.load_errors.clear()
	d._validate_world()
	assert_true(d.load_errors.size() > 0)


## TRAV-003: an older save without visited_regions remembers its abode, sect and anchors.
func test_old_save_backfills_known_places() -> void:
	var gs := _game_state()
	var c := _start()
	c.abode = "waterfall_cave"
	c.sect = {"id": "azure_cloud_sect", "rank": 0}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	saved["player"].erase("visited_regions")
	saved["player"]["life_stats"] = {}
	gs.load_save_dict(saved)
	var v: Array[String] = gs.player.visited_regions
	assert_true(v.has(gs.data.start_region))
	assert_true(v.has("misty_forest"), "abode region")
	assert_true(v.has("azure_peak"), "sect home region")
	assert_false(v.has("fallen_star_market"), "other halls are not credited")
	assert_eq(LifeStats.get_stat(gs.player, "regions_visited"), v.size())
	# A save that already has a list is left alone.
	saved["player"]["visited_regions"] = [gs.data.start_region]
	gs.load_save_dict(saved)
	assert_eq(gs.player.visited_regions, [gs.data.start_region] as Array[String])
	gs.end_session()


func test_season_change_posts_one_in_season_line() -> void:
	var c := _start()
	c.realm_index = 1
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	clock.total_days = 359
	var before: int = bus.history.size()
	_game_state().cultivate(2)  # crosses winter -> spring
	var lines := 0
	for i in range(maxi(0, before - 1), bus.history.size()):
		if String(bus.history[i]["text"]).begins_with("Spring has come. In season now:"):
			lines += 1
	assert_eq(lines, 1)


func test_first_exploration_finds_region_discovery_once() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "misty_forest"
	var herbs_before: int = c.inventory.get("spirit_herb", 0)
	gs.explore()
	assert_true(gs.world_flags.get("discovered_misty_forest", false))
	assert_eq(int(c.inventory.get("spirit_herb", 0)), herbs_before + 2)
	var saves := _root().get_node("SaveManager")
	assert_true(saves.save_game(TEST_SLOT))
	assert_true(saves.load_game(TEST_SLOT))
	DirAccess.remove_absolute(saves.save_path(TEST_SLOT))
	assert_true(gs.world_flags.get("discovered_misty_forest", false), "flag survives save/load")
	for i in 50:
		gs.player.alive = true
		gs.explore()
		if gs.pending_encounter != "":
			gs.pending_encounter = ""
	assert_true(Exploration.discovery_for(gs.player, gs.data, "misty_forest", gs.world_flags).is_empty())
	gs.end_session()


## EXPL-001: every explore day counts toward the region's familiarity, found or not.
func test_explore_days_are_counted() -> void:
	_start()
	var gs := _game_state()
	gs.explore_many(5, ["t_no_such_tag"])
	assert_eq(Exploration.familiarity(gs.player, gs.current_region), 5)
	gs.end_session()
