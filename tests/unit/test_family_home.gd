extends TestCase
## FAM-011: the Family Home (FamilyHome system, world place, GameState actions).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(people: Dictionary, id: String, region: String, age: int) -> CharacterData:
	var n := new_character(id.hash())
	n.id = id
	n.name = id.capitalize()
	n.home_region = region
	n.age_days = age * Calendar.DAYS_PER_YEAR
	people[id] = n
	return n


func _family() -> Dictionary:
	var people := {}
	var me := new_character()
	var wife := _person(people, "wife", "qingshi_village", 30)
	var concubine := _person(people, "concubine", "fallen_star_market", 25)
	var son := _person(people, "son", "fallen_star_market", 8)
	var grown := _person(people, "grown", "azure_peak", 20)
	var dead := _person(people, "dead", "misty_forest", 40)
	dead.alive = false
	me.spouses = [wife.id, concubine.id, dead.id] as Array[String]
	me.children = [son.id, grown.id] as Array[String]
	return {"me": me, "people": people}


func test_data_is_valid() -> void:
	assert_eq(FamilyHome.validate(data()).size(), 0, str(FamilyHome.validate(data())))
	for region_id in data().regions:
		assert_true(data().regions[region_id].has("family_home"), "%s has room for a family home" % region_id)


func test_homes_stand_where_living_family_lives() -> void:
	var f := _family()
	var me: CharacterData = f["me"]
	var people: Dictionary = f["people"]
	assert_eq(FamilyHome.regions(me, people, data()), ["azure_peak", "fallen_star_market", "qingshi_village"] as Array[String])
	assert_true(FamilyHome.has_home(me, people, data(), "fallen_star_market"))
	assert_false(FamilyHome.has_home(me, people, data(), "misty_forest"), "the dead keep no home")
	assert_eq(FamilyHome.at_home(me, people, data(), "fallen_star_market").map(func(c: CharacterData) -> String: return c.id), ["concubine", "son"])
	assert_false(FamilyHome.has_home(new_character(), people, data(), "qingshi_village"))


func test_visit_raises_favor_with_caps() -> void:
	var f := _family()
	var me: CharacterData = f["me"]
	var people: Dictionary = f["people"]
	var favor := {"concubine": 99, "son": 10}
	assert_eq(FamilyHome.check_visit(me, people, data(), "misty_forest"), "None of your family lives here.")
	var result := FamilyHome.visit(me, people, favor, data(), "fallen_star_market")
	assert_true(result["ok"])
	assert_eq(int(result["days"]), int(data().family["home"]["visit_days"]))
	var gain := int(data().family["home"]["visit_favor"])
	assert_eq(favor["concubine"], 100, "spouse favor stops at the cap")
	assert_eq(favor["son"], 10 + gain)
	assert_eq(result["gains"], {"concubine": 1, "son": gain})
	assert_false(favor.has("wife"), "only the family here")


func test_move_household() -> void:
	var f := _family()
	var me: CharacterData = f["me"]
	var people: Dictionary = f["people"]
	assert_eq(FamilyHome.movers(me, people, data(), "qingshi_village").map(func(c: CharacterData) -> String: return c.id), ["concubine", "son"], "grown children keep their own homes")
	assert_eq(FamilyHome.check_move(me, people, data(), "misty_forest"), "Your family has no home here.")
	var result := FamilyHome.move_household(me, people, data(), "qingshi_village")
	assert_true(result["ok"], result["reason"])
	assert_eq(result["moved"], ["concubine", "son"] as Array[String])
	assert_eq((people["son"] as CharacterData).home_region, "qingshi_village")
	assert_eq(FamilyHome.check_move(me, people, data(), "qingshi_village"), "Your whole household already lives here.")
	assert_eq(FamilyHome.regions(me, people, data()), ["azure_peak", "qingshi_village"] as Array[String])


func test_family_takes_the_spots_nearest_the_home() -> void:
	var positions: Array[Vector2] = [Vector2(0, 0), Vector2(500, 500), Vector2(100, 0), Vector2(480, 520)]
	var split := FamilyHome.split_spots(positions, 2, Vector2(490, 490))
	assert_eq(split[0], [Vector2(500, 500), Vector2(480, 520)] as Array[Vector2])
	assert_eq(split[1], [Vector2(0, 0), Vector2(100, 0)] as Array[Vector2], "the others keep their order")
	assert_eq(FamilyHome.split_spots(positions, 0, Vector2.ZERO)[1], positions)


func test_game_state_visit_and_move() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(40), {"gender": "female", "region": "misty_forest", "age_years": 25})
	Family.marry(c, wife, "wife")
	var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(41), {"age_years": 5, "region": gs.current_region})
	c.children.append(kid.id)
	var clock: Node = _root().get_node("GameClock")
	var day: int = clock.total_days
	var home: Interactable = load("res://src/world/interactables/family_home.gd").new()
	var options: Array[Dictionary] = home.get_options()
	assert_false(options[0]["disabled"], options[0]["label"])
	assert_true(String(options[0]["label"]).contains(kid.name), options[0]["label"])
	assert_true(String(options[1]["label"]).contains(wife.name), options[1]["label"])
	options[0]["action"].call()
	assert_eq(clock.total_days, day + int(gs.data.family["home"]["visit_days"]))
	assert_eq(int(gs.npc_favor[kid.id]), int(gs.data.family["home"]["visit_favor"]))
	gs.move_household_here()
	assert_eq(Npcs.region_of(wife, gs.data), gs.current_region)
	options = home.get_options()
	assert_true(options[1]["disabled"], "everyone is home")
	home.free()
	gs.end_session()


func test_world_builds_the_home_and_gathers_the_family() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(41), {"age_years": 5, "region": gs.current_region})
	c.children.append(kid.id)
	var world: Node = load("res://src/world/world.tscn").instantiate()
	_root().add_child(world)
	var home_node: Interactable = null
	var kid_node: Interactable = null
	for child in world.get_children():
		if child is Interactable and child.art_kind == "family_home":
			home_node = child
		elif child is Interactable and child.get("npc_id") == kid.id:
			kid_node = child
	assert_true(home_node != null, "the Family Home stands where the family lives")
	assert_true(kid_node != null)
	for child in world.get_children():
		if child is Interactable and child.art_kind == "npc" and child != kid_node and String(child.get("npc_id")).begins_with(Npcs.SPAWN_PREFIX):
			assert_true(child.position.distance_to(home_node.position) >= kid_node.position.distance_to(home_node.position), "the family stands nearest the home")
	world.free()
	gs.end_session()
