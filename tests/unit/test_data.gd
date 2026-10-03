extends TestCase
## Data files load and all cross-references are valid.


func test_data_loads_without_errors() -> void:
	assert_eq(data().load_errors.size(), 0, ", ".join(data().load_errors))


func test_realms_start_at_mortal_then_qi_refining() -> void:
	assert_eq(data().realms[0].id, "mortal")
	assert_eq(data().realms[1].id, "qi_refining")


func test_every_realm_has_stages_and_lifespan() -> void:
	for realm in data().realms:
		assert_gt(realm.stage_count(), 0, realm.id)
		assert_gt(realm.lifespan_years, 0, realm.id)
		assert_gt(realm.base_qi_per_day, 0.0, realm.id)


func test_lifespans_increase_with_realm() -> void:
	var realms := data().realms
	for i in range(1, realms.size()):
		assert_gt(realms[i].lifespan_years, realms[i - 1].lifespan_years, realms[i].id)


## F-005b balance rule: each breakthrough must add comfortably more lifespan than
## a 1.0x cultivator needs to reach the next one, so slow cultivators (~0.3x) and
## unlucky breakthrough streaks still rarely die of old age.
func test_lifespan_gain_outpaces_realm_time() -> void:
	var realms := data().realms
	for i in range(1, realms.size() - 1):
		var gain: int = realms[i + 1].lifespan_years - realms[i].lifespan_years
		var years := Cultivation.expected_realm_years(data(), i)
		assert_gt(float(gain), 10.0 * years, "%s: +%d years vs %.1f expected" % [realms[i].id, gain, years])


func test_required_professions_exist() -> void:
	for prof_id in ["alchemist", "blacksmith", "talisman_master", "array_master", "doctor"]:
		assert_true(data().professions.has(prof_id), prof_id)


func test_sects_cover_each_path() -> void:
	var tags := {}
	for sect: SectDef in data().sects.values():
		tags[sect.alignment_tag] = true
	for tag in ["righteous", "demonic", "neutral"]:
		assert_true(tags.has(tag), "no %s sect" % tag)
