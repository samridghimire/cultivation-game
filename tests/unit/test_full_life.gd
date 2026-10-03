extends TestCase
## QA-002: one character lives a whole life through GameState only (create,
## cultivate, sect, profession, alchemy, gear, a lost fight with an artifact
## respawn, courtship, marriage, a child) and the result survives save/load.

const TEST_SLOT := "_test_full_life"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## Key order changes in a JSON round trip; compare contents only.
func _same(a: Dictionary, b: Dictionary) -> String:
	return "" if JSON.stringify(a, "", true) == JSON.stringify(b, "", true) else "%s != %s" % [a, b]


func _node(path: String) -> Node:
	return _root().get_node(path)


## An unmarried adult generated woman living in `region_id`, or null.
func _bride(gs: Node, region_id: String) -> CharacterData:
	for c in Npcs.generated_in_region(gs.npcs, gs.data, region_id):
		if c.gender == "female" and Npcs.is_eligible(c, gs.data) and c.realm_index <= 1:
			return c
	return null


func test_full_life() -> void:
	var gs := _node("GameState")
	var saves := _node("SaveManager")
	var c := CharacterFactory.create("Lifer", gs.data, seeded_rng(2026))
	Names.apply(c, "Han", "Lifer")  # character creation always sets a surname
	c.spiritual_roots = {"fire": 85}
	gs.start_session(c)
	if c.gender == "":
		gs.choose_gender("male")
	c.gender = "male"  # the marriage below uses the male rules (wife)

	# Cultivate to Qi Refining layer 3.
	for i in 600:
		if c.realm_index >= 1 and c.stage >= 2:
			break
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			gs.attempt_breakthrough()
		else:
			gs.cultivate(Calendar.DAYS_PER_MONTH, 1.5)
	assert_true(c.realm_index >= 1 and c.stage >= 2, "reach Qi Refining 3, got %s" % Cultivation.realm_label(c, gs.data))
	assert_true(c.alive)

	# Join a sect and work a profession.
	gs.join_sect("myriad_treasure_pavilion")
	assert_eq(String(c.sect.get("id", "")), "myriad_treasure_pavilion")
	var stones := c.item_count("spirit_stone")
	gs.work_profession("alchemist", Calendar.DAYS_PER_MONTH)
	assert_gt(c.item_count("spirit_stone"), stones, "profession income")

	# Refine a pill.
	c.add_item("spirit_herb", 2)
	c.add_item("dew_grass", 1)
	var xp := float(c.professions["alchemist"]["xp"])
	gs.refine("qi_gathering_pill")
	assert_eq(c.item_count("spirit_herb"), 0, "ingredients used")
	assert_true(float(c.professions["alchemist"]["xp"]) > xp or int(c.professions["alchemist"]["rank"]) > 0, "alchemy xp")

	# Buy and equip gear.
	c.add_item("spirit_stone", 200)
	gs.buy_item("iron_sword")
	gs.equip_item("iron_sword")
	assert_eq(String(c.equipment.get("weapon", "")), "iron_sword")

	# Lose a fight far above our realm; the artifact pulls us back to the anchor.
	gs.bind_anchor("qingshi_rock")
	var lives: int = c.artifact_lives
	gs.fight("jade_python")
	assert_true(c.alive, "the artifact respawns the player")
	assert_eq(c.artifact_lives, lives - 1)
	assert_eq(gs.current_region, "qingshi_village")

	# Court and marry an eligible generated NPC. Nothing in-game raises favor
	# with generated NPCs yet (FAM-002h), so seed the courtship threshold.
	var bride := _bride(gs, gs.current_region)
	assert_true(bride != null, "an eligible bride lives in the start region")
	if bride == null:
		gs.end_session()
		return
	gs.npc_favor[bride.id] = int(gs.data.family["courtship"]["min_favor"])
	for i in 20:
		if int(gs.npc_favor[bride.id]) >= int(gs.data.family["proposal"]["min_favor"]):
			break
		gs.court(bride.id)
	assert_true(int(gs.npc_favor[bride.id]) >= int(gs.data.family["proposal"]["min_favor"]), "courting raises favor")
	gs.propose(bride.id, "wife")
	assert_true(Family.is_married_to(c, bride), Family.check_proposal(c, bride, int(gs.npc_favor[bride.id]), "wife", gs.data, gs.npcs))

	# Try for a child until one is born.
	for i in 40:
		if Children.is_pregnant(bride):
			break
		gs.try_for_child(bride.id)
	assert_true(Children.is_pregnant(bride), "conceived within 40 tries")
	for i in 20:
		if not c.children.is_empty():
			break
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(c.children.size(), 1, "a child is born")
	if c.children.is_empty():
		gs.end_session()
		return
	var child: CharacterData = gs.npcs[c.children[0]]
	assert_eq(child.parents, [bride.id, c.id] as Array[String])
	assert_eq(child.surname, c.surname)
	assert_false(Children.is_pregnant(bride))

	# Save, load and compare.
	var expected_player: Dictionary = c.to_dict()
	var expected_bride: Dictionary = bride.to_dict()
	var expected_child: Dictionary = child.to_dict()
	var expected_favor := int(gs.npc_favor[bride.id])
	var expected_days: int = _node("GameClock").total_days
	assert_true(saves.save_game(TEST_SLOT))
	gs.end_session()
	assert_true(saves.load_game(TEST_SLOT))
	assert_eq(_same(gs.player.to_dict(), expected_player), "")
	assert_eq(_same((gs.npcs[bride.id] as CharacterData).to_dict(), expected_bride), "")
	assert_eq(_same((gs.npcs[child.id] as CharacterData).to_dict(), expected_child), "")
	assert_eq(int(gs.npc_favor[bride.id]), expected_favor)
	assert_eq(_node("GameClock").total_days, expected_days)
	assert_eq(gs.current_region, "qingshi_village")
	# The family still works after loading: the wife lives here and can conceive again.
	assert_eq(Family.spouses_in_region(gs.player, gs.npcs, gs.data, gs.current_region).size(), 1)
	assert_eq(Children.check_conception(gs.player, gs.npcs[bride.id], gs.data), "")
	DirAccess.remove_absolute(saves.save_path(TEST_SLOT))
	gs.end_session()
