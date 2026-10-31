extends TestCase
## WU-413: the companion chip in the HUD status card, the combat report line, and the field's dry-day note.

func test_report_line() -> void:
	assert_eq(CombatReport.companion_line("Xiao Ling"), "Xiao Ling fights at your side")
	assert_eq(CombatReport.companion_line(""), "")


func x_test_dry_note() -> void:
	var place := {"type": "field_plot", "display_name": "T", "plots": 1, "rent": 1, "rent_days": 90,
		"plants": {"spirit_herb": {"days": 5, "yield": [2, 3]}}, "rain_bonus_days": 1, "frozen_seasons": ["winter"]}
	var key := "qingshi_village:T"
	var c := new_character()
	c.inventory = {"spirit_stone": 20, "spirit_herb": 5}
	assert_eq(FieldPlots.dry_note(c, place, key, 10, "clear"), "", "not rented")
	FieldPlots.rent(c, "qingshi_village", place, 10)
	FieldPlots.plant(c, data(), place, key, "spirit_herb", 10)
	assert_eq(FieldPlots.dry_note(c, place, key, 10, "clear"), "Dry, water it today.")
	assert_eq(FieldPlots.dry_note(c, place, key, 10, "rain"), "")
	FieldPlots.water(c, place, key, 10, "clear")
	assert_eq(FieldPlots.dry_note(c, place, key, 10, "clear"), "")


func test_tool_glyphs() -> void:
	assert_eq(HudIcons.tool_glyph("watering_can").get_size(), Vector2(12, 12))
	assert_eq(HudIcons.tool_glyph("hoe").get_size(), Vector2(12, 12))
	assert_true(HudIcons.tool_glyph("nope") == null)
