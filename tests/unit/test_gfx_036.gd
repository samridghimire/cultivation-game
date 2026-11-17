extends TestCase
## GFX-036: fallen beasts lie on the ground, the backdrop varies per region, forced weather sticks.


func test_fallen_beast_lies_flat_on_the_ground() -> void:
	var r := DuelStage.fallen_rect(Vector2(96, 60), Vector2(100, 150), true)
	assert_true(absf(r.end.y - 150.0) <= 2.0)
	assert_true(r.size.y <= 62.0)


func test_fallen_person_rests_on_the_ground() -> void:
	var r := DuelStage.fallen_rect(Vector2(28, 72), Vector2(100, 150), false)
	assert_true(absf(r.end.y - 150.0) <= 2.0)
	assert_true(r.size.y <= 30.0)


func test_silhouettes_vary_by_region_but_are_stable() -> void:
	var a := DuelStage.silhouette_shapes("qingshi_village", "roofs", 620.0)
	var b := DuelStage.silhouette_shapes("qingshi_village", "roofs", 620.0)
	var c := DuelStage.silhouette_shapes("fallen_star_market", "roofs", 620.0)
	assert_eq(a, b)
	assert_true(a != c)
	assert_true(a.size() >= 3)


func test_force_weather_survives_clock_advance() -> void:
	var world: Node = load("res://src/world/world.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	world.call("force_weather", "storm")
	GameClock.advance(1)
	assert_eq(world.get("_weather_kind"), "storm")
	world.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame


## GFX-107: the layered backdrop is deterministic per region and keeps props off the fighters' feet.
func test_backdrop_layers_gfx107() -> void:
	for rid in ["qingshi_village", "misty_forest", "withered_bone_marsh", "azure_peak", "fallen_star_market", "other"]:
		var a := DuelStage.backdrop_layers(rid, 620.0)
		var b := DuelStage.backdrop_layers(rid, 620.0)
		assert_eq(a, b, "deterministic " + rid)
		assert_true(a["props"].size() >= 2 and a["props"].size() <= 4, "2-4 props " + rid)
		assert_true(a["far"].size() > 0 and a["near"].size() > 0, "layers " + rid)
		for p in a["props"]:
			var f: float = float(p["x"]) / 620.0
			assert_true(not (f >= 0.15 and f <= 0.30) and not (f >= 0.70 and f <= 0.85), "prop clear of feet " + rid)


## GFX-182: a woods override drops the village props and keeps every prop and trunk out of the foot zones.
func test_backdrop_override_gfx182() -> void:
	var a := DuelStage.backdrop_layers("qingshi_village", 620.0, "pines")
	for p in a["props"]:
		assert_true(String(p["kind"]) != "fence" and String(p["kind"]) != "lantern", "no village prop in the woods")
		var f: float = float(p["x"]) / 620.0
		assert_true(not (f >= 0.15 and f <= 0.30) and not (f >= 0.70 and f <= 0.85), "prop clear of feet")
	for kind in ["cave", "ruins", "crags", "reeds", "hills", "river", "pines"]:
		var b := DuelStage.backdrop_layers("qingshi_village", 620.0, kind)
		assert_true(b["near"].size() > 0 and b["props"].size() >= 2, "layers " + kind)
		assert_eq(b, DuelStage.backdrop_layers("qingshi_village", 620.0, kind), "deterministic " + kind)
	for rid in ["qingshi_village", "misty_forest"]:
		var trunks := DuelStage.foreground_trunks(rid, 620.0)
		assert_true(trunks.size() >= 2 and trunks.size() <= 3, "2-3 trunks")
		for tr in trunks:
			var f2: float = float(tr["x"]) / 620.0
			assert_true(not (f2 >= 0.15 and f2 <= 0.85), "trunk at the stage edge")


## WU-547: the Defeated tag sits just above the lying body, centred on it, for beast and person.
func test_defeated_tag_hugs_the_body_wu547() -> void:
	var stage := DuelStage.new()
	stage.size = Vector2(620, 182)
	(Engine.get_main_loop() as SceneTree).root.add_child(stage)
	stage.setup("wild_boar", ["beast"])
	stage.show_end_pose(true, false)
	var body := stage.fallen_body_rect(1)
	var tag := stage.defeated_tag_rect(1)
	assert_true(body.position.y - tag.end.y <= 8.0 and body.position.y - tag.end.y >= 0.0, "beast tag bottom near body top")
	assert_true(absf(tag.get_center().x - body.get_center().x) < 1.0, "centred")
	stage.show_end_pose(false, false)
	body = stage.fallen_body_rect(0)
	tag = stage.defeated_tag_rect(0)
	assert_true(body.position.y - tag.end.y <= 8.0, "player tag near body")
	stage.queue_free()


## WU-563: a beaten beast rolls onto its back: 0.8x its height, resting on the feet line, with the shadow and plate in place.
func test_fallen_beast_on_its_back_wu563() -> void:
	var stage := DuelStage.new()
	stage.size = Vector2(620, 182)
	(Engine.get_main_loop() as SceneTree).root.add_child(stage)
	stage.setup("wild_boar", ["beast"])
	stage.show_end_pose(true, false)
	var body := stage.fallen_body_rect(1)
	var stand := stage._body_size(1)
	assert_true(Rect2(Vector2.ZERO, stage.size).encloses(body), "body inside the stage")
	assert_true(absf(body.end.y - stage._feet_of(1).y) <= 2.0, "bottom on the feet line")
	assert_true(body.size.y >= stand.y * 0.7 and body.size.y <= stand.y * 0.85, "height 0.7-0.85x standing")
	var sh := stage.shadow_rect(1)
	assert_true(body.position.x <= sh.get_center().x and sh.get_center().x <= body.end.x, "shadow under body")
	assert_false(stage.defeated_tag_rect(1).intersects(body), "plate clear of the body")
	assert_true(stage._dark[1] < DuelStage.FALLEN_DARKEN, "beast darkens less than a person")
	assert_true(stage._dust_start < 0.0, "no dust when not animated")
	stage.queue_free()
