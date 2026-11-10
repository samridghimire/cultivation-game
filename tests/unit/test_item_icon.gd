extends TestCase
## ItemIcon kinds, size and caching (GFX-019).


func _kind(id: String) -> String:
	return ItemIcon.kind_of(data().items[id])


func test_kinds_cover_every_item_with_a_glyph() -> void:
	for id: String in data().items:
		assert_true(ItemIcon.GLYPHS.has(ItemIcon.kind_of(data().items[id])), id)


func test_kind_of_each_category() -> void:
	assert_eq(_kind("moon_cake"), "food")
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


func test_icon_field_and_tag_mapping() -> void:
	assert_eq(ItemIcon.kind_of({"id": "x", "icon": "kite", "usable": true}), "kite")
	assert_eq(ItemIcon.kind_of({"id": "x", "tags": ["trophy"]}), "trophy")
	assert_eq(ItemIcon.kind_of({"id": "x", "tags": ["meat"]}), "meat")
	assert_eq(ItemIcon.kind_of({"id": "x", "tags": ["grain"]}), "grain")
	assert_eq(ItemIcon.kind_of({"id": "x", "tags": ["keepsake"]}), "charm")
	assert_eq(ItemIcon.kind_of({"id": "x", "usable": true}), "pill")
	assert_eq(ItemIcon.kind_of({"id": "x"}), "pouch")


func test_icon_kinds_match_glyphs_and_bodies() -> void:
	for kind: String in GameData.ITEM_ICON_KINDS:
		assert_true(ItemIcon.GLYPHS.has(kind), "glyph " + kind)
		assert_true(ItemIcon.BODY.has(kind), "body " + kind)
	for kind: String in ItemIcon.GLYPHS:
		var rows: Array = ItemIcon.GLYPHS[kind]
		assert_eq(rows.size(), 12, kind)
		for row: String in rows:
			assert_eq(row.length(), 12, kind)
			for ch in row:
				assert_true(ch in "oab.", kind)


func test_the_eight_festival_items_have_distinct_kinds() -> void:
	var seen: Dictionary = {}
	for id: String in ["ancestor_incense", "dragon_boat_charm", "five_colour_thread", "jade_rabbit_lantern", "osmanthus_wine", "paper_kite"]:
		seen[_kind(id)] = true
	assert_eq(seen.size(), 6)
	assert_eq(_kind("green_dumpling"), "food")


func test_validation_rejects_unknown_icon() -> void:
	var d: GameData = data()
	var item: Dictionary = d.items["moon_cake"]
	item["icon"] = "banana"
	d.load_errors.clear()
	d._validate()
	var found := false
	for e: String in d.load_errors:
		if e.contains("moon_cake") and e.contains("icon"):
			found = true
	item["icon"] = "food"
	d.load_errors.clear()
	assert_true(found)
