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


func test_named_figure_wins_over_tag_guess() -> void:
	assert_eq(EncounterScene.figure_of({"id": "x", "tags": ["beast"], "figure": "elder"}), "elder")
	assert_eq(EncounterScene.figure_of({"id": "x", "tags": ["beast"], "figure": "none"}), "player")
	assert_eq(EncounterScene.figure_of({"id": "x", "tags": ["beast"]}), "beast")
	assert_eq(EncounterScene.figure_of({"id": "x", "tags": ["beast"], "figure": "bogus"}), "beast")


func test_every_named_figure_is_valid_and_examples_exist() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.load_errors.size(), 0, str(data.load_errors))
	var named := 0
	for id: String in data.encounters:
		var f := String(data.encounters[id].get("figure", ""))
		if f != "":
			named += 1
			assert_true(f in GameData.ENCOUNTER_FIGURES, "%s: bad figure %s" % [id, f])
	assert_true(named >= 10, "at least 10 example figures set")


func test_every_figure_renders() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for f: String in GameData.ENCOUNTER_FIGURES:
		var scene := EncounterScene.new()
		tree.root.add_child(scene)
		scene.show_encounter({"id": "t_" + f, "tags": [], "figure": f})
		await tree.process_frame
		assert_true(scene.figure() != "")
		scene.free()


func test_backdrop_for_look() -> void:
	assert_eq(EncounterScene.backdrop_for_look("woods"), "pines")
	assert_eq(EncounterScene.backdrop_for_look("cave"), "cave")
	assert_eq(EncounterScene.backdrop_for_look("ruins"), "ruins")
	assert_eq(EncounterScene.backdrop_for_look("reeds"), "reeds")
	assert_eq(EncounterScene.backdrop_for_look("ridge"), "crags")
	assert_eq(EncounterScene.backdrop_for_look(""), "")
	assert_eq(EncounterScene.backdrop_for_look("bogus"), "")
	for look: String in PlaceLooks.EXPLORE_LOOKS:
		assert_true(EncounterScene.backdrop_for_look(look) != "", look)


func test_season_look_per_season() -> void:
	for s in ["Spring", "Summer", "Autumn", "Winter"]:
		assert_true(SeasonCard.SEASON_LOOKS.has(s))
	assert_true(SeasonCard.SEASON_LOOKS["Spring"]["ground"] != SeasonCard.SEASON_LOOKS["Autumn"]["ground"])
