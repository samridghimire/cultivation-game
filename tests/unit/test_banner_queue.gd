extends TestCase
## RV-002: banners queue instead of replacing each other.

func test_second_announce_waits_for_first() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	b.announce("Milestone", "a", Color.WHITE)
	assert_eq(b.title_text(), "Breakthrough!")
	assert_eq(b.queued_count(), 1)
	b.finish_current()
	assert_eq(b.title_text(), "Milestone")
	b.finish_current()
	assert_false(b.visible)
	b.free()


func test_queue_capped_dropping_milestones_first() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	for i in 5:
		b.announce("Milestone", str(i), Color.WHITE)
	assert_eq(b.queued_count(), Banner.MAX_QUEUE)
	b.finish_current()
	assert_eq(b.subtitle_text(), "1")
	b.free()


## WU-124: a held banner queues, release plays it, low banners are dropped.
func test_held_banner_queues_until_released() -> void:
	var b := Banner.new()
	b.set_held(true)
	b.announce("Milestone", "a", Color.WHITE)
	assert_eq(b.queued_count(), 1)
	assert_false(b.visible)
	b.announce("Spring arrives", "x", Color.WHITE, 1.4, true)
	assert_eq(b.queued_count(), 1, "low banners are dropped while held")
	b.set_held(false)
	assert_true(b.visible)
	assert_eq(b.subtitle_text(), "a")
	assert_eq(b.queued_count(), 0)
	b.free()


## A banner already showing when the hold starts finishes without starting the queued one.
func test_banner_ending_while_held_keeps_queue() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	b.set_held(true)
	b.announce("Milestone", "a", Color.WHITE)
	b.finish_current()
	assert_false(b.visible, "the queued banner waits for the report to close")
	assert_eq(b.queued_count(), 1)
	b.set_held(false)
	assert_eq(b.subtitle_text(), "a")
	b.free()


func test_hud_holds_banner_while_combat_report_open() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	tree.root.add_child(hud)
	hud._combat_report.show_fight("Wolf", true, PackedStringArray(["x"]))
	hud._update_modal()
	EventBus.milestone_reached.emit("m", "Second Chance")
	assert_false(hud._banner.visible, "banner waits for the report")
	assert_eq(hud._banner.queued_count(), 1)
	hud._combat_report.close()
	hud._update_modal()
	assert_true(hud._banner.visible)
	hud.queue_free()
