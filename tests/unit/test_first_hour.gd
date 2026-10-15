extends TestCase
## C-009: the first hour in Qingshi Village is guided and survivable.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## A fresh Qi Refining character with starting gear never meets a lethal fight
## it could lose without being warned: lethal foes are either beatable or
## Deadly (sensed and evaded), and forced fights (choice enemies) never kill.
func test_early_encounters_are_survivable() -> void:
	var d := data()
	var c := CharacterFactory.create("Newcomer", d, seeded_rng(9))
	c.realm_index = 1
	for e: Dictionary in d.encounters.values():
		if e.has("min_realm") and d.realm_index_of(String(e["min_realm"])) > 1:
			continue
		if e.has("enemy"):
			var enemy: Dictionary = d.enemies[e["enemy"]]
			if enemy.get("lethal", false):
				var danger := Combat.danger_label(c, d, enemy)
				assert_true(danger in ["Deadly", "Weak", "Even", "Risky"], "%s: a lethal %s fight a newcomer may not evade" % [e["id"], danger])
		for choice: Dictionary in e.get("choices", []):
			if choice.has("enemy"):
				assert_false(d.enemies[choice["enemy"]].get("lethal", false), "%s: a forced choice fight that can kill a newcomer" % e["id"])


func test_elder_mo_points_newcomers_around() -> void:
	var dialogue: Dictionary = data().dialogues["elder_mo"]
	var labels: Array = dialogue["nodes"]["greet"]["choices"].map(func(ch: Dictionary) -> String: return ch["label"])
	assert_true(labels.has("I am new to all this. Where should I begin?"))
	var text := String(dialogue["nodes"]["first_steps"]["text"])
	for word in ["Meditation Rock", "workshop", "sects", "clinic"]:
		assert_true(text.contains(word), word)
	assert_true(dialogue["nodes"].has("chores_info"))


func test_headman_chores_pay_once() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Newcomer", gs.data, seeded_rng(9))
	gs.start_session(c)
	c.realm_index = 1
	var places: Array = gs.data.regions["qingshi_village"]["places"].filter(func(p: Dictionary) -> bool: return p.get("deed_context", "") == "headman")
	assert_eq(places.size(), 1, "Headman Zhou stands in Qingshi Village")
	var chores := Deeds.available(gs.data, "headman", gs.world_flags)
	assert_eq(chores.size(), 4, "three chores and the extortion")
	var stones := c.item_count("spirit_stone")
	gs.perform_deed("chore_gather_herbs")
	assert_gt(c.item_count("spirit_stone"), stones)
	assert_eq(c.item_count("qi_gathering_pill") >= 1, true)
	gs.perform_deed("chore_widow_roof")
	gs.perform_deed("chore_drive_off_boar")
	assert_true(gs.world_flags.get("chore_boar_done", false), "a newcomer beats the boar")
	assert_eq(Deeds.available(gs.data, "headman", gs.world_flags).map(func(dd: Dictionary) -> String: return dd["id"]), ["extort_headman"], "each chore once")
	assert_gt(c.alignment, 0)
	gs.end_session()


## QA-063: the sim records the first real win, its foe, and the day the first style was bought.
func test_sim_records_first_win_and_style() -> void:
	var root := _root()
	var r: Dictionary = preload("res://tests/sim/first_hour.gd").play(root.get_node("GameState"), root.get_node("GameClock"), 2, 3, true)
	root.get_node("GameState").end_session()
	assert_true(int(r["first_win_day"]) >= 0, "a curious newcomer wins a fight in 3 months")
	assert_true(String(r["first_win_enemy"]) != "", "the first win names its foe")
	assert_true(int(r["first_style_day"]) >= int(r["first_win_day"]) - 14 or int(r["first_style_day"]) == -1, "style day is a clock day or -1")


## QA-066: the sim policy keeps an attempt log and the first bottleneck day per realm.
func test_play_logs_breakthrough_attempts() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var r: Dictionary = preload("res://tests/sim/first_hour.gd").play(gs, clock, 2, 36, true)
	assert_true(r.has("breaks") and r.has("bottleneck_day"))
	var seen := false
	var qr: int = gs.data.realm_index_of("qi_refining")
	var foundation_attempts := 0
	for a: Dictionary in r["breaks"]:
		for key in ["day", "from_realm", "chance", "pill", "stones", "success", "injury"]:
			assert_true(a.has(key), "attempt logged without %s" % key)
		assert_true(float(a["chance"]) > 0.0 and float(a["chance"]) < 1.0)
		if int(a["from_realm"]) == qr:
			foundation_attempts += 1
		if a["success"] and int(a["from_realm"]) == qr:
			seen = true
			assert_true(r["bottleneck_day"].has(a["from_realm"]), "success without a bottleneck day")
	assert_gt(foundation_attempts, 0, "seed 2 attempts Foundation Establishment inside 36 months")
	assert_true(seen, "seed 2 reaches Foundation inside 36 months (first Foundation breakthrough logged)")
	gs.end_session()
