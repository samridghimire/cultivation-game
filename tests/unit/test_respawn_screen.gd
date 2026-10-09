extends TestCase
## ART-005: choosing where to awaken after a Creation Artifact respawn.

const DEMON := {"id": "test_demon", "name": "Test Demon", "realm": "tribulation_transcendence", "stage": 3, "hp": 0, "attack": 0, "defense": 0, "speed": 0, "lethal": true, "techniques": [], "rewards": {}}


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_respawn_choices_list_respawn_point_first() -> void:
	var c := CharacterData.new()
	c.anchors = ["qingshi_rock", "misty_clearing", "azure_cliff"]
	var choices := CreationArtifact.respawn_choices(c, data())
	assert_eq(choices.map(func(ch: Dictionary) -> String: return ch["anchor_id"]), ["azure_cliff", "misty_clearing", "qingshi_rock"])
	assert_true(choices[0]["respawn_point"])
	assert_false(choices[1]["respawn_point"])
	assert_eq(choices[0]["label"], CreationArtifact.anchor_name(data(), "azure_cliff"))


func test_respawn_choices_without_anchors_offer_start_region() -> void:
	var choices := CreationArtifact.respawn_choices(CharacterData.new(), data())
	assert_eq(choices.size(), 1)
	assert_eq(choices[0]["anchor_id"], "")
	assert_eq(CreationArtifact.anchor_region(data(), ""), data().start_region)
	assert_eq(CreationArtifact.anchor_region(data(), "azure_cliff"), data().anchors["azure_cliff"]["region"])


func test_summary_text_counts_lives() -> void:
	assert_true(RespawnScreen.summary_text({"lives_left": 1, "qi_lost": 12.4}).begins_with("1 life remains"))
	assert_true(RespawnScreen.summary_text({"lives_left": 2, "qi_lost": 0.0}).begins_with("2 lives remain"))
	assert_true(RespawnScreen.summary_text({"lives_left": 0, "qi_lost": 0.0}).contains("next death is final"))
	assert_true(RespawnScreen.summary_text({"lives_left": 2, "qi_lost": 12.6}).contains("12 qi"))


func test_lesson_text_needs_a_fight() -> void:
	assert_eq(RespawnScreen.lesson_text({"lives_left": 2}), "")
	var text := RespawnScreen.lesson_text({"enemy_name": "Stone Ape", "win_chance": 0.123})
	assert_true(text.contains("12% odds against Stone Ape"))
	assert_true(text.contains("Grow stronger"))


func test_cost_text_shows_cost_and_stones() -> void:
	var c := CharacterData.new()
	c.add_item("spirit_stone", 7)
	var text := RespawnScreen.cost_text(c, data())
	assert_true(text.contains("%d spirit stones" % CreationArtifact.recharge_cost(c, data())))
	assert_true(text.contains("you have 7"))


func test_fight_death_stores_odds_in_pending_respawn() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Fallen", gs.data, seeded_rng())
	gs.start_session(c)
	gs.pending_event = ""
	gs._die_violently("Slain.", {"enemy_id": "x", "enemy_name": "Ape", "win_chance": 0.2})
	assert_eq(gs.pending_respawn["enemy_name"], "Ape")
	assert_eq(RespawnScreen.lesson_text(gs.pending_respawn).contains("20%"), true)


## [REVIEW] win_chance rates a full-HP fight with no allies, so a death in a
## wounded bout (start_hp given) must not show those odds as the lesson.
func test_wounded_bout_death_has_no_odds_lesson() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Wounded", gs.data, seeded_rng())
	gs.start_session(c)
	gs.pending_event = ""
	c.realm_index = 1
	gs.fight_enemy(DEMON)
	assert_true(gs.pending_respawn.has("win_chance"), "a full-HP fight records its odds")
	gs.pending_respawn = {}
	gs.fight_enemy(DEMON, 1)
	assert_false(gs.pending_respawn.is_empty(), "the wounded bout ended in a respawn")
	assert_false(gs.pending_respawn.has("win_chance"))
	assert_eq(RespawnScreen.lesson_text(gs.pending_respawn), "")
	gs.end_session()


func test_choose_other_anchor_after_respawn() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Reborn", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = 1
	gs.bind_anchor("misty_clearing")
	gs.fight_enemy(DEMON)
	assert_true(c.alive)
	assert_eq(gs.pending_respawn["anchor_id"], "misty_clearing", "default respawn point")
	assert_eq(gs.current_region, gs.data.anchors["misty_clearing"]["region"])
	gs.choose_respawn_anchor("qingshi_rock")
	assert_true(gs.pending_respawn.is_empty())
	assert_eq(gs.current_region, gs.data.anchors["qingshi_rock"]["region"])
	assert_eq(gs.spawn_anchor, "qingshi_rock", "the world places the player at the chosen anchor")
	gs.choose_respawn_anchor("misty_clearing")
	assert_eq(gs.current_region, gs.data.anchors["qingshi_rock"]["region"], "no second choice without a new respawn")
	gs.end_session()


func test_screen_offers_a_button_per_anchor() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Reborn", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = 1
	gs.bind_anchor("misty_clearing")
	var screen := RespawnScreen.new()
	screen.open()
	assert_false(screen.visible, "nothing pending: stays closed")
	gs.fight_enemy(DEMON)
	screen.open()
	assert_true(screen.visible)
	var buttons := screen.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 2)
	assert_true((buttons[0] as Button).text.contains("respawn point"))
	(buttons[1] as Button).pressed.emit()
	assert_false(screen.visible)
	assert_eq(gs.current_region, gs.data.anchors["qingshi_rock"]["region"])
	screen.free()
	gs.end_session()
