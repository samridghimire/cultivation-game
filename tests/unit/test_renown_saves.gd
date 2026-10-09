extends TestCase
## QA-056: renown, bounties, gift tastes, letters, greetings and festival stock survive a
## save round trip, and every committed fixture save answers their queries without errors.

const FIXTURE_DIR := "res://tests/fixtures/saves"


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _round_trip(gs: Node) -> void:
	gs.load_save_dict(JSON.parse_string(JSON.stringify(gs.to_save_dict())))


func test_fame_state_survives_round_trip() -> void:
	var gs := _gs()
	gs.rng.seed = 11
	gs.start_session(CharacterFactory.create("Fame", gs.data, gs.rng))
	gs.pending_event = ""
	var p: CharacterData = gs.player
	p.realm_index = 1
	p.stage = 3
	p.renown["misty_forest"] = 60
	p.renown["azure_peak"] = 110
	var today: int = GameClock.total_days
	var offers := Bounties.offers(p, gs.data, today, "misty_forest")
	assert_true(not offers.is_empty(), "a bounty is on offer")
	var bounty_id := String(offers[0]["id"])
	Bounties.take(p, gs.data, bounty_id, today)
	p.bounty_cooldowns["azure_crane_bounty"] = today + 40
	var paid := Bounties.paid_stones(p, gs.data, Bounties.def_of(gs.data, bounty_id))
	gs.world_flags["taste_%s_%s" % ["old_herbalist", "moon_cake"]] = 1
	gs.world_flags["taste_%s_%s" % ["old_herbalist", "spirit_stone"]] = -1
	for line in ["one", "two", "three"]:
		Letters.remember(p, gs.data, "Letter " + line, today)
	gs.world_flags["greeted_some_npc"] = today
	gs.current_region = "fallen_star_market"
	gs.world_events = [{"id": "mid_autumn_festival", "region": "fallen_star_market", "start_day": today, "end_day": today + 8, "done": false}]
	var stock_before: Array = gs.festival_stock()
	assert_true(not stock_before.is_empty(), "festival stock exists")
	var journal_before := Letters.journal_lines(p)
	var offers_before := Bounties.offers(p, gs.data, today, "misty_forest")

	_round_trip(gs)
	p = gs.player
	assert_eq(int(p.renown["misty_forest"]), 60, "renown misty")
	assert_eq(int(p.renown["azure_peak"]), 110, "renown azure")
	assert_eq(String(p.bounty.get("id", "")), bounty_id, "active bounty")
	assert_eq(Bounties.paid_stones(p, gs.data, Bounties.def_of(gs.data, bounty_id)), paid, "bounty pay")
	assert_eq(int(p.bounty_cooldowns["azure_crane_bounty"]), today + 40, "cooldown")
	assert_eq(int(gs.world_flags["taste_old_herbalist_moon_cake"]), 1, "liked taste")
	assert_eq(int(gs.world_flags["taste_old_herbalist_spirit_stone"]), -1, "disliked taste")
	assert_eq(Letters.journal_lines(p), journal_before, "letters")
	assert_eq(int(gs.world_flags["greeted_some_npc"]), today, "greeting cooldown")
	assert_eq(gs.festival_stock(), stock_before, "festival stock")
	assert_eq(Bounties.offers(p, gs.data, today, "misty_forest").map(func(b: Dictionary) -> String: return b["id"]), offers_before.map(func(b: Dictionary) -> String: return b["id"]), "board")
	gs.end_session()


func test_fixtures_answer_fame_queries() -> void:
	var gs := _gs()
	var dir := DirAccess.open(FIXTURE_DIR)
	assert_true(dir != null, "fixture dir")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DIR.path_join(f)))
		assert_true(parsed is Dictionary, f + " parses")
		gs.rng.seed = 3
		gs.start_session(CharacterFactory.create("Fx", gs.data, gs.rng))
		gs.load_save_dict(parsed["game"])
		var today: int = GameClock.total_days
		var p: CharacterData = gs.player
		for region_id in gs.data.regions:
			assert_true(Renown.value(p, region_id) >= 0, f + " renown")
			Renown.greeting(p, gs.data, region_id, "Someone", today)
			Bounties.offers(p, gs.data, today, region_id)
			WorldEvents.shop_items(gs.data, gs.world_events, region_id)
		Letters.journal_lines(p)
		gs.festival_stock()
		Bounties.active(p, gs.data, today)
		assert_true(Renown.describe(p, gs.data) is PackedStringArray, f + " describe")
		gs.end_session()
