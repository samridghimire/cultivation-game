extends TestCase
## QA-039: guards for a typical player's first Foundation Establishment year
## (sim: tests/sim/simulate_foundation_year.gd). Loose: C-031 may tighten them.

const FoundationYear := preload("res://tests/sim/foundation_year.gd")
const SEEDS := 10
const REALM := 2
## (region, sect) cells played: the worst-looking rogue and sect starts of the sim baseline.
const CELLS: Array = [["fallen_star_market", false], ["myriad_peaks_ridge", true]]


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_friendly_regions_include_start_region() -> void:
	assert_true(FoundationYear.friendly_regions(data(), REALM).has("qingshi_village"), "Qingshi has Foundation encounters")


func test_first_foundation_year_is_survivable() -> void:
	var gs := _root().get_node("GameState")
	for cell: Array in CELLS:
		var no_life := 0
		var won := 0
		var lost := 0
		for s in range(1, SEEDS + 1):
			var r: Dictionary = FoundationYear.play(gs, s, REALM, cell[0], cell[1])
			if int(r["lives_spent"]) == 0:
				no_life += 1
			won += int(r["won"])
			lost += int(r["lost"])
		assert_true(no_life >= 8, "%s: only %d of %d seeds spent no artifact life" % [cell, no_life, SEEDS])
		assert_true(won + lost == 0 or float(won) / float(won + lost) >= 0.5, "%s: won %d of %d fights" % [cell, won, won + lost])


func test_play_records_odds_and_stage_milestones() -> void:
	# QA-045: every fight fought has a rated odds entry; the fight_threats switch is deterministic per seed.
	var gs := _root().get_node("GameState")
	var r: Dictionary = FoundationYear.play(gs, 2, REALM, "azure_peak", true, 4, true)
	var again: Dictionary = FoundationYear.play(gs, 2, REALM, "azure_peak", true, 4, true)
	assert_eq((r["odds"] as Array).size(), int(r["won"]) + int(r["lost"]), "one rated odds per fight fought")
	assert_eq(r["odds"], again["odds"], "same seed, same fights")
	assert_true(int(r["stage_m3"]) <= int(r["stage"]), "stage never drops between month 3 and the end")
	for o: float in r["odds"]:
		assert_true(o >= 0.0 and o <= 1.0, "odds are a chance")


func test_first_core_formation_year_is_survivable() -> void:
	# QA-042: the same loose guard one realm up (sim: simulate_foundation_year.gd -- 10 3).
	var gs := _root().get_node("GameState")
	var realm := 3
	assert_true(FoundationYear.friendly_regions(data(), realm).has("myriad_peaks_ridge"), "Myriad Peaks Ridge has Core Formation encounters")
	for cell: Array in [["myriad_peaks_ridge", false], ["myriad_peaks_ridge", true]]:
		var no_life := 0
		for s in range(1, 6):
			var r: Dictionary = FoundationYear.play(gs, s, realm, cell[0], cell[1], 12)
			if int(r["lives_spent"]) == 0:
				no_life += 1
		assert_true(no_life >= 4, "%s: only %d of 5 seeds spent no artifact life" % [cell, no_life])
