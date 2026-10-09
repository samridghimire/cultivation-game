extends TestCase
## LW-001: world events (WorldEvents) and their GameState hooks.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_real_data_is_valid() -> void:
	assert_eq(WorldEvents.validate(data()).size(), 0, ", ".join(WorldEvents.validate(data())))
	for event_id in ["beast_tide", "sect_tournament", "auction_season", "demonic_incursion"]:
		assert_true(data().world_events.has(event_id), event_id)


func test_validation_catches_bad_events() -> void:
	var d := GameData.load_from_dir()
	d.world_events["bad"] = {"id": "bad", "monthly_chance": 2.0, "min_days": 0, "max_days": 0, "regions": ["nowhere"], "modifiers": {"weather": 1, "price_mult": 0}}
	assert_eq(WorldEvents.validate(d).size(), 5, ", ".join(WorldEvents.validate(d)))


func test_every_event_tag_has_encounters() -> void:
	var d := data()
	for def: Dictionary in d.world_events.values():
		for tag in def.get("modifiers", {}).get("encounter_tags", []):
			var found := d.encounters.values().any(func(e: Dictionary) -> bool: return (e.get("tags", []) as Array).has(tag))
			assert_true(found, "%s adds tag '%s' but no encounter uses it" % [def["id"], tag])


func test_roll_starts_each_event_once_and_expire_ends_it() -> void:
	var d := data()
	var active: Array = []
	var rng := seeded_rng()
	var started_ids := {}
	for month in 400:
		for ended in WorldEvents.expire(active, month * 30):
			assert_true(int(ended["end_day"]) <= month * 30)
		for started in WorldEvents.roll(d, active, month * 30, rng):
			started_ids[started["id"]] = true
			var def := WorldEvents.def_of(d, started["id"])
			assert_true((def["regions"] as Array).has(started["region"]))
			var days := int(started["end_day"]) - int(started["start_day"])
			assert_true(days >= int(def["min_days"]) and days <= int(def["max_days"]), str(started))
		var ids := active.map(func(i: Dictionary) -> String: return i["id"])
		for id in ids:
			assert_eq(ids.count(id), 1, "%s runs twice at once" % id)
	assert_eq(started_ids.size(), d.world_events.size(), "every event happens over 400 months: %s" % str(started_ids.keys()))
	WorldEvents.expire(active, 1000000)
	assert_true(active.is_empty(), "everything ends eventually")


func test_modifiers_apply_only_in_the_region() -> void:
	var d := data()
	var active: Array = [{"id": "demonic_incursion", "region": "misty_forest", "start_day": 0, "end_day": 60}, {"id": "spirit_qi_tide", "region": "misty_forest", "start_day": 0, "end_day": 60}]
	assert_almost_eq(WorldEvents.qi_multiplier(d, active, "misty_forest"), 0.85 * 1.5)
	assert_almost_eq(WorldEvents.qi_multiplier(d, active, "azure_peak"), 1.0)
	assert_almost_eq(WorldEvents.price_multiplier(d, active, "misty_forest"), 1.15)
	assert_eq(WorldEvents.encounter_tags(d, active, "misty_forest"), ["incursion"] as Array[String])
	assert_true(WorldEvents.encounter_tags(d, active, "azure_peak").is_empty())
	assert_true(WorldEvents.news(d, active[0], true).contains(Exploration.region_name(d, "misty_forest")))
	assert_true(WorldEvents.describe(d, active, 30)[0].contains("left"))
	var base := Reputation.buy_price(new_character(), d, "qi_gathering_pill", "")
	assert_eq(Reputation.buy_price(new_character(), d, "qi_gathering_pill", "", 1.25), roundi(base * 1.25))


func test_game_state_rolls_saves_and_applies_events() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	assert_true(gs.world_events.is_empty())
	gs.current_region = "fallen_star_market"
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": "auction_season", "region": "fallen_star_market", "start_day": day, "end_day": day + 40}]
	assert_almost_eq(gs.market_multiplier(), 1.25)
	c.inventory = {"spirit_stone": 1000}
	var price := Reputation.buy_price(c, gs.data, "qi_gathering_pill", "", 1.25)
	gs.buy_item("qi_gathering_pill")
	assert_eq(c.item_count("spirit_stone"), 1000 - price, "auction season prices")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.world_events = []
	gs.load_save_dict(saved)
	assert_eq(gs.world_events.size(), 1, "active events are saved")
	assert_eq(int(gs.world_events[0]["end_day"]), day + 40)
	saved.erase("world_events")
	gs.load_save_dict(saved)
	assert_true(gs.world_events.is_empty(), "old saves load without events")
	gs.world_events = [{"id": "spirit_qi_tide", "region": "fallen_star_market", "start_day": day, "end_day": day + 40}]
	assert_almost_eq(gs.region_qi_density(), Exploration.qi_density(gs.data, "fallen_star_market") * 1.5)
	gs.cultivate(Calendar.DAYS_PER_MONTH * 2)
	assert_true(gs.world_events.all(func(i: Dictionary) -> bool: return int(i["end_day"]) > _root().get_node("GameClock").total_days), "the tide ended at a month boundary")
	gs.end_session()


func test_event_tags_join_exploration() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.realm_index = 1
	c.stage = 3
	gs.current_region = "fallen_star_market"
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": "sect_tournament", "region": "fallen_star_market", "start_day": day, "end_day": day + 400}]
	var seen := false
	for i in 40:
		gs.pending_encounter = ""
		gs.explore(["no_such_tag_lw001"])
		if gs.pending_encounter == "tournament_bout":
			seen = true
			break
	assert_true(seen, "tournament encounters join the explore pool")
	gs.end_session()


## LW-001b: the HUD names events in the current region; merchants share rumors.
func test_hud_suffix_and_rumors() -> void:
	var d := data()
	var active: Array = [{"id": "beast_tide", "region": "misty_forest", "start_day": 0, "end_day": 45}]
	assert_eq(load("res://src/ui/hud.gd").region_event_suffix(d, active, "misty_forest"), "   Beast Tide!")
	assert_eq(load("res://src/ui/hud.gd").region_event_suffix(d, active, "azure_peak"), "")
	var hud = load("res://src/ui/hud.gd")
	var tournament: Array = [{"id": "sect_tournament", "region": "fallen_star_market", "start_day": 0, "end_day": 40}]
	var cultivator := new_character()
	cultivator.realm_index = 1
	var mortal := new_character()
	mortal.realm_index = 0
	assert_true(hud.region_event_suffix(d, tournament, "fallen_star_market", cultivator).contains("(you can enter)"), "QR can enter")
	assert_false(hud.region_event_suffix(d, tournament, "fallen_star_market", mortal).contains("(you can enter)"), "mortal cannot")
	assert_false(hud.region_event_suffix(d, tournament, "fallen_star_market").contains("(you can enter)"), "no character, no hint")
	var lines := WorldEvents.rumors(d, active, PackedStringArray(["extra"]), 15)
	assert_eq(lines.size(), 2)
	assert_true(lines[0].begins_with("Rumor has it the Beast Tide in %s will last another" % Exploration.region_name(d, "misty_forest")), lines[0])
	assert_eq(lines[1], "extra")
	assert_true(WorldEvents.rumors(d, [], PackedStringArray(), 0)[0].contains("nothing worth gossiping"))
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	var merchant: Node = load("res://src/world/interactables/merchant.gd").new()
	var rumor_option: Dictionary = merchant.get_options()[1]
	assert_eq(rumor_option["label"], "Ask about rumors")
	var bus := _root().get_node("EventBus")
	var posted: Array = []
	var cb := func(text: String, _category: String) -> void: posted.append(text)
	bus.message_posted.connect(cb)
	(rumor_option["action"] as Callable).call()
	bus.message_posted.disconnect(cb)
	assert_true(posted.any(func(t: String) -> bool: return t.contains("Auction House")), str(posted))
	merchant.free()
	gs.end_session()


func test_far_event_news_is_not_posted() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var day: int = _root().get_node("GameClock").total_days
	var posted: Array = []
	var bus := _root().get_node("EventBus")
	var cb := func(text: String, _category: String) -> void: posted.append(text)
	bus.message_posted.connect(cb)
	gs.world_events = [
		{"id": "beast_tide", "region": "azure_peak", "start_day": day - 40, "end_day": day - 1},
		{"id": "auction_season", "region": "qingshi_village", "start_day": day - 40, "end_day": day - 1},
	]
	gs._world_events_month()
	bus.message_posted.disconnect(cb)
	var far_name := Exploration.region_name(gs.data, "azure_peak")
	var near_name := Exploration.region_name(gs.data, "qingshi_village")
	assert_false(posted.any(func(t: String) -> bool: return t.contains(far_name) and t.contains("Beast Tide")), "far end news dropped: %s" % str(posted))
	assert_true(posted.any(func(t: String) -> bool: return t == WorldEvents.news(gs.data, {"id": "auction_season", "region": "qingshi_village"}, false)), "local end news posted: %s" % str(posted))
	assert_true(near_name != "")


func _session_with(event_id: String, region: String, realm_index: int = 1) -> Node:
	var gs := _root().get_node("GameState")
	var c := new_character()
	c.realm_index = realm_index
	c.stage = 2
	gs.start_session(c)
	gs.current_region = region
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": event_id, "region": region, "start_day": day, "end_day": day + 30}]
	return gs


func test_opponents_are_generated_and_scale() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.stage = 2
	var rng := seeded_rng()
	var first := WorldEvents.opponent(d, "sect_tournament", "tournament", c, 0, rng)
	var last := WorldEvents.opponent(d, "sect_tournament", "tournament", c, 2, rng)
	assert_eq(int(first["stage"]), 2)
	assert_eq(int(last["stage"]), 4)
	assert_true(first["spar"] and not first["lethal"])
	assert_eq(WorldEvents.opponent(d, "demonic_incursion", "defence", c, 0, rng)["realm"], d.realms[1].id)


func test_check_join_reasons() -> void:
	var gs := _session_with("sect_tournament", "azure_peak")
	assert_eq(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "tournament", "azure_peak"), "")
	assert_true(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "tournament", "qingshi_village") != "", "wrong region")
	assert_true(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "defence", "azure_peak") != "", "no defence here")
	gs.player.realm_index = 0
	assert_true(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "tournament", "azure_peak") != "", "mortals")
	gs.end_session()


func _overwhelm(c: CharacterData) -> void:
	Buffs.add(c, "test_might", "Test Might", 100000, {"attack": 30.0, "defense": 30.0, "max_hp": 30.0, "speed": 5.0})


func _prize_manuals(c: CharacterData) -> int:
	var n := 0
	for k in c.inventory.keys():
		if String(k).begins_with("manual_"):
			n += 1
	return n


func test_enter_tournament_pays_prize_once() -> void:
	var gs := _session_with("sect_tournament", "azure_peak", 3)
	gs.player.stage = 0
	gs.player.inventory = {"spirit_stone": 0}
	_overwhelm(gs.player)
	gs.enter_tournament("sect_tournament")
	assert_true(bool(gs.world_events[0]["done"]), "event marked done")
	assert_eq(gs.player.item_count("spirit_stone"), 150, "prize stones")
	assert_eq(_prize_manuals(gs.player), 1, "a manual in the prize")
	assert_eq(LifeStats.get_stat(gs.player, "tournaments_won"), 1)
	assert_true(gs.player.milestones.has("tournament_champion"), "milestone awarded")
	gs.enter_tournament("sect_tournament")
	assert_eq(gs.player.item_count("spirit_stone"), 150, "only once per event")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_true(bool(gs.world_events[0]["done"]), "done survives save/load")
	gs.end_session()


func test_enter_tournament_loss_pays_nothing() -> void:
	var gs := _session_with("sect_tournament", "azure_peak", 3)
	gs.player.stage = 0
	gs.player.inventory = {"spirit_stone": 0}
	Buffs.add(gs.player, "test_frail", "Test Frail", 100000, {"attack": -0.95, "defense": -0.95, "max_hp": -0.95, "speed": -0.95})
	var rounds := int(gs.data.world_events["sect_tournament"]["tournament"]["rounds"])
	_bout_logs = []
	EventBus.combat_finished.connect(_on_bout)
	gs.enter_tournament("sect_tournament")
	EventBus.combat_finished.disconnect(_on_bout)
	assert_true(bool(gs.world_events[0]["done"]), "a lost tournament is still used up")
	assert_eq(gs.player.item_count("spirit_stone"), 0, "no prize")
	assert_eq(_prize_manuals(gs.player), 0)
	assert_eq(LifeStats.get_stat(gs.player, "tournaments_won"), 0)
	assert_true(_bout_logs.size() >= 1 and _bout_logs.size() < rounds, "knocked out before the last bout")
	gs.end_session()


func test_tournament_bouts_get_tougher() -> void:
	var gs := _session_with("sect_tournament", "azure_peak", 3)
	gs.player.stage = 0
	_overwhelm(gs.player)
	_bout_logs = []
	EventBus.combat_finished.connect(_on_bout)
	gs.enter_tournament("sect_tournament")
	EventBus.combat_finished.disconnect(_on_bout)
	var foe_hp: Array = []
	for l: PackedStringArray in _bout_logs:
		foe_hp.append(_hp_in(l[0], "Foe"))
	assert_eq(foe_hp.size(), 3)
	assert_true(foe_hp[0] < foe_hp[1] and foe_hp[1] < foe_hp[2], "each bout a stage tougher: %s" % str(foe_hp))
	gs.end_session()


var _bout_logs: Array = []


func _on_bout(_name: String, _victory: bool, log: PackedStringArray) -> void:
	_bout_logs.append(log)


func _hp_in(line: String, marker: String) -> int:
	var rx := RegEx.create_from_string(marker + ": (\\d+) hp")
	var found := rx.search_all(line)
	return int(found[-1].get_string(1)) if not found.is_empty() else -1


func test_tournament_carries_hp_between_bouts() -> void:
	var gs := _session_with("sect_tournament", "azure_peak", 3)
	gs.player.stage = 0
	_overwhelm(gs.player)
	var rounds := int(gs.data.world_events["sect_tournament"]["tournament"]["rounds"])
	_bout_logs = []
	EventBus.combat_finished.connect(_on_bout)
	gs.enter_tournament("sect_tournament")
	EventBus.combat_finished.disconnect(_on_bout)
	assert_eq(_bout_logs.size(), rounds, "every bout fought")
	for i in range(1, _bout_logs.size()):
		var prev: PackedStringArray = _bout_logs[i - 1]
		var left := _hp_in("\n".join(prev), "You")
		if left < 0:
			left = _hp_in(prev[0], "You")
		assert_eq(_hp_in(_bout_logs[i][0], "You"), left, "bout %d starts where bout %d ended" % [i + 1, i])
	gs.end_session()


func test_pay_prize_gives_stones_manual_and_reputation() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var sect_id: String = d.sects.keys()[0]
	c.sect = {"id": sect_id, "rank": 0}
	var before := Reputation.value(c, d, sect_id)
	var stones_before := c.item_count("spirit_stone")
	WorldEvents.pay_prize(d, c, "sect_tournament", {}, seeded_rng())
	assert_eq(c.item_count("spirit_stone"), stones_before + 150)
	assert_eq(Reputation.value(c, d, sect_id), before + 15)
	assert_true(c.inventory.keys().any(func(k: String) -> bool: return k.begins_with("manual_")))


func test_defend_against_incursion() -> void:
	var gs := _session_with("demonic_incursion", "qingshi_village", 3)
	gs.player.alignment = 0
	_overwhelm(gs.player)
	var stones: int = gs.player.item_count("spirit_stone")
	gs.defend_against_incursion("demonic_incursion")
	assert_true(bool(gs.world_events[0]["done"]))
	assert_gt(gs.player.item_count("spirit_stone"), stones, "defence pays")
	assert_gt(gs.player.alignment, 0, "defending is righteous")
	assert_eq(LifeStats.get_stat(gs.player, "incursions_repelled"), 1)
	assert_true(gs.player.milestones.has("incursion_repelled"), "milestone awarded")
	var after: int = gs.player.item_count("spirit_stone")
	gs.defend_against_incursion("demonic_incursion")
	assert_eq(gs.player.item_count("spirit_stone"), after, "only once per event")
	gs.end_session()


func test_validation_catches_bad_joinable_events() -> void:
	var d := GameData.load_from_dir()
	d.world_events["bad"] = {"id": "bad", "monthly_chance": 0.1, "min_days": 1, "max_days": 1, "regions": ["qingshi_village"], "tournament": {"rounds": 0, "prize": {"items": {"nope": 1}, "manuals": ["nope2"]}}, "defence": {"enemy": "nobody", "effects": {}}}
	assert_eq(WorldEvents.validate(d).size(), 5, ", ".join(WorldEvents.validate(d)))


## WU-005: joinable event entries show how dangerous the rivals are.
func test_event_options_show_danger() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.realm_index = 1
	gs.current_region = "fallen_star_market"
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events = [{"id": "sect_tournament", "region": "fallen_star_market", "start_day": day, "end_day": day + 40}]
	var labels: Array = load("res://src/world/interactables/explore_site.gd").event_options().map(func(o: Dictionary) -> String: return o["label"])
	assert_eq(labels.size(), 1)
	assert_true(String(labels[0]).begins_with("Enter the"), labels[0])
	var danger := false
	for word in ["Weak", "Even", "Risky", "Dangerous", "Deadly"]:
		danger = danger or String(labels[0]).contains("(%s)" % word)
	assert_true(danger, "label shows a danger word: %s" % labels[0])
	gs.end_session()


func test_event_ends_on_its_end_day_not_the_month_end() -> void:
	var gs := _session_with("sect_tournament", "azure_peak")
	var day: int = _root().get_node("GameClock").total_days
	gs.world_events[0]["end_day"] = day + 3
	assert_eq(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "tournament", "azure_peak"), "")
	gs._pass_time(4)
	assert_true(gs.world_events.is_empty(), "expired mid-month")
	assert_true(WorldEvents.check_join(gs.data, gs.world_events, gs.player, "sect_tournament", "tournament", "azure_peak") != "", "can't join an ended event")
	gs.end_session()


func test_rolled_instances_carry_done_flag_so_save_round_trips_are_stable() -> void:
	var d := data()
	var rolled: Array = []
	for seed_value in 200:
		rolled = WorldEvents.roll(d, [], 0, seeded_rng(seed_value))
		if not rolled.is_empty():
			break
	assert_false(rolled.is_empty(), "some event rolled")
	for inst: Dictionary in rolled:
		assert_true(inst.has("done") and inst["done"] == false, "fresh instance has done=false")


func _lantern_instance(day: int) -> Dictionary:
	return {"id": "lantern_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 8}


func test_months_gate_when_events_start() -> void:
	var d := data()
	var rng := seeded_rng(5)
	var starts_in: Dictionary = {}
	for month in range(0, 24):
		var day := month * Calendar.DAYS_PER_MONTH
		var active: Array = []
		for inst in WorldEvents.roll(d, active, day, rng):
			if inst["id"] == "lantern_festival":
				starts_in[Calendar.month_of(day)] = int(starts_in.get(Calendar.month_of(day), 0)) + 1
	assert_eq(starts_in.keys(), [10], "only in month 10")
	assert_eq(int(starts_in[10]), 2, "once a year, both years")


func test_festival_favor_multiplier() -> void:
	var d := data()
	assert_true(WorldEvents.is_festival(d, "lantern_festival"))
	assert_false(WorldEvents.is_festival(d, "beast_tide"))
	var active: Array = [_lantern_instance(0)]
	assert_almost_eq(WorldEvents.favor_multiplier(d, active, "qingshi_village"), 2.0)
	assert_almost_eq(WorldEvents.favor_multiplier(d, active, "misty_forest"), 1.0)
	assert_eq(WorldEvents.scaled_favor(d, active, "qingshi_village", 3), 6)
	WorldEvents.expire(active, 100)
	assert_almost_eq(WorldEvents.favor_multiplier(d, active, "qingshi_village"), 1.0)


func test_validator_rejects_bad_months_and_favor_mult() -> void:
	var d := GameData.load_from_dir()
	d.world_events["bad_month"] = {"id": "bad_month", "monthly_chance": 1.0, "min_days": 1, "max_days": 2, "regions": ["qingshi_village"], "months": [13], "modifiers": {}}
	d.world_events["bad_mult"] = {"id": "bad_mult", "monthly_chance": 1.0, "min_days": 1, "max_days": 2, "regions": ["qingshi_village"], "modifiers": {"favor_mult": 0.5}}
	var errors := WorldEvents.validate(d)
	assert_eq(errors.size(), 2, ", ".join(errors))


func test_festival_doubles_chat_favor_and_saves() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var npc := Npcs.spawn({}, gs.data, seeded_rng(3), {"gender": "female", "age_years": 20, "realm": "qi_refining"})
	npc.id = "villager_a"
	gs.npcs["villager_a"] = npc
	gs.npcs["villager_b"] = npc
	gs.current_region = "qingshi_village"
	var cap := int(gs.data.family["acquaintance"]["chat_max_favor"])
	gs.chat("villager_a")
	var normal: int = gs.npc_favor["villager_a"]
	gs.world_events = [_lantern_instance(_root().get_node("GameClock").total_days)]
	gs.chat("villager_b")
	var festive: int = gs.npc_favor["villager_b"]
	assert_eq(festive, mini(normal * 2, cap), "twice the favor, capped")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.world_events = []
	gs.load_save_dict(saved)
	assert_eq(gs.world_events.size(), 1)
	assert_eq(gs.world_events[0]["id"], "lantern_festival")
	gs.end_session()


func test_festival_shop_items() -> void:
	var d := data()
	var active: Array = [_lantern_instance(0)]
	assert_eq(WorldEvents.shop_items(d, active, "qingshi_village"), ["paper_lantern"])
	assert_eq(WorldEvents.shop_items(d, active, "misty_forest"), [])
	WorldEvents.expire(active, 100)
	assert_eq(WorldEvents.shop_items(d, active, "qingshi_village"), [])
	assert_true(Items.sources(d, "paper_lantern").has("Festival stall: Lantern Festival"))
	assert_true(Items.sources(d, "moon_cake").has("Festival stall: Mid-Autumn Moon Festival"))


func test_validator_rejects_bad_shop_items() -> void:
	var d := GameData.load_from_dir()
	d.world_events["lantern_festival"]["shop_items"] = ["no_such_item"]
	assert_eq(WorldEvents.validate(d).size(), 1, ", ".join(WorldEvents.validate(d)))


func test_game_state_festival_stock() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	gs.world_events = []
	assert_eq(gs.festival_stock(), [])
	gs.world_events = [_lantern_instance(0)]
	assert_eq(gs.festival_stock(), ["paper_lantern"])
	gs.world_events = []


## FEST-003: a festival activity anyone can join, once per festival.
func test_festival_activity_reasons_and_effects() -> void:
	var gs := _session_with("lantern_festival", "qingshi_village", 0)
	var d: GameData = gs.data
	assert_eq(WorldEvents.check_activity(d, gs.world_events, gs.player, "lantern_festival", "qingshi_village"), "", "mortals can join")
	assert_true(WorldEvents.check_activity(d, gs.world_events, gs.player, "lantern_festival", "azure_peak") != "", "wrong region")
	assert_true(WorldEvents.check_activity(d, gs.world_events, gs.player, "sect_tournament", "azure_peak") != "", "no activity")
	gs.player.attributes["comprehension"] = 11
	var qi_before: int = gs.player.qi
	var result := WorldEvents.do_activity(d, gs.world_events, gs.player, "lantern_festival", "qingshi_village", gs.world_flags)
	assert_true(bool(result["ok"]) and not bool(result["bonus"]), "no bonus at 11")
	assert_true(gs.player.qi > qi_before)
	assert_true(bool(gs.world_events[0]["activity_done"]))
	assert_true(WorldEvents.check_activity(d, gs.world_events, gs.player, "lantern_festival", "qingshi_village") != "", "once only")
	assert_false(bool(WorldEvents.do_activity(d, gs.world_events, gs.player, "lantern_festival", "qingshi_village", gs.world_flags)["ok"]))
	gs.world_events[0].erase("activity_done")
	gs.player.attributes["comprehension"] = 12
	assert_true(bool(WorldEvents.do_activity(d, gs.world_events, gs.player, "lantern_festival", "qingshi_village", gs.world_flags)["bonus"]), "bonus at 12")
	gs.end_session()


func test_festival_activity_survives_save_and_validates() -> void:
	var gs := _session_with("lantern_festival", "qingshi_village", 0)
	gs.world_events[0]["activity_done"] = true
	var saved: Dictionary = gs.to_save_dict()
	gs.world_events = []
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_true(bool(gs.world_events[0]["activity_done"]), "activity_done saved")
	gs.end_session()
	var d := GameData.load_from_dir()
	d.world_events["bad"] = {"id": "bad", "monthly_chance": 0.1, "min_days": 1, "max_days": 1, "regions": ["qingshi_village"], "activity": {"text": "x", "days": 0, "effects": {}, "bonus": {"attribute": "nope", "min": 3, "text": "t", "effects": {}}}}
	assert_eq(WorldEvents.validate(d).size(), 2, ", ".join(WorldEvents.validate(d)))
