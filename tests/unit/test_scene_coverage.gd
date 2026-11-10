extends TestCase
## C-316: every named Qingshi villager has a lower-tier and a close-friend scene; gifts exist; enough generic scenes.


func test_named_villagers_have_two_scenes() -> void:
	var data: GameData = data()
	for id: String in data.npcs:
		if String(data.npcs[id].get("region", "")) != "qingshi_village":
			continue
		var mins: Array = []
		for scene: Dictionary in data.scenes:
			if String(scene["npc"]) == id:
				mins.append(int(scene["min_favor"]))
		assert_true(mins.has(40) and mins.has(60), "%s has a friend and a close-friend scene" % id)


func test_generic_scenes_and_gifts() -> void:
	var data: GameData = data()
	var generic := 0
	for scene: Dictionary in data.scenes:
		if String(scene["npc"]) == "any_villager":
			generic += 1
		if scene.has("gift"):
			assert_true(data.items.has(String(scene["gift"])), "gift %s exists" % scene["gift"])
	assert_true(generic >= 4, "at least 4 any_villager scenes")
