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
