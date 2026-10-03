extends TestCase
## The clinic place: treat patients, treat your own injuries, pay the doctor.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _clinic() -> Node:
	return load("res://src/world/interactables/clinic.gd").new()


func _find(options: Array[Dictionary], prefix: String) -> Dictionary:
	for option in options:
		if option["label"].begins_with(prefix):
			return option
	return {}


func test_clinic_is_a_valid_place_type_in_regions() -> void:
	assert_true(data().load_errors.is_empty())
	var found := 0
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place["type"] == "clinic":
				found += 1
	assert_true(found >= 2)


func test_healthy_player_can_only_treat_patients() -> void:
	var gs := _gs()
	var c := new_character()
	c.injuries = {}
	gs.start_session(c)
	var clinic := _clinic()
	var options: Array[Dictionary] = clinic.get_options()
	assert_eq(options.size(), 1)
	var before: int = gs.player.age_days
	options[0]["action"].call()
	assert_eq(gs.player.age_days, before + Calendar.DAYS_PER_MONTH)
	assert_true(gs.player.professions.has(Medicine.DOCTOR))
	clinic.free()


func test_injured_player_can_treat_self_or_pay() -> void:
	var gs := _gs()
	var c := new_character()
	c.injuries = {"broken_bones": 60}
	c.inventory = {}
	gs.start_session(c)
	var clinic := _clinic()
	var options: Array[Dictionary] = clinic.get_options()
	var pay := _find(options, "Pay the doctor to heal your Broken Bones")
	assert_false(pay.is_empty())
	assert_true(pay["disabled"])
	assert_false(_find(options, "Treat your Broken Bones").is_empty())
	gs.player.add_item("spirit_stone", 100)
	pay = _find(clinic.get_options(), "Pay the doctor")
	assert_false(pay["disabled"])
	pay["action"].call()
	assert_false(gs.player.injuries.has("broken_bones"))
	assert_eq(gs.player.item_count("spirit_stone"), 100 - 20)
	assert_eq(clinic.get_options().size(), 1)
	clinic.free()
