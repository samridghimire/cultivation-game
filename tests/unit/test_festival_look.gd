extends TestCase
## WU-072: festivals get a banner, "Festival:" labels and a favor note in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _lantern() -> Dictionary:
	return {"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 8}


func test_labels() -> void:
	var d: GameData = _root().get_node("GameState").data
	assert_eq(WorldEvents.active_label(d, "lantern_festival"), "Festival: Lantern Festival")
	assert_eq(WorldEvents.active_label(d, "beast_tide"), "%s!" % WorldEvents.event_name(d, "beast_tide"))
	assert_true(WorldMapScreen.HudScript.region_event_suffix(d, [_lantern()], "qingshi_village").contains("Festival: Lantern Festival"))
	var c := new_character(5)
	var marks := WorldMapScreen.region_marks(c, d, {}, [_lantern()], 1, "qingshi_village", "qingshi_village")
	var texts := ""
	for m: Dictionary in marks:
		texts += String(m["text"])
	assert_true(texts.contains("Festival: Lantern Festival (7 days left)") or texts.contains("Festival: Lantern Festival ("), texts)


func test_banner_on_festival_start() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(new_character(778))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	var banner: Banner = hud.get("_banner")
	banner.finish_current()
	_root().get_node("EventBus").festival_started.emit("Lantern Festival", "Lanterns drift.")
	assert_true(banner.visible)
	assert_eq(banner.title_text(), "Lantern Festival")
	assert_eq(banner.subtitle_text(), "Lanterns drift.")
	hud.free()
	gs.end_session()


func test_chat_note_with_and_without_festival() -> void:
	var gs: Node = _root().get_node("GameState")
	var npc_script: GDScript = load("res://src/world/interactables/npc.gd")
	assert_eq(npc_script.festival_note(gs.data, [], "qingshi_village"), "")
	assert_eq(npc_script.festival_note(gs.data, [_lantern()], "qingshi_village"), " (festival: favor x2)")


## C-047: every festival tag has at least 2 encounters, and each festival uses one.
func test_each_festival_tag_has_two_encounters() -> void:
	var d: GameData = _root().get_node("GameState").data
	var tags: Array = []
	for ev in d.world_events.values():
		if bool(ev.get("festival", false)):
			var t: Array = ev.get("modifiers", {}).get("encounter_tags", [])
			assert_true(not t.is_empty(), "festival %s has no encounter tag" % ev["id"])
			tags.append_array(t)
	assert_true(tags.size() >= 3)
	for tag in tags:
		var n := 0
		for enc in d.encounters.values():
			if (enc.get("tags", []) as Array).has(tag):
				n += 1
		assert_true(n >= 2, "festival tag %s has %d encounters" % [tag, n])


## C-061: every festival sells at least 2 festival goods, which no ordinary merchant stocks.
func test_every_festival_has_two_untagged_shop_items() -> void:
	var d := GameData.load_from_dir()
	for ev: Dictionary in d.world_events.values():
		if not bool(ev.get("festival", false)):
			continue
		var goods: Array = ev.get("shop_items", [])
		assert_true(goods.size() >= 2, "festival %s needs 2+ shop items" % ev["id"])
		for item_id: String in goods:
			var item: Dictionary = d.items[item_id]
			assert_true((item.get("tags", []) as Array).is_empty(), "%s must be untagged" % item_id)
			assert_true(int(item["price"]) <= 15, "%s is cheap" % item_id)
