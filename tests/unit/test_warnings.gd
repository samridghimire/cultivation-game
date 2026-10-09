extends TestCase
## WU-086: the final-death warning before fights and on the lives line.

const FIGHT := {
	"id": "test_warn_fight", "tags": ["test_warn_tag"], "weight": 1, "kind": "neutral", "days": 1,
	"text": "A bandit blocks the road.",
	"choices": [
		{"label": "Fight him", "enemy": "mountain_bandit"},
		{"label": "Walk on"},
	],
}


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_helper_text() -> void:
	var c := new_character()
	c.artifact_lives = 0
	assert_eq(Warnings.final_death_warning(c), Warnings.FINAL_DEATH)
	c.artifact_lives = 1
	assert_eq(Warnings.final_death_warning(c), "")
	c.artifact_lives = -1
	assert_eq(Warnings.final_death_warning(c), "")
	c.artifact_lives = 0
	assert_eq(Warnings.append_to(c, "Hunt"), "Hunt\n" + Warnings.FINAL_DEATH)


func test_lives_line() -> void:
	var gs := _gs()
	var c := new_character()
	c.artifact_lives = 0
	assert_true(CreationArtifact.describe(c, gs.data)[0].contains("(death is final)"))
	c.artifact_lives = 2
	assert_false(CreationArtifact.describe(c, gs.data)[0].contains("(death is final)"))


func test_encounter_fight_choice_warns() -> void:
	var gs := _gs()
	for lives in [0, 1]:
		gs.start_session(new_character())
		gs.player.artifact_lives = lives
		gs.data.encounters[FIGHT["id"]] = FIGHT.duplicate(true)
		gs.pending_encounter = FIGHT["id"]
		var window := EncounterWindow.new()
		window.open()
		var buttons := window.choice_buttons()
		assert_eq(buttons[0].text.contains(Warnings.FINAL_DEATH), lives == 0)
		assert_false(buttons[1].text.contains(Warnings.FINAL_DEATH), "a peaceful choice never warns")
		window.free()
		gs.end_session()
		gs.data.encounters.erase(FIGHT["id"])


func test_threat_prompt_warns() -> void:
	var gs := _gs()
	for lives in [0, 1]:
		var c := new_character()
		gs.start_session(c)
		c.artifact_lives = lives
		var prompt := ThreatPrompt.new()
		prompt.prepare("mist_wolf")
		var fight := prompt.menu_options()[1]
		assert_eq(String(fight["description"]).contains(Warnings.FINAL_DEATH), lives == 0)
		prompt.free()
		gs.end_session()
