extends TestCase
## Creation Artifact: lives, anchors, recharging, respawn and the GameState death path.

const DEMON := {"id": "test_demon", "name": "Test Demon", "realm": "tribulation_transcendence", "stage": 3, "hp": 0, "attack": 0, "defense": 0, "speed": 0, "lethal": true, "techniques": [], "rewards": {}}


func test_new_character_holds_the_artifact() -> void:
	var c := new_character()
	assert_eq(c.artifact_lives, int(data().artifact["starting_lives"]))
	assert_eq(c.anchors, [data().artifact["start_anchor"]] as Array[String])
	assert_eq(CreationArtifact.anchor_slots(c, data()), 1)


func test_ensure_only_initialises_once() -> void:
	var c := new_character()
	c.artifact_lives = 0
	CreationArtifact.ensure(c, data())
	assert_eq(c.artifact_lives, 0, "an empty artifact stays empty")


func test_old_save_gets_starting_lives() -> void:
	var d := new_character().to_dict()
	d.erase("artifact_lives")
	d.erase("artifact_recharges")
	d.erase("anchors")
	var c := CharacterData.from_dict(d)
	assert_eq(c.artifact_lives, -1)
	CreationArtifact.ensure(c, data())
	assert_eq(c.artifact_lives, int(data().artifact["starting_lives"]))


func test_artifact_state_round_trips() -> void:
	var c := new_character()
	c.artifact_lives = 5
	c.artifact_recharges = 2
	c.realm_index = 1
	CreationArtifact.bind_anchor(c, data(), "azure_cliff")
	assert_eq(CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))).to_dict(), c.to_dict())


func test_anchor_slots_grow_with_realm() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	assert_eq(CreationArtifact.anchor_slots(c, data()), 3)
	c.realm_index = data().realms.size() - 1
	assert_gt(CreationArtifact.anchor_slots(c, data()), 3)


func test_bind_respects_slots_and_order() -> void:
	var c := new_character()
	assert_false(CreationArtifact.bind_anchor(c, data(), "azure_cliff")["ok"], "mortals have one slot")
	assert_false(CreationArtifact.bind_anchor(c, data(), "nowhere")["ok"])
	c.realm_index = 1
	assert_true(CreationArtifact.bind_anchor(c, data(), "azure_cliff")["ok"])
	assert_eq(c.anchors[-1], "azure_cliff")
	assert_true(CreationArtifact.bind_anchor(c, data(), "qingshi_rock")["ok"], "rebinding an anchor makes it the latest")
	assert_eq(c.anchors, ["azure_cliff", "qingshi_rock"] as Array[String])
	assert_true(CreationArtifact.unbind_anchor(c, "azure_cliff"))
	assert_false(CreationArtifact.unbind_anchor(c, "azure_cliff"))


func test_recharge_costs_grow() -> void:
	var c := new_character()
	c.inventory = {}
	var first := CreationArtifact.recharge_cost(c, data())
	assert_false(CreationArtifact.recharge(c, data())["ok"], "cannot afford")
	c.add_item("spirit_stone", 10000)
	var lives := c.artifact_lives
	assert_true(CreationArtifact.recharge(c, data())["ok"])
	assert_eq(c.artifact_lives, lives + 1)
	assert_eq(c.item_count("spirit_stone"), 10000 - first)
	assert_gt(CreationArtifact.recharge_cost(c, data()), first)
	c.artifact_lives = int(data().artifact["max_lives"])
	assert_false(CreationArtifact.recharge(c, data())["ok"], "full")


func test_respawn_costs_a_life_and_qi() -> void:
	var c := new_character()
	c.realm_index = 1
	c.qi = 1000.0
	CreationArtifact.bind_anchor(c, data(), "azure_cliff")
	var lives := c.artifact_lives
	var result := CreationArtifact.respawn(c, data())
	assert_true(result["ok"])
	assert_eq(result["anchor_id"], "azure_cliff")
	assert_eq(result["region"], "azure_peak")
	assert_eq(c.artifact_lives, lives - 1)
	assert_almost_eq(c.qi, 1000.0 * (1.0 - float(data().artifact["respawn"]["qi_loss_fraction"])))
	assert_eq(CreationArtifact.respawn(c, data(), "qingshi_rock")["anchor_id"], "qingshi_rock", "a chosen bound anchor")


func test_respawn_without_anchor_uses_start_region() -> void:
	var c := new_character()
	c.anchors.clear()
	assert_eq(CreationArtifact.respawn(c, data())["region"], data().start_region)
	c.artifact_lives = 0
	assert_false(CreationArtifact.can_respawn(c))
	assert_false(CreationArtifact.respawn(c, data())["ok"])


func test_game_state_respawn_then_final_death() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Reborn", gs.data, seeded_rng())
	gs.start_session(c)
	gs.current_region = "azure_peak"
	var lives := c.artifact_lives
	gs.fight_enemy(DEMON)
	assert_true(c.alive, "the artifact pulls the soul back")
	assert_eq(c.artifact_lives, lives - 1)
	assert_eq(gs.current_region, gs.data.anchors[gs.data.artifact["start_anchor"]]["region"])
	c.artifact_lives = 0
	gs.fight_enemy(DEMON)
	assert_false(c.alive, "no lives left: death is final")
	gs.end_session()


func test_game_state_anchor_and_recharge_actions() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Anchor", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = 1
	gs.bind_anchor("misty_clearing")
	assert_eq(c.anchors[-1], "misty_clearing")
	gs.unbind_anchor("misty_clearing")
	assert_false(c.anchors.has("misty_clearing"))
	c.add_item("spirit_stone", 1000)
	var lives := c.artifact_lives
	gs.recharge_artifact()
	assert_eq(c.artifact_lives, lives + 1)
	gs.end_session()
