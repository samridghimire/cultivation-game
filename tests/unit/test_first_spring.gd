extends TestCase
## QA-210: can a newcomer finish year 1's Spring village tasks? Bream and petals must be reachable in Qingshi;
## the stag is a printed report (threat for a fresh character, village hunt quarry, ally damage).

func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func _spring_tasks() -> Array:
	var gd := _gd()
	return SeasonTasks.tasks_for(gd, 9)


func test_bream_and_petals_reachable_in_spring() -> void:
	var gd := _gd()
	var region: Dictionary = gd.regions["qingshi_village"]
	var bream_ok := false
	for p: Dictionary in region.get("places", []):
		if p.get("type", "") != "fishing":
			continue
		for e: Dictionary in p.get("catch_table", []):
			if e.get("item", "") == "peach_blossom_bream" and (e.get("seasons", []) as Array).has("spring") and not e.has("requires_flag"):
				bream_ok = true
	assert_true(bream_ok, "peach_blossom_bream can be caught in Qingshi in spring")
	var petal_ok := false
	for e: Dictionary in region.get("forage", {}).get("items", []):
		if e.get("item", "") == "peach_blossom_petal" and (e.get("seasons", []) as Array).has("spring"):
			petal_ok = true
	assert_true(petal_ok, "peach_blossom_petal can be foraged in Qingshi in spring")


func test_spring_stag_report() -> void:
	var gd := _gd()
	var c := new_character()
	var targets: Array[String] = []
	for t: Dictionary in _spring_tasks():
		targets.append(String(t["target"]))
	assert_true(targets.has("peach_blossom_bream"))
	assert_true(targets.has("peach_blossom_petal"))
	var spring_day := 360 * 0 + 9 # year 1, day 9 of spring
	var quarry := VillageHunt.quarry(gd, "qingshi_village", spring_day)
	var ally := VillageHunt.ally(c, gd, 0.15)
	for t in targets:
		if gd.enemies.has(t):
			print("QA-210 report: ", t, " threat=", Wildlife.threat(c, gd, t), " village quarry=", quarry,
				" ally damage=", ally.get("damage", 0))
