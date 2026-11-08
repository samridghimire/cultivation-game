extends TestCase
## UI-LEAK-001: building a HUD screen must not leave orphan nodes behind.


func test_panel_style_is_a_fresh_stylebox() -> void:
	var a := UIStyle.panel_style()
	assert_true(a != UIStyle.panel_style(), "each call returns its own StyleBox")
	assert_eq(a.bg_color, UIStyle.PANEL)
	assert_true(a is FramedPanel, "GFX-099: panels are framed")


func test_screens_leave_no_orphan_nodes() -> void:
	for screen_class in [ChoiceMenu, CharacterSheet, InventoryScreen, TechniquesScreen, CraftingScreen, CombatReport, PauseMenu, SettingsScreen, LoadScreen]:
		var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var screen: Control = screen_class.new()
		screen.free()
		var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		assert_eq(after, before, "%s leaked %d nodes" % [screen_class.get_global_name(), after - before])


func test_shared_theme_styles_form_controls() -> void:
	var t := UIStyle.theme()
	assert_true(t == UIStyle.theme(), "cached")
	for pair in [["LineEdit", "normal"], ["LineEdit", "focus"], ["OptionButton", "normal"], ["OptionButton", "focus"], ["PopupMenu", "panel"], ["CheckBox", "focus"], ["CheckButton", "focus"], ["HSlider", "slider"], ["HSlider", "grabber_area"], ["SpinBox", "normal"], ["VScrollBar", "grabber"], ["HScrollBar", "scroll"]]:
		assert_true(t.has_stylebox(pair[1], pair[0]), "%s/%s styled" % pair)


func test_key_cap_rects_cover_each_key() -> void:
	var font := ThemeDB.fallback_font
	var rects := UIStyle.key_cap_rects(font, 12, "[E] Talk   [C] Sheet", 400.0, 4.0, 26.0)
	assert_eq(rects.size(), 2)
	assert_true(rects[0].end.x < rects[1].position.x, "caps do not overlap")
	assert_true(rects[1].end.x <= 400.0, "caps stay inside the bar")
