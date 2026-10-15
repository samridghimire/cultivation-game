extends TestCase
## WU-165: HUD panels fade when the player or a place label is behind them.

const HudScript := preload("res://src/ui/hud.gd")


func test_panel_alpha() -> void:
	var panel := Rect2(0, 0, 100, 100)
	var none: Array[Rect2] = []
	var far: Array[Rect2] = [Rect2(300, 300, 10, 10)]
	var near: Array[Rect2] = [Rect2(300, 300, 10, 10), Rect2(90, 90, 40, 40)]
	assert_eq(HudScript.panel_alpha(panel, none), 1.0)
	assert_eq(HudScript.panel_alpha(panel, far), 1.0)
	assert_eq(HudScript.panel_alpha(panel, near), 0.35)
