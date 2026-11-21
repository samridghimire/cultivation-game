extends TestCase
## FOLK-035: lending a hand (Folk.lend_*, GameState.lend_a_hand, Guidance.make_friend_hint).


## FOLK-037: every villager just had tea, so the Grow closer hint falls through to gifts.
const TEA_RESTING := {"tea_elder_mo": 0, "tea_hunter_ma": 0}


func _npcs(d: GameData) -> Dictionary:
	var npcs := {}
	Npcs.ensure_all(npcs, d, seeded_rng(3))
	return npcs


func test_verb_falls_back() -> void:
	var d := data()
	assert_eq(Folk.lend_verb(d, "elder_mo"), "sorting scrolls")
	assert_eq(Folk.lend_verb(d, "nobody"), "with their chores")


func test_cooldown_and_cap() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var mo: CharacterData = npcs["elder_mo"]
	var flags := {"lend_elder_mo": 10}
	assert_eq(Folk.lend_check(c, mo, d, {}, 0, 0, "qingshi_village"), "")
	assert_eq(Folk.lend_check(c, mo, d, flags, 16, 0, "qingshi_village"), "Again in 1 day.")
	assert_eq(Folk.lend_check(c, mo, d, flags, 17, 0, "qingshi_village"), "")
	assert_true(Folk.lend_check(c, mo, d, {}, 0, 45, "qingshi_village").contains("glad of the help"))
	assert_true(Folk.lend_check(c, mo, d, {}, 0, 0, "misty_forest").contains("not here"))


func test_gain_and_yield() -> void:
	var d := data()
	var c := new_character()
	var base := Folk.lend_gain(c, d, 0)
	assert_true(base >= 4)
	assert_eq(Folk.lend_gain(c, d, 44), 1, "capped at max_favor")
	assert_true(Folk.lend_yield(d, "elder_mo").is_empty(), "read has no yield")
	d.npcs["elder_mo"]["activity"] = "hoe"
	assert_eq(String(Folk.lend_yield(d, "elder_mo")["item"]), "millet")
	d.npcs["elder_mo"]["activity"] = "read"


func test_validation_rejects_bad_block() -> void:
	var d := data()
	var old: Dictionary = d.family["lend_a_hand"].duplicate(true)
	d.family["lend_a_hand"]["yields"]["hoe"]["item"] = "no_such_item"
	d.family["lend_a_hand"]["verbs"]["dance"] = "dancing"
	d.family["lend_a_hand"]["max_favor"] = 10
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	assert_true(text.contains("unknown item") and text.contains("unknown activity 'dance'") and text.contains("max_favor"))
	d.family["lend_a_hand"] = old
	d.load_errors.clear()


func test_make_friend_hint() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var hint := Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {})
	assert_true(hint.begins_with("Make a friend: lend "), hint)
	var step2 := Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {"elder_mo": 25})
	assert_true(step2.begins_with("Become friends: lend "), step2)
	assert_true(step2.ends_with("/40)."), step2)
	assert_eq(Guidance.make_friend_hint(c, d, npcs, {}, "qingshi_village", 0, {"elder_mo": 41}), "")


func test_make_friend_gift_form() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var flags := {}
	var liked := ""
	for item_id: String in d.items:
		if Family.gift_taste(d, "elder_mo", item_id) == 1 and Family.gift_value(d, item_id) > 0:
			liked = item_id
			break
	assert_true(liked != "", "elder_mo likes some item")
	c.add_item(liked, 1)
	var favor := {"elder_mo": 25}
	for id: String in d.npcs:
		flags["lend_" + id] = 0
	var gift := Guidance.make_friend_hint(c, d, npcs, flags, "qingshi_village", 0, favor)
	assert_true(gift.begins_with("Become friends: give "), gift)
	assert_true(gift.contains(String(d.items[liked].get("name", liked))), gift)
	assert_eq(Guidance.make_friend_hint(new_character(), d, npcs, flags, "qingshi_village", 0, favor), "")


func test_friend_line_in_first_four() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var lines := Guidance.hints(c, d, 1.0, 8, npcs, {}, "qingshi_village", 0, {})
	var idx := -1
	for i in lines.size():
		if lines[i].begins_with("Make a friend: lend "):
			idx = i
	assert_true(idx >= 0 and idx < 4, "friend line index %d in %s" % [idx, lines])


## GUIDE-279: before the first win an Easy fight line outranks the friend line; after a win the order is unchanged.
func test_easy_fight_before_friend_until_first_win() -> void:
	var c := new_character()
	var lines := PackedStringArray(["Goal: x", "Make a friend: lend Mo a hand (1 day).", "Easy fight: Boar (98 in 100)", "Cultivate."])
	var out := Guidance._fight_before_friend(lines, c)
	assert_eq(out[1], "Easy fight: Boar (98 in 100)")
	assert_eq(out[2], "Make a friend: lend Mo a hand (1 day).")
	LifeStats.add(c, "fights_won")
	var after := Guidance._fight_before_friend(lines, c)
	assert_eq(after[1], "Make a friend: lend Mo a hand (1 day).")
	assert_eq(after[2], "Easy fight: Boar (98 in 100)")


func test_fight_before_friend_in_hints_then_friend_at_index_two() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var lines := Guidance.hints(c, d, 1.0, 8, npcs, {}, "qingshi_village", 0, {})
	var f := -1
	var m := -1
	for i in lines.size():
		if f < 0 and lines[i].begins_with("Easy fight:"):
			f = i
		if m < 0 and lines[i].begins_with("Make a friend:"):
			m = i
	assert_true(m >= 0, str(lines))
	if f >= 0:
		assert_true(f < m, "fight before friend: %s" % [lines])
	LifeStats.add(c, "fights_won")
	var won := Guidance.hints(c, d, 1.0, 8, npcs, {}, "qingshi_village", 0, {})
	assert_true(won.find("") == -1 and String(won[mini(2, won.size() - 1)]).begins_with("Make a friend:") or won.size() < 3, str(won))


## C-404: validation of lend_lines.
func test_lend_lines_validation() -> void:
	var d := data()
	var mo: Array = d.npcs["elder_mo"]["lend_lines"]
	var ma: Array = d.npcs["hunter_ma"]["lend_lines"]
	d.npcs["elder_mo"]["lend_lines"] = ["a", "b", "c", "d"]
	d.npcs["hunter_ma"]["lend_lines"] = ["x".repeat(141)]
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	d.npcs["elder_mo"]["lend_lines"] = mo
	d.npcs["hunter_ma"]["lend_lines"] = ma
	d.load_errors.clear()
	assert_true(text.contains("'elder_mo' lend_lines needs 1-3"), text)
	assert_true(text.contains("'hunter_ma' lend_lines entries"), text)


func test_every_start_region_named_npc_has_two_lend_lines() -> void:
	var d := data()
	for id: String in d.npcs:
		var lines: Array = d.npcs[id].get("lend_lines", [])
		assert_eq(lines.size(), 2, id)


## C-404: the posted thank-you is one of the NPC's lines (with the player's name); no lines, only the lend message.
func test_lend_posts_a_thank_you_line() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var bus := root.get_node("EventBus")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var lines: Array = gs.data.npcs["elder_mo"]["lend_lines"].duplicate()
	var mark: int = bus.posted_count
	gs.lend_a_hand("elder_mo")
	var texts: Array = []
	for row in bus.history:
		texts.append(String(row["text"]))
	var found := 0
	for line: String in lines:
		if texts.has(line.replace("{player}", gs.player.name)):
			found += 1
	assert_eq(found, 1, str(texts))
	gs.world_flags.erase("lend_elder_mo")
	gs.data.npcs["elder_mo"].erase("lend_lines")
	bus.history.clear()
	gs.lend_a_hand("elder_mo")
	var after: Array = []
	for row in bus.history:
		after.append(String(row["text"]))
	gs.data.npcs["elder_mo"]["lend_lines"] = lines
	gs.end_session()
	assert_true(after.any(func(t: String) -> bool: return t.contains("You spend the day")), str(after))
	for line: String in lines:
		assert_false(after.has(line.replace("{player}", "")), line)


func _liked_item(d: GameData, npc_id: String) -> String:
	for item_id: String in d.items:
		if Family.gift_taste(d, npc_id, item_id) == 1 and Family.gift_value(d, item_id) > 0:
			return item_id
	return ""


func test_grow_closer_bag_shop_and_off() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var liked := _liked_item(d, "elder_mo")
	assert_true(liked != "")
	# No Friend yet: no line. A Friend with nothing liked in reach: no line.
	assert_eq(Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", {"elder_mo": 30}), "")
	var favor := {"elder_mo": 45}
	var none := Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", favor, TEA_RESTING, 0)
	assert_true(none == "" or none.ends_with("/60)."), none)
	c.add_item(liked, 1)
	var line := Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", favor, TEA_RESTING, 0)
	assert_true(line.begins_with("Grow closer: give "), line)
	assert_true(line.contains(String(d.items[liked].get("name", liked))) and line.ends_with("(favor 45/60)."), line)
	# Someone Close already: off.
	assert_eq(Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", {"elder_mo": 45, _other_villager(d): 60}), "")


func test_grow_closer_names_highest_friend() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var other := _other_villager(d)
	for id: String in ["elder_mo", other]:
		var item := _liked_item(d, id)
		if item != "":
			c.add_item(item, 1)
	var line := Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", {"elder_mo": 42, other: 52}, TEA_RESTING, 0)
	if line != "":
		assert_true(line.contains(npcs[other].name) and line.ends_with("(favor 52/60)."), line)


func _other_villager(d: GameData) -> String:
	for id: String in d.npcs:
		if id != "elder_mo":
			return id
	return ""


## FOLK-037: call_on_check / call_on_gain.
func test_call_on_check_and_gain() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var mo: CharacterData = npcs["elder_mo"]
	assert_eq(Folk.call_on_check(c, mo, d, {}, 0, 40, "qingshi_village"), "")
	assert_true(Folk.call_on_check(c, mo, d, {}, 0, 39, "qingshi_village").contains("well enough"))
	assert_true(Folk.call_on_check(c, mo, d, {}, 0, 80, "qingshi_village").contains("always glad"))
	assert_true(Folk.call_on_check(c, mo, d, {}, 0, 50, "misty_forest").contains("not here"))
	c.parents.append("elder_mo")
	assert_true(Folk.call_on_check(c, mo, d, {}, 0, 50, "qingshi_village").contains("Family"))
	c.parents.clear()
	var flags := {"tea_elder_mo": 10}
	assert_eq(Folk.call_on_check(c, mo, d, flags, 13, 50, "qingshi_village"), "Again in 4 days.")
	assert_eq(Folk.call_on_check(c, mo, d, flags, 17, 50, "qingshi_village"), "")
	assert_eq(Folk.call_on_gain(c, d, 79), 1, "capped at max_favor")
	assert_true(Folk.call_on_gain(c, d, 40) >= 3)


## WU-588: the People card's next-step line.
func test_next_step_line() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var mo: CharacterData = npcs["elder_mo"]
	assert_eq(Folk.next_step(c, mo, d, {}, 0, 40, "qingshi_village"), "Tea ready (weekly)")
	assert_eq(Folk.next_step(c, mo, d, {"tea_elder_mo": 10}, 13, 40, "qingshi_village"), "Lend a hand today")
	var both := {"tea_elder_mo": 10, "lend_elder_mo": 10}
	assert_eq(Folk.next_step(c, mo, d, both, 13, 40, "qingshi_village"), "Tea again in 4 days", "tea and lend tie: tea")
	both["lend_elder_mo"] = 9
	assert_eq(Folk.next_step(c, mo, d, both, 13, 40, "qingshi_village"), "Lend a hand: %ss" % Calendar.weekday_name(16))
	var spent := {"tea_elder_mo": 0, "lend_elder_mo": 0}
	assert_eq(Folk.next_step(c, mo, d, spent, 1, 50, "qingshi_village"), "Tea again in 6 days", "tea returns before lend only on a tie")
	var capped := {"taste_elder_mo_moon_cake": 1}
	assert_eq(Folk.next_step(c, mo, d, capped, 0, 90, "qingshi_village"), "Likes: %s" % String(d.items["moon_cake"]["name"]))
	assert_eq(Folk.next_step(c, mo, d, {}, 0, 90, "qingshi_village"), "", "nothing left at the top")
	assert_eq(Folk.next_step(c, mo, d, {}, 0, 85, "qingshi_village"), "", "sworn friend reached")


func test_call_on_validation() -> void:
	var d := data()
	var old: Dictionary = d.family["folk_visits"]["call_on"].duplicate()
	d.family["folk_visits"]["call_on"]["max_favor"] = 10
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("max_favor"))
	d.family["folk_visits"]["call_on"] = old.duplicate()
	d.family["folk_visits"]["call_on"].erase("favor")
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("favor must be a number"))
	d.family["folk_visits"]["call_on"] = old
	d.load_errors.clear()
	d._validate()
	assert_true(d.load_errors.is_empty(), "\n".join(d.load_errors))


func test_grow_closer_prefers_tea_then_gift() -> void:
	var d := data()
	var npcs := _npcs(d)
	var c := new_character()
	var liked := _liked_item(d, "elder_mo")
	var favor := {"elder_mo": 45}
	var line := Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", favor, {}, 100)
	assert_true(line.begins_with("Grow closer: share tea at ") and line.ends_with("(favor 45/60)."), line)
	c.add_item(liked, 1)
	line = Guidance.grow_closer_hint(c, d, npcs, "qingshi_village", favor, {"tea_elder_mo": 99}, 100)
	assert_true(line.begins_with("Grow closer: give "), line)

## WU-585: the helping player never stands in a wall, a stall, a house or off the map beside any working villager.
func test_lend_spot_is_free_for_every_working_villager() -> void:
	var d := data()
	var checked := 0
	for id in d.npcs:
		var def: Dictionary = d.npcs[id]
		if String(def.get("activity", "")) == "" or not def.get("spots", {}).has("work"):
			continue
		var region: Dictionary = d.regions[String(def.get("region", ""))]
		var w: Array = def["spots"]["work"]
		var npc_pos := Vector2(float(w[0]), float(w[1]))
		var spot := Scenery.lend_spot(region, npc_pos, 40.0)
		var body := Rect2(spot - Vector2(14, 14), Vector2(28, 28))
		for r in Scenery.landmark_rects(region, true):
			assert_false(r.intersects(body), "%s: the lend spot %s is inside a solid landmark" % [id, spot])
		var sz: Array = region["map"]["size"]
		assert_true(Rect2(Vector2.ZERO, Vector2(float(sz[0]), float(sz[1]))).encloses(body), "%s: the lend spot %s is off the map" % [id, spot])
		assert_true(spot.distance_to(npc_pos) <= 80.1, "%s: the lend spot is beside the villager" % id)
		checked += 1
	assert_true(checked >= 12, "checked %d working villagers" % checked)


func test_lend_spot_steps_aside_for_a_wall() -> void:
	var region := {"map": {"size": [400, 400], "landmarks": [{"kind": "house", "pos": [160, 200], "size": [60, 60]}]}}
	assert_eq(Scenery.lend_spot(region, Vector2(200, 200), 40.0), Vector2(240, 200), "left is a house: stand right")
	var open := {"map": {"size": [400, 400], "landmarks": []}}
	assert_eq(Scenery.lend_spot(open, Vector2(200, 200), 40.0), Vector2(160, 200), "open ground: left")
