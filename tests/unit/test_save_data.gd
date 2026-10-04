extends TestCase


func test_character_round_trips_through_json() -> void:
	var c := new_character()
	c.realm_index = 2
	c.stage = 3
	c.qi = 1234.5
	c.alignment = -321
	c.sect = {"id": "blood_lotus_sect", "rank": 1, "contribution": 450}
	Professions.add_xp(c, data(), "alchemist", 250.0)
	c.add_item("qi_gathering_pill", 3)

	var json := JSON.stringify(c.to_dict())
	var restored := CharacterData.from_dict(JSON.parse_string(json))
	assert_eq(restored.to_dict(), c.to_dict())
	assert_eq(typeof(restored.realm_index), TYPE_INT)
	assert_eq(typeof(restored.inventory["qi_gathering_pill"]), TYPE_INT)


func test_calendar() -> void:
	assert_eq(Calendar.format_date(0), "Year 1, Month 1, Day 1")
	assert_eq(Calendar.format_date(Calendar.DAYS_PER_YEAR + Calendar.DAYS_PER_MONTH + 4), "Year 2, Month 2, Day 5")
	assert_eq(Calendar.format_duration(Calendar.DAYS_PER_YEAR + Calendar.DAYS_PER_MONTH), "1 year, 1 month")
	assert_eq(Calendar.format_duration(0), "0 days")


## QA-20261003-4: guard for CLAUDE.md rule 5. Every CharacterData field must be
## saved by to_dict and restored by from_dict, so a new field that is left out
## fails here instead of silently resetting when a save is loaded.
func _script_vars(c: CharacterData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop in c.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(prop)
	return out


func test_every_character_field_is_saved() -> void:
	var c := new_character()
	var saved := c.to_dict()
	for prop in _script_vars(c):
		assert_true(saved.has(prop["name"]), "CharacterData.%s is missing from to_dict()" % prop["name"])


func test_every_character_field_survives_a_save() -> void:
	var c := new_character()
	# Simple fields get a generic non-default value; dictionaries need their real shape.
	for prop in _script_vars(c):
		var field: String = prop["name"]
		match int(prop["type"]):
			TYPE_BOOL:
				c.set(field, not bool(c.get(field)))
			TYPE_INT:
				c.set(field, int(c.get(field)) + 7)
			TYPE_FLOAT:
				c.set(field, float(c.get(field)) + 0.5)
			TYPE_STRING:
				c.set(field, "x_" + field)
			TYPE_ARRAY:
				(c.get(field) as Array).append("x_" + field)
	c.spouse_ranks = {"x_spouses": "wife"}
	c.pregnancy = {"partner": "x_spouses", "days_left": 30}
	c.attributes["charisma"] = 13
	c.spiritual_roots = {"fire": 77}
	Professions.add_xp(c, data(), "alchemist", 250.0)
	c.sect = {"id": "blood_lotus_sect", "rank": 1, "contribution": 450}
	c.add_item("qi_gathering_pill", 3)
	c.equipment = {"weapon": "iron_sword"}
	c.techniques = {"x_tech": {"level": 2, "xp": 12.5}}
	c.injuries = {"x_injury": 9}
	Buffs.add(c, "x_buff", "X Buff", 5, {"attack": 1.5})
	c.mission_cooldowns = {"x_mission": 400}
	c.trial_progress = {"fist_saint_grave": 2}
	c.training = {"assignment": "profession", "profession": "alchemist"}
	c.artifact_storage = {"spirit_stone": 12}
	c.reputation = {"azure_cloud_sect": 150}
	c.abode_storage = {"iron_ore": 4}
	c.secret_realms = {"verdant_remnant": {"opening": 2, "floor": 1}}
	c.grudges = {"npc_test_victim": 40}
	c.gratitude = {"npc_test_friend": 25}
	c.dao = {"sword_dao": {"level": 2, "progress": 30.5}}
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var before := c.to_dict()
	var after := restored.to_dict()
	for prop in _script_vars(c):
		var field: String = prop["name"]
		assert_eq(after.get(field), before.get(field), "CharacterData.%s does not survive a save" % field)
	for field in before:
		if before[field] is Dictionary:
			assert_false((before[field] as Dictionary).is_empty(), "test fixture: give dictionary field '%s' a value" % field)
