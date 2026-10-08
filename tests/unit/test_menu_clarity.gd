extends TestCase
## FH-010: join reasons, anchor entries and lethal fight wording.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func test_disabled_join_entry_shows_reason() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var found := false
	for o: Dictionary in hall.get_options():
		if String(o["label"]).begins_with("Join") and o["disabled"]:
			found = true
			assert_true(String(o["reason"]) != "" and not String(o["label"]).contains(String(o["reason"])), o["label"])
	assert_true(found, "a mortal is refused by at least one sect")
	hall.free()
	gs.end_session()


func test_anchor_entries() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var a: Node = load("res://src/world/interactables/interactable.gd").new()
	a.anchor_id = "a1"
	var b: Node = load("res://src/world/interactables/interactable.gd").new()
	b.anchor_id = "b1"
	var slots := CreationArtifact.anchor_slots(c, gs.data)
	c.anchors.clear()
	for i in range(slots):
		c.anchors.append("x%d" % i)
	var bind := _find(a.menu_options(), "Bind artifact anchor")
	assert_true(bind["disabled"], "all slots used")
	assert_true(String(bind["label"]).contains("anchor slots are bound; release one first"), bind["label"])
	c.anchors.clear()
	c.anchors.append("a1")
	assert_true(_find(a.menu_options(), "Release").is_empty(), "the only anchor cannot be released")
	c.anchors.append("b1")
	assert_false(_find(a.menu_options(), "Release").is_empty(), "release shown with two anchors")
	a.free()
	b.free()
	gs.end_session()


func test_fight_label_marks_lethal() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var enemy: Dictionary = (gs.data.enemies.values()[0] as Dictionary).duplicate()
	enemy["lethal"] = true
	assert_true(UIStyle.fight_label(c, gs.data, enemy).ends_with(", to the death"))
	enemy["lethal"] = false
	assert_false(UIStyle.fight_label(c, gs.data, enemy).contains("death"))
	gs.end_session()
