extends TestCase
## WU-100: the merchant menu offers the festival activity only while a festival runs here.

const MerchantScript := preload("res://src/world/interactables/merchant.gd")


func _find(options: Array[Dictionary], needle: String) -> Dictionary:
	for opt: Dictionary in options:
		if String(opt["label"]).contains(needle):
			return opt
	return {}


func test_festival_entry_follows_festival() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = []
	var merchant := MerchantScript.new()
	assert_true(_find(merchant.get_options(), "(festival)").is_empty(), "no festival, no entry")
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	var entry := _find(merchant.get_options(), "(festival)")
	assert_false(entry.is_empty(), "entry during the festival")
	assert_true(String(entry["label"]).begins_with("Float a lantern"), entry["label"])
	assert_false(String(entry["description"]).is_empty())
	assert_false(bool(entry["disabled"]))
	var qi_before: float = gs.player.qi
	(entry["action"] as Callable).call()
	assert_true(gs.player.qi > qi_before, "taking part raises qi")
	entry = _find(merchant.get_options(), "(festival)")
	assert_true(bool(entry["disabled"]), "disabled after taking part")
	assert_false(String(entry["reason"]).is_empty())
	merchant.free()
	gs.end_session()
