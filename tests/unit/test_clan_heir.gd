extends TestCase
## FAM-008: clan heirs (default by birth rank and age, designation) and succession.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(people: Dictionary, id: String, age: int, birth_rank: String = "wife") -> CharacterData:
	var n := new_character(id.hash())
	n.id = id
	n.name = id
	n.age_days = age * Calendar.DAYS_PER_YEAR
	n.birth_rank = birth_rank
	people[id] = n
	return n


## A clan headed by "head" with children: concubine's eldest son, wife's younger
## daughter, an adopted eldest child, and a grandchild through the daughter.
func _family() -> Dictionary:
	var people := {}
	var head := _person(people, "head", 60, "")
	head.gender = "male"
	var concubine_son := _person(people, "concubine_son", 30, "concubine")
	var wife_daughter := _person(people, "wife_daughter", 20, "wife")
	var adopted := _person(people, "adopted", 35, "")
	var grandchild := _person(people, "grandchild", 2, "")
	head.children.append_array([concubine_son.id, wife_daughter.id, adopted.id])
	wife_daughter.children.append(grandchild.id)
	var clan := ClanData.new()
	clan.name = "Lin Clan"
	clan.head = head.id
	clan.members = {"head": "patriarch", "concubine_son": "core", "wife_daughter": "core", "adopted": "core", "grandchild": "core"}
	return {"people": people, "clan": clan, "head": head}


func test_heir_rules_are_valid() -> void:
	assert_eq(Clans.validate(data()).size(), 0, str(Clans.validate(data())))
	assert_eq(Clans.heir_title(data(), "male"), "Young Master")
	assert_eq(Clans.heir_title(data(), "female"), "Young Mistress")
	assert_eq(Clans.heir_title(data(), "unknown"), "Clan Heir")


func test_default_heir_prefers_main_wife_then_eldest() -> void:
	var f := _family()
	var people: Dictionary = f["people"]
	var clan: ClanData = f["clan"]
	var head: CharacterData = f["head"]
	assert_eq(Clans.default_heir(clan, head, people, data()), "wife_daughter", "the main wife's child outranks an elder concubine's son")
	people["wife_daughter"].alive = false
	assert_eq(Clans.default_heir(clan, head, people, data()), "concubine_son")
	people["concubine_son"].alive = false
	assert_eq(Clans.default_heir(clan, head, people, data()), "adopted", "adopted children come last")
	clan.members.erase("adopted")
	assert_eq(Clans.default_heir(clan, head, people, data()), "", "only clan members inherit")


func test_designating_an_heir() -> void:
	var f := _family()
	var people: Dictionary = f["people"]
	var clan: ClanData = f["clan"]
	var head: CharacterData = f["head"]
	var stranger := _person(people, "stranger", 30)
	clan.members[stranger.id] = "outer"
	assert_true(Clans.check_designate(head, clan, stranger, people).contains("descendants"))
	assert_true(Clans.check_designate(head, null, stranger, people).contains("no clan"))
	var outsider := _person(people, "outsider_son", 10)
	head.children.append(outsider.id)
	assert_true(Clans.check_designate(head, clan, outsider, people).contains("not of"))
	assert_true(Clans.designate_heir(head, clan, people["grandchild"], people)["ok"], "grandchildren can inherit")
	assert_eq(Clans.heir(clan, head, people, data()), "grandchild")
	assert_true(Clans.check_designate(head, clan, people["grandchild"], people).contains("already"))
	people["grandchild"].alive = false
	assert_eq(Clans.heir(clan, head, people, data()), "wife_daughter", "a dead heir falls back to the default")
	Clans.sync_family(head, clan, people, data())
	assert_eq(clan.heir, "", "a dead heir is cleared")


func test_succession_when_the_head_dies() -> void:
	var f := _family()
	var people: Dictionary = f["people"]
	var clan: ClanData = f["clan"]
	var head: CharacterData = f["head"]
	assert_false(Clans.succeed(clan, people, data())["succeeded"], "a living head keeps the seat")
	Clans.designate_heir(head, clan, people["concubine_son"], people)
	head.alive = false
	var result := Clans.succeed(clan, people, data())
	assert_true(result["succeeded"])
	assert_eq(result["previous"], "head")
	assert_eq(clan.head, "concubine_son")
	assert_eq(clan.members["concubine_son"], "patriarch")
	assert_false(clan.members.has("head"))
	assert_eq(clan.heir, "")


func test_succession_without_heirs_falls_to_highest_rank() -> void:
	var people := {}
	var head := _person(people, "head", 60)
	var elder := _person(people, "elder", 40)
	var old_core := _person(people, "old_core", 70)
	var clan := ClanData.new()
	clan.head = head.id
	clan.members = {"head": "patriarch", "elder": "elder", "old_core": "core"}
	head.alive = false
	assert_eq(Clans.succeed(clan, people, data())["head"], "elder")
	elder.alive = false
	old_core.alive = false
	var result := Clans.succeed(clan, people, data())
	assert_false(result["succeeded"], "the line ends")
	assert_eq(clan.head, "")


func test_heir_saves() -> void:
	var clan := ClanData.new()
	clan.heir = "gen_son"
	assert_eq(ClanData.from_dict(JSON.parse_string(JSON.stringify(clan.to_dict()))).heir, "gen_son")
	assert_eq(ClanData.from_dict({"name": "Old"}).heir, "")


func test_game_state_designate_heir() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.inventory["spirit_stone"] = 2000
	var son := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 5, "region": gs.current_region})
	var daughter := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 3, "region": gs.current_region})
	c.children.append_array([son.id, daughter.id])
	gs.designate_heir(daughter.id)  # no clan yet: a warning
	gs.found_clan()
	assert_true(gs.clan.members.has(daughter.id))
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.designate_heir(daughter.id)
	assert_eq(clock.total_days, days, "naming an heir takes no time")
	assert_eq(gs.clan.heir, daughter.id)
	gs.load_save_dict(JSON.parse_string(JSON.stringify(gs.to_save_dict())))
	assert_eq(gs.clan.heir, daughter.id, "the heir survives a save")
	gs.end_session()
