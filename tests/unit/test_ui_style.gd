extends TestCase
## UI-LEAK-001: building a HUD screen must not leave orphan nodes behind.


func test_panel_style_is_a_fresh_stylebox() -> void:
	var a := UIStyle.panel_style()
	assert_true(a != UIStyle.panel_style(), "each call returns its own StyleBox")
	assert_eq(a.bg_color, UIStyle.PANEL)


func test_screens_leave_no_orphan_nodes() -> void:
	for screen_class in [ChoiceMenu, CharacterSheet, InventoryScreen, TechniquesScreen, CraftingScreen, CombatReport, PauseMenu, SettingsScreen, LoadScreen]:
		var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var screen: Control = screen_class.new()
		screen.free()
		var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		assert_eq(after, before, "%s leaked %d nodes" % [screen_class.get_global_name(), after - before])
