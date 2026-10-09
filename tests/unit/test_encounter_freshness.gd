## ENC-003: familiar non-fight encounters fade while the fight share stays put.
extends TestCase

const TAGS := ["forest", "herbs"]


func _fade_all(c: CharacterData, count: int) -> void:
	for e: Dictionary in data().encounters.values():
		c.encounter_counts[String(e["id"])] = count


func _total(pool: Array[Dictionary], fights: bool) -> float:
	var t := 0.0
	for entry in pool:
		if Exploration._may_fight(entry["encounter"]) == fights:
			t += entry["weight"]
	return t


func test_freshness_values() -> void:
	var c := new_character()
	var plain := {"id": "x", "kind": "fortune"}
	assert_almost_eq(Exploration.freshness(c, plain), 1.0)
	c.encounter_counts["x"] = 1
	assert_almost_eq(Exploration.freshness(c, plain), 1.0 / 1.5)
	c.encounter_counts["x"] = 2
	assert_almost_eq(Exploration.freshness(c, plain), 0.5)
	c.encounter_counts["x"] = 500
	assert_almost_eq(Exploration.freshness(c, plain), 0.2)
	for extra: Dictionary in [{"enemy": "wolf"}, {"blocked_by_flag": "f"}, {"only_if_applicable": true}, {"repeatable": true}, {"discovery_only": true}]:
		var e := {"id": "x"}
		e.merge(extra)
		assert_almost_eq(Exploration.freshness(c, e), 1.0, 0.001, str(extra))


func test_totals_are_preserved() -> void:
	var c := new_character()
	var fresh := Exploration.eligible_encounters(c, data(), TAGS, {})
	_fade_all(c, 20)
	var faded := Exploration.eligible_encounters(c, data(), TAGS, {})
	assert_almost_eq(_total(faded, true), _total(fresh, true), 0.0001)
	assert_almost_eq(_total(faded, false), _total(fresh, false), 0.0001)


func _share(c: CharacterData, id: String) -> float:
	var pool := Exploration.eligible_encounters(c, data(), TAGS, {})
	var total := 0.0
	var mine := 0.0
	for entry in pool:
		total += entry["weight"]
		if entry["encounter"]["id"] == id:
			mine = entry["weight"]
	return mine / total


func test_met_encounter_loses_share_others_gain() -> void:
	var c := new_character()
	var fading := ""
	var other := ""
	for entry in Exploration.eligible_encounters(c, data(), TAGS, {}):
		var e: Dictionary = entry["encounter"]
		if Exploration.fades(e):
			if fading == "":
				fading = String(e["id"])
			elif other == "":
				other = String(e["id"])
	assert_true(fading != "" and other != "")
	var before_a := _share(c, fading)
	var before_b := _share(c, other)
	c.encounter_counts[fading] = 10
	assert_true(_share(c, fading) <= before_a * 0.5, "met encounter fades")
	assert_true(_share(c, other) > before_b, "fresh one gains")


func test_counts_round_trip() -> void:
	var c := new_character()
	c.encounter_counts["forest_lost"] = 3
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.encounter_counts.get("forest_lost", 0), 3)
	var d := c.to_dict()
	d.erase("encounter_counts")
	assert_eq(CharacterData.from_dict(d).encounter_counts.size(), 0)


func test_plain_gathering_is_repeatable() -> void:
	assert_true(data().encounters["forest_herbs"].get("repeatable", false))
