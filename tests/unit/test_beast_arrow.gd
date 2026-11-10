extends TestCase
## GFX-075: the edge arrow that points at an off-screen great beast.

const VIEW := Rect2(0, 0, 1280, 800)


func test_on_screen_hides() -> void:
	assert_false(bool(BeastArrow.edge_arrow(Vector2(600, 400), VIEW, 36.0)["visible"]))


func test_four_edges() -> void:
	var r := BeastArrow.edge_arrow(Vector2(-300, 400), VIEW, 36.0)
	assert_true(bool(r["visible"]))
	assert_eq((r["position"] as Vector2).x, 36.0)
	assert_eq((r["position"] as Vector2).y, 400.0)
	assert_true(absf(absf(float(r["angle"])) - PI) < 0.3)
	r = BeastArrow.edge_arrow(Vector2(1700, 400), VIEW, 36.0)
	assert_eq((r["position"] as Vector2).x, 1244.0)
	assert_true(absf(float(r["angle"])) < 0.3)
	r = BeastArrow.edge_arrow(Vector2(640, -200), VIEW, 36.0)
	assert_eq((r["position"] as Vector2).y, 36.0)
	assert_true(absf(float(r["angle"]) + PI / 2.0) < 0.1)
	r = BeastArrow.edge_arrow(Vector2(640, 1500), VIEW, 36.0)
	assert_eq((r["position"] as Vector2).y, 764.0)
	assert_true(absf(float(r["angle"]) - PI / 2.0) < 0.1)


func test_corner() -> void:
	var r := BeastArrow.edge_arrow(Vector2(2000, 2000), VIEW, 36.0)
	assert_eq(r["position"], Vector2(1244, 764))
	assert_true(float(r["angle"]) > 0.0 and float(r["angle"]) < PI / 2.0)


func test_clear_of_hud_rect_slides_along_edge() -> void:
	var box := Rect2(20, 380, 150, 60)
	var hud: Array[Rect2] = [Rect2(0, 300, 300, 200)]
	var placed := BeastArrow.clear_of(box, hud, VIEW)
	assert_false(placed.intersects(hud[0]))
	assert_true(VIEW.encloses(placed))
	var none: Array[Rect2] = []
	assert_eq(BeastArrow.clear_of(box, none, VIEW), box)


func test_hides_while_a_modal_is_open() -> void:
	var arrow := BeastArrow.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(arrow)
	EventBus.ui_modal_changed.emit(true)
	assert_false(arrow.visible, "hidden behind an open menu")
	EventBus.ui_modal_changed.emit(false)
	assert_true(arrow.visible)
	arrow.free()


func test_clamp_marker_moves_out_of_panel() -> void:
	var panel: Array[Rect2] = [Rect2(10, 10, 300, 200)]
	var p := BeastArrow.clamp_marker(Vector2(100, 100), VIEW, panel)
	assert_true(p.x >= 316.0 or p.y >= 216.0)
	assert_true(VIEW.has_point(p))


func test_clamp_marker_free_point_unchanged() -> void:
	var panel: Array[Rect2] = [Rect2(10, 10, 300, 200)]
	assert_eq(BeastArrow.clamp_marker(Vector2(800, 500), VIEW, panel), Vector2(800, 500))
