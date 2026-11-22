extends TestCase
## SECT-031: sect_joined / sect_promoted signals, Guidance.sect_welcome and Sects.promotion_summary.

var _joined: Array[String] = []
var _promoted: Array = []


func _on_joined(id: String) -> void:
	_joined.append(id)


func _on_promoted(id: String, rank: int) -> void:
	_promoted.append([id, rank])


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Moments", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	c.alignment = 0
	gs.start_session(c)
	return c


func test_join_and_promotion_signals() -> void:
	var c := _start()
	var gs := _gs()
	_joined.clear()
	_promoted.clear()
	_bus().sect_joined.connect(_on_joined)
	_bus().sect_promoted.connect(_on_promoted)
	gs.join_sect("blood_lotus_sect")
	gs.join_sect("myriad_treasure_pavilion")  # refused: already a member
	assert_eq(_joined, ["blood_lotus_sect"] as Array[String])
	c.sect["rank"] = 1
	gs._post_promotion()
	assert_eq(_promoted.size(), 1)
	assert_eq(_promoted[0], ["blood_lotus_sect", 1])
	_bus().sect_joined.disconnect(_on_joined)
	_bus().sect_promoted.disconnect(_on_promoted)
	gs.end_session()


func test_failed_join_emits_nothing() -> void:
	var c := _start()
	var gs := _gs()
	_joined.clear()
	_bus().sect_joined.connect(_on_joined)
	c.alignment = -900  # far from a righteous sect
	gs.join_sect("azure_cloud_sect")
	assert_true(_joined.is_empty())
	_bus().sect_joined.disconnect(_on_joined)
	gs.end_session()


func test_welcome_summary() -> void:
	var d := data()
	var c := CharacterFactory.create("Welcome", d, seeded_rng(5))
	c.realm_index = 1
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var home := Sects.home_region(d, "azure_cloud_sect")
	var away := Guidance.sect_welcome(c, d, "azure_cloud_sect", "qingshi_village")
	assert_gt(int(away["home_days"]), 0)
	assert_true(String(away["duty"]) != "")
	assert_true(String(away["first_step"]).begins_with("Walk to"))
	assert_true((away["perks"] as PackedStringArray).size() <= 3)
	var here := Guidance.sect_welcome(c, d, "azure_cloud_sect", home)
	assert_eq(int(here["home_days"]), 0)
	assert_true(String(here["first_step"]).contains("at the hall"))


func test_promotion_summary_top_rank() -> void:
	var d := data()
	var c := CharacterFactory.create("Top", d, seeded_rng(6))
	var sect: SectDef = d.sects["azure_cloud_sect"]
	c.sect = {"id": "azure_cloud_sect", "rank": sect.ranks.size() - 1, "contribution": 0}
	var s := Sects.promotion_summary(c, d)
	assert_eq(String(s["next_needs"]), "")
	assert_eq(String(s["rank_name"]), sect.rank_name(sect.ranks.size() - 1))
	c.sect["rank"] = 1
	assert_true(String(Sects.promotion_summary(c, d)["next_needs"]) != "")
