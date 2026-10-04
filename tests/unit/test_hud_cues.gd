extends TestCase
## UI-006: the HUD warns when lifespan runs low and when a breakthrough is due.

const HUD := preload("res://src/ui/hud.gd")


func test_lifespan_category_thresholds() -> void:
	assert_eq(HUD.lifespan_category(50, 80), "")
	assert_eq(HUD.lifespan_category(12, 80), "warning")
	assert_eq(HUD.lifespan_category(4, 80), "danger")
	assert_eq(HUD.lifespan_category(3, 1000), "danger", "a few years left is always urgent")
	assert_eq(HUD.lifespan_category(100, 1000), "warning")
	assert_eq(HUD.lifespan_category(0, 0), "danger")


func test_bottleneck_hint_only_at_bottleneck() -> void:
	var d := data()
	var c := new_character()
	assert_eq(HUD.bottleneck_hint(c, d), "")
	var realm: RealmDef = d.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	assert_true(Cultivation.can_attempt_breakthrough(c, d))
	var hint: String = HUD.bottleneck_hint(c, d)
	assert_true(hint.begins_with("Bottleneck!"), hint)
	assert_true(hint.contains("%d%%" % int(Cultivation.breakthrough_chance(c, d) * 100)), hint)
	c.realm_index = d.realms.size() - 1
	realm = d.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	assert_eq(HUD.bottleneck_hint(c, d), "You stand at the peak of the known realms.")
