extends TestCase
## WU-546: the first-visit arrival banner (title + stats + teacher line) wraps into the column between the
## status card and the Next-steps card instead of covering them, at 1280x800 and 1280x720.

const LONG_SUB := "First visit · Qi x1.8 · Moderate\nPeddler Hei teaches Drowned Reed Step (favor 20, from Qi Refining) and Broker Qian teaches Gold-Piercing Finger (favor 25)"


func test_wrap_lines_fits_width() -> void:
	var font := ThemeDB.fallback_font
	var out := Banner.wrap_lines(LONG_SUB, font, 18, 500.0)
	assert_true(out.split("\n").size() > 2, "the long teacher line wraps")
	for line in out.split("\n"):
		assert_true(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= 500.0 + 1.0, "line fits: " + line)
	assert_eq(Banner.wrap_lines("short", font, 18, 500.0), "short")


func test_slim_banner_stays_between_the_cards() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	for h in [800, 720]:
		var host := Control.new()
		host.size = Vector2(1280, h)
		root.add_child(host)
		var banner := Banner.new()
		host.add_child(banner)
		banner.announce("Withered Bone Marsh", LONG_SUB, Color.WHITE, 3.0, false, null, true)
		await (Engine.get_main_loop() as SceneTree).process_frame
		await (Engine.get_main_loop() as SceneTree).process_frame
		var ribbon := banner.ribbon_rect()
		assert_true(ribbon.position.x >= 1280.0 * Banner.SLIM_LEFT - 1.0, "clear of the status card at %d" % h)
		assert_true(ribbon.end.x <= 1280.0 * Banner.SLIM_RIGHT + 1.0, "clear of the Next-steps card at %d" % h)
		assert_true(ribbon.end.y <= float(h) * 0.4, "stays in the top part of the screen at %d" % h)
		host.queue_free()


## GFX-206: the HUD's blocker rects include the banner ribbon while it shows.
func test_hud_occupied_rects_include_banner() -> void:
	var hud: Node = load("res://src/ui/hud.tscn").instantiate() if ResourceLoader.exists("res://src/ui/hud.tscn") else null
	if hud == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hud)
	await tree.process_frame
	hud._banner.announce("Qingshi Village", "Arrival", Color.WHITE, 5.0, false, null, true)
	await tree.process_frame
	await tree.process_frame
	assert_true(hud.banner_showing())
	var ribbon: Rect2 = hud._banner.ribbon_rect()
	var covered := false
	for r: Rect2 in hud.occupied_rects():
		if r.encloses(ribbon):
			covered = true
	assert_true(covered, "banner ribbon in occupied_rects")
	tree.root.remove_child(hud)
	hud.free()
	await tree.process_frame
