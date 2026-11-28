extends TestCase
## GUIDE-306: Guidance.first_spar_hint names someone here who would spar, for the first bout only.


func _fixture() -> Array:
	var d := data()
	var c := CharacterFactory.create("Sparrer", d, seeded_rng(3))
	c.realm_index = 1
	c.sect = {}
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	rival.realm_index = 1
	rival.stage = 0
	return [d, c, people, rival]


func test_first_spar_hint_names_a_willing_partner_here() -> void:
	var s := _fixture()
	var d: GameData = s[0]
	var c: CharacterData = s[1]
	var people: Dictionary = s[2]
	var rival: CharacterData = s[3]
	var favor := {rival.id: 20}
	var line := Guidance.first_spar_hint(c, d, people, favor, "qingshi_village", 100, {})
	assert_true(line.begins_with("%s (" % rival.name) and line.contains(" here would spar with you"), line)
	assert_eq(Guidance.first_spar_hint(c, d, people, favor, "other_region", 100, {}), "", "not here")
	c.npc_action_days["spar:" + rival.id] = 90
	assert_eq(Guidance.first_spar_hint(c, d, people, favor, "qingshi_village", 100, {}), "", "only the first bout")
