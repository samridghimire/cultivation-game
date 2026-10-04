extends TestCase
## QA-005: family edge cases (deaths during pregnancy, respawn while pregnant,
## save/load mid-pregnancy, children of a deceased parent).

const TEST_SLOT := "_test_family_edges"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


## Starts a session for a player of `gender` married to a generated spouse
## living in the start region. Returns [player, spouse].
func _married(gender: String) -> Array[CharacterData]:
	var gs := _game_state()
	var c := CharacterFactory.create("Edge", gs.data, seeded_rng(31), gender)
	Names.apply(c, "Han", "Edge")
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var spouse := Npcs.spawn(gs.npcs, gs.data, seeded_rng(32), {"region": gs.current_region, "gender": "female" if gender == "male" else "male", "age_years": 20})
	var rank := "wife" if gender == "male" else "dao_companion"
	c.spouses.append(spouse.id)
	c.spouse_ranks[spouse.id] = rank
	spouse.spouses.append(c.id)
	spouse.spouse_ranks[c.id] = rank
	return [c, spouse]


func test_npc_dying_while_pregnant_loses_the_child() -> void:
	var npcs := {}
	var mother := Npcs.spawn(npcs, data(), seeded_rng(), {"gender": "female", "cultivates": false})
	mother.spiritual_roots = {}
	mother.age_days = (Cultivation.lifespan_years(mother, data()) - 1) * Calendar.DAYS_PER_YEAR + Calendar.DAYS_PER_YEAR - 10
	mother.pregnancy = {"partner": "player", "days_left": 200}
	var events := Npcs.simulate(npcs, data(), Calendar.DAYS_PER_MONTH, seeded_rng())
	assert_false(mother.alive)
	assert_false(Children.is_pregnant(mother), "the dead do not stay pregnant")
	assert_eq(events.size(), 1)
	assert_true(String(events[0]["text"]).contains("unborn child"), events[0]["text"])


func test_pregnant_wife_dying_reports_lost_child_and_no_birth() -> void:
	var gs := _game_state()
	var pair := _married("male")
	var c := pair[0]
	var wife := pair[1]
	wife.cultivates = false
	wife.spiritual_roots = {}
	wife.age_days = (Cultivation.lifespan_years(wife, gs.data) - 1) * Calendar.DAYS_PER_YEAR
	wife.pregnancy = {"partner": c.id, "days_left": 200}
	var log: Array[String] = []
	var on_post := func(text: String, _category: String) -> void: log.append(text)
	EventBus.message_posted.connect(on_post)
	gs.cultivate(Calendar.DAYS_PER_YEAR)
	EventBus.message_posted.disconnect(on_post)
	assert_false(wife.alive)
	assert_true(c.children.is_empty(), "no child is born to a dead mother")
	var heard := false
	for line in log:
		heard = heard or (line.contains(wife.name) and line.contains("unborn child"))
	assert_true(heard, "the player hears the child was lost: %s" % [log])
	# Widowed, the player can marry again (FAM-002g).
	assert_eq(Family.spouses_of_rank(c, "wife", gs.npcs), 0)
	gs.end_session()


func test_child_born_after_the_father_died() -> void:
	var gs := _game_state()
	var pair := _married("female")
	var c := pair[0]
	var husband := pair[1]
	c.pregnancy = {"partner": husband.id, "days_left": 60}
	husband.alive = false
	husband.cause_of_death = "old age"
	gs.cultivate(Calendar.DAYS_PER_MONTH * 3)
	assert_eq(c.children.size(), 1, "a posthumous child is still born")
	var child: CharacterData = gs.npcs[c.children[0]]
	assert_eq(child.parents, [c.id, husband.id] as Array[String])
	assert_eq(child.surname, husband.surname, "the child takes the late father's surname")
	assert_true(husband.children.has(child.id))
	assert_eq(child.birth_rank, "dao_companion")
	gs.end_session()


func test_respawn_does_not_end_a_pregnancy() -> void:
	var gs := _game_state()
	var pair := _married("female")
	var c := pair[0]
	c.pregnancy = {"partner": pair[1].id, "days_left": 200}
	var lives: int = c.artifact_lives
	gs.fight("jade_python")
	assert_true(c.alive)
	assert_eq(c.artifact_lives, lives - 1, "the fight was lost and the artifact respawned the player")
	assert_true(Children.is_pregnant(c), "the artifact restores the soul and the child with it")
	assert_true(int(c.pregnancy["days_left"]) < 200, "the pregnancy keeps progressing")
	gs.end_session()


func test_save_and_load_mid_pregnancy_then_birth() -> void:
	var gs := _game_state()
	var saves := _root().get_node("SaveManager")
	var pair := _married("male")
	var c := pair[0]
	var wife := pair[1]
	wife.pregnancy = {"partner": c.id, "days_left": 45}
	assert_true(saves.save_game(TEST_SLOT))
	gs.end_session()
	assert_true(saves.load_game(TEST_SLOT))
	var loaded_wife: CharacterData = gs.npcs[wife.id]
	assert_eq(loaded_wife.pregnancy, {"partner": c.id, "days_left": 45})
	gs.cultivate(Calendar.DAYS_PER_MONTH * 2)
	assert_eq(gs.player.children.size(), 1, "the child is born after loading")
	assert_false(Children.is_pregnant(loaded_wife))
	DirAccess.remove_absolute(saves.save_path(TEST_SLOT))
	gs.end_session()
