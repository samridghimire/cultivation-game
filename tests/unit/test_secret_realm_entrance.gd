extends TestCase
## W-005b: the secret realm entrance place and the "realm opened" message cue.

const ENTRANCE := preload("res://src/world/interactables/secret_realm_entrance.gd")
const REALM := "verdant_remnant"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _gs() -> Node:
	return _root().get_node("GameState")


func _clock() -> Node:
	return _root().get_node("GameClock")


## A Qi Refining player standing in the realm's region with stones to spare.
func _start(realm_id: String = "qi_refining") -> CharacterData:
	var gs := _gs()
	var c := new_character(31)
	c.spiritual_roots = {"wood": 80}
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of(realm_id)
	c.add_item("spirit_stone", 500)
	gs.current_region = String(SecretRealms.realm(gs.data, REALM)["region"])
	return c


func _open_day() -> int:
	var def := SecretRealms.realm(_gs().data, REALM)
	return int(def.get("offset_years", 0)) * Calendar.DAYS_PER_YEAR


func _labels(options: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	for o in options:
		out.append(String(o["label"]))
	return out


func test_opened_between_and_opening_news() -> void:
	var d := data()
	var def := SecretRealms.realm(d, REALM)
	var start := int(def.get("offset_years", 0)) * Calendar.DAYS_PER_YEAR
	assert_true(SecretRealms.opened_between(def, start - 30, start + 5))
	assert_false(SecretRealms.opened_between(def, start + 1, start + 5), "already open before")
	assert_false(SecretRealms.opened_between(def, start - 60, start - 30), "still sealed")
	var c := new_character()
	c.realm_index = d.realm_index_of("qi_refining")
	var here := SecretRealms.opening_news(c, d, String(def["region"]), start - 1, start)
	assert_eq(here.size(), 1)
	assert_true(here[0].contains("has opened here"), here[0])
	var elsewhere := SecretRealms.opening_news(c, d, "no_such_region", start - 1, start)
	assert_true(elsewhere.size() == 1 and elsewhere[0].begins_with("Rumors"), str(elsewhere))
	c.realm_index = 0
	assert_eq(SecretRealms.opening_news(c, d, "no_such_region", start - 1, start).size(), 0, "no rumor for those the barrier repels")


func test_sealed_entrance_shows_status_only() -> void:
	_start()
	var entrance: Interactable = ENTRANCE.new()
	var options := entrance.get_options()
	var name: String = SecretRealms.realm(_gs().data, REALM)["name"]
	assert_eq(options.size(), 1, str(_labels(options)))
	assert_true(options[0]["disabled"])
	assert_true(String(options[0]["label"]).begins_with("%s: Sealed, opens in" % name), options[0]["label"])
	entrance.free()
	_gs().end_session()


func test_open_entrance_offers_delve_with_guardian_and_cost() -> void:
	var c := _start()
	_clock().total_days = _open_day()
	var entrance: Interactable = ENTRANCE.new()
	var options := entrance.get_options()
	assert_eq(options.size(), 2, str(_labels(options)))
	var delve: Dictionary = options[1]
	assert_true(String(delve["label"]).begins_with("Delve into floor 1/"), delve["label"])
	assert_true(String(delve["label"]).contains("guardian:"), delve["label"])
	assert_true(String(delve["label"]).contains("entry"), delve["label"])
	assert_false(delve["disabled"])
	# A mortal is repelled: the entry stays but is disabled with the reason.
	c.realm_index = 0
	delve = entrance.get_options()[1]
	assert_true(delve["disabled"])
	assert_true(String(delve["label"]).contains("repels"), delve["label"])
	entrance.free()
	_gs().end_session()


func test_delving_spends_the_entry_once() -> void:
	var c := _start()
	_clock().total_days = _open_day()
	var stones := c.item_count("spirit_stone")
	var def := SecretRealms.realm(_gs().data, REALM)
	var entrance: Interactable = ENTRANCE.new()
	entrance.get_options()[1]["action"].call()
	assert_eq(c.item_count("spirit_stone") <= stones - int(def.get("entry_stones", 0)) or not c.alive, true)
	assert_eq(SecretRealms.entry_cost(c, def, _clock().total_days), 0, "entry paid for this opening")
	entrance.free()
	_gs().end_session()


func test_time_passing_posts_the_opening_cue() -> void:
	_start()
	var bus: Node = _root().get_node("EventBus")
	_clock().total_days = _open_day() - 10
	var before: int = bus.history.size()
	_gs().cultivate(Calendar.DAYS_PER_MONTH)
	var found := false
	for entry: Dictionary in bus.history.slice(before):
		found = found or String(entry["text"]).contains("has opened here")
	assert_true(found, "opening cue posted")
	_gs().end_session()
