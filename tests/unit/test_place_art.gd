extends TestCase
## VIS-003: every place type has placeholder art and interaction targets pulse.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## Place types that existed at VIS-003. Newer types fall back to a plain box
## until they get art (VIS-004), so this list is deliberately not data-driven.
func test_core_place_types_have_art() -> void:
	for kind in ["meditation", "merchant", "sect_hall", "workshop", "deed_giver", "explore", "travel", "gather", "npc"]:
		assert_true(PlaceArt.KINDS.has(kind), "no art for '%s'" % kind)


func test_highlight_pulses_only_while_targeted() -> void:
	var node := Interactable.new()
	node.art_kind = "meditation"
	_root().add_child(node)
	assert_false(node.is_processing(), "idle places do not redraw every frame")
	node.highlighted = true
	assert_true(node.is_processing())
	node.highlighted = false
	assert_false(node.is_processing())
	node.free()


## VIS-004: every place type in regions.json (and abodes) has its own art,
## and drawing each one raises no errors.
func test_every_place_type_has_art_and_draws() -> void:
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			assert_true(PlaceArt.KINDS.has(String(place["type"])), "no art for '%s'" % place["type"])
	assert_true(PlaceArt.KINDS.has("abode"))
	var nodes: Array = []
	for kind in PlaceArt.KINDS:
		var node := Interactable.new()
		node.art_kind = kind
		node.anchor_id = "qingshi_rock" if kind == "meditation" else ""
		_root().add_child(node)
		node.queue_redraw()
		nodes.append(node)
	await _root().get_tree().process_frame
	await _root().get_tree().process_frame
	for node in nodes:
		node.free()


## W-005e: the rift glows while a realm in the region is open.
func test_secret_realm_rift_glows_while_open() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	gs.start_session(new_character())
	gs.current_region = "misty_forest"
	var rift: Node = load("res://src/world/interactables/secret_realm_entrance.gd").new()
	var def := SecretRealms.realm(gs.data, "verdant_remnant")
	var open_day := -1
	for day in range(0, 3650 * 4, 5):
		if SecretRealms.is_open(def, day):
			open_day = day
			break
	assert_true(open_day >= 0)
	clock.total_days = open_day
	assert_true(rift.art_active())
	clock.total_days = open_day + int(def.get("open_days", 30)) + 1
	assert_false(rift.art_active())
	rift.free()
	gs.end_session()
