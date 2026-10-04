extends TestCase
## C-010: Foundation and Core Formation injuries, their cures and recipes.

const HIGH_INJURIES := ["meridian_rupture", "cracked_dantian", "spirit_burn", "soul_scar", "demonic_qi_corrosion", "golden_core_fissure", "sundered_body"]


func test_every_injury_has_a_cure_and_a_recipe_teaches_it() -> void:
	var d := data()
	for injury_id in HIGH_INJURIES:
		assert_true(d.injuries.has(injury_id), injury_id)
		var cures: Array = d.items.values().filter(func(item: Dictionary) -> bool: return String(item.get("effects", {}).get("heal_injury", "")) == injury_id)
		assert_eq(cures.size(), 1, "%s has one dedicated cure" % injury_id)
		var cure_id := String(cures[0]["id"])
		assert_true(d.recipes.has(cure_id), "%s can be refined" % cure_id)
		assert_true(d.items.has("recipe_" + cure_id), "a scroll teaches %s" % cure_id)
		assert_lt_price(d, cure_id, injury_id)


## A cure costs less than the clinic would charge for a fresh injury, so a
## Doctor's or alchemist's pills are worth buying and selling.
func assert_lt_price(d: GameData, cure_id: String, injury_id: String) -> void:
	assert_true(int(d.items[cure_id]["price"]) <= int(d.injuries[injury_id]["treatment_cost"]), "%s costs more than a clinic visit" % cure_id)


func test_min_realm_keeps_high_injuries_off_low_cultivators() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.attributes["fortune"] = 10
	for i in 300:
		c.injuries = {}
		var injury := Injuries.roll(c, d, "breakthrough_failure", seeded_rng(i))
		assert_false(injury in HIGH_INJURIES, "Qi Refining suffered %s" % injury)
	c.realm_index = d.realm_index_of("core_formation")
	var seen := {}
	for i in 300:
		c.injuries = {}
		seen[Injuries.roll(c, d, "breakthrough_failure", seeded_rng(i))] = true
	assert_true(seen.has("golden_core_fissure"), "Core Formation can crack its core: %s" % str(seen.keys()))


func test_min_realm_is_validated() -> void:
	var d := GameData.load_from_dir()
	d.injury_sources["combat_defeat"]["table"].append({"id": "spirit_burn", "weight": 1, "min_realm": "nowhere"})
	d.load_errors.clear()
	d._validate()
	assert_true(Array(d.load_errors).any(func(e: String) -> bool: return e.contains("unknown min_realm 'nowhere'")), str(d.load_errors))
