extends TestCase
## WU-134: the breakthrough window before a Foundation+ breakthrough.

const PILL := "foundation_establishment_pill"


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


## A Qi Refining 9th Layer player at the bottleneck, optionally holding the pill.
func _bottleneck(with_pill: bool) -> void:
	var c := new_character()
	c.realm_index = 1
	var realm: RealmDef = data().realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	if with_pill:
		c.add_item(PILL, 1)
	_gs().start_session(c)
	_gs().current_region = "qingshi_village"


func _take_button(screen: Control) -> Button:
	return screen.find_child("Take_" + PILL, true, false) as Button


func _chance(screen: Control) -> int:
	return int(screen._chance.text.to_int())


func test_take_pill_raises_chance_and_consumes_it() -> void:
	_bottleneck(true)
	var screen := BreakthroughScreen.new()
	screen.open()
	var button := _take_button(screen)
	assert_true(button != null, "a Take button for the held pill")
	var before := _chance(screen)
	button.pressed.emit()
	assert_eq(_gs().player.item_count(PILL), 0)
	assert_eq(_gs().player.breakthrough_pill, "foundation_establishment")
	assert_eq(_chance(screen), before + 25)
	assert_true(screen._pills.get_child_count() == 0 or _take_button(screen) == null or screen._pills.get_children().all(func(n): return n.is_queued_for_deletion()))
	screen.free()


func test_no_pill_shows_the_source_hint() -> void:
	_bottleneck(false)
	var screen := BreakthroughScreen.new()
	screen.open()
	assert_true(_take_button(screen) == null)
	assert_true(screen._hint.visible and screen._hint.text.contains("Pill"), screen._hint.text)
	assert_true(screen._risk.text.contains("lose"), screen._risk.text)
	screen.free()


func test_term_line_signs() -> void:
	assert_eq(BreakthroughScreen.term_line({"label": "Base", "value": 0.35}), "Base  +35%")
	assert_eq(BreakthroughScreen.term_line({"label": "Fortune 8", "value": -0.02}), "Fortune 8  -2%")


func test_focus_never_starts_on_attempt_and_closed_fires() -> void:
	_bottleneck(false)
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var screen := BreakthroughScreen.new()
	host.add_child(screen)
	screen.open()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var owner := screen.get_viewport().gui_get_focus_owner()
	assert_true(owner != null and screen.is_ancestor_of(owner), "something inside is focused")
	assert_true(owner != screen._attempt_button, "not Attempt")
	var fired := [0]
	screen.closed.connect(func() -> void: fired[0] += 1)
	screen._later_button.pressed.emit()
	assert_eq(fired[0], 1)
	screen.open()
	screen._attempt_button.pressed.emit()
	assert_eq(fired[0], 2)
	host.queue_free()


func test_meditation_spot_routes_foundation_to_the_window() -> void:
	_bottleneck(false)
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var entry := {}
	for o: Dictionary in spot.get_options():
		if String(o["label"]).begins_with("Attempt breakthrough"):
			entry = o
	assert_false(entry.is_empty())
	assert_eq(entry["action"], EventBus.breakthrough_prepare_requested.emit)
	spot.free()
	# Mortal -> Qi Refining stays a one-click step.
	var c := new_character()
	var realm: RealmDef = data().realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	_gs().start_session(c)
	_gs().current_region = "qingshi_village"
	spot = load("res://src/world/interactables/meditation_spot.gd").new()
	entry = {}
	for o: Dictionary in spot.get_options():
		if String(o["label"]).begins_with("Attempt breakthrough"):
			entry = o
	assert_eq(entry["action"], _gs().attempt_breakthrough)
	spot.free()


func test_realm_blurb_names_the_next_realm_and_is_empty_past_the_end() -> void:
	var data: GameData = _gs().data
	assert_eq(BreakthroughScreen.realm_blurb(data, 0), data.realms[1].description)
	assert_eq(BreakthroughScreen.realm_blurb(data, data.realms.size() - 1), "")


func test_pill_hint_stones_against_price() -> void:
	_bottleneck(false)
	var p: CharacterData = _gs().player
	var price := Guidance.next_realm_pill_price(p, data())
	assert_true(price > 0, "the pill has a shop price")
	p.add_item("spirit_stone", -p.item_count("spirit_stone"))
	p.add_item("spirit_stone", price - 1)
	var short := BreakthroughScreen.pill_hint(p, data())
	assert_true(short.ends_with(" You have %d of %d stones." % [price - 1, price]), short)
	p.add_item("spirit_stone", 1)
	assert_true(BreakthroughScreen.pill_hint(p, data()).ends_with(" You can afford it."))


func test_pill_hint_empty_when_pill_held() -> void:
	_bottleneck(true)
	assert_eq(BreakthroughScreen.pill_hint(_gs().player, data()), "")
