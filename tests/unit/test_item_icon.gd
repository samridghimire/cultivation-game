extends TestCase
## ItemIcon kinds, size and caching (GFX-019).


func _kind(id: String) -> String:
	return ItemIcon.kind_of(data().items[id])


func test_kinds_cover_every_item_with_a_glyph() -> void:
	for id: String in data().items:
		assert_true(ItemIcon.GLYPHS.has(ItemIcon.kind_of(data().items[id])), id)


func test_kind_of_each_category() -> void:
	assert_eq(_kind("moon_cake"), "pill")
	assert_eq(_kind("boar_hide_jerkin"), "armor")
	assert_eq(_kind("spirit_stone"), "spirit_stone")
	var seen: Dictionary = {}
	for id: String in data().items:
		seen[ItemIcon.kind_of(data().items[id])] = true
	for kind: String in ["pill", "herb", "ore", "beast_material", "weapon", "armor", "talisman", "manual", "scroll"]:
		assert_true(seen.has(kind), kind)


func test_unusable_untagged_item_is_a_pouch() -> void:
	assert_eq(ItemIcon.kind_of({"id": "x"}), "pouch")
	assert_eq(ItemIcon.kind_of({"equip": {"slot": "boots"}}), "armor")
	assert_eq(ItemIcon.kind_of({"equip": {"slot": "accessory"}}), "accessory")


func test_texture_size_and_cache() -> void:
	var item: Dictionary = data().items["moon_cake"]
	var tex := ItemIcon.texture("moon_cake", item)
	assert_eq(tex.get_width(), ItemIcon.SIZE * ItemIcon.ZOOM)
	assert_true(tex == ItemIcon.texture("moon_cake", item), "cached")


func test_pills_tint_per_item() -> void:
	var pill := {"usable": true}
	var a := ItemIcon.texture("pill_a_tint", pill).get_image().get_pixel(10, 8)
	var found_different := false
	for id in ["pill_b", "pill_c", "pill_d", "pill_e"]:
		if ItemIcon.texture(id, pill).get_image().get_pixel(10, 8) != a:
			found_different = true
	assert_true(found_different)
