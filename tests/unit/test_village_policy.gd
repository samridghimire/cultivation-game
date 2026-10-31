extends TestCase
## QA-181: the sim's --village policy (FirstHour._village_month) rents, plants, harvests and fishes in Qingshi.


const FirstHour := preload("res://tests/sim/first_hour.gd")


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_village_month_rents_plants_and_fishes() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Villager", gs.data, seeded_rng(77))
	gs.start_session(c)

	c.add_item("spirit_stone", 20)
	c.add_item("village_mugwort", 3)
	FirstHour.village = true
	FirstHour.village_log = {"field_stones": 0, "rent": 0, "harvests": 0, "crops": 0, "fish_stones": 0, "fish_days": 0, "teas": 0, "quarrels": 0, "meals": 0}
	FirstHour._village_month(gs, c)
	FirstHour.village = false
	var field := FieldPlots.place_def(gs.data, "qingshi_village")
	var key := FieldPlots.key("qingshi_village", field)
	assert_true(FieldPlots.rented(c, key, _root().get_node("GameClock").total_days), "the field is rented")
	assert_eq(int(FirstHour.village_log["rent"]), int(field["rent"]))
	assert_true(int(FirstHour.village_log["fish_days"]) > 0, "it fished")
	assert_true(c.item_count("village_mugwort") < 3, "a herb was planted")
	gs.end_session()
