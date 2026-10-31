extends TestCase
## GFX-032: shared item rows with framed icons, count and price badges.


func test_row_has_framed_icon_and_count_badge() -> void:
	var b := ItemRow.make(data(), "spirit_stone", 3)
	assert_eq(String(b.name), "spirit_stone")
	assert_true(b.icon != null and b.icon.get_width() == ItemRow.SLOT, "framed 36 px slot")
	assert_false(b.text.contains("x3"), "count is not part of the name")
	var badge := b.get_node("Badge") as Control
	assert_true(badge.visible)
	assert_eq((badge.get_node("BadgeLabel") as Label).text, "x3")
	b.free()


func test_single_item_hides_badge() -> void:
	var b := ItemRow.make(data(), "spirit_stone", 1)
	assert_false((b.get_node("Badge") as Control).visible)
	b.free()


func test_price_badge_shows_stone_icon() -> void:
	var b := ItemRow.make(data(), "spirit_stone", 1, "", 15)
	var badge := b.get_node("Badge") as Control
	assert_true(badge.visible)
	assert_eq((badge.get_node("BadgeLabel") as Label).text, "15")
	assert_eq(badge.get_child_count(), 2, "stone icon + price")
	b.free()


func test_extra_tag_goes_in_text() -> void:
	var b := ItemRow.make(data(), "spirit_stone", 2, "(readied)")
	assert_true(b.text.ends_with("(readied)"))
	b.free()


func test_list_height_fits_rows() -> void:
	assert_true(InventoryScreen.LIST_ROW_HEIGHT >= ItemRow.SLOT + 4)
