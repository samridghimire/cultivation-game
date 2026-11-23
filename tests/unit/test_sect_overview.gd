extends TestCase
## WU-608: the hall's "Sect overview" row and the month-end sect row in the digest card.

const HallScript := preload("res://src/world/interactables/sect_hall.gd")


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _member() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Over", gs.data, seeded_rng(5))
	c.alignment = 0
	c.realm_index = 1
	gs.start_session(c)
	gs.join_sect("azure_cloud_sect")
	return c


func test_overview_label_only_for_reported_member() -> void:
	var c := _member()
	var d := _gs().data as GameData
	assert_eq(HallScript.overview_label(c, d, 0, {}), "")  # joined, not reported
	c.sect["reported"] = true
	var label: String = HallScript.overview_label(c, d, 0, {})
	assert_true(label.begins_with("Sect overview: "), label)
	assert_true(label.contains("contribution"), label)
	var rogue := CharacterFactory.create("R", d, seeded_rng(2))
	assert_eq(HallScript.overview_label(rogue, d, 0, {}), "")
	_gs().end_session()


func test_hall_menu_has_overview_row_first_for_reported() -> void:
	var c := _member()
	c.sect["reported"] = true
	var hall: Node = HallScript.new()
	hall.sect = "azure_cloud_sect"
	var options: Array[Dictionary] = hall.get_options()
	assert_true(String(options[0]["label"]).begins_with("Sect overview"), str(options[0]["label"]))
	c.sect["reported"] = false
	options = hall.get_options()
	assert_false(String(options[0]["label"]).begins_with("Sect overview"))
	hall.free()
	_gs().end_session()


func test_digest_sect_rows() -> void:
	assert_eq(DigestCard.sect_row("Your sect pays your monthly stipend: 30 spirit stones."), "Duty met: stipend paid (30 spirit stones)")
	assert_eq(DigestCard.sect_row("You fell short of your sect duty (4/10 contribution), so this month's stipend is withheld."), "Duty short by 6: stipend withheld")
	assert_eq(DigestCard.sect_row("A storm passes."), "A storm passes.")
	assert_eq(DayDigest.kind_of("Your sect pays your monthly stipend: 3 spirit stones.", "progress"), "sect")
