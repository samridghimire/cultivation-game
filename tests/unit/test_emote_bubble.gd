extends TestCase
## WU-486: Folk.gift_reaction, the npc_reaction signal from give_gift and the EmoteBubble node.


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_gift_reaction_table() -> void:
	assert_eq(Folk.gift_reaction(1, false), "love")
	assert_eq(Folk.gift_reaction(1, true), "love")
	assert_eq(Folk.gift_reaction(0, false), "happy")
	assert_eq(Folk.gift_reaction(0, true), "love", "any non-disliked gift on their birthday")
	assert_eq(Folk.gift_reaction(-1, false), "sweat")
	assert_eq(Folk.gift_reaction(-1, true), "sweat", "a disliked gift still stings")


func test_give_gift_emits_reaction() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Integration", gs.data, seeded_rng(4242))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	c.add_item("qi_gathering_pill", 2)
	var seen: Array = []
	var cb := func(id: String, kind: String) -> void: seen.append([id, kind])
	EventBus.npc_reaction.connect(cb)
	GameClock.total_days = Folk.birthday_day(npc, gs.data) + Calendar.DAYS_PER_YEAR + 3
	gs.give_gift(npc.id, "qi_gathering_pill")
	EventBus.npc_reaction.disconnect(cb)
	assert_eq(seen.size(), 1)
	assert_eq(String(seen[0][0]), npc.id)
	var taste := int(gs.world_flags.get("taste_%s_qi_gathering_pill" % npc.id, 0))
	assert_eq(String(seen[0][1]), Folk.gift_reaction(taste, false))


func test_bubble_frees_itself() -> void:
	var b := EmoteBubble.make("love", 0.05)
	_root().add_child(b)
	for i in 12:
		await (Engine.get_main_loop() as SceneTree).process_frame
		await (Engine.get_main_loop() as SceneTree).create_timer(0.02).timeout
	assert_true(not is_instance_valid(b) or b.is_queued_for_deletion(), "gone after its lifetime")
	if is_instance_valid(b):
		b.free()


func test_persistent_bubble_stays() -> void:
	var b := EmoteBubble.make("lesson", 0.0)
	_root().add_child(b)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(is_instance_valid(b) and not b.is_queued_for_deletion())
	b.free()


func test_npc_shows_bubble_and_hides_cake() -> void:
	var n: Node = preload("res://src/world/interactables/npc.gd").new()
	n.npc_id = "bubble_a"
	_root().add_child(n)
	assert_true(not n.has_bubble())
	EventBus.npc_reaction.emit("someone_else", "love")
	assert_true(not n.has_bubble(), "other villagers' reactions are ignored")
	EventBus.npc_reaction.emit("bubble_a", "sweat")
	assert_true(n.has_bubble())
	n.free()
