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


func _fail_breakthrough(gs: Node, c: CharacterData) -> bool:
	for i in 20:
		c.realm_index = 1
		c.stage = gs.data.realms[1].stage_count() - 1
		Cultivation.add_qi(c, gs.data, 1e12)
		c.breakthrough_bonus = -5.0
		EventBus.clear_history()
		gs.attempt_breakthrough()
		if c.realm_index == 1:
			return true
	return false


func _lesson_text() -> String:
	for e in EventBus.history:
		if String(e["text"]).begins_with("The lessons stay with you"):
			return String(e["text"])
	return ""


func test_failed_breakthrough_names_the_lesson() -> void:
	var c := _start()
	var gs := _game_state()
	c.breakthrough_failures = 0
	assert_true(_fail_breakthrough(gs, c))
	assert_true(_lesson_text().contains("+%d percent on your next attempt" % roundi(gs.data.failure_bonus * c.breakthrough_failures * 100.0)), _lesson_text())
	gs.end_session()


func test_failed_breakthrough_lesson_at_the_cap() -> void:
	var c := _start()
	var gs := _game_state()
	c.breakthrough_failures = 10
	assert_true(_fail_breakthrough(gs, c))
	var text := _lesson_text()
	assert_true(text.contains("already worth all they can teach"), text)
	assert_true(text.contains("+%d percent" % roundi(gs.data.failure_bonus_max * 100.0)), text)
	gs.end_session()


func test_player_dies_of_old_age() -> void:
	var c := _start()
	var gs := _game_state()
	c.spiritual_roots = {}  # no cultivation, so lifespan never grows
	var saves := _root().get_node("SaveManager")
	saves.autosave_enabled = false  # a year-long loop would write the autosave every month
	for i in 100:
		if not c.alive:
			break
		gs.perform_deed("help_villager")
		gs.work_profession("doctor", Calendar.DAYS_PER_YEAR)
	saves.autosave_enabled = true
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


func test_seasonal_herb_price_follows_the_season() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory["spirit_stone"] = 100
	GameClock.total_days = 0  # spring: spirit herb is in season
	gs.buy_item("spirit_herb")
	assert_eq(c.item_count("spirit_stone"), 95)
	GameClock.total_days = 300  # winter
	gs.buy_item("spirit_herb")
	assert_eq(c.item_count("spirit_stone"), 88)
	gs.sell_item("spirit_herb")
	assert_eq(c.item_count("spirit_stone"), 92)
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


func test_lost_fight_names_a_fairer_fight() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = 3
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0}
	c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}, "stone_skin": {"level": 2, "xp": 0.0}}
	assert_false(Guidance.fair_fights(c, gs.data, gs.world_flags, GameClock.total_days, gs.current_region).is_empty(), "a fair fight exists")
	var foe := {"id": "t", "name": "Test Foe", "realm": "tribulation", "stage": 5, "hp": 90000, "attack": 90000, "defense": 90000, "speed": 50, "techniques": [], "rewards": {}}
	gs.fight_enemy(foe)
	assert_true(gs.last_loss_advice.contains("A fairer fight"), gs.last_loss_advice)
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


## QA-055: combat_started fires before the fight, with the enemy and the
## player still unchanged (so tools can rate the odds the fight started from).
func test_combat_started_fires_before_the_fight() -> void:
	var c := _start()
	var gs := _game_state()
	var seen := []
	var on_started := func(enemy: Dictionary) -> void: seen.append([String(enemy["id"]), gs.player.item_count("spirit_stone")])
	EventBus.combat_started.connect(on_started)
	var foe := {"id": "w", "name": "Weak Foe", "realm": "mortal", "stage": 0, "hp": -50, "attack": -50, "defense": -50, "speed": 0, "techniques": [], "rewards": {"items": {"spirit_stone": 3}}}
	var before := c.item_count("spirit_stone")
	gs.fight_enemy(foe)
	EventBus.combat_started.disconnect(on_started)
	assert_eq(seen, [["w", before]], "emitted once, before the reward was paid")


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


func _set_weather(gs: Node, kind: String) -> void:
	gs.data.regions[gs.current_region]["weather"] = {"any": {kind: 1}}
	gs.data.weather_persist = 0.0


## The shared GameState data is reloaded fresh so these weather edits cannot leak into other tests.
func _restore_weather(gs: Node) -> void:
	gs.data = GameData.load_from_dir()


func test_rain_adds_a_thriving_herb_when_gathering() -> void:
	var c := _start()
	var gs := _game_state()
	gs.data.weather_effects = {"rain": {"herb_bonus_chance": 1.0}}
	var table := [{"item": "spirit_herb", "weight": 1, "min": 1, "max": 1}]
	_set_weather(gs, "clear")
	gs.gather(table, 1)
	var dry := c.item_count("spirit_herb")
	_set_weather(gs, "rain")
	var heard: Array[String] = []
	var cb := func(text: String, _cat: String) -> void: heard.append(text)
	EventBus.message_posted.connect(cb)
	gs.gather(table, 1)
	EventBus.message_posted.disconnect(cb)
	var wet := c.item_count("spirit_herb") - dry
	assert_eq(wet, dry + 1, "one extra on the rain day")
	assert_true("\n".join(heard).contains("The rain has the herbs thriving: +1"))
	_restore_weather(gs)


func test_rain_stirs_water_qi_for_a_water_root() -> void:
	var c := _start()
	c.spiritual_roots = {"water": 80}
	var gs := _game_state()
	gs.data.weather_effects = {"rain": {"qi_element": {"element": "water", "mult": 1.1}}}
	_set_weather(gs, "clear")
	var clear_density: float = gs.region_qi_density()
	var clear_days: int = gs.days_to_next_stage()
	_set_weather(gs, "rain")
	assert_almost_eq(gs.region_qi_density(), clear_density * 1.1)
	assert_true(gs.days_to_next_stage() < clear_days, "the HUD estimate follows the same rate")
	var before := c.qi
	gs.cultivate(10)
	var rain_gain := c.qi - before
	c.qi = before
	_set_weather(gs, "clear")
	gs.cultivate(10)
	assert_true(rain_gain > c.qi - before, "rain meditation gains more qi")
	_restore_weather(gs)


func test_seclusion_starting_on_rain_uses_the_mean_weather() -> void:
	var c := _start()
	c.spiritual_roots = {"water": 80}
	var gs := _game_state()
	gs.data.weather_effects = {"rain": {"qi_element": {"element": "water", "mult": 1.1}}}
	gs.data.regions[gs.current_region]["weather"] = {"any": {"rain": 1, "clear": 1}}
	gs.data.weather_persist = 0.0
	var day: int = GameClock.total_days
	var mean: float = Weather.mean_qi_mult(gs.data, gs.current_region, c, day, 30)
	assert_true(mean < 1.1, "a mixed month is below the full rain bonus")
	assert_almost_eq(gs.region_qi_density(30) / gs.region_qi_density(1), mean / Weather.qi_mult(gs.data, Weather.of(gs.data, gs.current_region, day), c))
	_restore_weather(gs)


func test_fishing_catches_and_weather_changes_the_odds() -> void:
	var c := _start()
	var gs := _game_state()
	var table := [{"item": "", "weight": 1}, {"item": "silver_carp", "weight": 1, "min": 1, "max": 1}]
	_set_weather(gs, "clear")
	var day := GameClock.total_days
	gs.data.fishing_weather = {"rain": 0.000001}
	gs.fish(table, 1, "Test Pond")
	assert_eq(GameClock.total_days, day + 1, "fishing takes the days")
	var clear_catch := c.item_count("silver_carp")
	_set_weather(gs, "rain")
	var before := c.item_count("silver_carp")
	for i in 20:
		gs.fish(table, 1)
	assert_eq(c.item_count("silver_carp"), before, "a rain day with a tiny multiplier catches nothing")
	_set_weather(gs, "clear")
	for i in 20:
		gs.fish(table, 1)
	assert_gt(c.item_count("silver_carp"), before + clear_catch, "clear days catch fish")
	_restore_weather(gs)


## FISH-006: a rain-only entry is caught only in rain; rain adds a draw; a storm refuses with no time passing.
func test_fishing_rain_entries_extra_draws_and_storm() -> void:
	var c := _start()
	var gs := _game_state()
	var table := [{"item": "silver_carp", "weight": 1, "min": 1, "max": 1, "weather": ["rain"]}]
	gs.data.fishing_weather = {}
	_set_weather(gs, "clear")
	for i in 10:
		gs.fish(table, 1)
	assert_eq(c.item_count("silver_carp"), 0, "a rain-only entry is not caught on a clear day")
	_set_weather(gs, "rain")
	gs.data.fishing_rules = {"rain_extra_draws": 0}
	var base_before := c.item_count("silver_carp")
	gs.fish(table, 1)
	var plain := c.item_count("silver_carp") - base_before
	assert_gt(plain, 0, "rain-only entry is caught in rain")
	gs.data.fishing_rules = {"rain_extra_draws": 1}
	var before := c.item_count("silver_carp")
	gs.fish(table, 1)
	assert_eq(c.item_count("silver_carp") - before, plain * 2, "one extra draw doubles an all-fish table")
	_set_weather(gs, "storm")
	var day := GameClock.total_days
	before = c.item_count("silver_carp")
	gs.fish(table, 1)
	assert_eq(GameClock.total_days, day, "a storm refuses and no time passes")
	assert_eq(c.item_count("silver_carp"), before)
	_restore_weather(gs)


## [REVIEW] FISH-004: a rank reached through the first-catch bonus is announced.
func test_first_catch_bonus_rank_up_is_announced() -> void:
	var c := _start()
	var gs := _game_state()
	_set_weather(gs, "clear")
	var table := [{"item": "silver_carp", "weight": 10, "min": 1, "max": 1}]
	c.catch_log = {}
	c.fishing_xp = Fishing.RANKS[1]["min"] - Fishing.FIRST_CATCH_XP - 1
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	for i in 20:
		gs.fish(table, 1)
		if c.catch_log.has("silver_carp"):
			break
	EventBus.message_posted.disconnect(_collect_post)
	assert_true(c.catch_log.has("silver_carp"), "a carp was caught")
	assert_eq(Fishing.rank_name(c.fishing_xp), Fishing.RANKS[1]["name"])
	assert_true("\n".join(_zero_round_posts).contains("Your fishing has improved"), "\n".join(_zero_round_posts))
	_restore_weather(gs)


func test_cook_meal_spends_fish_and_a_day() -> void:
	var c := _start()
	var gs := _game_state()
	var day := GameClock.total_days
	gs.cook_meal("fish_stew")
	assert_eq(c.item_count("fish_stew"), 0, "no fish, no meal")
	assert_eq(GameClock.total_days, day, "a failed cook takes no time")
	c.add_item("silver_carp", 2)
	gs.cook_meal("fish_stew")
	assert_eq(c.item_count("fish_stew"), 1)
	assert_eq(c.item_count("silver_carp"), 0)
	assert_eq(_root().get_node("GameClock").total_days, day + 1)


func test_snow_adds_a_day_to_travel() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	gs.data.road = {}
	var route: Dictionary = gs.data.regions[gs.data.start_region]["routes"][0]
	var normal: int = Exploration.check_travel(c, gs.data, gs.current_region, String(route["to"]))["days"]
	_set_weather(gs, "snow")
	var start_day := GameClock.total_days
	gs.travel(String(route["to"]))
	assert_eq(GameClock.total_days - start_day, normal + 1)
	_restore_weather(gs)


func test_one_travel_posts_one_arrival_line() -> void:  # GFX-065
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	gs.data.road = {}
	var route: Dictionary = gs.data.regions[gs.data.start_region]["routes"][0]
	gs.travel(String(route["to"]))
	var line := String(gs.world_flags.get("arrival_line", ""))
	if line == "":
		return
	var count := 0
	for m: Dictionary in EventBus.history:
		if String(m["text"]) == line and String(m["category"]) == "travel":
			count += 1
	assert_eq(count, 1, "the arrival line is posted once per travel")


func test_journey_days_matches_days_spent_and_labels() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	gs.data.road = {}
	var route: Dictionary = gs.data.regions[gs.data.start_region]["routes"][0]
	_set_weather(gs, "snow")
	var planned: int = gs.journey_days(route)
	assert_eq(WorldMapScreen.route_days_label(c, gs.data, route, 1), "%dd" % planned, "map label shows the snow day")
	var start_day := GameClock.total_days
	gs.travel(String(route["to"]))
	assert_eq(GameClock.total_days - start_day, planned, "journey_days is what travel spends")
	_set_weather(gs, "clear")
	assert_eq(gs.journey_days(route), Exploration.travel_days(c, gs.data, int(route["days"])))
	_restore_weather(gs)


func test_gather_option_notes_rain() -> void:
	_start()
	var gs := _game_state()
	gs.data.weather_effects = {"rain": {"herb_bonus_chance": 0.5}}
	_set_weather(gs, "rain")
	assert_true(GatherSite.gather_weather_note("Used in: x.").contains("herbs thrive"))
	_set_weather(gs, "clear")
	assert_eq(GatherSite.gather_weather_note("x"), "")
	_restore_weather(gs)


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


func test_rival_first_meeting_plays_once_around_day_ten() -> void:
	var c := _start()
	var gs := _game_state()
	gs.start_pending_event()
	var steps := 0
	while gs.in_dialogue() and steps < 10:
		gs.choose_dialogue(int(gs.dialogue_view()["choices"][-1]["index"]))
		steps += 1
	assert_true(Rivals.rival_of(c, gs.npcs) != null)
	gs._pass_time(5)
	assert_false(gs.world_flags.get(Rivals.FIRST_MEETING_FLAG, false), "too early")
	gs._pass_time(10)
	assert_eq(gs.dialogue_event, Rivals.FIRST_MEETING_EVENT)
	assert_true(gs.world_flags.get(Rivals.FIRST_MEETING_FLAG, false))
	steps = 0
	while gs.in_dialogue() and steps < 10:
		gs.choose_dialogue(int(gs.dialogue_view()["choices"][-1]["index"]))
		steps += 1
	assert_false(gs.in_dialogue())
	gs._pass_time(30)
	assert_false(gs.in_dialogue(), "the meeting never repeats")
	gs.end_session()


## RIVAL-005: a rival's breakthrough is reported once after the meeting.
func test_rival_breakthrough_news_posts_once() -> void:
	var c := _start()
	var gs := _game_state()
	var rival := Rivals.rival_of(c, gs.npcs)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs.world_flags[Rivals.SEEN_REALM_FLAG] = rival.realm_index
	rival.realm_index += 1
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs._rival_news()
	var first := _zero_round_posts.size()
	gs._rival_news()
	EventBus.message_posted.disconnect(_collect_post)
	assert_eq(first, 1)
	assert_eq(_zero_round_posts.size(), 1, "no second line")
	gs.world_flags.erase(Rivals.SEEN_REALM_FLAG)
	rival.realm_index += 1
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs._rival_news()
	EventBus.message_posted.disconnect(_collect_post)
	assert_eq(_zero_round_posts.size(), 0, "a missing key posts nothing")
	assert_eq(int(gs.world_flags[Rivals.SEEN_REALM_FLAG]), rival.realm_index)
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
	assert_eq(GameData.plain_name("Cloud-Sea Cliff (5x qi)"), "Cloud-Sea Cliff")
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
	var stopped: int = clock.total_days
	assert_true(absi(stopped - needed) <= 2, "weather averaged over the span moves the stop day only slightly")
	needed = stopped
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
	gs.world_flags["discovered_" + gs.current_region] = true
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


## WU-501: the explored place's look is kept while a choice encounter is pending, then cleared.
func test_explore_look_kept_for_pending_choice() -> void:
	_start()
	var gs := _game_state()
	gs.data.encounters["t_look"] = {"id": "t_look", "tags": ["t_look"], "weight": 1, "text": "A fork.", "effects": {}, "days": 1,
		"choices": [{"text": "Go on", "effects": {}}]}
	gs.last_explore_look = "cave"
	gs._meet_encounter(gs.data.encounters["t_look"])
	assert_eq(gs.pending_encounter, "t_look")
	assert_eq(gs.last_explore_look, "cave")
	gs.choose_encounter(0)
	assert_eq(gs.last_explore_look, "")
	gs.world_flags["found_hermit_garden"] = true
	gs.explore(["t_no_such_tag"], "woods")
	if gs.pending_encounter == "":
		assert_eq(gs.last_explore_look, "", "cleared when nothing is pending")
	gs.data.encounters.erase("t_look")
	gs.end_session()


## REVIEW: a stale look never carries into a loaded game or a new session.
func test_explore_look_reset_on_load_and_new_session() -> void:
	_start()
	var gs := _game_state()
	gs.last_explore_look = "cave"
	gs.load_save_dict(JSON.parse_string(JSON.stringify(gs.to_save_dict())))
	assert_eq(gs.last_explore_look, "", "load clears it")
	gs.last_explore_look = "cave"
	gs.end_session()
	assert_eq(gs.last_explore_look, "", "end_session clears it")


## FH-025: an encounter on day one stops the exploring there.
func test_explore_many_stops_when_something_happens() -> void:
	_start()
	var gs := _game_state()
	gs.data.encounters["t_ex_find"] = {"id": "t_ex_find", "tags": ["t_ex"], "weight": 1, "text": "You find a stone.", "effects": {}, "days": 1}
	var start_day: int = _root().get_node("GameClock").total_days
	var days: int = gs.explore_many(7, ["t_ex"])
	assert_eq(days, 1)
	assert_eq(_root().get_node("GameClock").total_days, start_day + 1)
	gs.world_flags["found_hermit_garden"] = true  # C-048: Qingshi's deeper path would stop the run
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


## PROF-013: an order that lapses posts what you were short of and bumps commissions_lapsed.
func test_commission_lapse_names_shortfall_and_counts() -> void:
	var c := _start()
	var gs := _game_state()
	c.commissions = [{"profession": "alchemist", "recipe": "qi_gathering_pill", "item": "qi_gathering_pill", "count": 2, "reward": 10, "xp": 5.0, "due_day": GameClock.total_days + 1}]
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.cultivate(3)
	EventBus.message_posted.disconnect(_collect_post)
	assert_true("\n".join(_zero_round_posts).contains("lapsed. You were short of "), "\n".join(_zero_round_posts))
	assert_eq(LifeStats.get_stat(c, "commissions_lapsed"), 1)
	gs.end_session()


## GUIDE-059: delivering a 2-unit order posts the plural item name.
func test_commission_delivery_message_is_plural() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	gs.cultivate(Calendar.DAYS_PER_MONTH + 1)
	var order: Dictionary = c.commissions[0]
	order["count"] = 2
	c.add_item(order["item"], 2)
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.deliver_commission(0)
	EventBus.message_posted.disconnect(_collect_post)
	var expect := "You deliver 2 %s:" % Items.item_plural(gs.data, String(order["item"]), 2)
	assert_true("\n".join(_zero_round_posts).contains(expect), expect)
	assert_true(Items.item_plural(gs.data, String(order["item"]), 2) != String(gs.data.items[order["item"]]["name"]))
	gs.end_session()


func test_commission_delivery_earns_renown_and_failure_does_not() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.realm_index = 1
	gs.cultivate(Calendar.DAYS_PER_MONTH + 1)
	var before := Renown.value(c, gs.current_region)
	gs.deliver_commission(0)
	assert_eq(Renown.value(c, gs.current_region), before, "a failed delivery adds nothing")
	var order: Dictionary = c.commissions[0]
	c.add_item(order["item"], int(order["count"]))
	gs.deliver_commission(0)
	assert_eq(Renown.value(c, gs.current_region), before + int(gs.data.renown["sources"]["commission"]))
	gs.end_session()


func test_patients_session_earns_renown() -> void:
	var c := _start()
	var gs := _game_state()
	var before := Renown.value(c, gs.current_region)
	gs.treat_patients(Calendar.DAYS_PER_MONTH)
	assert_eq(Renown.value(c, gs.current_region), before + int(gs.data.renown["sources"]["patients"]))
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


func test_year_review_names_the_rival_last() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	var seen: Array = []
	var cb := func(_year: int, lines: PackedStringArray, _start: int) -> void: seen.append(lines)
	bus.year_reviewed.connect(cb)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	clock.advance(Calendar.DAYS_PER_YEAR)
	bus.year_reviewed.disconnect(cb)
	var lines: PackedStringArray = seen[0]
	assert_eq(lines[lines.size() - 1], Rivals.year_line(c, rival, gs.world_flags))
	assert_true(lines[lines.size() - 1].begins_with(rival.name + " is "))


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
	var expected := 3 * Items.sell_price(gs.data, "spirit_herb", gs.price_season()) + 2 * Items.sell_price(gs.data, "iron_essence", gs.price_season())
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


func test_monthly_letter_and_visit_bonus() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := CharacterFactory.create("Pen Friend", gs.data, seeded_rng(9))
	npc.id = "pen_friend"
	gs.npcs["pen_friend"] = npc
	gs.npc_favor["pen_friend"] = 26
	var rules: Dictionary = gs.data.family["letters"]
	var saved: Dictionary = rules.duplicate(true)
	rules["monthly_chance"] = 1.0
	rules["kinds"] = [saved["kinds"][2]]
	c.realm_index = 1
	var seen: Array[String] = []
	var on_letter := func(n: String) -> void: seen.append(n)
	EventBus.letter_arrived.connect(on_letter)
	gs.cultivate(Calendar.DAYS_PER_MONTH)
	EventBus.letter_arrived.disconnect(on_letter)
	assert_gt(c.letters.size(), 0, "a letter arrived")
	assert_eq(seen, ["Pen Friend"], "the banner signal fired")
	assert_true(gs.world_flags.has("letter_visit_pen_friend"))
	rules["monthly_chance"] = 0.0
	var before: int = gs.npc_favor["pen_friend"]
	gs.chat("pen_friend")
	assert_gt(int(gs.npc_favor["pen_friend"]) - before, int(saved["visit_favor"]) - 1, "the invitation pays off")
	assert_false(gs.world_flags.has("letter_visit_pen_friend"))
	gs.data.family["letters"] = saved
	gs.end_session()


func test_answer_letter_request() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := CharacterFactory.create("Pen Friend", gs.data, seeded_rng(9))
	npc.id = "pen_friend"
	gs.npcs["pen_friend"] = npc
	gs.npc_favor["pen_friend"] = 30
	npc.home_region = gs.current_region
	c.letter_requests.append({"npc_id": "pen_friend", "item": "qi_gathering_pill", "count": 1, "until": GameClock.total_days + 30, "favor": 10, "effects": {}})
	var rows := Guidance.journal(c, gs.data, {}, GameClock.total_days, c.home_region, 1.0, gs.npcs)
	assert_true(str(rows).contains("asked for 1 Qi Gathering Pill"), "the journal lists the request")
	assert_true(gs.check_letter_request("pen_friend") != "")
	c.add_item("qi_gathering_pill", 1)
	gs.answer_letter_request("pen_friend")
	assert_eq(int(gs.npc_favor["pen_friend"]), 40)
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	rows = Guidance.journal(c, gs.data, {}, GameClock.total_days, c.home_region, 1.0, gs.npcs)
	assert_false(str(rows).contains("asked for 1 Qi Gathering Pill"))
	gs.end_session()


func test_answer_folk_request() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := CharacterFactory.create("Wu Lan", gs.data, seeded_rng(9))
	npc.id = "wu_lan"
	gs.npcs["wu_lan"] = npc
	gs.npc_favor["wu_lan"] = 10
	npc.home_region = gs.current_region
	c.letter_requests.append({"npc_id": "wu_lan", "item": "spirit_herb", "count": 3, "until": GameClock.total_days + 20, "favor": 5, "effects": {"items": {"spirit_stone": 5}}, "source": "folk"})
	var stones := c.item_count("spirit_stone")
	gs.answer_letter_request("wu_lan")
	assert_eq(c.item_count("spirit_stone"), stones, "without the items nothing changes")
	assert_eq(c.letter_requests.size(), 1)
	c.add_item("spirit_herb", 3)
	gs.answer_letter_request("wu_lan")
	assert_eq(c.item_count("spirit_herb"), 0)
	assert_eq(c.item_count("spirit_stone"), stones + 5)
	assert_eq(int(gs.npc_favor["wu_lan"]), 15)
	assert_eq(c.letter_requests.size(), 0)
	gs.end_session()


func test_answer_letter_request_needs_the_asker_present() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := CharacterFactory.create("Far Friend", gs.data, seeded_rng(9))
	npc.id = "far_friend"
	var other := "qingshi_village" if gs.current_region != "qingshi_village" else "misty_forest"
	npc.home_region = other
	gs.npcs["far_friend"] = npc
	gs.npc_favor["far_friend"] = 30
	c.letter_requests.append({"npc_id": "far_friend", "item": "qi_gathering_pill", "count": 1, "until": GameClock.total_days + 30, "favor": 10, "effects": {}})
	c.add_item("qi_gathering_pill", 1)
	var reason: String = gs.check_letter_request("far_friend")
	assert_true(reason.contains("in person"), reason)
	assert_true(reason.contains(String(gs.data.regions[other]["name"])))
	gs.answer_letter_request("far_friend")
	assert_eq(c.item_count("qi_gathering_pill"), 1, "nothing is handed over from afar")
	npc.home_region = gs.current_region
	assert_eq(gs.check_letter_request("far_friend"), "")
	gs.end_session()


func test_expired_request_line_is_family_topic() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := CharacterFactory.create("Late Friend", gs.data, seeded_rng(9))
	npc.id = "late_friend"
	gs.npcs["late_friend"] = npc
	c.letter_requests.append({"npc_id": "late_friend", "item": "qi_gathering_pill", "count": 1, "until": GameClock.total_days + 1, "favor": 10, "effects": {}})
	GameClock.advance(60)
	var found := false
	for entry in EventBus.history:
		if String(entry["text"]).contains("no longer waits"):
			found = true
			assert_eq(entry["topic"], "family")
	assert_true(found, "the expiry is posted")
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


## RIVAL-016: bouts with the rival are scored; other spars are not.
func test_spar_rival_keeps_score() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 5
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var rival := CharacterFactory.create("Old Rival", gs.data, seeded_rng(9))
	rival.id = "old_rival"
	rival.age_days = 30 * Calendar.DAYS_PER_YEAR
	rival.realm_index = 4
	gs.npcs["old_rival"] = rival
	var other := CharacterFactory.create("Bystander", gs.data, seeded_rng(10))
	other.id = "bystander"
	other.age_days = 30 * Calendar.DAYS_PER_YEAR
	other.realm_index = 4
	gs.npcs["bystander"] = other
	gs.npc_favor["bystander"] = 15
	c.rival = "old_rival"
	var clock := _root().get_node("GameClock")
	clock.advance(60)
	gs.spar_with("old_rival")
	var won := LifeStats.get_stat(c, "rival_bouts_won")
	var lost := LifeStats.get_stat(c, "rival_bouts_lost")
	assert_eq(won + lost, 1, "one bout scored")
	assert_eq(int(gs.world_flags.get(Rivals.BOUTS_WON_FLAG, 0)) + int(gs.world_flags.get(Rivals.BOUTS_LOST_FLAG, 0)), 1, "this rival's record too")
	var firsts := 0
	for entry in EventBus.history:
		if String(entry["text"]).contains("for the first time"):
			firsts += 1
	assert_eq(firsts, won, "the first win is announced once")
	clock.advance(60)
	var total := won + lost
	gs.spar_with("bystander")
	assert_eq(LifeStats.get_stat(c, "rival_bouts_won") + LifeStats.get_stat(c, "rival_bouts_lost"), total, "other spars do not count")
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


## GUIDE-209: arriving posts the day's arrival line and stores it for the HUD.
func test_travel_posts_arrival_line() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var target := String(gs.data.regions[gs.data.start_region]["routes"][0]["to"])
	gs.travel(target)
	assert_eq(int(gs.world_flags.get("arrival_day", -1)), GameClock.total_days)
	assert_eq(String(gs.world_flags.get("arrival_region", "")), target)
	var line := String(gs.world_flags.get("arrival_line", "x"))
	if line != "":
		assert_true(line.begins_with("Today in "), line)


## TRAV-006: with the road chance forced to 1, a journey meets a road encounter.
func test_travel_meets_route_encounter_of_its_road() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var old_road: Dictionary = gs.data.road
	var old_encounters: Dictionary = gs.data.encounters
	gs.data.road = {"chance_per_day": 1.0, "max_chance": 1.0, "encounter_tags": ["road"]}
	var only := {}
	for id: String in gs.data.encounters:
		if gs.data.encounters[id].has("road_regions") and (gs.data.encounters[id]["road_regions"] as Array).has("misty_forest") and not gs.data.encounters[id].has("weather"):
			only[id] = gs.data.encounters[id]
	assert_false(only.is_empty())
	gs.data.encounters = only
	gs.travel("misty_forest")
	gs.data.road = old_road
	gs.data.encounters = old_encounters
	assert_true(only.has(gs.last_travel_road_encounter), gs.last_travel_road_encounter)


func test_travel_meets_road_encounter() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var old_road: Dictionary = gs.data.road
	var old_encounters: Dictionary = gs.data.encounters
	gs.data.road = {"chance_per_day": 1.0, "max_chance": 1.0, "encounter_tags": ["road"]}
	gs.data.encounters = {"road_overturned_cart": old_encounters["road_overturned_cart"]}
	gs.last_explore_discovery = true  # left over from an earlier exploration
	gs.last_explore_deep_path = true
	var target := String(gs.data.regions[gs.data.start_region]["routes"][0]["to"])
	var before := LifeStats.get_stat(c, "encounters")
	var heard: Array[String] = []
	var cb := func(text: String, _cat: String) -> void: heard.append(text)
	EventBus.message_posted.connect(cb)
	gs.travel(target)
	EventBus.message_posted.disconnect(cb)
	assert_eq(gs.current_region, target)
	assert_eq(LifeStats.get_stat(c, "encounters"), before + 1)
	assert_true(heard.any(func(t: String) -> bool: return t.begins_with("On the road: ")), str(heard))
	assert_eq(gs.pending_encounter, "road_overturned_cart")
	assert_eq(gs.last_travel_road_encounter, "road_overturned_cart")  # WU-080: the arrival card waits for it
	assert_false(gs.last_explore_discovery, "a road encounter is not a discovery")
	assert_false(gs.last_explore_deep_path)
	var good := c.alignment
	gs.choose_encounter(0)
	assert_true(c.alignment > good)
	assert_eq(gs.pending_encounter, "")
	gs.data.road = old_road
	gs.data.encounters = old_encounters


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
	gs.travel("misty_forest")  # the road can meet an encounter too, so count from here
	var before := _encounter_total(c)
	gs.explore()
	var met := _encounter_total(c) - before
	assert_true(met >= 0 and met <= 1, "one explore day meets at most one encounter, got %d" % met)
	gs.end_session()


func _encounter_total(c: CharacterData) -> int:
	var total := 0
	for n in c.encounter_counts.values():
		total += int(n)
	return total


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
	gs.world_flags["discovered_" + gs.current_region] = true
	gs.explore_many(5, ["t_no_such_tag"])
	assert_eq(Exploration.familiarity(gs.player, gs.current_region), 5)
	gs.end_session()


## TRAV-007: the arrival message names the flying sword and the trip is shorter.
func test_travel_by_flying_sword() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	gs.data.road = {}
	var route: Dictionary = gs.data.regions[gs.data.start_region]["routes"][0]
	var start_day := GameClock.total_days
	var heard: Array[String] = []
	var cb := func(text: String, _cat: String) -> void: heard.append(text)
	EventBus.message_posted.connect(cb)
	gs.travel(String(route["to"]))
	EventBus.message_posted.disconnect(cb)
	assert_eq(gs.current_region, String(route["to"]))
	assert_eq(GameClock.total_days - start_day, maxi(1, ceili(int(route["days"]) * 0.67)))
	assert_true(heard.any(func(t: String) -> bool: return t.contains("on your flying sword you arrive")), str(heard))


## EXPL-003: the first time a region is mastered it is announced once and counted once.
func test_region_mastery_announced_once() -> void:
	var gs := _game_state()
	var c := _start()
	var region: String = gs.current_region
	for e: Dictionary in gs.data.encounters.values():
		Exploration.note_met(c, e)
		if String(e.get("blocked_by_flag", "")) != "":
			gs.world_flags[e["blocked_by_flag"]] = true
	gs.world_flags["discovered_" + region] = true
	c.explore_days[region] = 100000
	assert_true(gs.explore_outlook().contains("You know every path here."))
	var heard: Array[String] = []
	var cb := func(text: String, _cat: String) -> void: heard.append(text)
	EventBus.message_posted.connect(cb)
	gs._check_mastery()
	gs._check_mastery()
	EventBus.message_posted.disconnect(cb)
	assert_eq(heard.filter(func(t: String) -> bool: return t.contains("lines of your own palm")).size(), 1)
	assert_eq(LifeStats.get_stat(c, "regions_mastered"), 1)
	assert_true(gs.world_flags["mastered_" + region])
	LifeStats.backfill(c, gs.data, {"mastered_a": true, "mastered_b": true, "mastered_c": true})
	assert_eq(LifeStats.get_stat(c, "regions_mastered"), 3)


## FEST-003: festival activity as a player action.
func test_festival_activity_action() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}]
	assert_eq(gs.festival_activity_here(), "lantern_festival")
	assert_eq(gs.festival_activity_here(["equipment", "ore", "smithing"]), "", "smithies host no stall")
	assert_eq(gs.festival_activity_here(["herb", "ore"]), "lantern_festival")
	var qi: int = gs.player.qi
	var joined: int = LifeStats.get_stat(gs.player, "festival_activities")
	gs.festival_activity("lantern_festival")
	assert_true(gs.player.qi > qi)
	assert_eq(LifeStats.get_stat(gs.player, "festival_activities"), joined + 1)
	var qi2: int = gs.player.qi
	gs.festival_activity("lantern_festival")
	assert_eq(gs.player.qi, qi2, "a second try is refused")
	assert_true(gs.check_festival_activity("lantern_festival") != "")
	gs.end_session()


func test_friends_price_lowers_buy_multiplier() -> void:
	var gs := _game_state()
	_start()
	var base: float = gs.buy_multiplier()
	gs.player.shop_deals[gs.current_region] = {"mult": 0.9, "until": GameClock.total_days + 10}
	assert_true(is_equal_approx(gs.buy_multiplier(), base * 0.9))
	gs.player.shop_deals[gs.current_region]["until"] = GameClock.total_days - 1
	assert_true(is_equal_approx(gs.buy_multiplier(), base))


func test_region_qi_density_rises_with_deed_flag() -> void:
	_start()
	var gs := _game_state()
	gs.current_region = "azure_peak"
	var before: float = gs.region_qi_density()
	gs.world_flags["planted_guardian_seed"] = true
	assert_true(gs.region_qi_density() > before)
	gs.world_flags.erase("planted_guardian_seed")


func test_planting_the_guardian_seed_enriches_azure_peak() -> void:
	for choice_index in [0, 1]:
		_start()
		var gs := _game_state()
		gs.current_region = "azure_peak"
		var before: float = gs.region_qi_density()
		gs.pending_encounter = "misty_forest_valley_guardian"
		gs.choose_encounter(choice_index)
		assert_true(gs.world_flags.get("met_valley_guardian", false), "met either way")
		if choice_index == 0:
			assert_true(absf(gs.region_qi_density() - before * 1.1) < 0.0001, "planting raises Azure Peak qi by 10%")
		else:
			assert_eq(gs.region_qi_density(), before, "swallowing leaves it alone")


func test_breakthrough_reports_lifespan_and_qi_gain() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	Cultivation.add_qi(c, gs.data, 1e12)
	c.breakthrough_bonus = 5.0
	var before := Cultivation.lifespan_years(c, gs.data)
	var rate_before := Cultivation.qi_per_day(c, gs.data)
	var details: Array[String] = []
	var on_details := func(t: String) -> void: details.append(t)
	EventBus.breakthrough_details.connect(on_details)
	EventBus.clear_history()
	gs.attempt_breakthrough()
	EventBus.breakthrough_details.disconnect(on_details)
	assert_eq(c.realm_index, 2)
	var gain := Cultivation.lifespan_years(c, gs.data) - before
	assert_gt(gain, 0)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return e["text"] == "Your lifespan grows to %d years (+%d)." % [before + gain, gain]))
	assert_eq(details, ["Lifespan +%d years" % gain])
	var ratio := Cultivation.qi_per_day(c, gs.data) / rate_before
	assert_eq(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).begins_with("Your qi gathers")), ratio >= 1.5)
	gs.end_session()


func test_failed_breakthrough_posts_no_growth_lines() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	Cultivation.add_qi(c, gs.data, 1e12)
	c.breakthrough_bonus = -5.0
	EventBus.clear_history()
	gs.attempt_breakthrough()
	assert_eq(c.realm_index, 1)
	assert_false(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).begins_with("Your lifespan grows") or String(e["text"]).begins_with("Your qi gathers")))
	gs.end_session()


func _break_through_once(gs: Node, c: CharacterData) -> void:
	var realm := c.realm_index
	for i in 30:
		if c.realm_index > realm:
			return
		c.stage = gs.data.realms[c.realm_index].stage_names.size() - 1
		c.qi = 1.0e9
		gs.attempt_breakthrough()


func test_surpassing_the_rival_posts_once() -> void:
	var c := _start()
	var gs := _game_state()
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	c.realm_index = 1
	rival.realm_index = 1
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	# CAL-011: dawn almanac lines can push old lines out of the 200-line history, so count posts as they happen.
	var seen: Array[int] = [0]
	var counter := func(text: String, _cat: String) -> void:
		if text.begins_with("You have surpassed "):
			seen[0] += 1
	EventBus.message_posted.connect(counter)
	_break_through_once(gs, c)
	assert_true(c.realm_index > 1)
	assert_true(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	assert_eq(gs.last_surpassed_rival, rival.name, "the realm card can name the rival")
	assert_eq(seen[0], 1)
	_break_through_once(gs, c)
	assert_eq(seen[0], 1)
	gs.last_surpassed_rival = rival.name  # as if the monthly check had surpassed them
	_break_through_once(gs, c)
	assert_eq(gs.last_surpassed_rival, "", "a later breakthrough's realm card does not name a rival it did not pass")
	EventBus.message_posted.disconnect(counter)
	gs.end_session()


func test_catching_up_with_the_rival_posts_once() -> void:
	var c := _start()
	var gs := _game_state()
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	c.realm_index = 1
	rival.realm_index = 2
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	_break_through_once(gs, c)
	assert_eq(c.realm_index, 2)
	var lines := EventBus.history.filter(func(m): return String(m["text"]).begins_with("You have caught up with "))
	assert_eq(lines.size(), 1)
	assert_eq(int(gs.world_flags.get("rival_caught_up_realm", -1)), 2)
	gs._check_rival_caught_up(1)
	lines = EventBus.history.filter(func(m): return String(m["text"]).begins_with("You have caught up with "))
	assert_eq(lines.size(), 1, "once per realm")
	gs.end_session()


func test_surpassing_needs_the_first_meeting() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	Rivals.rival_of(c, gs.npcs).realm_index = 1
	gs.world_flags[Rivals.MEETING_FROM_FLAG] = 1000000  # the meeting must not play while breakthroughs pass days
	_break_through_once(gs, c)
	assert_false(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	gs.end_session()


## QA-078: the rival is still a mortal at the first meeting; the player's own awakening to Qi
## Refining is not "surpassing" them (the sim showed the flag set on day 15 in 9 of 10 seeds).
func test_leaving_mortality_does_not_surpass_a_mortal_rival() -> void:
	var c := _start()
	var gs := _game_state()
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	rival.realm_index = 0
	c.realm_index = 1
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	gs._rival_news()
	assert_false(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	assert_eq(_surpass_lines().size(), 0)
	gs.end_session()


func _death_news_lines() -> Array:
	return EventBus.history.filter(func(m): return String(m["text"]).begins_with("Word reaches you: your rival") and String(m["text"]).contains("old age"))


## RIVAL-011: a rival lost to old age is reported once, after the first meeting.
func test_rival_death_news_posts_once_after_meeting() -> void:
	var c := _start()
	var gs := _game_state()
	var rival: CharacterData = gs.npcs[c.rival]
	Npcs.die(rival, "old age")
	EventBus.clear_history()
	gs._rival_news()
	assert_eq(_death_news_lines().size(), 0, "nothing before the first meeting")
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs._rival_news()
	gs._rival_news()
	assert_eq(_death_news_lines().size(), 1, "posted once")
	gs.end_session()


func test_player_kill_of_rival_posts_no_death_news() -> void:
	var c := _start()
	var gs := _game_state()
	Npcs.die(gs.npcs[c.rival], "slain by " + c.name)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	gs._rival_news()
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).begins_with("Word reaches you")).size(), 0)
	assert_true(gs.world_flags.get("rival_death_news", false))
	gs.end_session()


## RIVAL-014: a rival lost not by your hand is replaced after a delay.
func test_successor_rival_appears_after_old_rival_dies() -> void:
	var c := _start()
	var gs := _game_state()
	var old_id := c.rival
	Npcs.die(gs.npcs[old_id], "old age")
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs.world_flags[Rivals.BOUTS_WON_FLAG] = 3
	var today := GameClock.total_days
	gs._rival_news()
	assert_eq(int(gs.world_flags[Rivals.SUCCESSOR_DAY_FLAG]), today + 180)
	var restored: Dictionary = gs.to_save_dict()
	assert_eq(int(restored["world_flags"][Rivals.SUCCESSOR_DAY_FLAG]), today + 180)
	EventBus.clear_history()
	GameClock.total_days = today + 180
	gs._rival_news()
	gs._rival_news()
	assert_true(c.rival != old_id)
	assert_true(gs.npcs[c.rival].alive)
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).begins_with("Word spreads of")).size(), 1)
	assert_true(Rivals.first_meeting_due(c, gs.npcs, gs.data, gs.world_flags, GameClock.total_days))
	assert_false(gs.world_flags.has(Rivals.SUCCESSOR_DAY_FLAG))
	assert_eq(Rivals.bout_record_text(gs.world_flags), "", "the successor starts with no bout record")
	gs.end_session()


func test_no_successor_after_player_kill_or_when_disabled() -> void:
	var c := _start()
	var gs := _game_state()
	Npcs.die(gs.npcs[c.rival], "slain by " + c.name)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs._rival_news()
	assert_false(gs.world_flags.has(Rivals.SUCCESSOR_DAY_FLAG))
	gs.end_session()
	var c2 := _start()
	var gs2 := _game_state()
	gs2.data.karma["rival"]["successor_delay_days"] = 0
	Npcs.die(gs2.npcs[c2.rival], "old age")
	gs2.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs2._rival_news()
	assert_false(gs2.world_flags.has(Rivals.SUCCESSOR_DAY_FLAG))
	gs2.end_session()


func _surpass_lines() -> Array:
	return EventBus.history.filter(func(m): return String(m["text"]).begins_with("You have surpassed "))


func test_rival_already_behind_is_surpassed_at_month_end() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 2
	Rivals.rival_of(c, gs.npcs).realm_index = 1
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	gs._rival_news()
	assert_true(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	assert_eq(_surpass_lines().size(), 1)
	gs._rival_news()
	assert_eq(_surpass_lines().size(), 1)
	gs.end_session()


func test_surpassed_rival_is_spurred_and_overtakes_again() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 2
	var rival := Rivals.rival_of(c, gs.npcs)
	rival.realm_index = 1
	rival.diligence = 0.5
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	gs._rival_news()
	assert_almost_eq(rival.diligence, 0.6, 0.001)
	assert_eq(_surpass_lines().size(), 1)
	rival.realm_index = 3
	gs._rival_news()
	assert_false(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	var again := EventBus.history.filter(func(m): return String(m["text"]).ends_with("has overtaken you again."))
	assert_eq(again.size(), 1)
	gs._rival_news()
	again = EventBus.history.filter(func(m): return String(m["text"]).ends_with("has overtaken you again."))
	assert_eq(again.size(), 1, "posts once")
	rival.realm_index = 1
	gs._rival_news()
	assert_eq(_surpass_lines().size(), 2, "can be surpassed again")
	gs.end_session()


func test_equal_rival_is_not_surpassed_at_month_end() -> void:
	var c := _start()
	var gs := _game_state()
	Rivals.rival_of(c, gs.npcs).realm_index = c.realm_index
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	EventBus.clear_history()
	gs._rival_news()
	assert_false(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	assert_eq(_surpass_lines().size(), 0)
	gs.end_session()


func test_unmet_rival_is_not_surpassed_at_month_end() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 2
	Rivals.rival_of(c, gs.npcs).realm_index = 1
	gs._rival_news()
	assert_false(gs.world_flags.get(Rivals.SURPASSED_FLAG, false))
	gs.end_session()


func _beat_realm_setup() -> Array:
	var c := _start()
	var gs := _game_state()
	c.realm_index = gs.data.realm_index_of("core_formation")
	c.stage = 0
	gs.data.enemies["t_found_foe"] = {"id": "t_found_foe", "name": "Test Foe", "realm": "foundation_establishment", "stage": 0, "hp": -50, "attack": -50, "defense": -50, "speed": -50, "lethal": false, "techniques": [], "rewards": {}}
	return [c, gs]


func test_beating_a_foundation_foe_sets_the_goal_flag() -> void:
	var gs: Node = _beat_realm_setup()[1]
	var flag := Guidance.beat_realm_flag("foundation_establishment")
	assert_false(gs.world_flags.has(flag))
	gs.fight("t_found_foe")
	assert_true(gs.world_flags.get(flag, false))
	gs.end_session()


func test_spar_and_lost_fight_do_not_set_the_beat_flag() -> void:
	var setup := _beat_realm_setup()
	var c: CharacterData = setup[0]
	var gs: Node = setup[1]
	var flag := Guidance.beat_realm_flag("foundation_establishment")
	var spar: Dictionary = gs.data.enemies["t_found_foe"].duplicate()
	spar["spar"] = true
	gs.data.enemies["t_spar_foe"] = spar
	gs.fight("t_spar_foe")
	assert_false(gs.world_flags.has(flag))
	c.realm_index = 0
	c.stage = 0
	var strong: Dictionary = gs.data.enemies["t_found_foe"].duplicate()
	strong.merge({"hp": 5000, "attack": 5000, "defense": 5000, "speed": 5000, "lethal": false}, true)
	gs.data.enemies["t_strong_foe"] = strong
	gs.fight("t_strong_foe")
	assert_false(gs.world_flags.has(flag))
	gs.end_session()


## RIVAL-013: a rival's attitude moving is announced; a change that keeps it is silent.
func test_rival_attitude_change_is_announced() -> void:
	var c := _start()
	var gs := _game_state()
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	gs.world_flags[Rivals.FIRST_MEETING_FLAG] = true
	gs.npc_favor[rival.id] = 0
	EventBus.clear_history()
	gs._rival_consequences({"rival_favor": 5})
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).contains("warms to you")).size(), 0)
	gs._rival_consequences({"rival_favor": 30})
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).contains("%s warms to you" % rival.name)).size(), 1)
	gs._rival_consequences({"rival_grudge": 50})
	assert_eq(EventBus.history.filter(func(m): return String(m["text"]).contains("%s now holds a grudge" % rival.name)).size(), 1)
	gs.end_session()


func test_first_craft_brings_the_first_order() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions.erase("alchemist")
	c.add_item("spirit_herb", 4)
	c.add_item("dew_grass", 2)
	gs.refine("qi_gathering_pill")
	assert_true(c.professions.has("alchemist"), "the craft starts the profession")
	assert_eq(c.commissions.size(), 1, "first craft: first order the same day")
	assert_eq(String(c.commissions[0]["profession"]), "alchemist")
	gs.refine("qi_gathering_pill")
	assert_eq(c.commissions.size(), 1, "second craft adds none")
	gs.end_session()


## Review of PROF-007: the early order is for the new craft only, not an extra roll for the others.
func test_first_craft_order_is_only_for_the_new_craft() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions.erase("alchemist")
	c.professions["blacksmith"] = {"rank": 0, "xp": 0.0}
	c.commissions.clear()
	c.add_item("spirit_herb", 4)
	c.add_item("dew_grass", 2)
	gs.refine("qi_gathering_pill")
	assert_eq(c.commissions.size(), 1)
	assert_eq(String(c.commissions[0]["profession"]), "alchemist")
	gs.end_session()


## PROF-008: reaching a rank also says what it opens.
func test_rank_up_while_crafting_posts_what_it_opens() -> void:
	var c := _start()
	var gs := _game_state()
	var def: ProfessionDef = gs.data.professions["alchemist"]
	c.professions["alchemist"] = {"rank": 0, "xp": def.xp_to_next(0) - 0.01}
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	EventBus.history.clear()
	gs.refine("qi_gathering_pill")
	assert_eq(Professions.rank_of(c, "alchemist"), 1)
	var texts: Array = EventBus.history.map(func(m): return String(m["text"]))
	var i := -1
	for k in texts.size():
		if String(texts[k]).begins_with("You are now "):
			i = k
	assert_gt(i, -1, "rank-up line posted")
	assert_true(String(texts[i + 1]).begins_with("You can now refine "), String(texts[i + 1]))
	gs.end_session()


func test_practised_crafter_gets_no_order_from_refining() -> void:
	var c := _start()
	var gs := _game_state()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	gs.refine("qi_gathering_pill")
	assert_eq(c.commissions.size(), 0)
	gs.end_session()


func test_meditating_resets_idle_cultivation_day() -> void:
	var c := _start()
	c.realm_index = 1
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	assert_eq(c.last_meditated_day, -1)
	var clock := _root().get_node("GameClock")
	_game_state().cultivate(40)
	assert_true(int(clock.total_days) > Guidance.IDLE_CULTIVATION_DAYS)
	assert_eq(c.last_meditated_day, int(clock.total_days), "stamped with the day the meditation ended")
	assert_eq(Guidance.idle_crafter_hint(c, _game_state().data, "qingshi_village", int(clock.total_days)), "", "not idle right after a long meditation")
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.last_meditated_day, c.last_meditated_day)
	var d := c.to_dict()
	d.erase("last_meditated_day")
	assert_eq(CharacterData.from_dict(d).last_meditated_day, -1)


## GUIDE-069: equipping the armor clears the armor hint.
func test_equipping_armor_clears_the_armor_hint() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = Guidance.ARMOR_HINT_MIN_STAGE
	c.techniques = {"blood_shadow_flight": {"level": 1}}
	c.equipment = {}
	c.inventory = {"spirit_stone": 500}
	var armor_id := Guidance.affordable_armor(c, gs.data, "myriad_peaks_ridge")
	assert_true(armor_id != "", "some armor is affordable")
	assert_true(Guidance.armor_hint(c, gs.data, "myriad_peaks_ridge") != "")
	c.add_item(armor_id, 1)
	gs.equip_item(armor_id)
	assert_eq(Guidance.armor_hint(c, gs.data, "myriad_peaks_ridge"), "")


## GUIDE-080: learning a body art and equipping armor completes the Foundation defence goal.
func test_foundation_defence_goal_flips_on_armor() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 2
	c.stage = 1
	c.equipment = {}
	c.techniques = {"stone_skin": {"level": 1, "xp": 0.0}}
	assert_false(Guidance.foundation_goals(c, gs.data, {})[1]["done"])
	var armor_id := Guidance.affordable_armor(c, gs.data, "fallen_star_market")
	c.inventory = {"spirit_stone": 500}
	armor_id = Guidance.affordable_armor(c, gs.data, "fallen_star_market")
	assert_true(armor_id != "")
	c.add_item(armor_id, 1)
	gs.equip_item(armor_id)
	assert_true(Guidance.foundation_goals(c, gs.data, {})[1]["done"])


func test_failed_breakthrough_injury_posts_what_it_costs() -> void:
	var c := _start()
	var gs := _game_state()
	var found := false
	for i in 40:
		if not _fail_breakthrough(gs, c):
			continue
		if not c.injuries.is_empty():
			found = true
			break
		c.injuries.clear()
	assert_true(found)
	var injury_id: String = c.injuries.keys()[0]
	var name := Injuries.injury_name(gs.data, injury_id)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool:
		return String(e["text"]).begins_with(name + ": ") and String(e["text"]).contains(" for about ")))
	gs.end_session()


func test_face_heart_vision_refuses_hidden_choice() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	c.alignment = 0
	Cultivation.add_qi(c, gs.data, 1e12)
	gs.face_heart_vision(3)
	assert_false(gs.heart_vision().is_empty(), "the hidden demonic choice is not a choice")
	assert_eq(c.alignment, 0)
	gs.end_session()


func test_face_heart_vision_posts_and_shifts_odds() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	Cultivation.add_qi(c, gs.data, 1e12)
	assert_false(gs.heart_vision().is_empty())
	var before := Cultivation.breakthrough_chance(c, gs.data)
	EventBus.clear_history()
	gs.face_heart_vision(2)
	assert_eq(EventBus.history.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("no change to your odds")).size(), 1)
	assert_almost_eq(Cultivation.breakthrough_chance(c, gs.data), before)
	assert_true(gs.heart_vision().is_empty())
	gs.end_session()


func test_greeting_for_hands_over_a_gift_once_per_cooldown() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.npc_favor[npc.id] = 39
	var before := c.inventory.duplicate()
	gs.receive_greeting_gift(npc.id)
	assert_eq(c.inventory, before)
	gs.npc_favor[npc.id] = 50
	gs.greeting_for(npc.id)
	gs.greeting_for(npc.id)
	assert_eq(c.inventory, before, "greeting_for is a pure getter")
	gs.receive_greeting_gift(npc.id)
	assert_true(c.inventory != before)
	assert_true(c.folk_gift_day.has(npc.id))
	var after := c.inventory.duplicate()
	gs.receive_greeting_gift(npc.id)
	assert_eq(c.inventory, after)


func test_friend_visits_and_shares_tea() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.npc_favor[npc.id] = 50
	gs.data.family["folk_visits"]["chance"] = 1.0
	_set_weather(gs, "clear")
	assert_eq(gs.visitor_today(), npc.id)
	assert_false(gs.visit_place_for(npc.id).is_empty())
	assert_eq(gs.check_tea(npc.id), "")
	gs.share_tea(npc.id)
	assert_eq(int(gs.npc_favor[npc.id]), 50 + int(gs.data.family["folk_visits"]["tea_favor"]))
	assert_eq(int(c.folk_visit_day[npc.id]), GameClock.total_days)
	assert_true(gs.check_tea(npc.id) != "", "once per visit")
	var favor_now := int(gs.npc_favor[npc.id])
	gs.share_tea(npc.id)
	assert_eq(int(gs.npc_favor[npc.id]), favor_now)
	gs.data.family["folk_visits"]["chance"] = 0.15
	_restore_weather(gs)


func test_folk_visit_day_round_trips() -> void:
	var c := _start()
	c.folk_visit_day = {"npc_1": 77}
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(int(back.folk_visit_day["npc_1"]), 77)
	assert_true(CharacterData.from_dict({}).folk_visit_day.is_empty())


func test_greeting_for_reads_favor_and_fills_player_name() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	assert_eq(gs.greeting_for(npc.id), "")
	gs.npc_favor[npc.id] = 40
	var warm: String = gs.greeting_for(npc.id)
	assert_true(warm != "")
	assert_false(warm.contains("{player}"))
	gs.npc_favor[npc.id] = -40
	assert_true(gs.greeting_for(npc.id) != warm)
	assert_eq(gs.greeting_for("nobody"), "")
	assert_eq(c.name, "Integration")


func test_full_month_greeting_names_the_newborn() -> void:
	_start()
	var gs := _game_state()
	var mother := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var elder_child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 8, "region": "qingshi_village", "realm": "mortal"})
	var baby := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 0, "region": "qingshi_village", "realm": "mortal"})
	mother.children.append(elder_child.id)
	mother.children.append(baby.id)
	var greetings: Dictionary = gs.data.family["folk_greetings"]
	var saved: Variant = greetings.get("celebration", {}).duplicate(true)
	greetings["celebration"] = {"full_month": ["Wish {child} a long life."]}
	Folk.start_celebration(gs.world_flags, [mother.id], GameClock.total_days, gs.data, "full_month")
	assert_eq(gs.greeting_for(mother.id), "Wish %s a long life." % baby.name, "the newest child, not the eldest")
	greetings["celebration"] = saved


func test_wedding_greeting_names_the_newest_spouse() -> void:
	_start()
	var gs := _game_state()
	var groom := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	var late_wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	var bride := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	late_wife.alive = false
	groom.spouses.append(late_wife.id)
	groom.spouses.append(bride.id)
	var greetings: Dictionary = gs.data.family["folk_greetings"]
	var saved: Variant = greetings.get("celebration", {}).duplicate(true)
	greetings["celebration"] = {"wedding": ["{partner} and I thank you."]}
	Folk.start_celebration(gs.world_flags, [groom.id], GameClock.total_days, gs.data)
	assert_eq(gs.greeting_for(groom.id), "%s and I thank you." % bride.name, "a widower's new bride, not the late wife")
	groom.spouses.clear()
	assert_eq(gs.greeting_for(groom.id), "my beloved and I thank you.")
	greetings["celebration"] = saved

func test_chat_may_give_a_tip_that_boosts_gathering() -> void:
	var c := _start()
	var gs := _game_state()
	var old: float = gs.data.family["folk_tips"]["chance"]
	gs.data.family["folk_tips"]["chance"] = 1.0
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": gs.current_region, "realm": "mortal"})
	gs.npc_favor[npc.id] = int(gs.data.family["folk_tips"]["min_favor"])
	gs.chat(npc.id)
	var tip: Dictionary = Folk.active_tip(gs.world_flags, GameClock.total_days)
	gs.data.family["folk_tips"]["chance"] = old
	assert_false(tip.is_empty())
	assert_true(gs.active_tip_text().begins_with("Tip: "))
	var table := [{"item": tip["item"], "weight": 1, "min": 1, "max": 1}]
	var before := c.item_count(tip["item"])
	gs.gather(table, 1)
	assert_true(c.item_count(tip["item"]) >= before + 1 + int(gs.data.family["folk_tips"]["bonus"]))
	gs.end_session()


func test_family_never_gives_a_tip() -> void:
	var c := _start()
	var gs := _game_state()
	var old: float = gs.data.family["folk_tips"]["chance"]
	gs.data.family["folk_tips"]["chance"] = 1.0
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": gs.current_region, "realm": "mortal"})
	c.parents.append(npc.id)
	gs.npc_favor[npc.id] = int(gs.data.family["folk_tips"]["min_favor"])
	gs.chat(npc.id)
	gs.data.family["folk_tips"]["chance"] = old
	assert_true(Folk.active_tip(gs.world_flags, GameClock.total_days).is_empty())
	gs.end_session()


func test_attend_celebration_gives_favor_to_both_once() -> void:
	var c := _start()
	var gs := _game_state()
	var a := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 25, "region": gs.current_region, "realm": "mortal"})
	var b := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 25, "region": gs.current_region, "realm": "mortal"})
	Family.marry(a, b, "wife")
	assert_true(gs.check_celebration(a.id) != "")
	Folk.start_celebration(gs.world_flags, [a.id, b.id], GameClock.total_days, gs.data)
	var day := GameClock.total_days
	var align := c.alignment
	gs.attend_celebration(a.id)
	assert_eq(int(gs.npc_favor.get(a.id, 0)), 6)
	assert_eq(int(gs.npc_favor.get(b.id, 0)), 6)
	assert_eq(c.alignment, align + 1)
	assert_eq(_root().get_node("GameClock").total_days, day + 1)
	gs.attend_celebration(b.id)
	assert_eq(int(gs.npc_favor.get(b.id, 0)), 6)
	assert_eq(_root().get_node("GameClock").total_days, day + 1)
	gs.end_session()



func test_birth_and_death_events_open_feast_and_funeral() -> void:
	var c := _start()
	var gs := _game_state()
	var mother := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 25, "region": gs.current_region, "realm": "mortal"})
	var father := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 27, "region": gs.current_region, "realm": "mortal"})
	Family.marry(mother, father, "wife")
	var birth: Dictionary = gs._celebration_for({"npc_id": mother.id, "kind": "birth", "text": "x"})
	assert_eq(birth["kind"], "full_month")
	assert_true(birth["ids"].has(mother.id) and birth["ids"].has(father.id))
	var elsewhere := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 25, "region": "misty_forest", "realm": "mortal"})
	assert_eq(gs._celebration_for({"npc_id": elsewhere.id, "kind": "birth", "text": "x"})["kind"], "")
	father.alive = false
	var death: Dictionary = gs._celebration_for({"npc_id": father.id, "kind": "death", "text": "x"})
	assert_eq(death["kind"], "funeral")
	assert_eq(death["ids"], [mother.id])
	var lone := Npcs.spawn(gs.npcs, gs.data, seeded_rng(8), {"age_years": 70, "region": gs.current_region, "realm": "mortal"})
	assert_eq(gs._celebration_for({"npc_id": lone.id, "kind": "death", "text": "x"})["kind"], "", "no mourners, no funeral")
	Folk.start_celebration(gs.world_flags, death["ids"], GameClock.total_days, gs.data, "funeral")
	assert_eq(Folk.celebration_label(gs.world_flags, mother.id, gs.data), "Pay your respects (1 day)")
	var align := c.alignment
	gs.attend_celebration(mother.id)
	assert_eq(int(gs.npc_favor.get(mother.id, 0)), 8)
	assert_eq(c.alignment, align + 1)
	assert_true(gs.check_celebration(mother.id) != "")
	gs.end_session()


func test_field_rent_plant_grow_harvest() -> void:
	var c := _start()
	var gs := _game_state()
	var place := FieldPlots.place_def(gs.data, gs.current_region)
	assert_false(place.is_empty(), "the start village rents a field")
	gs.current_region = "qingshi_village"
	c.inventory["spirit_stone"] = 20
	c.inventory["spirit_herb"] = 1
	c.spiritual_roots = {"fire": 80}
	gs.rent_field()
	assert_eq(c.item_count("spirit_stone"), 20 - int(place["rent"]))
	gs.plant_field("spirit_herb")
	assert_eq(c.item_count("spirit_herb"), 0)
	gs.harvest_field()
	assert_eq(c.item_count("spirit_herb"), 0, "not ripe yet")
	_game_state().get_node("/root/GameClock").advance(60)
	gs.harvest_field()
	assert_true(c.item_count("spirit_herb") >= 2, "harvested")
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.field_plots.size(), 1)


func test_tending_for_days_earns_the_harvest_bonus() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	var place := FieldPlots.place_def(gs.data, gs.current_region)
	var key := FieldPlots.key(gs.current_region, place)
	c.inventory["spirit_stone"] = 20
	c.inventory["spirit_herb"] = 1
	c.spiritual_roots = {"fire": 80}
	c.realm_index = 1
	gs.rent_field()
	gs.plant_field("spirit_herb")
	for i in 6:
		c.qi = 100.0
		gs.nourish_field()
		_game_state().get_node("/root/GameClock").advance(1)
	assert_eq(int(c.field_plots[key]["crops"][0]["care"]), 6)
	_game_state().get_node("/root/GameClock").advance(40)
	gs.harvest_field()
	assert_true(c.item_count("spirit_herb") >= 3, "2..3 plus the tended bonus")


func test_nourish_field_spends_qi_and_grows_crop() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	var place := FieldPlots.place_def(gs.data, gs.current_region)
	c.inventory["spirit_stone"] = 20
	c.inventory["spirit_herb"] = 1
	c.spiritual_roots = {"fire": 80}
	gs.rent_field()
	gs.plant_field("spirit_herb")
	var key := FieldPlots.key(gs.current_region, place)
	var before := int(c.field_plots[key]["crops"][0]["days_left"])
	var day := GameClock.total_days
	c.realm_index = 0
	gs.nourish_field()
	assert_eq(int(c.field_plots[key]["crops"][0]["days_left"]), before, "mortals cannot")
	c.realm_index = 1
	c.qi = 50.0
	gs.nourish_field()
	assert_eq(int(c.field_plots[key]["crops"][0]["days_left"]), before - 2)
	assert_eq(c.qi, 20.0)
	assert_eq(GameClock.total_days, day, "takes no time")


func test_settle_quarrel_mediate_and_extort() -> void:
	var c := _start()
	var gs := _game_state()
	var a := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var b := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	var key := Folk.quarrel_flag(gs.current_region)
	gs.world_flags[key] = {"a": a.id, "b": b.id, "topic": "rice_debt", "until": GameClock.total_days + 10}
	assert_eq(gs.check_quarrel(a.id), "")
	assert_false(gs.quarrel_of(b.id).is_empty())
	c.attributes["charisma"] = 1000
	gs.rng.seed = 1
	gs.settle_quarrel(a.id, "extort")
	assert_eq(int(gs.npc_favor[a.id]), -6)
	assert_false(gs.world_flags.has(key), "settling clears the quarrel")
	assert_true(gs.check_quarrel(a.id) != "")
	gs.world_flags[key] = {"a": a.id, "b": b.id, "topic": "rice_debt", "until": GameClock.total_days + 10}
	gs.settle_quarrel(b.id, "side_a")
	assert_eq(int(gs.npc_favor[a.id]), -6 + 8)
	assert_eq(int(gs.npc_favor[b.id]), -6 - 8)


func test_settling_a_quarrel_leaves_a_mark() -> void:
	var c := _start()
	var gs := _game_state()
	var a := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var b := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	var key := Folk.quarrel_flag(gs.current_region)
	var mark_key := Folk.mark_flag(gs.current_region)
	gs.world_flags[key] = {"a": a.id, "b": b.id, "topic": "rice_debt", "until": GameClock.total_days + 10}
	gs.settle_quarrel(a.id, "side_a")
	assert_eq(String(gs.world_flags[mark_key]["loser"]), b.id)
	assert_true(gs.together_places().is_empty())
	c.attributes["charisma"] = 1000
	gs.rng.seed = 1
	gs.world_flags[key] = {"a": a.id, "b": b.id, "topic": "rice_debt", "until": GameClock.total_days + 10}
	gs.settle_quarrel(a.id, "mediate")
	if gs.world_flags[mark_key]["choice"] == "mediate":
		assert_eq(gs.together_places().size(), 2)
	else:
		assert_eq(String(gs.world_flags[mark_key]["choice"]), "side_a", "a failed mediation leaves the old mark")


func test_friend_joins_the_fight() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "qi_refining"})
	gs.npc_favor[npc.id] = 50
	gs.invite_companion(npc.id)
	assert_true(c.folk_companion.is_empty(), "favor too low")
	gs.npc_favor[npc.id] = 60
	gs.invite_companion(npc.id)
	assert_eq(Folk.companion_today(c, GameClock.total_days), npc.id)
	gs.fight("training_dummy" if gs.data.enemies.has("training_dummy") else gs.data.enemies.keys()[0])
	assert_true(c.folk_companion.is_empty(), "companion used up")
	assert_true(int(gs.npc_favor[npc.id]) != 60)


func test_folk_companion_round_trips() -> void:
	var c := _start()
	c.folk_companion = {"npc": "n1", "day": 9}
	c.folk_companion_day = {"n1": 9}
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(String(back.folk_companion["npc"]), "n1")
	assert_eq(int(back.folk_companion_day["n1"]), 9)


func test_storm_gather_cuts_herbs_and_contemplation_doubles_thunder_dao() -> void:
	var c := _start()
	var gs := _game_state()
	var table := [{"item": "spirit_herb", "weight": 1, "min": 2, "max": 2}]
	_set_weather(gs, "clear")
	gs.rng.seed = 5
	gs.gather(table, 1)
	var calm_yield := c.item_count("spirit_herb")
	assert_gt(calm_yield, 0)
	_set_weather(gs, "storm")
	gs.rng.seed = 5
	gs.gather(table, 1)
	assert_eq(c.item_count("spirit_herb") - calm_yield, calm_yield - 1, "a storm day's gather yields one herb less")
	Dao.gain_levels(c, gs.data, "thunder_dao")
	c.attributes["comprehension"] = 1000
	var before: float = float(c.dao["thunder_dao"]["progress"])
	var level_before := Dao.level(c, "thunder_dao")
	gs.contemplate_dao("thunder_dao", 1)
	var stormy := float(c.dao["thunder_dao"]["progress"]) + 1000.0 * (Dao.level(c, "thunder_dao") - level_before) - before
	_set_weather(gs, "clear")
	var mid: float = float(c.dao["thunder_dao"]["progress"])
	var level_mid := Dao.level(c, "thunder_dao")
	gs.contemplate_dao("thunder_dao", 1)
	var calm := float(c.dao["thunder_dao"]["progress"]) + 1000.0 * (Dao.level(c, "thunder_dao") - level_mid) - mid
	assert_gt(stormy, calm * 1.5, "a storm day roughly doubles contemplation progress")
	_restore_weather(gs)


func test_storm_exploring_can_bring_lightning_wood_and_dao() -> void:
	var c := _start()
	var gs := _game_state()
	_set_weather(gs, "storm")
	gs.data.weather_effects["storm"]["explore"] = {"lightning_chance": 0.5, "lightning_damage_frac": 0.15, "thunderwood_chance": 0.5}
	c.spiritual_roots = {"metal": 60}
	Dao.gain_levels(c, gs.data, "thunder_dao")
	var before: float = float(c.dao["thunder_dao"]["progress"])
	var level_before := Dao.level(c, "thunder_dao")
	var wood := 0
	for i in 12:
		gs.rng.seed = i
		gs.explore()
		wood = c.item_count("lightning_struck_wood")
	var gained := float(c.dao["thunder_dao"]["progress"]) + 1000.0 * (Dao.level(c, "thunder_dao") - level_before) - before
	assert_gt(wood, 0, "a storm branch was found")
	assert_gt(gained, 0.0, "lightning fed Thunder Dao")
	_restore_weather(gs)


func test_friendship_tier_posts_line_and_gift_once() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.npc_favor[npc.id] = 35
	gs.check_friendships()
	assert_true(c.folk_tiers_seeded)
	assert_eq(gs.friendship_label(npc.id), "Acquaintance")
	gs.npc_favor[npc.id] = 45
	var rice := c.item_count("sweet_rice_ball")
	gs.check_friendships()
	assert_eq(c.item_count("sweet_rice_ball"), rice + 2)
	assert_eq(gs.friendship_label(npc.id), "Friend")
	gs.check_friendships()
	assert_eq(c.item_count("sweet_rice_ball"), rice + 2, "no repeat")
	gs.npc_favor[npc.id] = 30
	gs.check_friendships()
	gs.npc_favor[npc.id] = 45
	gs.check_friendships()
	assert_eq(c.item_count("sweet_rice_ball"), rice + 2, "dip and recover does not repeat")


func test_friendship_old_save_does_not_burst() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	c.folk_tiers_seeded = false
	gs.npc_favor[npc.id] = 70
	var before := c.inventory.duplicate()
	gs.check_friendships()
	assert_eq(c.inventory, before)
	assert_eq(gs.friendship_label(npc.id), "Close friend")


func test_goal005_first_fish_awards_first_catch() -> void:
	var c := _start()
	var gs := _game_state()
	var table := [{"item": "silver_carp", "weight": 1, "min": 1, "max": 1}]
	_set_weather(gs, "clear")
	gs.data.fishing_weather = {}
	assert_false(c.milestones.has("first_catch"))
	for i in 30:
		if c.milestones.has("first_catch"):
			break
		gs.fish(table, 1, "Test Pond")
	assert_true(c.milestones.has("first_catch"))
	_restore_weather(gs)


func test_birthday_gift_counts_double_once() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var other := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	GameClock.total_days = Folk.birthday_day(npc, gs.data) + Calendar.DAYS_PER_YEAR
	c.add_item("qi_gathering_pill", 3)
	var worth := Family.gift_value(gs.data, "qi_gathering_pill")
	gs.npc_favor[npc.id] = 0
	gs.give_gift(npc.id, "qi_gathering_pill")
	assert_eq(int(gs.npc_favor[npc.id]), worth * 2)
	var after := int(gs.npc_favor[npc.id])
	GameClock.total_days = Folk.birthday_day(npc, gs.data) + Calendar.DAYS_PER_YEAR
	gs.give_gift(npc.id, "qi_gathering_pill")
	assert_eq(int(gs.npc_favor[npc.id]) - after, worth, "only the first gift doubles")
	assert_true(other != null)


func test_named_friend_birthday_gift_doubles() -> void:
	var c := _start()
	var gs := _game_state()
	Npcs.ensure_all(gs.npcs, gs.data, seeded_rng(5))
	GameClock.total_days = Folk.birthday_day(gs.npcs["elder_mo"], gs.data) + Calendar.DAYS_PER_YEAR
	c.add_item("qi_gathering_pill", 2)
	var worth := Family.gift_value(gs.data, "qi_gathering_pill") * int(gs.data.family["acquaintance"]["gift_like_mult"])
	gs.npc_favor["elder_mo"] = 0
	gs.give_gift("elder_mo", "qi_gathering_pill")
	var first := int(gs.npc_favor["elder_mo"])
	assert_true(first >= worth, "doubled on the birthday")
	GameClock.total_days = Folk.birthday_day(gs.npcs["elder_mo"], gs.data) + Calendar.DAYS_PER_YEAR
	gs.give_gift("elder_mo", "qi_gathering_pill")
	assert_true(int(gs.npc_favor["elder_mo"]) - first < first, "second gift is not doubled")


func test_liked_gift_to_generated_villager_sets_taste_flag() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(8), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var liked := ""
	for item_id: String in gs.data.items:
		if Family.gift_taste(gs.data, npc.id, item_id) > 0 and Family.gift_value(gs.data, item_id) > 0:
			liked = item_id
			break
	assert_true(liked != "", "a generated villager likes something")
	c.add_item(liked, 1)
	gs.npc_favor[npc.id] = 0
	gs.give_gift(npc.id, liked)
	assert_eq(int(gs.world_flags.get("taste_%s_%s" % [npc.id, liked], 0)), 1)


func test_people_entries_lists_elder_mo_after_gift() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	Npcs.ensure_all(gs.npcs, gs.data, seeded_rng(4))
	c.add_item("spirit_herb", 5)
	gs.npc_favor["elder_mo"] = 10
	gs.give_gift("elder_mo", "spirit_herb")
	var found := false
	for e: Dictionary in gs.people_entries():
		if e["id"] == "elder_mo":
			found = true
			assert_true((e["likes_known"] as Array).has("spirit_herb"))
	assert_true(found)


func test_upcoming_days_lists_next_market_day() -> void:
	_start()
	var days: Array = []
	for e: Dictionary in _game_state().upcoming_days():
		if e["kind"] == "market":
			days.append(Calendar.day_of(int(e["day"])))
	assert_eq(days, [10, 25])


func test_engage_roamer() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	var roamers: Array[Dictionary] = gs.roamers_here()
	assert_true(roamers.size() >= 2)
	var slot := int(roamers[0]["slot"])
	var log_before := int(EventBus.posted_count)
	gs.engage_roamer(slot)
	assert_true(int(EventBus.posted_count) > log_before, "a fight was posted")
	for r in gs.roamers_here():
		assert_true(int(r["slot"]) != slot, "downed slot is gone today")
	var day_after := int(GameClock.total_days)
	assert_false(gs.engage_roamer(99), "bad slot refused")
	assert_eq(int(GameClock.total_days), day_after, "refusals pass no time")


## WILD-014: beat the Old Tusker, and the same weekday the Scarred Old Tusker walks in his slot.
func test_great_beast_returns_scarred() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	gs.player.realm_index = 3
	var g: Dictionary = gs.data.regions["misty_forest"]["roamers"]["great"]
	g.erase("max_realm")  # C-317: the Qi Refining cap is tested elsewhere; here a strong player fights the first beast
	GameClock.total_days = 7 * 60 + Wildlife.great_day("misty_forest", g)
	var found := false
	for r in gs.roamers_here():
		found = found or String(r["enemy"]) == "old_tusker_boar"
	assert_true(found, "the first beast walks")
	assert_true(gs.engage_roamer(Wildlife.GREAT_SLOT))
	assert_true(gs.player.great_beasts.has("old_tusker_boar"))
	assert_true(gs.player.item_count("old_tuskers_broken_tusk") >= 1)
	GameClock.total_days = Wildlife.next_great_day(gs.data, "misty_forest", GameClock.total_days + 1, 3, gs.player)
	var enemies: Array = []
	for r in gs.roamers_here():
		enemies.append(String(r["enemy"]))
	assert_true(enemies.has("scarred_old_tusker"), "the return walks")
	assert_false(enemies.has("old_tusker_boar"))
	assert_true(gs.engage_roamer(Wildlife.GREAT_SLOT))
	assert_true(gs.player.item_count("scarred_tuskers_spear_head") >= 1)


func test_engage_roamer_records_hunt() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	var r: Dictionary = gs.roamers_here()[0]
	var won: bool = gs.engage_roamer(int(r["slot"]))
	var n := int(gs.player.hunt_log.get(String(r["enemy"]), 0))
	assert_eq(n, 1 if won else 0, "only a win is logged")
	assert_eq(LifeStats.get_stat(gs.player, "beasts_hunted"), n)
	if not won:
		assert_true(Wildlife.spoils_of(gs.player, String(r["enemy"])).is_empty(), "a loss records no spoils")


func test_roamer_temper_and_charge() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	var roamers: Array[Dictionary] = gs.roamers_here()
	var slot := int(roamers[0]["slot"])
	assert_true(gs.roamer_temper(slot) in ["flees", "wary", "bold"])
	assert_eq(gs.roamer_temper(99), "")
	var before := EventBus.history.size()
	gs.engage_roamer(slot, true)
	var found := false
	for i in range(before, EventBus.history.size()):
		found = found or String(EventBus.history[i]["text"]).ends_with("charges you!")
	assert_true(found, "charge line posted")


func test_tomorrow_reminder_posted_once() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	GameClock.total_days = 4
	var before := EventBus.history.size()
	gs._pass_time(4)  # now total day 8: market tomorrow
	var n := 0
	for i in range(before, EventBus.history.size()):
		if String(EventBus.history[i]["text"]).begins_with("Tomorrow: market day"):
			n += 1
	assert_eq(n, 1)


## GOAL-007: one forage in Qingshi advances the newcomer ladder.
func test_forage_advances_first_goals() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	assert_false(Guidance.first_goals(gs.player, gs.data, gs.world_flags)[2]["done"])
	assert_true(gs.pick_forage(int(gs.forage_here()[0]["slot"])))
	assert_true(Guidance.first_goals(gs.player, gs.data, gs.world_flags)[2]["done"])


func test_pick_forage() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	var nodes: Array[Dictionary] = gs.forage_here()
	assert_true(nodes.size() >= 1)
	var n: Dictionary = nodes[0]
	var item := String(n["item"])
	var had: int = gs.player.item_count(item)
	var day := int(GameClock.total_days)
	assert_true(gs.pick_forage(int(n["slot"])))
	assert_eq(gs.player.item_count(item), had + int(n["amount"]))
	assert_eq(int(GameClock.total_days), day, "picking takes no time")
	assert_eq(LifeStats.get_stat(gs.player, "foraged"), 1)
	assert_false(gs.pick_forage(int(n["slot"])), "already picked")
	assert_eq(gs.forage_here().size(), nodes.size() - 1)
	assert_false(gs.pick_forage(99))


func test_great_beast_pays_double_and_counts() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	gs.player.realm_index = 5
	var def: Dictionary = gs.data.regions["misty_forest"]["roamers"]["great"]
	def.erase("max_realm")  # C-317: a strong player still meets the first beast here
	var wd := Wildlife.great_day("misty_forest", def)
	GameClock.total_days = 7 * 50 + wd
	var great: Dictionary = {}
	for r in gs.roamers_here():
		if int(r["slot"]) == Wildlife.GREAT_SLOT:
			great = r
	assert_false(great.is_empty(), "the great beast walks today")
	var before := int(gs.player.inventory.get("spirit_stone", 0))
	gs.data.items["test_trophy"] = {"name": "Test Tusk", "tags": ["trophy"]}
	def["trophy"] = "test_trophy"
	var won: bool = gs.engage_roamer(Wildlife.GREAT_SLOT)
	if won:
		assert_eq(gs.player.item_count("test_trophy"), 1, "trophy on the first great win")
		assert_eq(LifeStats.get_stat(gs.player, "great_beasts"), 1)
		var normal := int(gs.data.enemies[String(great["enemy"])]["rewards"]["items"]["spirit_stone"])
		assert_true(int(gs.player.inventory.get("spirit_stone", 0)) - before >= 2 * normal, "double stones")
	else:
		assert_eq(LifeStats.get_stat(gs.player, "great_beasts"), 0)
		assert_eq(gs.player.item_count("test_trophy"), 0)
	def.erase("trophy")
	gs.data.items.erase("test_trophy")


func test_great_beast_calendar_and_reminder() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	gs.player.realm_index = 2  # C-317: the return beast walks from Foundation
	var def: Dictionary = gs.data.regions["misty_forest"]["roamers"]["great"]
	def.erase("max_realm")  # the first beast still walks for this test
	var wd := Wildlife.great_day("misty_forest", def)
	var day := 7 * 50 + wd
	gs.player.visited_regions.erase("misty_forest")
	var kinds := func(es: Array[Dictionary]) -> int:
		var n := 0
		for e in es:
			if e["kind"] == "great_beast":
				n += 1
		return n
	assert_eq(kinds.call(VillageCalendar.upcoming(gs.data, {}, {}, [], "qingshi_village", day, 14, gs.player)), 0, "unexplored")
	gs.player.visited_regions.append("misty_forest")
	assert_eq(kinds.call(VillageCalendar.upcoming(gs.data, {}, {}, [], "qingshi_village", day, 14, gs.player)), 2)
	var quiet := VillageCalendar.reminders(gs.data, {}, {}, [], "misty_forest", day - 1, gs.player, {})
	assert_false(" ".join(quiet).contains("Great "), "LOG-005: no hunt, no bait, no eve line: " + str(quiet))
	var baited := {Wildlife.bait_flag("misty_forest"): day}
	var lines := VillageCalendar.reminders(gs.data, {}, {}, [], "misty_forest", day - 1, gs.player, baited)
	assert_true(" ".join(lines).contains("Great "), str(lines))
	# WILD-011: a far region's beast posts nothing, a beaten one posts nothing, the screen list is unchanged.
	var beast_name := Wildlife.display_name(gs.data, String(def["enemy"]), true)
	var far := VillageCalendar.reminders(gs.data, {}, {}, [], "myriad_peaks_ridge", day - 1, gs.player, {})
	assert_false(" ".join(far).contains(beast_name), "far region: " + str(far))
	var before := VillageCalendar.upcoming(gs.data, {}, {}, [], "qingshi_village", day, 14, gs.player).size()
	gs.player.great_beasts[String(def["enemy"])] = day - 3
	var beaten := VillageCalendar.reminders(gs.data, {}, {}, [], "misty_forest", day - 1, gs.player, baited)
	assert_false(" ".join(beaten).contains(beast_name), "beaten: " + str(beaten))
	assert_eq(VillageCalendar.upcoming(gs.data, {}, {}, [], "qingshi_village", day, 14, gs.player).size(), before)


func test_pick_forage_log_says_what_it_is_for() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	var n: Dictionary = gs.forage_here()[0]
	var msgs: Array = []
	var cb := func(text: String, _cat: String) -> void: msgs.append(text)
	EventBus.message_posted.connect(cb)
	assert_true(gs.pick_forage(int(n["slot"])))
	EventBus.message_posted.disconnect(cb)
	assert_true(msgs.size() >= 1)
	assert_true(String(msgs[0]).begins_with("You pick"), String(msgs[0]))


func test_great_beast_win_raises_renown() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	gs.player.realm_index = 5
	var def: Dictionary = gs.data.regions["misty_forest"]["roamers"]["great"]
	GameClock.total_days = 7 * 50 + Wildlife.great_day("misty_forest", def)
	var before := Renown.value(gs.player, "misty_forest")
	var won: bool = gs.engage_roamer(Wildlife.GREAT_SLOT)
	var gain := int(gs.data.renown["sources"]["great_beast"])
	if won:
		assert_eq(Renown.value(gs.player, "misty_forest"), before + gain, "renown once")
		assert_false(gs.engage_roamer(Wildlife.GREAT_SLOT), "the beast is gone for the day")
		assert_eq(Renown.value(gs.player, "misty_forest"), before + gain)
	else:
		assert_eq(Renown.value(gs.player, "misty_forest"), before, "no renown on a loss")


func test_ordinary_roamer_and_missing_source_add_no_renown() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	var before := Renown.value(gs.player, "qingshi_village")
	for r in gs.roamers_here():
		gs.engage_roamer(int(r["slot"]))
		break
	assert_eq(Renown.value(gs.player, "qingshi_village"), before)
	gs.data.renown["sources"].erase("great_beast")
	var r2 := Renown.gain(gs.player, gs.data, "misty_forest", "great_beast")
	assert_eq(int(r2["gained"]), 0)
	gs.data.renown["sources"]["great_beast"] = 15


func test_explore_posts_tracks_line_once_per_day() -> void:
	_start()
	var gs := _game_state()
	var clock: Node = _root().get_node("GameClock")
	var region := "misty_forest"
	gs.current_region = region
	gs.world_flags["discovered_" + region] = true
	var wd := Wildlife.great_day(region, gs.data.regions[region]["roamers"]["great"])
	clock.total_days = (clock.total_days / 7) * 7 + 7 + posmod(wd - 1, 7)
	if not Wildlife.tracks_today(gs.data, region, clock.total_days, gs.player.realm_index):
		clock.total_days += 7
	assert_true(Wildlife.tracks_today(gs.data, region, clock.total_days, gs.player.realm_index), "setup")
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.world_flags["tracks_day_" + region] = -1
	gs.explore(["t_no_such_tag"])
	clock.total_days -= 1  # still the same tracks day for the once-a-day guard
	var first := "\n".join(_zero_round_posts)
	assert_true(first.contains("Fresh tracks"), first)
	_zero_round_posts.clear()
	clock.total_days = int(gs.world_flags["tracks_day_" + region])
	gs.explore(["t_no_such_tag"])
	EventBus.message_posted.disconnect(_collect_post)
	assert_false("\n".join(_zero_round_posts).contains("Fresh tracks"), "once per day")
	gs.end_session()


## MARKET-011: the 6th and later units of one item sold to one merchant pay less; the wanted item is exempt.
func test_market_flooded_stall_pays_less() -> void:
	_start()
	var clock := _root().get_node("GameClock")
	clock.total_days = 10  # closed day: no wanted item
	GameState.current_region = "qingshi_village"
	GameState.shop_name = "Travelling Market Stall"
	var id := "dew_grass"
	var base := Items.sell_price(GameState.data, id)
	GameState.player.add_item(id, 8)
	var before := GameState.player.item_count("spirit_stone")
	GameState.sell_item(id, 7)
	var expected := base * 5 + roundi(base * 0.9) + roundi(base * 0.8)
	assert_eq(GameState.player.item_count("spirit_stone") - before, expected)
	assert_almost_eq(GameState.market_flood_mult(id), 0.7, 0.001)
	clock.total_days = 12  # two steps recovered
	assert_almost_eq(GameState.market_flood_mult(id), 0.9, 0.001)
	clock.total_days = 30
	assert_eq(GameState.market_flood_mult(id), 1.0)
	GameState.shop_name = ""


## MARKET-008: the stall pays 1.5x for today's wanted item, 5 units a day, and nothing extra for other items or days.
func test_market_wanted_price_and_cap() -> void:
	_start()
	var clock := _root().get_node("GameClock")
	clock.total_days = 9
	GameState.current_region = "qingshi_village"
	GameState.shop_name = "Travelling Market Stall"
	var want := GameState.market_wanted()
	assert_false(want.is_empty())
	var id := String(want["item"])
	var other := "boar_hide" if id != "boar_hide" else "dew_grass"
	var base := Items.sell_price(GameState.data, id)
	GameState.player.add_item(id, 8)
	GameState.player.add_item(other, 2)
	var before := GameState.player.item_count("spirit_stone")
	GameState.sell_item(id, 3)
	assert_eq(GameState.player.item_count("spirit_stone") - before, roundi(base * 1.5) * 3)
	assert_eq(int(GameState.market_wanted()["left"]), 2)
	before = GameState.player.item_count("spirit_stone")
	GameState.sell_item(id, 5)  # 2 at the bonus, 3 at the plain price
	assert_eq(GameState.player.item_count("spirit_stone") - before, roundi(base * 1.5) * 2 + base * 3)
	assert_eq(int(GameState.market_wanted()["left"]), 0)
	before = GameState.player.item_count("spirit_stone")
	GameState.sell_item(other, 2)
	assert_eq(GameState.player.item_count("spirit_stone") - before, Items.sell_price(GameState.data, other) * 2, "no bonus on other items")
	clock.total_days = 9 + 30  # next market day: a fresh allowance
	assert_eq(int(GameState.market_wanted()["left"]), 5)
	clock.total_days = 10  # closed
	assert_true(GameState.market_wanted().is_empty())
	GameState.shop_name = ""


## MARKET-009: selling the wanted item on three different market days makes the player a regular (once per day, not per item).
func test_market_regular_after_three_market_days() -> void:
	_start()
	var clock := _root().get_node("GameClock")
	GameState.current_region = "qingshi_village"
	GameState.shop_name = "Travelling Market Stall"
	GameState.world_flags["wanted_sold_travelling_market_stall_9"] = 5  # an old MARKET-008 flag is ignored
	var days := [9, 24, 39]
	for i in days.size():
		clock.total_days = days[i]
		var id := String(GameState.market_wanted()["item"])
		GameState.player.add_item(id, 4)
		GameState.sell_item(id, 1)
		GameState.sell_item(id, 2)  # same day: not counted again
		assert_eq(int(GameState.player.market_regular["travelling_market_stall"]), i + 1)
		assert_eq(int(GameState.market_wanted()["left"]), 2, "tally spans both sales")
		assert_eq(GameState.is_market_regular("Travelling Market Stall"), i == 2)
	clock.total_days = 54
	var plain := Places.rotating_picks(ShopDiscounts.place_named(GameState.data, "qingshi_village", "Travelling Market Stall"), 54)
	var picks := Places.rotating_picks(ShopDiscounts.place_named(GameState.data, "qingshi_village", "Travelling Market Stall"), 54, true)
	assert_eq(picks.size(), plain.size() + 1)
	var item := String(picks[0])
	var cut := GameState.buy_multiplier(item)
	GameState.shop_name = ""
	assert_true(cut < GameState.buy_multiplier(item), "regular discount on a rotating ware")
	GameState.shop_name = ""


## MARKET-007: the Travelling Market Stall's shop gets its fixed tags plus 3 rotating picks on market day.
func test_market_stall_rotating_stock_options() -> void:
	_start()
	var clock := _root().get_node("GameClock")
	clock.total_days = 9  # day 10 of the month
	var stall: Interactable = load("res://src/world/interactables/merchant.gd").new()
	stall.display_name = "Travelling Market Stall"
	stall.open_days = [10, 25]
	stall.stock_tags = ["sweet_rice_ball"]
	stall.rotating_stock = ShopDiscounts.place_named(GameState.data, "qingshi_village", "Travelling Market Stall")["rotating_stock"]
	var tags: Array = Places.stock_tags_today({"display_name": stall.display_name, "open_days": stall.open_days, "stock_tags": stall.stock_tags, "rotating_stock": stall.rotating_stock}, clock.total_days)
	assert_eq(tags.size(), 4)
	assert_true(tags.has("sweet_rice_ball"))
	assert_false(stall.get_options().is_empty(), "open on day 10")
	stall.free()


func test_season_digest_posts_once_per_season() -> void:
	var gs := _game_state()
	var c := _start()
	c.visited_regions.append("qingshi_village")
	gs.current_region = "qingshi_village"
	GameClock.total_days = 85
	gs.world_flags.erase("season_digest_idx")
	# CAL-011: pin plain omens so no almanac dawn line or reminder depends on the day.
	var saved_omens: Array = gs.data.almanac["omens"]
	gs.data.almanac["omens"] = [{"id": "p", "name": "Plain", "text": "t", "weight": 1, "boost": {}}]
	gs._pass_time(1)  # first pass seeds the flag silently
	var before: int = _non_almanac_posts()
	gs._pass_time(1)  # still spring
	assert_eq(_non_almanac_posts(), before, "no post inside a season")
	GameClock.total_days = 89
	gs._pass_time(1)  # day 90: summer begins
	assert_true(_non_almanac_posts() > before)
	assert_true(String(EventBus.history[EventBus.history.size() - 1]["text"]).length() > 0)
	var after: int = _non_almanac_posts()
	gs._pass_time(1)
	assert_eq(_non_almanac_posts(), after, "not again the same season")
	gs.data.almanac["omens"] = saved_omens


## CAL-011: posts so far minus dawn almanac lines (those depend on the day's omen).
func _non_almanac_posts() -> int:
	var n: int = EventBus.posted_count
	for m: Dictionary in EventBus.history:
		if String(m["category"]) == "almanac":
			n -= 1
	return n


## WILD-015: baiting on a tracks day spends the item and a day, and the baited beast fights weakened once.
func test_bait_the_trail() -> void:
	_start()
	var gs := _game_state()
	var clock: Node = _root().get_node("GameClock")
	var region := "misty_forest"
	gs.current_region = region
	var wd := Wildlife.great_day(region, gs.data.regions[region]["roamers"]["great"])
	clock.total_days = (clock.total_days / 7) * 7 + 7 + posmod(wd - 1, 7)
	assert_true(Wildlife.tracks_today(gs.data, region, clock.total_days, gs.player.realm_index), "setup")
	assert_eq(gs.bait_offer(), "", "no bait held")
	assert_false(gs.set_bait())
	gs.player.add_item("village_mugwort", 2)
	assert_eq(gs.bait_offer(), "village_mugwort")
	var day := int(clock.total_days)
	assert_true(gs.set_bait())
	assert_eq(gs.player.item_count("village_mugwort"), 1)
	assert_eq(int(clock.total_days), day + 1)
	assert_eq(int(gs.world_flags[Wildlife.bait_flag(region)]), day + 1)
	assert_eq(gs.bait_offer(), "", "not a tracks day any more")
	var slots: Array = gs.roamers_here()
	var found := false
	for r in slots:
		if int(r["slot"]) == Wildlife.GREAT_SLOT:
			found = true
	assert_true(found, "the beast walks the day after")
	gs.engage_roamer(Wildlife.GREAT_SLOT)
	assert_false(gs.world_flags.has(Wildlife.bait_flag(region)), "bait used up")
	gs.end_session()


## WU-456: the explore site offers the bait row on a tracks day only.
func test_explore_site_bait_row() -> void:
	var Site := preload("res://src/world/interactables/explore_site.gd")
	_start()
	var gs := _game_state()
	var clock: Node = _root().get_node("GameClock")
	var region := "misty_forest"
	gs.current_region = region
	var wd := Wildlife.great_day(region, gs.data.regions[region]["roamers"]["great"])
	clock.total_days = (clock.total_days / 7) * 7 + 7 + posmod(wd - 1, 7)
	var rows := Site.bait_options()
	assert_eq(rows.size(), 1, "disabled row without bait")
	assert_true(bool(rows[0]["disabled"]))
	assert_true(String(rows[0]["reason"]).contains("mugwort"))
	gs.player.add_item("village_mugwort", 2)
	rows = Site.bait_options()
	assert_eq(rows.size(), 1)
	assert_false(rows[0].has("disabled"))
	assert_true(String(rows[0]["description"]).contains("weakened"))
	(rows[0]["action"] as Callable).call()
	assert_eq(gs.player.item_count("village_mugwort"), 1)
	assert_true(gs.world_flags.has(Wildlife.bait_flag(region)))
	assert_eq(Site.bait_options().size(), 0, "not a tracks day now")
	gs.end_session()


## WU-456: bait_line words both cases.
func test_bait_line_text() -> void:
	var data: GameData = _game_state().data
	var held := Wildlife.bait_line(data, "misty_forest", "village_mugwort")
	assert_true(held.begins_with("Uses 1 "), held)
	assert_true(held.contains("weakened"))
	assert_true(Wildlife.bait_line(data, "misty_forest", "").begins_with("You need "))
	assert_eq(Wildlife.bait_line(data, "qingshi_village", ""), "")


## SEASON-003: the season-ending line posts once, three days before the season ends.
func test_season_ending_posts_once() -> void:
	var gs := _game_state()
	var c := _start()
	c.visited_regions.append("misty_forest")
	gs.current_region = "misty_forest"
	gs.world_flags.erase("season_ending_idx")
	GameClock.total_days = 200
	gs._pass_time(1)
	assert_false(gs.world_flags.has("season_ending_idx"), "mid-season posts nothing")
	GameClock.total_days = 265
	var before: int = EventBus.posted_count
	gs._pass_time(1)  # day 266
	assert_true(EventBus.posted_count > before)
	var found := false
	for h in EventBus.history:
		if String(h["text"]).begins_with("Autumn ends in"):
			found = true
	assert_true(found, "line posted")
	var after: int = EventBus.posted_count
	gs._pass_time(1)
	var again := 0
	for h in EventBus.history:
		if String(h["text"]).begins_with("Autumn ends"):
			again += 1
	assert_eq(again, 1, "once per season")
	assert_true(EventBus.posted_count >= after)


## SEASON-004: ending a day in a festival's region sets festival_seen_<id> to the year.
func test_festival_seen_flag() -> void:
	var gs := _game_state()
	_start()
	GameClock.total_days = 140
	gs.current_region = "qingshi_village"
	gs.world_events = [{"id": "dragon_boat_festival", "region": "qingshi_village", "start_day": 140, "end_day": 148}]
	gs.world_flags.erase("festival_seen_dragon_boat_festival")
	gs._pass_time(1)
	assert_eq(int(gs.world_flags.get("festival_seen_dragon_boat_festival", -1)), Calendar.year_of(141))
	gs.world_flags.erase("festival_seen_dragon_boat_festival")
	gs.current_region = "misty_forest"
	gs._pass_time(1)
	assert_false(gs.world_flags.has("festival_seen_dragon_boat_festival"), "elsewhere is not seen")


## WILD-016: the village hunt is offered in its window, once a season, with the hunters' strike and doubled spoils.
func test_village_hunt() -> void:
	_start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	GameClock.total_days = 188  # autumn day 9
	assert_eq(gs.village_hunt_quarry(), "", "before the first market day")
	GameClock.total_days = 189  # autumn day 10, the first market day
	assert_eq(gs.village_hunt_quarry(), "mist_fox")
	GameClock.total_days = 192
	assert_eq(gs.village_hunt_quarry(), "", "window over")
	GameClock.total_days = 190
	gs.player.realm_index = 3
	var npc_id := ""
	for id: String in gs.npcs:
		if gs.npcs[id].alive and gs.npcs[id].home_region == "qingshi_village":
			npc_id = id
			break
	var favor_before: int = int(gs.npc_favor.get(npc_id, 0))
	var won: bool = gs.join_village_hunt()
	assert_eq(int(gs.world_flags[VillageHunt.FLAG]), 180)
	assert_eq(gs.hunt_ally, {}, "ally cleared")
	assert_eq(gs.village_hunt_quarry(), "", "once a season")
	if won and npc_id != "":
		assert_eq(int(gs.npc_favor.get(npc_id, 0)), mini(100, favor_before + 1))
	GameClock.total_days = 189 + 90  # winter day 10
	assert_eq(gs.village_hunt_quarry(), "den_wolf", "next season again")
	GameClock.total_days = 189 + 180  # spring
	assert_eq(gs.village_hunt_quarry(), "fog_antler_stag")
	gs.current_region = "misty_forest"
	GameClock.total_days = 189
	assert_eq(gs.village_hunt_quarry(), "", "only where the hunt is posted")
	assert_false(gs.join_village_hunt())
	gs.end_session()


## WILD-017: the hunt takes its days, doubles the report's spoils, favours the hunter, shows on Today.
func test_village_hunt_days_and_hunter() -> void:
	_start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	gs.player.realm_index = 3
	GameClock.total_days = 189
	var today := Guidance.today_lines(gs.player, gs.data, gs.world_flags, gs.world_events, 189, "qingshi_village", gs.npcs, gs.npc_favor)
	assert_true(" ".join(today).contains("The village hunt rides out after the"), "today line")
	var hunter_id := ""
	for id: String in gs.npcs:
		if gs.npcs[id].alive and gs.npcs[id].home_region == "qingshi_village":
			hunter_id = id
			break
	gs.data.npcs[hunter_id] = {"id": hunter_id, "hunter": true}
	gs.npc_favor[hunter_id] = 0
	var days := int(VillageHunt.def(gs.data, "qingshi_village")["days"])
	var won: bool = gs.join_village_hunt()
	assert_true(GameClock.total_days >= 189 + days, "the hunt takes its days")
	assert_eq(gs.current_region, "qingshi_village")
	assert_eq(int(gs.world_flags[VillageHunt.FLAG]), 180, "spent win or lose")
	if won and gs.npcs[hunter_id].alive:
		assert_eq(int(gs.npc_favor[hunter_id]), 3, "+1 village, +2 hunter")
	if won:
		assert_eq(String(gs.world_flags["village_news"]["kind"]), "village_hunt", "FOLK-034")
	gs.end_session()


## TODAY-001: the wrapper reads the live session.
func test_today_lines_wrapper() -> void:
	var gs := _game_state()
	_start()
	GameClock.total_days = 268
	gs.current_region = "misty_forest"
	assert_eq(gs.today_lines(), Guidance.today_lines(gs.player, gs.data, gs.world_flags, gs.world_events, 268, "misty_forest", gs.npcs, gs.npc_favor))
	assert_true(gs.today_lines().size() <= Guidance.TODAY_MAX)


func test_arrival_never_posts_a_season_line_twice() -> void:  # WU-464
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	gs.data.road = {}
	EventBus.clear_history()
	var route: Dictionary = gs.data.regions[gs.data.start_region]["routes"][0]
	gs.travel(String(route["to"]))
	var seen := {}
	for m: Dictionary in EventBus.history:
		if String(m["text"]).contains(" run in "):
			assert_false(seen.has(m["text"]), "season sentence posted once")
			seen[m["text"]] = true
	var sc := Wildlife.season_clause(gs.data, gs.current_region, GameClock.total_days)
	if sc != "":
		var n := 0
		for m: Dictionary in EventBus.history:
			if String(m["text"]).contains(sc):
				n += 1
		assert_eq(n, 1, "in-season sentence appears in one message")


func _today_lines_count() -> int:  # TODAY-002
	var n := 0
	for m: Dictionary in EventBus.history:
		if String(m["text"]).begins_with("Today in"):
			n += 1
	return n


func test_new_session_posts_arrival_line_once() -> void:  # TODAY-002
	_start()
	var gs := _game_state()
	gs.call("_post_arrival_line")  # a second caller on the same day and region posts nothing more
	gs.call("_post_arrival_line")
	assert_true(_today_lines_count() <= 1, "the arrival line is posted at most once")


func test_season_line_posted_once_per_season_and_region() -> void:  # TODAY-002
	_start()
	var gs := _game_state()
	var region := "misty_forest"
	var season_day := -1
	for d in range(0, Calendar.DAYS_PER_YEAR):
		if Wildlife.season_clause(gs.data, region, d) != "":
			season_day = d
			break
	assert_true(season_day >= 0, "misty forest has an in-season beast")
	GameClock.total_days = season_day
	gs.current_region = region
	gs.world_flags.erase("season_line_seen")
	EventBus.clear_history()
	var clause := Wildlife.season_clause(gs.data, region, season_day)
	gs.call("_post_arrival_line")
	gs.current_region = "qingshi_village"
	gs.call("_post_arrival_line")
	gs.current_region = region
	gs.call("_post_arrival_line")
	var count := 0
	for m: Dictionary in EventBus.history:
		if String(m["text"]).contains(clause):
			count += 1
	assert_eq(count, 1, "the in-season line is posted once for the season")
	GameClock.total_days = season_day + Calendar.DAYS_PER_YEAR
	gs.current_region = "qingshi_village"
	gs.call("_post_arrival_line")
	gs.current_region = region
	gs.call("_post_arrival_line")
	count = 0
	for m: Dictionary in EventBus.history:
		if String(m["text"]).contains(clause):
			count += 1
	assert_eq(count, 2, "and again the next year's season")


## FOLK-018: a gift is remembered: next chat within 30 days posts one line, once.
func test_gift_memory_line_posts_once_then_expires() -> void:
	var c := _start()
	var gs := _game_state()
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(8), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var liked := ""
	for item_id: String in gs.data.items:
		if Family.gift_taste(gs.data, npc.id, item_id) > 0 and Family.gift_value(gs.data, item_id) > 0:
			liked = item_id
			break
	c.add_item(liked, 1)
	gs.npc_favor[npc.id] = 0
	gs.give_gift(npc.id, liked)
	var entry_text := Folk.last_gift_text(gs.world_flags, npc.id, gs.data)
	assert_true(entry_text.begins_with("Last gift: ") and entry_text.ends_with("(liked)"), entry_text)
	gs.world_flags["gift_memory"][npc.id]["day"] = GameClock.total_days - 1  # "the next day"
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.chat(npc.id)
	var first := "\n".join(_zero_round_posts)
	assert_true(first.contains(npc.name + ": \""), first)
	_zero_round_posts.clear()
	gs.chat(npc.id)
	EventBus.message_posted.disconnect(_collect_post)
	assert_false("\n".join(_zero_round_posts).contains(npc.name + ": \""), "once only")


## FOLK-019: named villagers with a dialogue file remember gifts and news too, one line per talk.
func test_named_npc_remembers_gift_then_news() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	c.add_item("venison", 1)
	gs.npc_favor["hunter_ma"] = 0
	gs.give_gift("hunter_ma", "venison")
	gs.world_flags["gift_memory"]["hunter_ma"]["day"] = GameClock.total_days - 1
	Folk.record_news(gs.world_flags, "contest_win", "the festival", "qingshi_village", GameClock.total_days)
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.start_dialogue("hunter_ma")
	var first := "\n".join(_zero_round_posts)
	assert_true(first.contains("Hunter Ma: \""), "gift memory line: " + first)
	assert_eq(first.count("Hunter Ma: \""), 1, "only one line per talk")
	_zero_round_posts.clear()
	gs.start_dialogue("hunter_ma")  # news now, once
	assert_eq("\n".join(_zero_round_posts).count("Hunter Ma: \""), 1, "news line next talk")
	_zero_round_posts.clear()
	gs.start_dialogue("hunter_ma")
	EventBus.message_posted.disconnect(_collect_post)
	assert_false("\n".join(_zero_round_posts).contains("Hunter Ma: \""), "nothing the third time")


## FOLK-020: Hunter Ma teaches once when you are close; saved; old saves teach on the next talk.
func test_close_friend_teaches_lesson_once() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 59
	gs.start_dialogue("hunter_ma")
	assert_false(c.lessons_taught.has("hunter_ma:0"), "not yet close")
	gs.npc_favor["hunter_ma"] = 62
	_zero_round_posts.clear()
	EventBus.message_posted.connect(_collect_post)
	gs.start_dialogue("hunter_ma")
	EventBus.message_posted.disconnect(_collect_post)
	assert_true(c.lessons_taught.has("hunter_ma:0"), "taught")
	assert_true("\n".join(_zero_round_posts).contains("read a track"), "line posted")
	var reloaded := CharacterData.from_dict(c.to_dict())
	assert_true(reloaded.lessons_taught.has("hunter_ma:0"), "saved")
	c.lessons_taught.clear()  # a save from before the feature
	gs.start_dialogue("hunter_ma")
	assert_true(c.lessons_taught.has("hunter_ma:0"), "taught on next talk")
	var day: int = c.lessons_taught["hunter_ma:0"]
	gs.start_dialogue("hunter_ma")
	assert_eq(int(c.lessons_taught["hunter_ma:0"]), day, "not taught twice")
	assert_eq(gs.lessons_for("hunter_ma").size(), 2)
	assert_true(gs.lessons_for("hunter_ma")[0]["taught"])


## COOK-001: a lesson with learn_dish adds the dish.
func test_lesson_teaches_a_dish() -> void:
	var c := _start()
	var gs := _game_state()
	gs.current_region = "qingshi_village"
	var lessons: Array = gs.data.npcs["hunter_ma"]["lessons"]
	lessons[0]["effects"] = {"learn_dish": "boar_roast"}
	gs.npc_favor["hunter_ma"] = 62
	gs.start_dialogue("hunter_ma")
	assert_true(c.known_dishes.has("boar_roast"))


## WILD-021: beating the last beast of the trail finishes it once: flag, line, milestone, news; survives a save.
func test_great_trail_finish() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "misty_forest"
	gs.player.realm_index = 5
	var def: Dictionary = gs.data.regions["misty_forest"]["roamers"]["great"]
	var chain := Wildlife.great_chain(def)
	for step: Dictionary in chain:
		step.erase("max_realm")
	for i in chain.size():
		GameClock.total_days = 7 * (60 + i * 2) + Wildlife.great_day("misty_forest", def)
		assert_true(gs.engage_roamer(Wildlife.GREAT_SLOT), "step %d" % i)
		var done: bool = gs.world_flags.has(Wildlife.trail_flag("misty_forest"))
		assert_eq(done, i == chain.size() - 1, "trail done only after the last step (%d)" % i)
	assert_eq(String(gs.world_flags["village_news"]["kind"]), "great_trail")
	gs.check_milestones()
	assert_true(gs.player.milestones.has("great_trail_misty_forest"))
	var restored := _game_state()
	restored.load_save_dict(gs.to_save_dict())
	assert_true(restored.world_flags.has(Wildlife.trail_flag("misty_forest")))


func test_season_review_emits_once_per_boundary() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var seen: Array = []
	var cb := func(season: String, _year: int, lines: PackedStringArray) -> void: seen.append([season, lines])
	bus.season_reviewed.connect(cb)
	LifeStats.add(c, "fights_won", 2)
	clock.advance(3 * Calendar.DAYS_PER_MONTH)  # spring -> summer
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], "Spring")
	var won2: Array = []  # SEASON-014: the wording is any recap template
	for t: String in GameState.data.season_tasks["recap"]["fights_won"]:
		won2.append(t.replace("{n}", "2").replace("{s}", "s"))
	assert_true(won2.any(func(t: String) -> bool: return t in (seen[0][1] as PackedStringArray)))
	assert_false(Array(seen[0][1] as PackedStringArray).any(func(l: String) -> bool: return l.begins_with("Coming:")), "WU-534: no Coming line in the look back")
	clock.advance(6 * Calendar.DAYS_PER_MONTH)  # summer -> autumn -> winter in one call
	assert_eq(seen.size(), 2)
	assert_eq(seen[1][0], "Autumn")
	# winter -> spring: log only, no banner signal (the year review shows)
	LifeStats.add(c, "fights_won", 1)
	clock.advance(3 * Calendar.DAYS_PER_MONTH)
	bus.season_reviewed.disconnect(cb)
	assert_eq(seen.size(), 2)
	var logged := false
	for m in bus.history:
		if String(m["text"]) in (GameState.data.season_tasks["recap"]["fights_won"] as Array).map(func(t: String) -> String: return t.replace("{n}", "1").replace("{s}", "")):
			logged = true
	assert_true(logged, "the winter line is logged")


func test_season_review_skips_old_save() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var d := c.to_dict()
	d.erase("season_start_stats")
	d.erase("season_start_day")
	var old := CharacterData.from_dict(d)
	assert_eq(old.season_start_day, -1)
	_game_state().player = old
	var seen: Array = []
	var cb := func(_s: String, _y: int, _l: PackedStringArray) -> void: seen.append(1)
	bus.season_reviewed.connect(cb)
	clock.advance(3 * Calendar.DAYS_PER_MONTH)
	bus.season_reviewed.disconnect(cb)
	assert_eq(seen.size(), 0)
	assert_true(old.season_start_day >= 0)
	var rt := CharacterData.from_dict(old.to_dict())
	assert_eq(rt.season_start_day, old.season_start_day)
	assert_eq(rt.season_start_stats, old.season_start_stats)


func test_season_kickoff_follows_recap() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var order: Array = []
	var a := func(_s: String, _y: int, _l: PackedStringArray) -> void: order.append("recap")
	var b := func(s: String, _y: int, l: PackedStringArray) -> void: order.append("kick:" + s + ":" + str(l.size()))
	var yr := func(_y: int, _l: PackedStringArray, _sy: int) -> void: order.append("year")
	bus.season_reviewed.connect(a)
	bus.season_began.connect(b)
	bus.year_reviewed.connect(yr)
	LifeStats.add(c, "fights_won", 1)
	clock.advance(3 * Calendar.DAYS_PER_MONTH)  # spring -> summer
	assert_eq(order.size(), 2)
	assert_eq(order[0], "recap")
	assert_true(String(order[1]).begins_with("kick:Summer:"))
	order.clear()
	clock.advance(6 * Calendar.DAYS_PER_MONTH)  # -> winter
	clock.advance(3 * Calendar.DAYS_PER_MONTH)  # winter -> spring: year review, then kickoff
	bus.season_reviewed.disconnect(a)
	bus.season_began.disconnect(b)
	bus.year_reviewed.disconnect(yr)
	# both are emitted in the same day change; the HUD shows the year review first (pending kickoff waits)
	assert_true(order.has("year"))
	var kicked := false
	for o in order:
		if String(o).begins_with("kick:Spring:"):
			kicked = true
	assert_true(kicked)


func test_season_recap_names_a_finished_project_stage() -> void:  # GUIDE-224
	var c := _start()
	var clock := _root().get_node("GameClock")
	var bus := _root().get_node("EventBus")
	var seen: Array = []
	var cb := func(_s: String, _y: int, lines: PackedStringArray) -> void: seen.append(lines)
	bus.season_reviewed.connect(cb)
	clock.advance(Calendar.DAYS_PER_MONTH)
	c.season_start_sets = c.seasons_completed.size()
	c.seasons_completed.append("test_season_a")
	clock.advance(2 * Calendar.DAYS_PER_MONTH)  # the season ends
	bus.season_reviewed.disconnect(cb)
	assert_eq(seen.size(), 1)
	var expected: String = SeasonTasks.project_recap_line(_game_state().data, c.seasons_completed.size() - 1, c.seasons_completed.size())
	assert_true(expected != "")
	assert_true(expected in (seen[0] as PackedStringArray), "project line in recap")


func test_season_recap_without_a_finished_stage_or_snapshot() -> void:  # GUIDE-224
	var d: GameData = _game_state().data
	assert_eq(SeasonTasks.project_recap_line(d, 3, 3), "")
	assert_eq(SeasonTasks.project_recap_line(d, -1, 5), "", "old save: no snapshot")
	var line := SeasonTasks.project_recap_line(d, 0, 1)
	assert_true(line != "" and line.length() <= 80)
	var old := CharacterData.from_dict({})
	assert_eq(old.season_start_sets, -1)


## FISH-008: a first fishing trip that comes home empty lands the common fish.
func test_fishing_beginners_luck_once() -> void:
	var c := _start()
	var gs := _game_state()
	_set_weather(gs, "clear")
	var table := [{"item": "", "weight": 1000}, {"item": "silver_carp", "weight": 3, "min": 1, "max": 1}]
	c.catch_log = {}
	var got := 0
	for i in 30:
		gs.fish(table, 1, "", 0.0)
		got = c.item_count("silver_carp")
		if got > 0:
			break
	assert_eq(got, 1, "the first trips always end with exactly one fish by luck or draw")
	assert_true(c.catch_log.has("silver_carp"))
	var before := c.item_count("silver_carp")
	var empty := [{"item": "", "weight": 1}]
	gs.fish(empty, 1, "", 0.5)
	assert_eq(c.item_count("silver_carp"), before, "no beginner fish once one has been caught")
	_restore_weather(gs)


## GUIDE-233: a first trip that got away posts only the beginner's-luck line, never "got away".
func test_fishing_first_trip_slipped_has_one_line() -> void:
	var c := _start()
	var gs := _game_state()
	_set_weather(gs, "clear")
	var table := [{"item": "", "weight": 1000}, {"item": "silver_carp", "weight": 3, "min": 1, "max": 1}]
	var checked := false
	for seed_i in 200:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_i
		if not Fishing.got_away(0.0, probe):
			continue
		c.catch_log = {}
		gs.rng.seed = seed_i
		EventBus.history.clear()
		gs.fish(table, 1, "", 0.0)
		var texts: Array = EventBus.history.map(func(e: Dictionary) -> String: return String(e["text"]))
		assert_false(texts.has(Fishing.GOT_AWAY), "no contradicting line")
		assert_true(texts.any(func(t: String) -> bool: return t.begins_with("A fish takes the bait and slips free")), str(texts))
		checked = true
		break
	assert_true(checked)
	_restore_weather(gs)


func test_slipped_first_cast_posts_one_fishing_line() -> void:  # FISH-010
	var c := _start()
	var gs := _game_state()
	_set_weather(gs, "clear")
	var table := [{"item": "", "weight": 1000}, {"item": "silver_carp", "weight": 3, "min": 1, "max": 1}]
	for seed_i in 200:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_i
		if not Fishing.got_away(0.0, probe):
			continue
		c.catch_log = {}
		gs.rng.seed = seed_i
		EventBus.history.clear()
		gs.fish(table, 1, "", 0.0)
		var texts: Array = EventBus.history.map(func(e: Dictionary) -> String: return String(e["text"]))
		var slips := texts.filter(func(t: String) -> bool: return t.begins_with("A fish takes the bait and slips free") or t == Fishing.GOT_AWAY)
		assert_eq(slips.size(), 1, str(texts))
		assert_false(texts.has(Fishing.GOT_AWAY))
		break
	_restore_weather(gs)


## FISH-009: a fresh character's first trip at the Qingshi jetty always lands a fish and posts exactly one
## beginner's-luck line, in every season, on clear and rain days, whatever the cast quality or rng.
func test_fishing_first_trip_in_qingshi_never_empty() -> void:
	var gs := _game_state()
	var places := (gs.data.regions["qingshi_village"]["places"] as Array).filter(func(p: Dictionary) -> bool: return p.get("type", "") == "fishing")
	assert_false(places.is_empty())
	var table: Array = places[0]["catch_table"]
	for season_i in 4:
		for kind in ["clear", "rain"]:
			for quality in [0.0, 0.5, 1.0]:
				for seed_i in 25:
					var c := _start(seed_i + 1)
					_set_weather(gs, kind)
					gs.rng.seed = seed_i * 7 + 3
					_root().get_node("GameClock").total_days = season_i * 3 * Calendar.DAYS_PER_MONTH + 2
					EventBus.history.clear()
					gs.fish(table, 2, "Village Pond Jetty", quality)
					var texts: Array = EventBus.history.map(func(e: Dictionary) -> String: return String(e["text"]))
					var ctx := "season %d %s q=%s seed %d: %s" % [season_i, kind, quality, seed_i, str(texts)]
					var fish_count := 0
					for id: String in c.inventory:
						if "fish" in gs.data.items.get(id, {}).get("tags", []):
							fish_count += int(c.inventory[id])
					assert_true(fish_count >= 1, ctx)
					var luck := texts.filter(func(t: String) -> bool: return t.contains("Beginner's luck"))
					var natural := texts.any(func(t: String) -> bool: return t.contains("You fish for") and t.contains("+"))
					assert_true(luck.size() == 1 or natural, ctx)
					assert_false(texts.any(func(t: String) -> bool: return t.contains("nothing bites")), ctx)
					assert_false(luck.size() == 1 and texts.has(Fishing.GOT_AWAY), ctx)
	_restore_weather(gs)


# --- CAL-010: the village almanac ---------------------------------------------

func _force_omen(gs: Node, effects: Dictionary) -> void:
	gs.data.almanac["omens"] = [{"id": "t", "name": "Test omen", "text": "t", "weight": 1, "boost": effects}]


func test_almanac_lines_for_the_journal() -> void:
	_start()
	var gs := _game_state()
	_force_omen(gs, {"fishing_mult": 1.2})
	assert_eq(String(gs.today_omen()["id"]), "t")
	var lines: PackedStringArray = gs.almanac_lines()
	assert_eq(lines.size(), 2)
	assert_true(lines[0].begins_with("Almanac: Test omen"))
	assert_eq(lines[1], "Tomorrow: Test omen.")
	_restore_weather(gs)


func test_almanac_plain_day_gather_keeps_rng_sequence() -> void:
	var c := _start(77)
	var gs := _game_state()
	_force_omen(gs, {})
	var table := [{"item": "spirit_herb", "weight": 1, "min": 1, "max": 1}]
	gs.rng.seed = 5
	gs.gather(table, 1)
	var plain := c.item_count("spirit_herb")
	_force_omen(gs, {"gather_bonus": 0.25})
	gs.rng.seed = 5
	gs.gather(table, 1)
	assert_true(c.item_count("spirit_herb") - plain >= plain, "a lucky day never yields less")
	_restore_weather(gs)


func test_almanac_gift_favor_and_sell_and_practice() -> void:
	var c := _start()
	var gs := _game_state()
	Npcs.ensure_all(gs.npcs, gs.data, seeded_rng(5))
	c.add_item("qi_gathering_pill", 2)
	_force_omen(gs, {})
	gs.npc_favor["elder_mo"] = 0
	gs.give_gift("elder_mo", "qi_gathering_pill")
	var plain := int(gs.npc_favor["elder_mo"])
	_force_omen(gs, {"gift_favor": 2})
	gs.npc_favor["elder_mo"] = 0
	GameClock.total_days += 3
	gs.give_gift("elder_mo", "qi_gathering_pill")
	assert_true(int(gs.npc_favor["elder_mo"]) >= plain, "a gift omen never lowers favor")
	# selling
	c.add_item("spirit_herb", 20)
	_force_omen(gs, {})
	var before := c.item_count("spirit_stone")
	gs.sell_item("spirit_herb", 10)
	var base_gain := c.item_count("spirit_stone") - before
	_force_omen(gs, {"sell_mult": 1.1})
	before = c.item_count("spirit_stone")
	gs.sell_item("spirit_herb", 10)
	assert_true(c.item_count("spirit_stone") - before >= base_gain)
	_restore_weather(gs)


## SECT-006: the steward's chore pays contribution toward the monthly duty and takes a day.
func test_sect_hall_steward_chore() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 1
	gs.join_sect("azure_cloud_sect")
	assert_eq(c.sect.get("id", ""), "azure_cloud_sect")
	var before := Sects.duty_progress(c)
	var stones := c.item_count("spirit_stone")
	var day: int = _root().get_node("GameClock").total_days
	gs.perform_deed("hall_chore_azure_light")
	assert_eq(Sects.duty_progress(c), before + 5)
	assert_eq(c.item_count("spirit_stone"), stones + 1)
	assert_eq(_root().get_node("GameClock").total_days, day + 1)


## CAL-011: dawn posts exactly one almanac line on a non-plain day and none on a plain day.
func test_almanac_dawn_line() -> void:
	var gs := _game_state()
	_start()
	gs.current_region = "qingshi_village"
	var salt := Almanac.salt_of(gs.player)
	var plain_day := -1
	var lucky_day := -1
	for day in range(5, 300):
		var plain := Almanac.is_plain(Almanac.omen_for(gs.data, day, salt))
		if plain and plain_day < 0:
			plain_day = day
		if not plain and lucky_day < 0:
			lucky_day = day
	for pair in [[plain_day, 0], [lucky_day, 1]]:
		GameClock.total_days = int(pair[0]) - 1
		gs._last_reminder_day = -1
		var before := EventBus.history.size()
		gs._pass_time(1)
		var n := 0
		for i in range(before, EventBus.history.size()):
			if String(EventBus.history[i]["category"]) == "almanac":
				n += 1
		assert_eq(n, int(pair[1]), "almanac lines on day %d" % int(pair[0]))


## GUIDE-237: arriving somewhere the ordinary beasts would kill you warns once per season.
func test_travel_warns_about_deadly_beasts_once_per_season() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var region := "myriad_peaks_ridge"
	assert_true(Wildlife.is_grave(String(Wildlife.region_threat(c, gs.data, region, GameClock.total_days)["label"])))
	var seen := [0]
	var cb := func(text: String, category: String) -> void:
		if category == "danger" and text.begins_with("The beasts of"):
			seen[0] += 1
	EventBus.message_posted.connect(cb)
	gs._warn_beasts(region, GameClock.total_days)
	gs._warn_beasts(region, GameClock.total_days)
	EventBus.message_posted.disconnect(cb)
	assert_eq(seen[0], 1)
	assert_true(gs.world_flags.has("warned_" + region))


## GUIDE-237: the warning belongs to the season you arrive in, so a trip that crosses a season boundary warns again.
func test_beast_warning_uses_the_arrival_season() -> void:
	var gs := _game_state()
	var c := _start()
	c.realm_index = 1
	var region := "myriad_peaks_ridge"
	var season_len := Calendar.DAYS_PER_MONTH * 3
	var last_autumn_day := season_len * 3 - 1
	var departure := last_autumn_day - 1
	assert_true(Calendar.season_of(departure) != Calendar.season_of(departure + 3), "the trip crosses a season")
	gs._warn_beasts(region, departure)
	var departure_season := int(gs.world_flags["warned_" + region])
	gs._warn_beasts(region, departure + 3)
	assert_true(int(gs.world_flags["warned_" + region]) != departure_season, "arrival in the next season warns again")


func test_artifact_drinks_growth_and_hums() -> void:
	var gs := _game_state()
	var c := _start()
	var bus := _root().get_node("EventBus")
	var before := c.artifact_energy
	c.stage = 0
	ArtifactFunctions.sync_marks(c)
	c.stage += 1
	gs._pass_time(1)
	assert_eq(c.artifact_energy, before + 15, "a stage up feeds the artifact")
	c.stage += 1
	gs._pass_time(0)
	assert_eq(c.artifact_energy, before + 30)
	# crossing the unseal threshold hums once
	c.realm_index = gs.data.realm_index_of("qi_refining")
	ArtifactFunctions.sync_marks(c)
	c.artifact_energy = 99
	c.stage += 1
	var count: int = bus.posted_count
	gs._pass_time(1)
	assert_gt(bus.posted_count, count)
	assert_true(gs.world_flags.get("artifact_hum_storage", false), "the hum is recorded")
	assert_true(Guidance.hints(c, gs.data, 1.0, 12, {}, gs.world_flags).has("Unseal Storage Space in the artifact (O)"))
	ArtifactFunctions.unlock(c, gs.data, "storage", gs.world_flags)
	assert_false(Guidance.hints(c, gs.data, 1.0, 12, {}, gs.world_flags).has("Unseal Storage Space in the artifact (O)"), "hint gone once unsealed")


## REVIEW: folded energy gains of one session never show up in the next one's first energy line.
func test_new_session_drops_folded_artifact_gains() -> void:
	var gs := _game_state()
	_start()
	gs._artifact_pending = 25
	gs._artifact_line_day = GameClock.total_days
	_start()
	assert_eq(gs._artifact_pending, 0)
	assert_eq(gs._artifact_line_day, -1)
	gs._artifact_pending = 25
	gs.load_save_dict(gs.to_save_dict())
	assert_eq(gs._artifact_pending, 0)


## LOG-002: the "artifact drinks the change" line posts once a week; gains in between fold into the next line.
func test_artifact_energy_line_posts_once_a_week() -> void:
	var gs := _game_state()
	_start()
	var bus := _root().get_node("EventBus")
	gs._artifact_wakes(10)
	assert_eq(gs._artifact_pending, 0, "the first gain posts")
	var count: int = bus.posted_count
	gs._artifact_wakes(10)
	assert_eq(bus.posted_count, count, "no second line inside the window")
	assert_eq(gs._artifact_pending, 10, "the gain is folded, not lost")
	gs._artifact_line_day -= GameState.ARTIFACT_LINE_DAYS
	gs._artifact_wakes(5)
	assert_eq(gs._artifact_pending, 0, "the next week's line carries the folded gains")
	assert_gt(bus.posted_count, count)


func test_artifact_first_win_feeds_once() -> void:
	var gs := _game_state()
	var c := _start()
	c.artifact_energy = 0
	for i in 12:
		if c.artifact_won.has("wild_boar"):
			break
		c.qi = 0.0
		gs.fight("wild_boar")
		if not c.alive:
			break
	assert_true(c.artifact_won.has("wild_boar"))
	var after_first := c.artifact_energy
	assert_true(after_first >= 5)
	gs.fight("wild_boar")
	assert_true(c.artifact_energy <= after_first, "no second first-win")


## SEASON-021: a won explore fight advances the season hunt.
func test_explore_win_counts_for_the_season_hunt() -> void:
	_start()
	var gs := _game_state()
	GameClock.total_days = 5
	gs.player.season_tasks = {}
	var hunt_n := func() -> int:
		for t: Dictionary in SeasonTasks.list(gs.player, gs.data, GameClock.total_days):
			if String(t["text"]).contains("Boar"):
				return int(t["n"])
		return -1
	assert_eq(hunt_n.call(), 0)
	gs.start_session(CharacterFactory.create("Boar", gs.data, seeded_rng(5)))
	GameClock.total_days = 5
	gs.player.realm_index = 2
	assert_true(gs._explore_fight("wild_boar"), "strong player wins")
	assert_eq(hunt_n.call(), 1, "the won explore fight counts")
	gs.end_session()


func test_buy_hint_is_remembered_for_the_hinted_region() -> void:
	var gs := _game_state()
	_start()
	var other := ""
	for id: String in gs.data.regions:
		if id != gs.current_region and Exploration.region_name(gs.data, id) != "":
			other = id
			break
	assert_true(other != "")
	var item_name := String(gs.data.items["qi_gathering_pill"]["name"])
	gs.note_buy_hint("Buy a %s in %s." % [item_name, Exploration.region_name(gs.data, other)])
	assert_eq(gs.buy_hints.get(other, []), ["qi_gathering_pill"])
	gs.note_buy_hint("Nothing to buy here.")
	assert_eq(gs.buy_hints.get(other, []), ["qi_gathering_pill"])
	# SHOP-005: a non-buy hint that names an item and a region is not remembered.
	gs.buy_hints.clear()
	gs.note_buy_hint("Sell your %s in %s." % [item_name, Exploration.region_name(gs.data, other)])
	assert_false(gs.buy_hints.has(other))
	gs.note_buy_hint("Buy a %s in %s." % [item_name, Exploration.region_name(gs.data, other)])
	gs.buy_hints.clear()


## [REVIEW] SHOP-002: a remembered buy hint is cleared by buying the item there and never outlives the session.
func test_buy_hint_clears_on_buy_and_new_session() -> void:
	var gs := _game_state()
	var c := _start()
	gs.buy_hints[gs.current_region] = ["qi_gathering_pill"]
	c.add_item("spirit_stone", 10000)
	gs.buy_item("qi_gathering_pill")
	assert_false(gs.buy_hints.has(gs.current_region), "bought: the errand is done")
	gs.buy_hints["somewhere"] = ["qi_gathering_pill"]
	_start()
	assert_true(gs.buy_hints.is_empty(), "a new character starts with no remembered errands")


## SHOP-004: every item a hint names is remembered (max 4, newest first), buying clears only that one, and saves keep them.
func test_buy_hints_remember_several_and_save() -> void:
	var gs := _game_state()
	_start()
	var other := ""
	for id: String in gs.data.regions:
		if id != gs.current_region and Exploration.region_name(gs.data, id) != "":
			other = id
			break
	var a := String(gs.data.items["qi_gathering_pill"]["name"])
	var b := String(gs.data.items["spirit_stone"]["name"])
	gs.note_buy_hint("Buy a %s in %s." % [a, Exploration.region_name(gs.data, other)])
	gs.note_buy_hint("Buy %s in %s." % [b, Exploration.region_name(gs.data, other)])
	assert_eq(gs.buy_hints[other], ["spirit_stone", "qi_gathering_pill"], "newest first, both kept")
	var d: Dictionary = gs.to_save_dict()
	assert_eq(d["buy_hints"][other], ["spirit_stone", "qi_gathering_pill"])
	gs.buy_hints = {}
	gs.load_save_dict(d)
	assert_eq(gs.buy_hints[other], ["spirit_stone", "qi_gathering_pill"], "round-trips")
	d.erase("buy_hints")
	gs.load_save_dict(d)
	assert_true(gs.buy_hints.is_empty(), "an old save without the key loads with {}")
	gs.buy_hints[gs.current_region] = ["qi_gathering_pill", "spirit_stone"]
	gs.buy_hints[gs.current_region] = ["qi_gathering_pill", "spirit_stone"]
	gs.player.add_item("spirit_stone", 10000)
	gs.buy_item("qi_gathering_pill")
	assert_eq(gs.buy_hints[gs.current_region], ["spirit_stone"], "buying one clears only that one")


func test_hunter_ma_teaches_iron_fist() -> void:
	var gs := _game_state()
	var c := _start()
	gs.npc_favor["hunter_ma"] = 0
	gs.start_dialogue("hunter_ma")
	var locked := false
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Show me how you fight"):
			locked = bool(ch["disabled"])
	assert_true(locked, "at favor 0 the lesson is shown locked")
	gs.end_dialogue()
	gs.npc_favor["hunter_ma"] = 15
	gs.start_dialogue("hunter_ma")
	var idx := -1
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Show me how you fight"):
			assert_false(bool(ch["disabled"]))
			idx = int(ch["index"])
	assert_true(idx >= 0)
	gs.choose_dialogue(idx)
	var day := GameClock.total_days
	var train := -1
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Train with him"):
			train = int(ch["index"])
	assert_true(train >= 0)
	gs.choose_dialogue(train)
	assert_true(c.techniques.has("iron_fist"), "he taught the punch")
	assert_eq(GameClock.total_days - day, 5, "five days of training")
	gs.start_dialogue("hunter_ma")
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Show me how you fight"):
			assert_true(bool(ch["disabled"]), "locked once learned")
	gs.end_dialogue()


## C-363: after the lesson Hunter Ma hides it and offers a spar (favor once a week); a bought manual never sees the lesson.
func test_hunter_ma_after_the_lesson() -> void:
	var gs := _game_state()
	var c := _start()
	gs.npc_favor["hunter_ma"] = 15
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}  # bought the manual
	gs.start_dialogue("hunter_ma")
	var spars: Array[int] = []
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		assert_false(String(ch["label"]).begins_with("Show me how you fight"), "lesson hidden")
		if String(ch["label"]).begins_with("Spar with me"):
			spars.append(int(ch["index"]))
	assert_eq(spars.size(), 1, "one spar choice listed")
	var day := GameClock.total_days
	gs.choose_dialogue(spars[0])
	assert_eq(GameClock.total_days - day, 1, "one day")
	assert_eq(int(gs.npc_favor["hunter_ma"]), 16, "+1 favor the first time")
	gs.start_dialogue("hunter_ma")
	spars.clear()
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Spar with me"):
			spars.append(int(ch["index"]))
	assert_eq(spars.size(), 1, "still one listed")
	gs.choose_dialogue(spars[0])
	assert_eq(int(gs.npc_favor["hunter_ma"]), 16, "no more favor within the week")
	GameClock.total_days += 8
	gs.start_dialogue("hunter_ma")
	for ch: Dictionary in gs.dialogue_view()["choices"]:
		if String(ch["label"]).begins_with("Spar with me"):
			gs.choose_dialogue(int(ch["index"]))
			break
	assert_eq(int(gs.npc_favor["hunter_ma"]), 17, "favor again after a week")
	gs.end_dialogue()

func test_fight_enemy_stores_summary_for_an_easy_win_only() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 3
	var weak: Dictionary = gs.data.enemies["wild_boar"].duplicate(true)
	assert_true(gs.fight_enemy(weak))
	assert_eq(gs.last_fight_summary.size(), 2)
	assert_true(gs.last_fight_summary[0].begins_with("You beat"), gs.last_fight_summary[0])
	gs.end_session()
