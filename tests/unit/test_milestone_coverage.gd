extends TestCase
## QA-026: milestone emission through GameState, progress bounds, journal text hygiene.

const Balance := preload("res://tests/sim/combat_balance.gd")


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var c := CharacterFactory.create("Milestone", _gs().data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	_gs().start_session(c)
	return c


var _reached: Array[String] = []


func _on_reached(id: String, _name: String) -> void:
	_reached.append(id)


func test_check_milestones_emits_first_fight_once() -> void:
	var c := _start()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.qi = 0.0
	_reached.clear()
	EventBus.milestone_reached.connect(_on_reached)
	assert_true(_gs().fight_enemy(data().enemies["wild_boar"]), "a Foundation cultivator beats a boar")
	_gs().check_milestones()
	_gs().check_milestones()
	EventBus.milestone_reached.disconnect(_on_reached)
	assert_eq(_reached.count("first_fight"), 1, str(_reached))
	assert_true(c.milestones.has("first_fight"))


func _check_progress(c: CharacterData, label: String) -> void:
	for def: Dictionary in data().milestones:
		var id := String(def["id"])
		var p := Milestones.progress(c, data(), {}, null, id)
		assert_gt(int(p["target"]), 0, "%s %s target" % [label, id])
		assert_true(int(p["current"]) <= int(p["target"]), "%s %s current<=target" % [label, id])
		assert_true(int(p["current"]) >= 0, "%s %s current>=0" % [label, id])
		if c.milestones.has(id):
			assert_eq(int(p["current"]), int(p["target"]), "%s %s earned is full" % [label, id])


func test_progress_is_bounded_for_fresh_and_veteran() -> void:
	var fresh := new_character()
	_check_progress(fresh, "fresh")
	var vet := Balance.veteran_player(data(), data().realm_index_of("core_formation"), 0)
	_check_progress(vet, "veteran")
	Milestones.award(vet, data(), {}, null)
	_check_progress(vet, "veteran-awarded")


func _assert_clean_journal(entries: Array[Dictionary], label: String) -> void:
	var seen := {}
	for e in entries:
		var line := String(e["text"])
		for bad in ["%", "{", "<null>"]:
			assert_false(line.contains(bad), "%s: '%s' contains %s" % [label, line, bad])
		var key := "%s|%s" % [e["section"], line]
		assert_false(seen.has(key), "%s: duplicate line '%s'" % [label, line])
		seen[key] = true


func test_journal_text_is_clean() -> void:
	var d := data()
	var fresh := new_character()
	_assert_clean_journal(Guidance.journal(fresh, d, {}, 0, d.start_region), "fresh")
	var disciple := new_character()
	disciple.realm_index = 1
	var r := Sects.join(disciple, d, "myriad_treasure_pavilion")
	assert_true(r.get("ok", true) != false, str(r))
	_assert_clean_journal(Guidance.journal(disciple, d, {}, 10, d.start_region), "disciple")
	var vet := Balance.veteran_player(d, d.realm_index_of("core_formation"), 0)
	_assert_clean_journal(Guidance.journal(vet, d, {}, 10, d.start_region), "veteran")
