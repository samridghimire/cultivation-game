extends TestCase
## G-010b: the abode place claims, secludes, uses its chest and binds its anchor.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _labels(place: Node) -> Array:
	return place.menu_options().map(func(o: Dictionary) -> String: return o["label"])


func _find(place: Node, prefix: String) -> Dictionary:
	for o: Dictionary in place.menu_options():
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func test_claim_seclusion_chest_and_anchor() -> void:
	var gs := _gs()
	var c := new_character()
	c.inventory = {"spirit_stone": 350, "golden_bell_talisman": 2}
	gs.start_session(c)
	gs.current_region = "misty_forest"
	var place: Node = load("res://src/world/interactables/abode.gd").new()
	place.abode_id = "waterfall_cave"
	place.anchor_id = "waterfall_cave_abode"
	var claim := _find(place, "Claim")
	assert_true(claim["disabled"], "mortals are refused")
	assert_true(String(claim["label"]).contains("("), "refusal reason shown")
	assert_eq(place.menu_options().size(), 1, "no anchor entries for strangers: %s" % str(_labels(place)))
	c.realm_index = gs.data.realm_index_of("qi_refining")
	claim = _find(place, "Claim")
	assert_false(claim["disabled"], claim["label"])
	(claim["action"] as Callable).call()
	assert_eq(c.abode, "waterfall_cave", "claimed")
	assert_true(place.is_owned())
	assert_false(_find(place, "Cultivate in seclusion").is_empty(), str(_labels(place)))
	var day: int = gs.get_node("/root/GameClock").total_days
	(_find(place, "Cultivate in seclusion")["action"] as Callable).call()
	assert_eq(int(gs.get_node("/root/GameClock").total_days) - day, 30, "a month in seclusion")
	(_find(place, "Open the storage chest")["action"] as Callable).call()
	var put := _find(place, "Put away Golden Bell")
	assert_false(put["disabled"], put["label"])
	(put["action"] as Callable).call()
	assert_eq(int(c.abode_storage.get("golden_bell_talisman", 0)), 2, "stored")
	(_find(place, "Take out Golden Bell")["action"] as Callable).call()
	assert_eq(c.item_count("golden_bell_talisman"), 2, "taken back")
	place.on_menu_closed()
	assert_false(_find(place, "Open the storage chest").is_empty(), "closing the menu leaves the chest")
	c.anchors.erase("waterfall_cave_abode")
	assert_false(_find(place, "Bind artifact anchor").is_empty(), "owner can bind the anchor: %s" % str(_labels(place)))
	place.free()
	gs.end_session()
