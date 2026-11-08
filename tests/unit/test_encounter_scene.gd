extends TestCase
## WU-488: the encounter card's scene strip.


func test_figure_for_tags() -> void:
	assert_eq(EncounterScene.figure_for(["wild", "beast"]), "beast")
	assert_eq(EncounterScene.figure_for(["road", "hunt"]), "beast")
	assert_eq(EncounterScene.figure_for(["village", "cultivator"]), "robed")
	assert_eq(EncounterScene.figure_for(["mountain", "herbs"]), "treasure")
	assert_eq(EncounterScene.figure_for(["village"]), "player")
	assert_eq(EncounterScene.figure_for([]), "player")


func test_tokens_include_id_words() -> void:
	var t := EncounterScene.tokens_for({"id": "village_grey_robed_recruiter", "tags": ["village"]})
	assert_eq(EncounterScene.figure_for(t), "robed")


func test_every_encounter_card_has_a_figure_and_fits() -> void:
	var data := GameData.new()
	var longest := 0
	for id: String in data.encounters:
		var enc: Dictionary = data.encounters[id]
		assert_true(EncounterScene.figure_for(EncounterScene.tokens_for(enc)) in ["beast", "robed", "treasure", "player"])
		longest = maxi(longest, String(enc.get("text", "")).length())
	assert_true(longest < 700, "longest encounter text %d chars should fit a 17px, 656px-wide label in a few lines" % longest)
	assert_true(EncounterScene.STRIP_SIZE.y + 520.0 <= 720.0)
