extends TestCase
## WU-410: the quarrel window opens from either villager, shows the same four choices and settles through GameState.


func _setup() -> Array:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Quarrel", gs.data, seeded_rng(4242))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var a := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	var b := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 40, "region": "qingshi_village", "realm": "mortal"})
	gs.current_region = "qingshi_village"
	gs.world_flags[Folk.quarrel_flag(gs.current_region)] = {"a": a.id, "b": b.id, "topic": "rice_debt", "until": GameClock.total_days + 10}
	return [gs, a, b]


func _labels(w: QuarrelWindow) -> Array[String]:
	var out: Array[String] = []
	for btn in w.choice_buttons():
		out.append(btn.text)
	return out


func test_labels_and_title() -> void:
	var l := QuarrelWindow.choice_labels("A", "B", {"attribute": "charisma", "target": 10})
	assert_eq(l["mediate"], "[Charisma 10] Mediate")
	assert_eq(l["side_b"], "Side with B")
	assert_eq(QuarrelWindow.title_for("A", "B"), "A quarrel: A and B")


func test_same_four_choices_from_either_villager() -> void:
	var s := _setup()
	var w := QuarrelWindow.new()
	w.open_for(s[1].id)
	var from_a := _labels(w)
	assert_eq(from_a.size(), 4)
	assert_true(w.visible)
	assert_true(w.body_text() != "")
	assert_true(w.footer_text().begins_with("Tags in [brackets]"))
	w.close()
	w.open_for(s[2].id)
	assert_eq(_labels(w), from_a)
	w.free()


func test_escape_closes_without_settling() -> void:
	var s := _setup()
	var w := QuarrelWindow.new()
	w.open_for(s[1].id)
	w.close()
	assert_false(w.visible)
	assert_false(s[0].quarrel_of(s[1].id).is_empty(), "quarrel still open")
	w.free()


func test_choosing_settles_and_shows_the_result() -> void:
	var s := _setup()
	var w := QuarrelWindow.new()
	w.open_for(s[1].id)
	w.choice_buttons()[1].pressed.emit()
	assert_true(s[0].quarrel_of(s[1].id).is_empty(), "settled")
	assert_true(w.body_text().contains("side"), w.body_text())
	assert_eq(w.choice_buttons().size(), 1)
	assert_eq(w.choice_buttons()[0].text, "Close")
	w.free()


func test_no_quarrel_means_no_window() -> void:
	var s := _setup()
	s[0].world_flags.erase(Folk.quarrel_flag(s[0].current_region))
	var w := QuarrelWindow.new()
	w.open_for(s[1].id)
	assert_false(w.visible)
	w.free()
