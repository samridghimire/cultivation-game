extends TestCase
## QA-019: drives a fresh newcomer through the first-hour path using the calls
## the menus make and checks hints, message text and survival after each step.

const BAD_TEXT: Array[String] = ["%", "{", "<null>", "<Object", "null"]

var _gs: Node
var _c: CharacterData
var _seen := 0


func _bus() -> Node:
	return _gs.get_node("/root/EventBus")


## Asserts the invariants after the step called `step`.
func _check(step: String) -> void:
	assert_true(_c.alive, step + ": player alive")
	var hints := Guidance.hints(_c, _gs.data, 1.0, 5, _gs.npcs, _gs.world_flags, _gs.current_region)
	assert_gt(hints.size(), 0, step + ": hints are not empty")
	for h in hints:
		assert_true(String(h).strip_edges() != "", step + ": blank hint")
	if _gs.world_flags.get("talked_elder_mo", false):
		assert_false(Array(hints).any(func(h: String) -> bool: return h.begins_with("Ask Elder Mo")), step + ": Elder Mo hint repeats")
	var history: Array[Dictionary] = _bus().history
	for i in range(_seen, history.size()):
		var text := String(history[i]["text"])
		for bad in BAD_TEXT:
			if bad == "null" and not text.contains("<null>"):
				continue
			assert_false(text.contains(bad), "%s: unformatted text '%s'" % [step, text])
	_seen = history.size()


func _pick_first(view: Dictionary) -> int:
	for ch: Dictionary in view.get("choices", []):
		if ch.get("disabled", false):
			assert_true(String(ch.get("reason", "")) != "", "disabled dialogue option needs a reason")
	for ch: Dictionary in view.get("choices", []):
		if not ch.get("disabled", false):
			return int(ch["index"])
	return -1


func test_newcomer_path() -> void:
	_gs = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var rng := seeded_rng(4242)
	_c = CharacterFactory.create("Newcomer", _gs.data, rng)
	_c.spiritual_roots = {"fire": 40, "wood": 40, "water": 40}
	_gs.start_session(_c)
	_gs.pending_event = ""
	_bus().clear_history()
	_seen = 0
	_check("start")

	# Elder Mo
	_gs.start_dialogue("elder_mo")
	var guard := 0
	while _gs.in_dialogue() and guard < 10:
		var view: Dictionary = _gs.dialogue_view()
		var pick := -1
		for ch: Dictionary in view.get("choices", []):
			if String(ch["label"]).begins_with("I am new") and not ch.get("disabled", false):
				pick = int(ch["index"])
		if pick < 0:
			pick = _pick_first(view)
		if pick < 0:
			break
		_gs.choose_dialogue(pick)
		guard += 1
	if _gs.in_dialogue():
		_gs.end_dialogue()
	assert_true(_gs.world_flags.get("talked_elder_mo", false), "Elder Mo flag set")
	_check("elder mo")

	# Chores until 20 stones
	for chore in ["chore_gather_herbs", "chore_widow_roof", "chore_drive_off_boar"]:
		if _c.item_count("spirit_stone") >= 20:
			break
		_gs.perform_deed(chore)
		_check(chore)
	assert_gt(_c.item_count("spirit_stone"), 0, "chores pay stones")

	# Herb seller
	var stock := Items.shop_stock(_gs.data, 8, ["herb", "ore"])
	assert_gt(stock.size(), 0, "herb seller stocks something")
	var before := _c.item_count("spirit_stone")
	_gs.buy_item(String(stock[0]))
	assert_true(_c.item_count("spirit_stone") <= before, "buying never adds stones")
	_check("buy")

	# Meditate to a breakthrough
	var months := 0
	while not Cultivation.can_attempt_breakthrough(_c, _gs.data) and months < 120 and _c.alive:
		_gs.cultivate(30, 2.0)
		_gs.pending_event = ""
		months += 1
	_check("meditate")
	if Cultivation.can_attempt_breakthrough(_c, _gs.data):
		_gs.attempt_breakthrough()
		_check("breakthrough")

	# Join a sect
	var sects := Sects.accepting_sects(_c, _gs.data)
	assert_false(sects.is_empty(), "a newcomer who broke through is accepted somewhere")
	if not sects.is_empty():
		_gs.join_sect(sects[0])
		assert_false(_c.is_rogue(), "joined a sect")
		_check("join sect")
		var took := false
		for id: String in Sects.available_missions(_c, _gs.data):
			var reason := Sects.check_mission(_c, _gs.data, id)
			if reason != "":
				continue
			if int(_gs.data.sect_missions[id].get("min_rank", 0)) != 0:
				continue
			if Sects.mission_danger(_c, _gs.data, id) in ["Dangerous", "Deadly"]:
				continue
			_gs.take_mission(id)
			_check("mission " + id)
			took = true
			break
		assert_true(took, "a rank-0 mission could be taken")
		for id: String in Sects.available_missions(_c, _gs.data):
			var why := Sects.check_mission(_c, _gs.data, id)
			if why == "":
				continue
			assert_false(why.contains("%") or why.contains("{"), "mission reason is formatted: " + why)

	# Explore 10 times
	for i in 10:
		if not _c.alive:
			break
		_gs.explore()
		if _gs.pending_threat != "":
			_gs.face_threat(false)
		if _gs.pending_encounter != "":
			var choices: Array[Dictionary] = _gs.encounter_choices()
			for ch in choices:
				if ch.get("disabled", false):
					assert_true(String(ch.get("reason", "")) != "", "disabled encounter choice needs a reason")
			for k in choices.size():
				if not choices[k].get("disabled", false):
					_gs.choose_encounter(k)
					break
		_gs.pending_event = ""
		_check("explore %d" % i)
	_gs.end_session()
