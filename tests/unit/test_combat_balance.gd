extends TestCase
## QA-007: the combat balance analysis (tests/sim/combat_balance.gd) and the
## guard that no fight the player cannot avoid is unwinnable where it appears.

const Balance := preload("res://tests/sim/combat_balance.gd")


func test_typical_player_gear_respects_grade_cap() -> void:
	var mortal := Balance.typical_player(data(), 0, 0)
	assert_eq(mortal.equipment.get("weapon", ""), "iron_sword")
	for realm in 4:
		var c := Balance.typical_player(data(), realm, 0, true)
		for slot: String in c.equipment:
			var item: Dictionary = data().items[c.equipment[slot]]
			assert_true(int(item["equip"]["grade"]) <= realm + 1, "%s grade fits realm %d" % [c.equipment[slot], realm])
			assert_false(item.get("tags", []).has("demonic"), "no evil artifacts in typical gear")
		for item_id in c.readied_talismans:
			assert_true(int(data().items[item_id]["combat"]["grade"]) <= realm + 1, "%s grade fits realm %d" % [item_id, realm])


func test_typical_player_beats_bare_player_odds() -> void:
	var enemy: Dictionary = data().enemies["mist_wolf"]
	var typical := Balance.win_rate(Balance.typical_player(data(), 1, 0), data(), enemy, 40)
	var bare := Balance.win_rate(Balance.bare_player(data(), 1, 0), data(), enemy, 40)
	assert_true(typical >= bare, "gear and techniques never hurt")


func test_appearances_cover_encounters_and_missions() -> void:
	var sources := {}
	for a: Dictionary in Balance.appearances(data()):
		sources[a["source"]] = a
	assert_true(sources.has("encounter village_boar"))
	assert_true(sources.has("mission cull_mist_wolves"))
	assert_true(sources["mission cull_mist_wolves"]["forced"], "missions are always fought")
	assert_eq(sources["encounter forest_wolf"]["realm_index"], 1)
	assert_false(sources["encounter forest_wolf"]["forced"], "a lethal Deadly foe is evaded")


func test_verdicts() -> void:
	assert_eq(Balance.verdict(0.0, 0.05), "unbeatable")
	assert_eq(Balance.verdict(1.0, 1.0), "trivial")
	assert_eq(Balance.verdict(0.2, 0.9), "hard")
	assert_eq(Balance.verdict(0.7, 1.0), "ok")


## A sect mission, an encounter choice or a non-lethal ambush is always fought,
## so a typical player at the peak of the realm where it opens must be able to win.
func test_no_forced_fight_is_unbeatable_where_it_appears() -> void:
	for a: Dictionary in Balance.appearances(data()):
		if not a["forced"]:
			continue
		var enemy: Dictionary = data().enemies[a["enemy"]]
		var realm: int = a["realm_index"]
		var peak := Balance.typical_player(data(), realm, data().realms[realm].stage_count() - 1)
		var rate := Balance.win_rate(peak, data(), enemy, 40)
		assert_true(rate >= Balance.UNBEATABLE_BELOW, "%s (%s) opens at %s but wins only %d%%" % [a["enemy"], a["source"], data().realms[realm].name, roundi(rate * 100)])


## QA-007b: a foe is first met at (or before) its own realm, so it is a real
## fight there instead of a pushover one realm later. A lethal foe met early
## is sensed as Deadly and evaded until the player can face it.
func test_no_enemy_first_appears_above_its_realm() -> void:
	var first := {}
	for a: Dictionary in Balance.appearances(data()):
		var enemy_id: String = a["enemy"]
		first[enemy_id] = mini(int(first.get(enemy_id, 999)), int(a["realm_index"]))
	for enemy_id: String in first:
		var own := data().realm_index_of(String(data().enemies[enemy_id]["realm"]))
		assert_true(first[enemy_id] <= own, "%s (%s) is first met at realm %d" % [enemy_id, data().realms[own].name, first[enemy_id]])


## QA-007d: same-realm fights carry tension, realm gaps stay nearly impossible.
func test_same_realm_fights_are_not_foregone() -> void:
	for realm in range(1, 5):
		var peak := data().realms[realm].stage_count() - 1
		for stage in [0, peak]:
			var rate := Balance.same_stage_rate(data(), realm, stage, 60)
			assert_true(rate >= 0.6 and rate <= 0.95, "%s stage %d: typical player wins %d%% vs a plain same-stage foe" % [data().realms[realm].name, stage, roundi(rate * 100)])
		var up := Balance.win_rate(Balance.typical_player(data(), realm, peak), data(), Balance.plain_enemy(data(), realm + 1, 0), 60)
		assert_true(up < 0.1, "%s peak beats the next realm %d%% of the time" % [data().realms[realm].name, roundi(up * 100)])


## QA-018: the veteran loadout is derived from data, never demonic or activated,
## and gets stronger with realm.
func test_veteran_loadout_is_derived_from_data() -> void:
	assert_eq(Balance.loadout(data(), 0), ["iron_fist", "stone_skin"] as Array[String])
	for realm in Balance.LATE_REALMS + 1:
		var arts := Balance.loadout(data(), realm)
		assert_eq(arts.size(), 2, "realm %d has a combat and a body art" % realm)
		for tech_id in arts:
			var def: TechniqueDef = data().techniques[tech_id]
			assert_true(def.activation.is_empty(), "%s is not a forbidden art" % tech_id)
			assert_true(data().realm_index_of(def.min_realm) <= realm, "%s is learnable at realm %d" % [tech_id, realm])
			assert_false(String(data().items[def.manual_item].get("description", "")).to_lower().contains("demonic"), "%s is not demonic" % tech_id)
	var v := Balance.veteran_player(data(), 4, 0)
	var t := Balance.typical_player(data(), 4, 0)
	assert_true(Combat.stats(v, data())["attack"] >= Combat.stats(t, data())["attack"], "a veteran hits at least as hard")


## QA-018: through Soul Formation, no fight the player cannot avoid is unwinnable
## for a veteran at the peak of the realm where it opens.
func test_no_forced_fight_is_unbeatable_for_veteran_through_soul_formation() -> void:
	for a: Dictionary in Balance.appearances(data()):
		var realm: int = a["realm_index"]
		if not a["forced"] or realm > Balance.LATE_REALMS:
			continue
		var peak := Balance.veteran_player(data(), realm, data().realms[realm].stage_count() - 1)
		var rate := Balance.win_rate(peak, data(), data().enemies[a["enemy"]], 40)
		assert_true(rate >= Balance.UNBEATABLE_BELOW, "%s (%s): veteran wins only %d%%" % [a["enemy"], a["source"], roundi(rate * 100)])


## QA-025: the Nascent Soul encounters, read at the player's stage on appearance
## (stage 0 of the encounter's min_realm), are never near-hopeless for a veteran
## when they cannot be evaded.
func test_forced_nascent_soul_fights_are_fair_on_appearance_for_veteran() -> void:
	var ns := data().realm_index_of("nascent_soul")
	var checked := 0
	for a: Dictionary in Balance.appearances(data()):
		if not a["forced"] or a["realm_index"] != ns:
			continue
		checked += 1
		var rate := Balance.win_rate(Balance.veteran_player(data(), ns, 0), data(), data().enemies[a["enemy"]], 40)
		assert_true(rate >= 0.15, "%s (%s): veteran on appearance wins only %d%%" % [a["enemy"], a["source"], roundi(rate * 100)])
	assert_gt(checked, 0)
