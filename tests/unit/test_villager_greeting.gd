extends TestCase
## WU-401: who greets the player now.


func _c(id: String, x: float) -> Dictionary:
	return {"id": id, "pos": Vector2(x, 0)}


func test_nearest_within_radius() -> void:
	var people := [_c("a", 50), _c("b", 20), _c("c", 200)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, false, false), "b")


func test_out_of_range_is_silent() -> void:
	assert_eq(VillagerGreeting.pick([_c("a", 61)], Vector2.ZERO, {}, 5, false, false), "")
	assert_eq(VillagerGreeting.pick([_c("a", 60)], Vector2.ZERO, {}, 5, false, false), "a")


func test_already_greeted_today() -> void:
	var people := [_c("a", 10), _c("b", 40)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {"a": 5}, 5, false, false), "b")
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {"a": 4}, 5, false, false), "a")


func test_modal_or_active_bubble_blocks() -> void:
	var people := [_c("a", 10)]
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, true, false), "")
	assert_eq(VillagerGreeting.pick(people, Vector2.ZERO, {}, 5, false, true), "")


func test_folk_request_detection() -> void:
	assert_false(VillagerGreeting.is_folk_request({}))
	assert_false(VillagerGreeting.is_folk_request({"npc_id": "a", "item": "x", "count": 1}))
	assert_true(VillagerGreeting.is_folk_request({"source": "folk", "count": 3}))


func test_greeting_asks_only_when_player_holds_enough() -> void:
	var req := {"source": "folk", "count": 3}
	assert_eq(VillagerGreeting.with_request("Morning.", req, 3, "Spirit Grass"), "Morning. Did you bring the Spirit Grass?")
	assert_eq(VillagerGreeting.with_request("Morning.", req, 2, "Spirit Grass"), "Morning.")
	assert_eq(VillagerGreeting.with_request("Morning.", {"source": "letter", "count": 1}, 5, "Spirit Grass"), "Morning.")
	assert_eq(VillagerGreeting.with_request("", req, 5, "Spirit Grass"), "")


func test_asker_shows_badge_and_full_label() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Ask", gs.data, seeded_rng(7)))
	var n: Interactable = load("res://src/world/interactables/npc.gd").new()
	n.display_name = "Villager"
	n.npc_id = "nobody_generated"
	n.size = Vector2(28, 28)
	n.refresh_request()
	assert_false(n.shows_badge())
	assert_eq(n.label_alpha(Vector2(900, 0)), 0.0)
	gs.player.letter_requests.append({"npc_id": "nobody_generated", "item": "spirit_stone", "count": 1, "until": GameClock.total_days + 5, "favor": 3, "effects": {}, "source": "folk", "text": ""})
	n.refresh_request()
	assert_true(n.shows_badge())
	assert_eq(n.label_alpha(Vector2(900, 0)), 1.0)
	n.free()
